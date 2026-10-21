# Phase 2: RISC-V Core (PicoRV32) Bring-Up Report

- **Date:** 2026-10-21
- **Status:** `[x] SIMULATION VERIFIED; SYNTHESIS READY`
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

---

## 3. Firmware Toolchain & Compilation

- **Compiler:** GNU RISC-V Cross-Compiler (`riscv64-unknown-elf-gcc` v13.2.0 via WSL2 Ubuntu)
- **Target Flags:** `-march=rv32i -mabi=ilp32 -Os -nostdlib -Wl,-Bstatic`
- **Linker Script:** [`firmware/linker/bringup.ld`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/firmware/linker/bringup.ld)
- **Startup Code:** [`firmware/startup/crt0.S`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/firmware/startup/crt0.S)
- **Binary Image:** 384 bytes (96 words) generated into [`firmware/tests/gpio_toggle.hex`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/firmware/tests/gpio_toggle.hex)

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

Synthesized and placed/routed with AMD-Xilinx Vivado v2025.1.0 (`scripts/build_bitstream.tcl`):

| Resource Type | Used | Total Available | Utilization (%) |
|---|---|---|---|
| **Slice LUTs** | **1,001** | 17,600 | **5.69%** |
| - LUT as Logic | 957 | 17,600 | 5.44% |
| - LUT as Distributed RAM | 44 | 6,000 | 0.73% |
| **Slice Registers (FF)** | **569** | 35,200 | **1.62%** |
| **Block RAM (RAMB36E1)** | **4** | 60 | **6.67%** (16 KB) |
| **DSPs** | **0** | 80 | **0.00%** |
| **Clock Primitives (MMCM)** | **1** | 2 | **50.00%** |
| **Global Clock Buffers (BUFG)**| **2** | 32 | **6.25%** |

Full report: [`results/synthesis/utilization_bringup.txt`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/synthesis/utilization_bringup.txt)

---

## 6. Static Timing Analysis (STA) at 100 MHz

| Metric | Target | Measured | Timing Margin / Status |
|---|---|---|---|
| **Worst Negative Slack (WNS)** | $\ge 0.000\text{ ns}$ | **+3.098 ns** | **MET (3.098 ns positive setup slack)** |
| **Total Negative Slack (TNS)** | $0.000\text{ ns}$ | **0.000 ns** | **MET (0 failing endpoints)** |
| **Worst Hold Slack (WHS)** | $\ge 0.000\text{ ns}$ | **+0.036 ns** | **MET (No hold violations)** |
| **Total Hold Slack (THS)** | $0.000\text{ ns}$ | **0.000 ns** | **MET (0 failing endpoints)** |
| **Primary Clock (`sys_clk_pin`)**| 125 MHz (8.000 ns) | 125.000 MHz | **MET** |
| **CPU System Clock (`clk_100mhz`)**| 100 MHz (10.000 ns)| 100.000 MHz | **MET** |

Full report: [`results/timing/timing_bringup.txt`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/timing/timing_bringup.txt)

---

## 7. Bitstream Generation & Hardware Programming

- **Generated Bitstream:** `build/top_bringup.bit` (MD5 / bitgen completed successfully with 0 errors).
- **Physical Board Top-Level:** [`rtl/soc/top_bringup_board.sv`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/rtl/soc/top_bringup_board.sv)
- **Board Firmware:** [`firmware/tests/gpio_toggle_board.c`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/firmware/tests/gpio_toggle_board.c) with calibrated 0.25-second delays per step.
- **Automated JTAG Programming Script:** [`scripts/program_board.tcl`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/scripts/program_board.tcl)
  ```powershell
  & "C:\Xilinx\2025.1\Vivado\bin\vivado.bat" -mode batch -source scripts/program_board.tcl
  ```

