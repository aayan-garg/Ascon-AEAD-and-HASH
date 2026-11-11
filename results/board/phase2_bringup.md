# Phase 2: RISC-V Core (PicoRV32) Bring-Up Report

- **Date:** 2026-10-21 (Updated November 5, 2026)
- **Status:** `[x] SIMULATION VERIFIED; TIMING CLOSED & BITSTREAM GENERATED`
- **Core:** PicoRV32 RV32I AXI4-Lite Core (`rtl/soc/picorv32.v`)
- **Top-Level:** `rtl/soc/top_bringup.sv`
- **Testbench:** `tb/unit/tb_picorv32_bringup.sv`
- **Firmware:** `firmware/tests/gpio_toggle.c`

---

## 1. System Architecture

```
+--------------------------------------------------------------------------+
| top_bringup (Zybo Z7-10 PL Fabric)                                       |
|                                                                          |
|  +--------------------+                                                  |
|  |   PicoRV32 RV32I   |                                                  |
|  |     (picorv32_axi) |                                                  |
|  +---------+----------+                                                  |
|            | AXI4-Lite Master (100 MHz)                                  |
|  +---------v----------------------------------------------------------+  |
|  | AXI4-Lite Address Decoder                                          |  |
|  +---------+-----------------------------------+----------------------+  |
|            | 0x0000_0000 - 0x0000_3FFF         | 0x1000_0000          |
|  +---------v-----------+             +---------v----------+           |
|  | 16 KB BRAM Slave    |             | AXI4-Lite GPIO     |           |
|  | (Instruction & Data)|             | Peripheral Slave   |           |
|  +---------------------+             +---------+----------+           |
|                                                |                      |
|                                     +----------v-----------+          |
|                                     | [3:0] LEDs (LD0..LD3)|          |
|                                     | [6:4] RGB LED (LD6)  |          |
|                                     | [31]  Test Pass Flag |          |
|                                     +----------------------+          |
+--------------------------------------------------------------------------+
```

---

## 2. Address Map

| Address Range | Size | Access | Description |
|---|---|---|---|
| `0x0000_0000 - 0x0000_3FFF` | 16 KB | R/W | Unified instruction and data Block RAM |
| `0x1000_0000 - 0x1000_000F` | 16 B | R/W | GPIO Output Control (LEDs, RGB LED, Test Flag) |
| `0x4000_0000 - 0x4000_0FFF` | 4 KB | R/W | Ascon Cryptographic Engine & DMA Registers |

---

## 3. Firmware Toolchain & Compilation

- **Compiler:** GNU RISC-V Cross-Compiler (`riscv64-unknown-elf-gcc` v13.2.0 via WSL2 Ubuntu)
- **Target Flags:** `-march=rv32i -mabi=ilp32 -Os -nostdlib -Wl,-Bstatic`
- **Linker Script:** [`firmware/linker/bringup.ld`](../../firmware/linker/bringup.ld)
- **Startup Code:** [`firmware/startup/crt0.S`](../../firmware/startup/crt0.S)
- **Binary Image:** 384 bytes (96 words) generated into [`firmware/tests/gpio_toggle.hex`](../../firmware/tests/gpio_toggle.hex)

---

## 4. Simulation Execution Log

Executed on AMD-Xilinx Vivado Simulator v2025.1.0 (`tb/unit/tb_picorv32_bringup.sv`):

```text
[BRAM] Initializing 16 KB BRAM from: firmware/tests/gpio_toggle.hex
================================================================
STARTING PICORV32 BRING-UP TESTBENCH: tb_picorv32_bringup
Target Core: PicoRV32 RV32I AXI Core
Firmware:    firmware/tests/gpio_toggle.hex
Clock:       100 MHz (Period: 10 ns)
================================================================
[TIME 100000] Reset de-asserted. CPU executing from 0x00000000...
[TIME 1975000 | Cycle 188] GPIO LED transition: 0000 -> 0001 (Hex: 0x1)
[TIME 4255000 | Cycle 416] GPIO LED transition: 0001 -> 0010 (Hex: 0x2)
[TIME 6535000 | Cycle 644] GPIO LED transition: 0010 -> 0100 (Hex: 0x4)
[TIME 8815000 | Cycle 872] GPIO LED transition: 0100 -> 1000 (Hex: 0x8)
[TIME 11095000 | Cycle 1100] GPIO LED transition: 1000 -> 1111 (Hex: 0xf)

----------------------------------------------------------------
[SUCCESS] Test Pass Marker detected (GPIO bit 31 asserted)!
  Cycles Elapsed:      1384 cycles
  Execution Time:      13935000 ns
  Walking 1s Observed: [LED0:1, LED1:1, LED2:1, LED3:1, ALL:1]
  Final LED State:     1111 (Hex: 0xf)
  Scratch RAM Read/Write Verification: PASSED
----------------------------------------------------------------
ALL PHASE 2 CRITERIA SATISFIED: PicoRV32 bring-up VERIFIED!
```

---

## 5. Post-Routing FPGA Utilization (Zybo Z7-10 / XC7Z010-1CLG400C)

Synthesized and placed/routed with AMD-Xilinx Vivado v2025.1.0:

### Full SoC Bring-Up with Ascon Coprocessor & DMA (`top_bringup_board`)
*Report: [`results/synthesis/utilization_bringup.txt`](../synthesis/utilization_bringup.txt)*

| Resource Type | Used | Total Available | Utilization (%) |
|---|:---:|:---:|:---:|
| **Slice LUTs** | **5,088** | 17,600 | **28.91%** |
| - LUT as Logic | 5,044 | 17,600 | 28.66% |
| - LUT as Distributed RAM | 44 | 6,000 | 0.73% |
| **Slice Registers (FF)** | **5,486** | 35,200 | **15.59%** |
| **Block RAM (RAMB36E1)** | **4** | 60 | **6.67%** (16 KB) |
| **DSPs** | **0** | 80 | **0.00%** |
| **Clock Primitives (MMCM)** | **1** | 2 | **50.00%** |
| **Global Clock Buffers (BUFG)**| **2** | 32 | **6.25%** |

*(Standalone baseline PicoRV32 core alone accounts for ~1,001 LUTs and 569 FFs; the integrated Ascon coprocessor, DMA engine, boot controller, and fetch guard comprise the remainder).*

---

## 6. Static Timing Analysis (STA) at 100 MHz

*Report: [`results/timing/timing_bringup.txt`](../timing/timing_bringup.txt)*

| Metric | Target | Measured | Timing Margin / Status |
|---|---|:---:|---|
| **Worst Negative Slack (WNS)** | $\ge 0.000\text{ ns}$ | **+1.510 ns** | **MET (1.510 ns positive setup slack)** |
| **Total Negative Slack (TNS)** | $0.000\text{ ns}$ | **0.000 ns** | **MET (0 failing endpoints)** |
| **Worst Hold Slack (WHS)** | $\ge 0.000\text{ ns}$ | **+0.027 ns** | **MET (No hold violations)** |
| **Total Hold Slack (THS)** | $0.000\text{ ns}$ | **0.000 ns** | **MET (0 failing endpoints)** |
| **Maximum Frequency ($F_{max}$)**| $\ge 100\text{ MHz}$ | **117.79 MHz** | **MET** |

---

## 7. Implementation & Hardware Scope Status

Routed timing closed cleanly at +1.510 ns WNS ($F_{max} = 117.79\text{ MHz}$) and bitstream generation was completed via [`scripts/build_bitstream.tcl`](../../scripts/build_bitstream.tcl) (`build/top_bringup.bit`, raw build transcript archived in [`results/board/bitstream_build_raw.log`](bitstream_build_raw.log)). Physical constraints are enforced in [`board/zybo_z7_10.xdc`](../../board/zybo_z7_10.xdc) for [`rtl/soc/top_bringup_board.sv`](../../rtl/soc/top_bringup_board.sv), with on-board execution procedures and recorded results tracked in [`results/board/HARDWARE_RUNBOOK.md`](HARDWARE_RUNBOOK.md).
