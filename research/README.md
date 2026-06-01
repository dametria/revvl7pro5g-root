# REVVL 7 Pro 5G — Public Research Dump

> **Device:** T-Mobile REVVL 7 Pro 5G (TMRV07P5G, Pinehurst)
> **SoC:** Qualcomm SM6450 (Snapdragon 6 Gen 1, Parrot)
> **GPU:** Adreno 710 (A7xx, v1)
> **Bits:** SW_S88823AA1_V046 (Android 14, patch 2025-03-05) + V016 (Android 16, OTA)

## Root Exploit

**CVE-2025-21479** — Adreno GPU SMMU bypass. Confirmed working on V046.
See [main README](../README.md) for instructions.

## Directory Structure

```
research/
├── README.md                  # This file
├── firmware/                  # Firmware binaries
│   ├── a710_sqe_V046.fw       # GPU SQE firmware from V046 (VULNERABLE)
│   ├── a710_sqe_V016.fw       # GPU SQE firmware from V016 (PATCHED)
│   ├── a730_sqe_V046.fw       # Comparison firmware (same GPU family)
│   ├── a730_sqe_V016.fw
│   ├── gmu_gen70000_V046.bin  # GPU Management Unit firmware
│   ├── gmu_gen70000_V016.bin
│   ├── kernel_config_V046.gz  # Kernel .config (CONFIG_ options)
│   ├── cmdline.txt            # Kernel boot parameters
│   └── sepolicy_V046.bin      # SELinux policy binary
├── dumps/                     # Sanitized device dumps
│   ├── build_info.txt         # Build fingerprint, SoC, GPU, RAM, kernel
│   ├── cpuinfo.txt            # /proc/cpuinfo (8 cores: 4×A78 + 4×A55)
│   ├── partitions.txt         # Fastboot getvar all partition table
│   ├── kernel_modules.txt     # Loaded kernel modules (245 modules)
│   ├── fastboot_oem.txt       # Fastboot OEM commands (stripped ABL)
│   └── uefi_strings.txt       # Critical UEFI configuration strings
└── docs/                      # Analysis documents
    ├── CVE-2025-21479_ROOT_EXPLOIT.md    # Exploit mechanism detail
    ├── GPU_SQE_FIRMWARE_ANALYSIS.md      # Adreno 710 SQE firmware RE
    └── SESSION_2026-06-01_UEFI_BOOT_ANALYSIS.md  # UEFI/ABL/fastboot analysis
```

## Key Findings

### Bootloader
- **ABL:** Encrypted at rest, ELF32 wrapper. Same entry addr (0x9fa00000) across V046/V016.
- **UEFI:** 100% identical between V046 and V016 (6.6MB, 97 DXE modules).
- **Config:** `EnableShell=0x1`, `AllowNonPersistentVarsInRetail=0x1`, `EnableVariablePolicyEngine=0`
- **Fastboot:** Stripped ABL — only `oem device-info`, `oem permission <mode>` (T-Mo auth gate), `oem select-display-panel`, `oem off-mode-charge`.
- **uefivarstore:** Qcom PTBL format, near-empty (variables are non-persistent).

### GPU Firmware
- **V046:** `and $xx,$12,0x3` at 2 locations (0x260, 0x14dc) — **VULNERABLE**
- **V016:** All converted to `and $xx,$12,0x7` (3 instances). New additional hardening at 0x38a0 — **PATCHED**
- V046 firmware: 35,572 bytes. V016: 36,308 bytes (88% code rewritten).

### Kernel
- **V046:** 5.10.209-android12-9 (December 2024 build)
- **V016:** 5.10.236-android12-9 (January 2026)
- CONFIG_MODULES=yes (245 modules loaded), CONFIG_GKI=no
- CONFIG_KALLSYMS_ALL=yes, CONFIG_EFI_STUB=yes
- CONFIG_DM_VERITY=yes, CONFIG_SECURITY_SELINUX=yes
- `unprivileged_bpf_disabled=0`, `bpf_jit_enable=1` — eBPF JIT available

### CPU
- 8 cores: 4× Cortex-A78 (part 0xd41) + 4× Cortex-A55 (part 0xd05)
- No PAC, MTE, BTI — limited hardware security features
- SoC ID: 537, Platform: QRD, Revision: 1.0

### Open Attack Vectors (V046)
- UEFI Shell trigger (USB keyboard, GPIO, NVRAM) — `EnableShell=0x1`
- xbl_sc_test_mode partition — XBLTestMode.c module
- uefivarstore PTBL writes (AllowNonPersistentVarsInRetail=0x1)
- Macchiato TA X509 parser (TZ) — "Insecure Test Root CA1" in production tz.img
- EDL/Firehose via Linux

### Open Attack Vectors (V016)
- UEFI Shell (identical to V046)
- New ABL code (303KB, 88% rewritten vs V046)
- New GPU firmware — find non-IB_LEVEL bugs
- Kernel 5.10.236 — check CVE gap vs current LTS

## Disclaimer

All data sanitized — no serial numbers, IMEI, or personal identifiers. Technical analysis only.
