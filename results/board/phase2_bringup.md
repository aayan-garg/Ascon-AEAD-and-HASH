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

## 5. Exit Criteria Status

1. **Bare-metal C Execution:** Verified.
2. **AXI4-Lite Bus Handshake:** Verified (zero protocol deadlocks, write responses and read data routed correctly).
3. **GPIO Toggle:** Walking 1s across `led[0..3]` and all LEDs verified.
4. **RAM Data Path Integrity:** Scratchpad array write and readback verified.
5. **Physical Board Bring-Up Gate:** Ready for Vivado bitstream synthesis and Zybo Z7-10 JTAG programming (`board/zybo_z7_10.xdc`).
