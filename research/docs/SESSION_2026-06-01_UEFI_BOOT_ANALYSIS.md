# REVVL 7 Pro 5G — Сессия 2026-06-01: UEFI/ABL/Fastboot Анализ

## Состояние устройства
- Build: `SW_S88823AA1_V046` (OTA защита работает, не обновился)
- Bootloader: locked (`unlocked:no`, `Device critical unlocked: false`)
- Kernel base: `0xffffff8008000000` (найден через perf_event_open ранее)
- KGSL: magic `0x09`, GPU command submission работает (ret=0), но CP-команды не исполняются
- EDL: вход работает (PID:9008), но Sahara handshake — USB bulk timeout (нужен Linux)

## Fastboot A4 Enumeration

### Работающие команды
- `oem device-info` — `Device unlocked: false`, `Verity mode: true`
- `getvar all` — полный список разделов и переменных

### Не работают
- `oem help` — `unknown command` (18+ команд)
- `flashing get_unlock_ability` — `permission denied, auth needed`
- `fetch` — не поддерживается устройством

### Критические переменные
- `kernel: uefi` — ядро загружается через UEFI, не ABL напрямую
- `product: Pinehurst` — кодовое имя
- `current-slot: a` — активный слот

## Ключевые разделы (из `getvar all`)

| Раздел | Размер | Блок | Назначение | Уровень угрозы |
|--------|--------|------|------------|----------------|
| **uefivarstore** | 512KB | sde69 | UEFI NVRAM (BootOrder, BootNext, BDS vars) | **S-TIER** |
| **devinfo** | 4KB | sde60 | Unlock state (offsets 0x10/0x18 → 0x01) | **S-TIER** |
| **xbl_sc_test_mode** | 64KB | sde78 | XBL test mode флаги (`XBLTestMode.c`) | **S-TIER** |
| **spunvm** | 32MB | sde76 | SPU NVM (device keys, provisioning) | A |
| **secdata** | 28KB | sde70 | Security config | A |
| **rtice** | 512KB | sde77 | Runtime Integrity Check | B |
| **tzsc** | 128KB | sde75 | TZ Secure Channel | B |
| **dip** | 1MB | sde61 | Device Information | B |
| **storsec** | 128KB | sde71 | Storage Security | B |

### Доступность
- Все блочные устройства: `brw-------` (root only)
- `/sys/firmware/efi/` — **НЕ СУЩЕСТВУЕТ** (UEFI runtime services не экспортируются в Linux)
- Прямая запись возможна только через EDL или root

## UEFI Firmware Volume Анализ

### Структура uefi.img
```
uefi.img (2,691,072 bytes)
├── ELF64 wrapper
│   ├── Machine: ARM64 (AArch64)
│   ├── Entry: 0xA7000000
│   ├── 1× PT_LOAD: vaddr=0xA7000000, size=0x28F000, flags=RWX
│   └── Нет section headers (стрипнут)
├── Qcom ext header (0x28 bytes)
│   ├── ImageSize = 0x14003828
│   └── FV GUID = 8C8CE578-8A3D-4F1C-9935-896185C32DD3
├── FV header (0x48 bytes от _FVH)
│   ├── Signature: _FVH
│   ├── Attributes: 0x000CFFFE
│   ├── HeaderLength: 72
│   ├── Revision: 0x02
│   └── BlockMap: 655 × 4096 байт
└── FFS files (4):
    ├── [0] SEC_CORE (290,840 bytes) — 8AF09F13-44C5-96EC-1437-DD899CB5EE5D
    ├── [1] FREEFORM (7,747 bytes)  — DDE58710-41CD-4306-DBFB-3FA90BB1D2DD
    ├── [2] FV_IMAGE (1,367,965 bytes) — GZIP → 3,952,648 bytes → 58 PE модулей
    └── [3] FV_IMAGE (970,288 bytes)  — GZIP → 2,711,560 bytes → 39 PE модулей
```

### Формат сжатия
- FV_IMAGE body: GUID-defined section (type 0x02)
  - Section GUID: 1D301FE9-BE79-4353-91C2-D23BC959AE0C (Qcom-специфичный)
  - GZIP магия (`1f 8b`) по смещению +24 от начала body
- Распакованные файлы сохранены в `%TEMP%\uefi_extracted\`

## Инвентаризация DXE модулей (97 PE total)

### Критические модули (FV2)

| Модуль | Роль | Файл |
|--------|------|------|
| **QcomBds** | Boot Device Selection | QcomBds.AutoGen.c |
| **Shell** | UEFI Shell | Enter Shell menu option |
| **VerifiedBootDxe** | Android Verified Boot | VerifiedBootDxe.AutoGen.c |
| **SecureBoot** | UEFI Secure Boot | + SecurityToggleApp |
| **SecurityStubDxe** | Security architecture | SecurityStubDxe.AutoGen.c |
| **DxeCore** | DXE Core dispatcher | DxeCoreEntryPoint.c |
| **RuntimeDxe** | Runtime services | |
| **CapsuleRuntimeDxe** | Firmware updates | |
| **CpuDxe** | CPU management | ArmCpuDxe.AutoGen.c |

### Консоль / HID
- `ConPlatformDxe`, `ConSplitterDxe`, `GraphicsConsoleDxe`, `TerminalDxe`, `SerialDxe`
- `HiiDatabase`, `EnglishDxe`

### USB стек
- `UsbDxe`, `UsbKbDxe`, `UsbMassStorageDxe`, `XhciDxe`
- Поддержка USB-клавиатур подтверждена

### Storage
- `PartitionDxe`, `DiskIoDxe`, `Fat`, `EmmcDxe`

### Платформа Qcom
- `ClockDxe`, `PmicDxe`, `SmemDxe`, `ButtonsDxe`
- `ArmGicDxe`, `ArmTimerDxe`, `RngDxe`

### Критически ОТСУТСТВУЮЩИЕ модули
- **VariableRuntimeDxe** — нет отдельного модуля; переменные встроены в другой компонент
- **BootManagerMenuApp** — встроен в QcomBds (нет отдельного UiApp)
- **LinuxLoader** — не модуль, а BDS boot path (строка конфигурации)
- **AuthVariable** — не найден
- **VariableSmm** — не найден
- **TcgDxe / TrEEDxe** — не найдены (TPM отсутствует?)

## Строки конфигурации UEFI

```
DefaultBDSBootApp = "LinuxLoader"
EnableOEMSetupAppInRetail = 0x0
AllowNonPersistentVarsInRetail = 0x1    ← переменные можно писать!
EnableShell = 0x1                        ← UEFI Shell включен!
EnableLogFsSyncInRetail = 0x1
EnableVariablePolicyEngine = 0           ← политика переменных выключена
EnableMultiCoreFvDecompression = 1
EnableUefiSecAppDebugLogDump = 0x0
EnableDisplayThread = 0x1
EnableDisplayImageFv = 0x1
EnableSDHCSwitch = 0x1
```

## Строки Shell (из FV2)

```
"Enter Shell"
"Launch the Shell, no startup script is run"
"Label = Enter Shell"
```

## XBL Test Mode (подтверждение)

Из `xbl.img` strings:
```
Pegging-tool : Result is %x and test_mode is %x
XBLTestMode.c           ← исходный файл модуля
test_mode               ← переменная
debug board connected
debug policy applied
no debug policy applied
```

Раздел `xbl_sc_test_mode` (64KB) — вероятно хранит флаг test_mode.

## Маппинг Xiaomi → REVVL (финальный вердикт)

| Stage | Xiaomi | REVVL аналог | Вердикт |
|-------|--------|-------------|---------|
| 1 | MQSAS binder → shell-exec | `com.factory.mmigroup` AfterSaleMode (system_priv) | **НЕ ПРОВЕРЕН** — нужен androguard |
| 2 | Unsigned UEFI из efisp FAT | **UEFI Shell trigger** (`EnableShell=0x1`) или **BDS redirect** через uefivarstore (`AllowNonPersistentVars=1`) | **ОСНОВНОЙ ВЕКТОР** |
| 3 | `oem set-gpu-preemption` arg-inject | — | **НЕПРИМЕНИМ** — oem команд нет |

## Пути атаки (приоритет)

### 🥇 #1: EDL → devinfo/uefivarstore (быстрый)
- Linux live USB → `edl.py r devinfo` → патч 0x10/0x18 → BL unlock
- Блокиратор: Sahara USB timeout (должен решиться на Linux)

### 🥈 #2: UEFI Shell trigger (мощный, требует RE)
- Ghidra на QcomBds → найти триггер Shell меню
- Гипотезы:
  - Vol- / Vol+ кнопка при загрузке
  - USB клавиатура → Esc/F2
  - Boot failure → fallback to menu
  - NVRAM переменная `BootManagerMenu`
- Если Shell активирован:
  - UEFI Shell → `setvar BootNext` → attacker EFI app
  - UEFI Shell → `mm` (memory map) → доступ к переменным
  - UEFI Shell → `dmpstore` → дамп всех переменных

### 🥉 #3: XBL Test Mode (исследовательский)
- Ghidra на xbl.img → reverse `XBLTestMode.c`
- Понять что включает `test_mode`
- Если bypass verifier → unsigned boot

### #4: MMIGroup App (Stage-1)
- androguard на `MMIGroup_NoIcon.apk` (system_priv)
- Поиск binder методов для shell-exec

### #5: KGSL GPU Root (резерв)
- Нужны Adreno 710 CP-opcode'ы
- CAF исходники или утечка

## Следующие конкретные шаги

1. **Ghidra анализ QcomBds** (в FV2):
   - Найти функцию, добавляющую "Enter Shell" в меню
   - Найти код проверки `EnableShell = 0x1`
   - Найти условие активации Boot Manager меню
   
2. **Ghidra анализ xbl.img** — reverse `XBLTestMode.c`:
   - Что делает test_mode?
   - Можно ли его активировать через `xbl_sc_test_mode` раздел?

3. **EDL на Linux** — решить проблему Sahara USB:
   - `edl.py` должен работать без timeout'ов
   - Цель: прочитать devinfo и uefivarstore

## Артефакты

- `C:\Users\kukuruza\Downloads\REVVL 7 PRO - A16 OTA UNPACKED\` — A16 OTA
- `C:\Users\kukuruza\Documents\Claude\revvl\A16_OTA_analysis\` — strings extracts + avbtool
- `C:\Users\kukuruza\AppData\Local\Temp\uefi_extracted\` — распакованные FV2/FV3 (3.9MB, 2.7MB)
- `C:\Users\kukuruza\AppData\Local\Temp\parse_fv_v2.py` — парсер FFS
- `C:\Users\kukuruza\AppData\Local\Temp\parse_decompress_fv.py` — распаковщик FV
- `C:\Users\kukuruza\AppData\Local\Temp\scan_modules.py` — инвентаризация модулей
- `C:\Users\kukuruza\AppData\Local\Temp\scan_fv.py` — сканер PE/Shell строк
- `C:\Users\kukuruza\Downloads\ghidra_12.1_PUBLIC_20260513\` — Ghidra 12.1
- `/data/local/tmp/kf`, `/data/local/tmp/kf_test` — KGSL бинарники на устройстве
