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
1. Blue RGB LED on → Hashing in progress (boot_ctrl in HASH/WAIT_HASH state)
2. After ~22 µs (≈2,200 cycles @ 100 MHz for 64-byte image): All 4 LEDs solid ON + Green RGB LED → **BOOT OK**

**Pass criteria:** LED[3:0] = 4'b1111, RGB = Green

---

## Step 3 — Tamper Demo (SW1 = HIGH)

**Setup:** Flip SW1 to HIGH before or during boot

**What it does:** SW1 asserts `tamper_det` input to `boot_ctrl.sv`. The FSM latches tamper and enters `STATE_HALT_REFUSE` immediately and permanently.

**Expected:**
1. LEDs 1 and 3 toggle alternately (pattern 4'b1010 / 4'b0101) + Red RGB LED → **BOOT REFUSED**
2. State is **sticky** — pressing BTN0 (reset) is the only way to clear it.

**Pass criteria:** RGB = Red, LEDs show refusal pattern. Toggling SW1 back to LOW does NOT clear the refusal.

---

## Step 4 — Corrupted Image Demo

The FIRMWARE_HEX parameter in `top_bringup_board.sv` can be changed to load a corrupted image:

| FIRMWARE_HEX | Expected Outcome |
|---|---|
| `firmware/tests/boot_matrix/bram_case1_valid.hex` | BOOT OK (Green) |
| `firmware/tests/boot_matrix/bram_case2_flipped.hex` | BOOT REFUSED (Red) |
| `firmware/tests/boot_matrix/bram_case3_wrong_digest.hex` | BOOT REFUSED (Red) |
| `firmware/tests/boot_matrix/bram_case4_invalid_len.hex` | BOOT REFUSED (Red) |
| `firmware/tests/boot_matrix/bram_case5_bad_magic.hex` | BOOT REFUSED (Red) |

To switch images: rebuild bitstream with new FIRMWARE_HEX generic, then reprogram.

---

## Step 5 — Reading Boot Cycles

Boot time is measured cycle-accurately in simulation by `tb_secure_boot.sv` (see case log files in `results/board/boot_matrix/`).

For on-board measurement, use a logic analyzer on GPIO pins or route `boot_ctrl`'s `jump_enable` to a spare GPIO and use an oscilloscope.

**Formula:**
```
Boot time (µs) = cycles_to_jump / 100.0
```

| Image Size | Expected Cycles (sim) | Expected Time @ 100 MHz |
|---|---|---|
| 64 B | ~2,200 | ~22 µs |
| 256 B | ~5,400 | ~54 µs |
| 1 KB | ~19,000 | ~190 µs |
| 4 KB | ~73,000 | ~730 µs |

*(Cycle counts are estimates based on: 12-round hash init + 8 rounds/64-bit block × blocks + 12-round finalize + DMA overhead. Measured values from simulation take precedence.)*

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
