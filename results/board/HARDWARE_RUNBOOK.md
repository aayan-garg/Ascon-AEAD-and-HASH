# Hardware Runbook — Ascon Secure Boot on Zybo Z7-10

**Target:** Digilent Zybo Z7-10 (XC7Z010-1CLG400C)  
**Bitstream:** `build/top_bringup.bit`  
**Clock:** 125 MHz on-board oscillator → MMCM → 100 MHz system clock  

---

## Prerequisites

1. Digilent Zybo Z7-10 connected via USB-JTAG
2. Vivado 2025.1 installed (Hardware Manager)
3. Bitstream built: `build/top_bringup.bit` (run `vivado -mode batch -source scripts/build_bitstream.tcl` if missing)

---

## Step 1 — Program the Bitstream

**Option A — Vivado GUI:**
1. Open Vivado → Flow → Open Hardware Manager → Open Target → Auto Connect
2. Right-click XC7Z010 → Program Device → select `build/top_bringup.bit` → Program

**Option B — Batch TCL:**
```tcl
vivado -mode batch -source scripts/program_board.tcl
```

**Expected:** LEDs briefly all-on (FPGA config), then Blue RGB LED lights (BOOTING state).

---

## Step 2 — Normal Boot (Valid Image)

**Setup:** All switches SW0–SW3 = LOW (0)

**Expected sequence:**
1. Blue RGB LED on → Hashing in progress (`boot_ctrl` in HASH/WAIT_HASH state)
2. After 906 cycles (9.06 µs @ 100 MHz for 64-byte image): Hardware verifies digest and grants `jump_enable`.
3. After 1,342 cycles (13.42 µs @ 100 MHz): Application payload executes, asserting all 4 LEDs solid ON (`4'b1111`) + Green RGB LED → **BOOT OK**.

**Pass criteria:** LED[3:0] = 4'b1111, RGB = Green.

---

## Step 3 — Primary Project Deliverable Demo: Byte-Flipping Fault Injection (SW0 = HIGH)

**Requirement:** `[SPEC]` Project_PS.md "Demo: good image boots (LED pattern); flipping one byte via a switch makes the boot refuse."

**Setup:**
1. Flip **SW0 to HIGH (1)** before pressing BTN0 (reset), or while the system is running.
2. Press **BTN0 (Reset)** to trigger a fresh boot cycle with SW0 active.

**Hardware Fault Mechanism:**
- When `SW0 == 1`, hardware in `top_bringup.sv` intercepts the DMA stream at address `0x0000_1040` (word index `12'h410`), inverting bit 0 of the first application payload byte:
  ```systemverilog
  wire [31:0] dma_bram_rdata = (sw[0] && (dma_bram_addr_q == 12'h410)) ?
                               (dma_bram_raw ^ 32'h00000001) : dma_bram_raw;
  ```
- The Boot ROM streams candidate payload through DMA into the Ascon Hash-256 accelerator.
- The computed hash digest fails comparison against the reference manifest in Boot ROM and hardware `boot_ctrl`.
- The system unconditionally enters `STATE_HALT_REFUSE`, activating the hardware refusal pattern.

**Expected Observation:**
1. Discrete LEDs display alternating refusal pattern: **`4'b1010`** (LD3 ON, LD2 OFF, LD1 ON, LD0 OFF).
2. RGB LED LD6 lights solid **RED** (`3'b001`).
3. Execution locks out in an infinite dead-loop; `fetch_guard` suppresses any instruction fetches to application memory.

**Recovery (Proving Both Outcomes on Hardware):**
1. Flip **SW0 back to LOW (0)**.
2. Press **BTN0 (Reset)**.
3. System immediately returns to **BOOT OK**: all 4 discrete LEDs ON (`4'b1111`) and RGB LED glowing **GREEN**.

---

## Step 4 — Glitch / Tamper Sensor Injection Demo (SW1 = HIGH)

**Setup:** Flip SW1 to HIGH.

**What it does:** SW1 asserts physical `tamper_det` input to `boot_ctrl.sv`. The hardware FSM latches tamper sticky in `tamper_latched_q` and immediately enters `STATE_HALT_REFUSE`.

**Expected:**
1. Discrete LEDs show **`4'b1010`** + solid **RED** RGB LED → **BOOT REFUSED**.
2. State is **sticky** — flipping SW1 back to LOW does NOT clear the refusal. Only pressing BTN0 (system reset) clears the latch.

---

## Step 5 — Corrupted Image Hex Demonstration

The `FIRMWARE_HEX` parameter in `top_bringup_board.sv` can be changed to load a pre-compiled faulty image:

| FIRMWARE_HEX | Expected Outcome | Discrete LEDs | RGB LED |
|---|:---:|:---:|:---:|
| `firmware/tests/boot_matrix/bram_case1_valid.hex` | **BOOT OK** | `4'b1111` | **GREEN** |
| `firmware/tests/boot_matrix/bram_case2_flipped.hex` | **BOOT REFUSED** | `4'b1010` | **RED** |
| `firmware/tests/boot_matrix/bram_case3_wrong_digest.hex` | **BOOT REFUSED** | `4'b1010` | **RED** |
| `firmware/tests/boot_matrix/bram_case4_invalid_len.hex` | **BOOT REFUSED** | `4'b1010` | **RED** |
| `firmware/tests/boot_matrix/bram_case5_bad_magic.hex` | **BOOT REFUSED** | `4'b1010` | **RED** |

---

## Step 6 — Cycle-Accurate Boot Latency Benchmarks

Boot time was measured cycle-accurately in simulation by `tb_secure_boot.sv` and `tb_payload_sizes.sv` (see [`results/board/boot_matrix/boot_scaling_benchmark.log`](boot_matrix/boot_scaling_benchmark.log)):

| Payload Size | Reset Release $\rightarrow$ `jump_enable` | Time to Jump (@ 100 MHz) | Reset Release $\rightarrow$ `test_pass` | Total Boot Time (@ 100 MHz) |
|:---:|:---:|:---:|:---:|:---:|
| **64 Bytes** | **906 cycles** | **9.06 µs** | **1,342 cycles** | **13.42 µs** |
| **1,024 Bytes (1 KB)** | **2,706 cycles** | **27.06 µs** | **3,155 cycles** | **31.55 µs** |
| **4,096 Bytes (4 KB)** | **8,462 cycles** | **84.62 µs** | **8,933 cycles** | **89.33 µs** |

**Empirical Scaling Model ($L$ in bytes):**
$$\text{Cycles to Jump}(L) = 1.874 \times L + 786.5\quad (18.74\text{ ns/byte} + 7.865\ \mu\text{s})$$
$$\text{Cycles to Pass}(L) = 1.882 \times L + 1225.2\quad (18.82\text{ ns/byte} + 12.252\ \mu\text{s})$$

---

## Step 6 — On-Board KAT Verification

The secure boot testbench (`tb_secure_boot.sv`) runs a 9-case boot matrix in simulation. For on-board KAT verification:

1. Load `bram_case1_valid.hex` → confirm BOOT OK (Green)
2. Load `bram_case2_flipped.hex` → confirm BOOT REFUSED (Red)
3. Assert SW1 mid-boot → confirm sticky BOOT REFUSED

Log expected LED patterns and compare against §2–§4 above.

---

## LED Pattern Reference

| State | LED[3:0] | RGB LED6 | Meaning |
|---|---|---|---|
| Booting / Hashing | 4'b0001 | Blue | Hash computation in progress |
| Boot OK | 4'b1111 | Green | Image verified, CPU running |
| Boot Refused | 4'b1010 | Red | Tamper or digest mismatch — sticky lockout |
| Reset / Init | 4'b0000 | Off | MMCM not yet locked |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| All LEDs off after programming | MMCM not locking (125 MHz input missing) | Check J5 jumper: must be set for on-board oscillator |
| Stuck in Blue (BOOTING) | BRAM not initialised with valid firmware | Check FIRMWARE_HEX parameter; rebuild bitstream |
| Immediate Red after reset | SW1 asserted before reset released | Pull SW1 low, then press BTN0 |
| JTAG not found | USB cable not connected or driver issue | Use Digilent Adept to verify USB connection |
