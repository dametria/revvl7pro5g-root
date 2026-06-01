# REVVL 7 Pro 5G — Root Exploit

**CVE-2025-21479** — Adreno GPU SMMU bypass → **transient root** для T-Mobile REVVL 7 Pro 5G.

## Устройство

| Параметр | Значение |
|----------|---------|
| Модель | T-Mobile REVVL 7 Pro 5G (TMRV07P5G) |
| Кодовое имя | Pinehurst |
| SoC | Qualcomm SM6450 (Snapdragon 6 Gen 1) |
| GPU | Adreno 710 (A7xx family) |
| Ядро | 5.10.209-android12 |
| Билд | V046 (SW_S88823AA1_V046, патч 2025-03-05) **уязвим** |
| RAM | 8GB |

## Как работает

CVE-2025-21479 (июнь 2025, Qualcomm). Adreno A7xx firmware баг: `CP_SET_DRAW_STATE` устанавливает IB_LEVEL=4 (SDS). Привилегированная команда `CP_SMMU_TABLE_UPDATE` проверяет `IB_LEVEL & 0x3 == 0`. **4 & 3 = 0 → bypass!**

GPU firmware думает что команда из kernel ring buffer (уровень 0), разрешает изменение SMMU page tables → arbitrary physical memory read/write → kernel memory patch → root.

## Сборка

```bash
# Windows NDK 27
set NDK=C:\Users\%USERNAME%\Android\ndk\27.0.12077973
%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android34-clang.cmd -o cheese cheese.c -static
```

Или: `build_win.cmd` в репозитории.

## Запуск

```bash
adb push cheese /data/local/tmp/
adb shell chmod 755 /data/local/tmp/cheese

# Способ 1 (рекомендуемый):
adb shell CHEESE_ATTEMPT=0 /data/local/tmp/cheese id

# Способ 2 (ручной spray address):
adb shell CHEESE_PHYADDR=0xa0000000 /data/local/tmp/cheese id
```

## Успешный вывод

```
uid=0(root) gid=0(root) groups=0(root) context=u:r:shell:s0
```

## Параметры SM6450

| Параметр | Значение |
|----------|---------|
| KGSL magic | 0x09 |
| kgsl-3d0 ioctl CREATE | 0x09:0x13 |
| kgsl-3d0 ioctl MAP_USER_MEM | 0x09:0x15 |
| kgsl-3d0 ioctl GPU_COMMAND | 0x09:0x4A |
| kernel physical base | 0xA8000000 |
| kernel virtual base | 0xffffff8008000000 |
| Рабочие spray-адреса | 0xfebeb000, 0xd0b3b000, 0xa0000000, 0xd5cf0000 |

## Ограничения

- **Transient root** — переживает reboot (требуется ручной запуск после каждой перезагрузки)
- Kernel panic **исправлен** — PTE в swapper_pg_dir восстанавливается после root
- Spray-адрес вероятностный (~50-70% успех в зависимости от бута, 4 retry)
- Не даёт BL unlock — ABL игнорирует модифицированный devinfo на данном устройстве

## Безопасность

- **НЕ ПИСАТЬ** в boot или system разделы — BRICK
- **НЕ ИСПОЛЬЗОВАТЬ** Magisk "Install" кнопку — BRICK
- `CHEESE_ATTEMPT` и `CHEESE_PHYADDR` не деструктивны — можно пробовать многократно

## Research Dump

В директории [`research/`](research/) — публичные материалы для изучения устройства другими исследователями:

| Категория | Содержание |
|-----------|-----------|
| **firmware/** | GPU SQE (V046+V016), GMU, kernel config, cmdline, SELinux policy |
| **dumps/** | Таблица разделов, OEM-команды, UEFI-конфиг, сборка, SoC-параметры |
| **docs/** | Механика эксплойта, анализ GPU firmware, UEFI/ABL/fastboot разбор |

**Ключевые находки:**
- **GPU firmware V046** — уязвим (`and $xx,$12,0x3`), V016 полностью патч (`0x3→0x7` + доп. hardening)
- **UEFI идентичен** между V046 и V016 — `EnableShell=0x1`, `AllowNonPersistentVarsInRetail=0x1`
- **ABL зашифрован** в покое, 88% различается между V046 и V016
- **Ядро:** 5.10.209 (V046) → 5.10.236 (V016), 245 модулей, без GKI, eBPF JIT включён

## Благодарности

- [zhuowei/cheese](https://github.com/zhuowei/cheese) — оригинальный PoC
- [FreeXR](https://github.com/FreeXR/eureka_panther-adreno-gpu-exploit-1) — улучшенная версия
- Project Zero — Adrenaline
- Freedreno — регистры Adreno GPU
