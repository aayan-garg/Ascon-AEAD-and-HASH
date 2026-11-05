# Phase 7 — Direct Memory Access (DMA) Integration Summary

- **Date:** 2026-10-21 15:07:00 UTC
- **Status:** `[x] VERIFIED PASS (40/40 boundary assertions passed)`
- **Architecture:** Dedicated Dual-Port BRAM Master Engine (Port B) & Valid/Ready Stream Coprocessor Bridge
- **Base Address:** DMA Registers mapped at `0x4000_0060` – `0x4000_006C`
- **Target Platform:** Zybo Z7-10 (Xilinx XC7Z010-1CLG400C) + PicoRV32 RV32I Core

---

## 1. Architectural Overview

Phase 7 implements high-throughput bulk data movement between system BRAM and the Ascon coprocessor via a custom, hardware-optimized Direct Memory Access (DMA) engine (`rtl/dma/dma_master.sv`):

```
                   +------------------------+
                   |  PicoRV32 RISC-V Host  |
                   +-----------+------------+
                               | AXI4-Lite Control Bus
                               v
               +----------------------------------+
               |     axil_regs.sv (0x4000_0000)   |
               |  DMA_SRC, DMA_LEN, DMA_CTRL/STAT |
               +---------------+------------------+
                               | cfg_start, abort, src, len
                               v
                       +----------------+
                       |  dma_master.sv | <-------+
                       +-------+--------+         |
         BRAM Port B Read Port |                  |
      (addr_b, en_b, rdata_b)  | (32-bit words)   |
                               v                  |
                   +-----------------------+      |
                   | 16 KB Dual-Port BRAM  |      |
                   |   (Zero Contention)   |      |
                   +-----------------------+      |
                                                  |
           Pipelined 64-bit Stream Interface      |
              stream_data, valid, ready, last     |
                               v                  |
                   +-----------------------+      |
                   |  ascon_core_top.sv    | -----+
                   | (AEAD-128 / Hash-256) |
                   +-----------------------+
```

### Architectural Decisions & FPGA Resource Optimization
1. **Contention-Free Dual-Port BRAM Access:** Rather than implementing an AXI4 Master (which would require an AXI interconnect/crossbar arbiter with cycle penalties, fabric LUT overhead, and possible CPU bus stalls), the DMA engine directly drives the independent read port (Port B) of the 16 KB True Dual-Port Block RAM. Port A is dedicated to the PicoRV32 host CPU instruction fetch/data load/stores.
2. **Synchronous Fetch Pipeline:** BRAM read data requires 1 clock cycle latency. The DMA engine implements an address-generation pipeline that fetches 32-bit words sequentially and packs them into 64-bit streaming beats (`{w1, w0}`) matching the internal word-width of the Ascon absorbing permutation.
3. **Robust Handshake Protocol:** Complies with standard `valid`/`ready`/`last` streaming semantics with sub-word remainder tracking (`stream_rem[2:0]`), ensuring zero-bubble backpressure absorption when the Ascon core performs permutation rounds.

---

## 2. DMA Register Map

The DMA engine is controlled via memory-mapped registers integrated within `rtl/bus/axil_regs.sv`:

| Offset | Register | Access | Description |
|:---:|:---:|:---:|---|
| `0x60` | `DMA_SRC` | R/W | 32-bit source byte address in BRAM (must be 4-byte aligned, `< 0x4000`) |
| `0x64` | `DMA_LEN` | R/W | 32-bit transfer payload length in bytes (0 to 16,384 bytes) |
| `0x68` | `DMA_CTRL` | R/W | Bit 0: `START` (self-clearing single-cycle strobe), Bit 1: `ABORT` |
| `0x6C` | `DMA_STATUS` | RO / W1C | Bit 0: `BUSY`, Bit 1: `DONE` (W1C), Bit 2: `ERR` (W1C, boundary/abort), Bits 7:4: `DMA_STATE` |

---

## 3. Boundary & Functional Verification Results (`tb_dma.sv`)

A comprehensive boundary testbench ([`tb/integration/tb_dma.sv`](../../tb/integration/tb_dma.sv)) was executed in Vivado XSim covering 10 distinct test scenarios and 40 individual assertions:

| Test ID | Test Scenario | Description / Stimulus | Result | Assertions |
|:---:|---|---|:---:|:---:|
| **1** | **0-Byte Boundary** | `cfg_len = 0`; verify instant completion without stream assertions | `PASS` | 4/4 |
| **2** | **1-Byte Transfer** | `cfg_len = 1`; verify single 64-bit beat with `rem=1`, `last=1`, correct byte lane | `PASS` | 5/5 |
| **3** | **4-Byte Transfer** | `cfg_len = 4`; single 32-bit word streamed as `{32'h0, W0}`, `rem=4`, `last=1` | `PASS` | 5/5 |
| **4** | **8-Byte Block** | `cfg_len = 8`; single full 64-bit beat `{W1, W0}`, `rem=0`, `last=1` | `PASS` | 4/4 |
| **5** | **16-Byte Multi-Beat**| `cfg_len = 16`; two consecutive 64-bit beats, proper `last` framing | `PASS` | 6/6 |
| **6** | **1 KB Bulk Backpressure**| 128 beats streamed with pseudo-random backpressure (50% stalls); bit integrity verified | `PASS` | 3/3 |
| **7** | **Oversized / OOB Rejection**| `cfg_src = 0x3F00, cfg_len = 1024` exceeding 16 KB BRAM boundary; error asserted, transfer blocked | `PASS` | 3/3 |
| **8** | **Unaligned Addr Rejection**| `cfg_src = 0x0002` (non-word aligned); error asserted immediately, engine remains idle | `PASS` | 2/2 |
| **9** | **Active Transfer Abort**| Mid-transfer abort via `cfg_abort`; verified immediate pipeline flush, busy cleared, error set | `PASS` | 4/4 |
| **10** | **Closed-Loop Hash256** | 64-byte payload streamed into live Ascon core; verified 256-bit digest against Python golden model | `PASS` | 4/4 |

**Summary:** 40 executed, 40 passed, 0 failed (100% PASS). Verification artifact: [`results/board/dma_boundary.log`](dma_boundary.log).

---

## 4. Bare-Metal SoC Integration (`tb_soc_dma.sv`)

- **Host Core:** PicoRV32 RV32I RISC-V processor executing from 16 KB dual-port BRAM.
- **Firmware Driver:** [`firmware/tests/accel_dma_test.c`](../../firmware/tests/accel_dma_test.c) compiled via `riscv64-unknown-elf-gcc`.
- **System Execution Sequence:**
  1. CPU initializes 64-byte payload at BRAM address `0x0000_1000` with incremental pattern `0x00, 0x01, ..., 0x3F`.
  2. CPU configures Ascon coprocessor for Hash-256 (`ASCON_CTRL = 0x02` for MODE=1).
  3. CPU sets message length (`ASCON_MSG_LEN = 64`) and starts coprocessor.
  4. CPU writes `DMA_SRC = 0x0000_1000`, `DMA_LEN = 64`, and pulses `DMA_CTRL = 0x01` (`START`).
  5. DMA engine autonomously fetches sixteen 32-bit words from BRAM Port B, packs them into eight 64-bit beats, and streams them into Ascon `stream_data_in` with backpressure handshaking.
  6. CPU polls `DMA_STATUS` until `DMA_DONE` is set.
  7. CPU polls `ASCON_STATUS` until `DONE` is set.
  8. CPU reads `DIGEST_0..7` and compares word-by-word against the 256-bit Golden Vector computed by Python reference model.
  9. CPU illuminates discrete LEDs (`0xF`) and asserts `test_pass` (`GPIO[31] = 1`).
- **Timing & Performance:**
  - Total elapsed simulation time: **2,122 cycles** (21.315 µs @ 100 MHz).
  - DMA transmission phase: **~120 cycles** for 64 bytes (absorbing 8 blocks with 12-round permutation interleaving).
  - Effective throughput: **53.3 MB/s** including coprocessor permutation wait states.

---

## 5. Phase 7 Exit Criteria Checklist

- [x] Custom burst-to-stream DMA engine implemented in `rtl/dma/dma_master.sv`
- [x] Contention-free Port B BRAM read interface integrated into `rtl/soc/top_bringup.sv`
- [x] Boundary conditions verified: 0-byte, 1-byte, 4-byte, 8-byte, 16-byte, 1 KB transfers (`tb_dma.sv`)
- [x] Boundary violations rejected: unaligned address, out-of-bounds overflow, transfer abort (`tb_dma.sv`)
- [x] Closed-loop Ascon Hash-256 digest verified against golden model (`tb_dma.sv`)
- [x] Bare-metal RISC-V firmware test implemented and compiled (`firmware/tests/accel_dma_test.c`, `.hex`)
- [x] Full SoC integration simulation verified with CPU execution (`tb_soc_dma.sv`)
- [x] Test pass marker (`GPIO[31] = 1`) detected with 0 errors
- [x] Verification log saved to `results/board/dma_boundary.log`
