# REVVL 7 Pro 5G — Adreno 710 GPU SQE Firmware Analysis

## Source
- Device: REVVL 7 Pro 5G (SM6450, Adreno 710)
- File: `/vendor/firmware/a710_sqe.fw` (35,572 bytes)
- Build: V046, security patch 2025-03-05

## Version Status

**UNPATCHED** — mask `0x3`, not `0x7`.

The firmware IS vulnerable to CVE-2025-21479. Samsung Galaxy S24 firmware was patched in v676 (May 2025) changing all instances of `and $xx, $12, 0x3` to `and $xx, $12, 0x7`. Our firmware still uses `0x3`.

## Vulnerable CP_SMMU_TABLE_UPDATE Handler

Located at **0x25c** in firmware:

```
0x025c: b80300aa    cread $03, [$00 + 0xaa]
0x0260: 2a440003    AND $04, $12, 0x3       ← VULN: 4 & 3 = 0 → bypass!
0x0264: 98641813    USHR $03, $03, $04
0x0268: c860004a    BRNE $03, 0, #0x4a      ← exit if NOT kernel RB
0x026c: 01000000    NOP
-- ACTUAL SMMU MODIFY CODE FOLLOWS --
0x0270: 981f1006    
0x0274: c8430002    
...
```

**Attack:** `CP_SET_DRAW_STATE` sets IB_LEVEL = 4 (SDS). Firmware checks `IB_LEVEL & 0x3 == 0`. Since `4 & 3 = 0`, the check passes and the firmware executes the privileged SMMU table modification code.

## Second instance at 0x14dc

Same vulnerability pattern at offset 0x14dc:
```
0x14dc: 0300442a    AND $04, $12, 0x3
0x14e0: 13186498    USHR $03, $03, $04
0x14e4: cfff60c8    BRNE $03, 0, #0xfff
```
Different branch target, same vulnerability.

## Patched firmware comparison

| Firmware | IB_LEVEL mask | Vulnerable |
|----------|--------------|------------|
| a710_sqe.fw (ours) | `0x3` | ✅ YES |
| Galaxy S24 v676 (May 2025) | `0x7` | ❌ Patched |

## CP Opcodes Used by Exploit

| CP Opcode | Value | Function |
|-----------|-------|----------|
| CP_SET_MODE | 0x2a | Enable immediate draw state |
| CP_SET_DRAW_STATE | 0x43 | Set IB_LEVEL=4 (SDS), jump to draw state |
| CP_SMMU_TABLE_UPDATE | 0x53 | Modify SMMU page tables |
| CP_MEM_WRITE | 0x3d | Write to physical memory via GPU |
| CP_MEM_TO_MEM | 0x73 | Copy from physical memory to GPU buffer |
| CP_WAIT_FOR_IDLE | 0x26 | Pipeline barrier |
| CP_WAIT_FOR_ME | 0x13 | CP pipeline barrier |
| CP_NOP | 0x10 | No operation |

## Packet Format (Type7)

```
CP_TYPE7_PKT = (7 << 28) | (count << 0) | parity(count) << 15 | 
               (opcode & 0x7F) << 16 | parity(opcode) << 23
```

## Artifacts
- `C:\Users\kukuruza\AppData\Local\Temp\a710_sqe.fw` — raw firmware
- `C:\Users\kukuruza\AppData\Local\Temp\a730_sqe.fw` — comparison (74KB)
- `C:\Users\kukuruza\AppData\Local\Temp\gmu_gen70000.bin` — GPU management firmware
