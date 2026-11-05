# Phase 6 — Accelerator Bus Integration (AXI4-Lite) Summary

- **Date:** 2026-10-21 14:34:00 UTC
- **Status:** `[x] VERIFIED PASS (all BFM and SoC tests passed)`
- **Bus Standard:** ARM AMBA AXI4-Lite (ARM IHI 0022E)
- **Base Address:** `0x4000_0000` (4 KB Window: `0x4000_0000` – `0x4000_0FFF`)
- **Target CPU:** PicoRV32 RV32I AXI Core

---

## 1. Architectural Implementation Overview

Phase 6 implements the memory-mapped control plane and bus interface bridging the PicoRV32 RISC-V host CPU with the Ascon AEAD/Hash cryptographic engine:

| Module / File | Purpose | Verification Artifact |
|---|---|---|
| [`rtl/bus/axil_regs.sv`](../../rtl/bus/axil_regs.sv) | Full AXI4-Lite Slave Register File & Coprocessor Bridge | BFM Testbench [`tb_axil_regs.sv`](../../tb/integration/tb_axil_regs.sv) (**100% PASS**) |
| [`rtl/soc/top_bringup.sv`](../../rtl/soc/top_bringup.sv) | SoC Top-Level: PicoRV32 + 16 KB BRAM + GPIO + Ascon Coprocessor | SoC Integration Testbench [`tb_soc_ascon.sv`](../../tb/integration/tb_soc_ascon.sv) (**100% PASS**) |
| [`firmware/tests/accel_hash_test.c`](../../firmware/tests/accel_hash_test.c) | Bare-Metal C RISC-V Firmware Driver & KAT Validator | Executed in SoC simulation; elapsed 1,027 cycles |

---

## 2. Register Map Implementation ([`docs/register_map.md`](../../docs/register_map.md))

All 32-bit registers were implemented and verified with strict protocol compliance:

| Offset | Register | Access | Verified Behavior |
|:---:|:---:|:---:|---|
| `0x00` | `CTRL` | R/W | `START` (bit 0, self-clearing), `MODE` (bit 1), `DEC` (bit 2), `SOFT_RST` (bit 3), `DMA_AUTO` (bit 4) |
| `0x04` | `STATUS` | RO / W1C | `BUSY` (bit 0), `DONE` (bit 1, W1C), `ERROR` (bit 2, W1C), `TAG_OK` (bit 3), `FSM_STATE` (bits 7:4) |
| `0x08` | `AD_LEN` | R/W | 32-bit associated data length in bytes |
| `0x0C` | `MSG_LEN` | R/W | 32-bit plaintext / ciphertext / message length in bytes |
| `0x10 - 0x1C` | `KEY_0 .. KEY_3` | WO | **Write-Only:** Reads return strictly `0x0000_0000` to prevent key readout (§2.5) |
| `0x20 - 0x2C` | `NONCE_0 .. NONCE_3` | R/W | 128-bit Nonce words |
| `0x30 - 0x3C` | `TAG_0 .. TAG_3` | R/W | Holds expected tag during decryption; holds computed tag after encryption |
| `0x40 - 0x5C` | `DIGEST_0 .. DIGEST_7` | RO | 256-bit Ascon-Hash256 digest output |
| `0x60 - 0x6C` | `DMA_*` | R/W | DMA source address, transfer length, control, and status registers |
| `0x70` | `IRQ_EN` | R/W | Interrupt enable mask (Done bit 0, Error bit 1) |
| `0x74 - 0x78` | `DATA_IN_0/1` | WO | CPU direct PIO data write registers (writing `DATA_IN_1` strobes 64-bit word) |
| `0x7C` | `CORE_ID` | RO | Returns hardware identification string `0x4153_4331` (`"ASC1"`) |
| `0x400 - 0x7FC`| `PT_BUFFER` | RO | Plaintext shadow buffer memory window (gated by `tag_ok`) |

---

## 3. Bus-Functional-Model (BFM) Verification Results ([`tb_axil_regs.sv`](../../tb/integration/tb_axil_regs.sv))

| Test ID | Objective | Stimulus / Access | Result | Status |
|---|---|---|---|---|
| **BFM-1** | Hardware Identification | Read `0x7C` (`CORE_ID`) | Returned `0x4153_4331` (`"ASC1"`), `resp = OKAY` | `PASS` |
| **BFM-2** | Secret Key Write-Only Gate | Write `0xDEADBEEF` to `KEY_0`; read back | Read returned strictly `0x0000_0000` | `PASS` |
| **BFM-3** | R/W Registers Integrity | Write/read `AD_LEN`, `MSG_LEN`, `NONCE_0` | Read data matches written values | `PASS` |
| **BFM-4** | Sub-word & Unaligned Rejection | `wstrb = 4'b0001`, unaligned read `0x09`, unmapped read `0xEC` | All rejected with `resp = 2'b10` (`SLVERR`) | `PASS` |
| **BFM-5** | End-to-End Hash256 Execution | `MSG_LEN = 0`, `CTRL = 0x03`, poll `STATUS.DONE`, read `DIGEST_0..7` | Exact bit match against NIST KAT Count 1; W1C clears `DONE` | `PASS` |
| **BFM-6** | End-to-End AEAD128 Execution | Write Key/Nonce, `AD_LEN=0`, `MSG_LEN=0`, `CTRL=0x01`, read `TAG_0..3` | Exact bit match against NIST KAT Count 1 | `PASS` |

---

## 4. Bare-Metal SoC Integration Verification ([`tb_soc_ascon.sv`](../../tb/integration/tb_soc_ascon.sv))

- **CPU Core:** PicoRV32 RV32I executing instructions from 16 KB BRAM.
- **Firmware:** Compiled C binary [`accel_hash_test.c`](../../firmware/tests/accel_hash_test.c) via `riscv64-unknown-elf-gcc`.
- **Observed Flow:**
  1. CPU initialized BRAM and peripheral bus.
  2. CPU validated `CORE_ID == 0x4153_4331`.
  3. CPU triggered Ascon-Hash256, polled `STATUS`, verified 8-word digest against NIST Count 1.
  4. CPU triggered Ascon-AEAD128, polled `STATUS`, verified 4-word tag against NIST Count 1.
  5. CPU asserted `test_pass` flag (`GPIO[31] = 1`) and illuminated discrete LEDs (`0xF`).
- **Timing:** Completed all checks and asserted `test_pass` in **1,027 clock cycles** (10.365 µs @ 100 MHz).
- **Exit Gate Status:** Fully satisfied and verified.
