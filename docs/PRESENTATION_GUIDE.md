# Step-by-Step Guide: Theory, Code Walkthrough & Presentation Script

This guide explains the **entire project from scratch** in plain, intuitive language so you can walk anyone through every step — from cryptographic math to RTL, formal proofs, FPGA synthesis, and physical Zybo Z7-10 hardware.

---

## Quick Truth Check: What Is Complete vs. What Remains?
- **100% Complete & Verified Across the Entire Stack:**
  1. **Algorithmic Golden Model:** Python NIST SP 800-232 reference (`2,120` vectors).
  2. **RTL Microarchitectures:** All permutation & S-box variants (1R, 2R, Half-Round, Serial-32, ESPRESSO, Kernel, BDD), AEAD128 + Hash-256 engines (`1,089` AEAD + `1,025` Hash KATs), and tamper plaintext gate.
  3. **Verification & Proofs:** Full 39/39 XSim regression suite (`1,540.04 s`), NuSMV CTL formal proof (`5/5` temporal safety invariants proved).
  4. **Synthesis & Timing Closure:** Out-of-context and full-SoC implementation across all variants meeting 100 MHz timing (`WNS = +1.510 ns` baseline, `+1.042 ns` ILA).
  5. **Physical Zybo Z7-10 FPGA Silicon Validation:**
     - **Rising-Edge Normal Boot Transient:** 186 cycles (1.86 µs @ 100 MHz) DMA-to-hash_ok verification, discrete LEDs = `4'b1111`, RGB `LD6` = Solid Green (`ila_rising_normal_boot_186cyc.png`).
     - **Live Byte-Flip Refusal:** `SW0=1` DMA bit-0 flip refusal, `boot_refuse=1`, discrete LEDs = `4'b1010`, RGB `LD6` = Solid Red (`ila_rising_fault_sw0.png`).
     - **Runtime Tamper Lockout:** `SW1=1` physical tamper asserting immediate refusal with persistent sticky lockout across switch deassertion until `BTN0` reset (`ila_rising_tamper_sw1.png`).
     - **Full On-Board NIST KAT Execution:** Standalone 128 KB BRAM KAT SoC (`ascon_kat.xpr`) executed all `1,025` Hash tests (`0x401`), `1,089` AEAD Encrypt tests (`0x441`), `1,089` AEAD Decrypt tests (`0x441`), and tampered-tag plaintext zeroization with 0 failures in 8,146,158 cycles (81.46 ms @ 100 MHz) captured on ILA (`ila_onboard_kat_all2114.png`).
- *(Note on research scope boundary: Hardware side-channel masking was surveyed and marked NOT DONE in RTL as analyzed in `docs/research_review.md`.)*

---

## Step 1 — The Problem Statement: Why Do We Need This?

In an IoT device (like our **RISC-V PicoRV32** soft CPU on the Zybo Z7-10 FPGA), firmware sits in memory (`16 KB` BRAM). If an attacker modifies even **1 single bit** of that stored application — either changing code on flash or injecting a glitch over the bus — the CPU could boot malicious instructions.

Our goal (`Project_PS.md`) has two halves:
1. **Build a NIST SP 800-232 Ascon Hardware Accelerator** supporting both:
   - **Ascon-Hash256** (compresses an arbitrary message into a unique 256-bit fingerprint/digest), and
   - **Ascon-AEAD128** (Authenticated Encryption with Associated Data: encrypts plaintext + authenticates both ciphertext and plaintext headers with a 128-bit tag, **and never releases decrypted bytes unless the tag verifies**).
2. **Integrate it into a Secure-Boot RISC-V SoC** so that:
   - Before executing the candidate application (`0x0000_1040`), the CPU's immutable Boot ROM asks a **DMA engine** to stream the app out of memory into **Ascon-Hash256**.
   - Dedicated **hardware (`boot_ctrl` + `fetch_guard`)** checks the 256-bit digest in silicon and physically blocks instruction fetches (`>= 0x1040`) with `NOP` instructions unless `hash_ok == 1` and no tamper alarm tripped.

---

## Step 2 — Theory & Building Blocks (Bottom-Up)

### 2.1 The 320-Bit Ascon State & Sponge Construction
Think of Ascon's core as a **320-bit blender** (`5 x 64-bit` registers: `x0, x1, x2, x3, x4`).
- Each **round** `p` scrambles those 320 bits through **three tiny steps** inside `rtl/ascon/round_core.sv`:
  1. **`p_C` (Constant Addition):** XORs an 8-bit round constant (`0xf0, 0xe1, ..., 0x4b`) into the low byte of `x2` so every round is mathematically distinct (prevents slide attacks).
  2. **`p_S` (Substitution Layer — 64 parallel 5-bit S-boxes):** Takes bit `i` from each of the 5 words (`{x0[i], x1[i], x2[i], x3[i], x4[i]}`) as a 5-bit slice (`0..31`) and maps it nonlinearly through `sbox5` across all 64 bit positions `i = 0..63` in parallel. **Why bit-slicing?** Because all 64 S-boxes compute concurrently in shallow combinational logic with zero RAM lookup tables!
  3. **`p_L` (Linear Diffusion Layer):** Inside `rtl/ascon/diffusion.sv`, each 64-bit word is XORed with two rotated copies of itself (`x0 ^ (x0 >>> 19) ^ (x0 >>> 28)`, etc.), spreading every local 1-bit change across all 64 bits within one round.

### 2.2 Four Boolean Ways to Build the Same 5-Bit S-Box (`Demo 01, Part A`)
Every S-box file takes `[4:0] in_x` and outputs the **exact same 32-row truth table** (NIST SP 800-232 Table 6), proven in `tb_demo_01_sbox_and_perm.sv`:
- `sbox5.sv` (**Baseline Bit-Sliced**): Implements Ascon's classic 3-step algebraic formula: affine input mixing → 5-bit Keccak $\chi$ (`t0 = s0 ^ (~s1 & s2)`) → affine output mixing. Only 5 AND gates!
- `sbox5_espresso.sv` (**ESPRESSO Exact Two-Level SOP**): Generated from UC Berkeley `espresso -Dexact`, minimizing the truth table into **30 shared AND product terms (`p00..p29`)** ORed together for `y0..y4` (**130 input literals**, **187 total SOP literals**).
- `sbox5_kernel.sv` (**Brayton-McMullen Kernel Extraction**): Factors repeated sub-expressions (`k0..k5`) out of the SOP equations (**57 literals saved**) to reduce multi-level logic depth.
- `sbox5_bdd.sv` (**ROBDD Mux Network**): Uses **32 binary `2:1` multiplexers (`cond ? a : b`)** following ordered Shannon expansion `[x1, x3, x0, x2, x4]`.
- **Important FPGA Insight:** When Vivado maps any of those 4 into Xilinx 7-Series **6-input LUTs (`LUT6`)**, a 5-input function fits inside just 5 `LUT6` primitives either way — so at the full `mode_ctrl` engine level all four land within `~2.1%` area (`3,191` to `3,258` LUTs).

### 2.3 Four Architectural Speed/Area Tradeoffs (`Demo 01, Part B`)
All four permutation cores implement the **exact same interface** (`start`, `rounds`, `in_x0..4` → `done`, `out_x0..4`) and produce the **exact same 320-bit result** after `p^12`:
- `permutation_2r.sv` (**2 Rounds/Cycle Unrolled**): Chains **two** `round_core` blocks back-to-back per clock. Retires `12` rounds in **`6` cycles**! Fastest throughput (`3,691.74 Mbps` engine AEAD @ Fmax), highest LUT count (`939` core / `3,604` engine), lowest Fmax (`135.85 MHz` core / `115.37 MHz` engine) because critical path doubles.
- `permutation_1r.sv` (**1 Round/Cycle Baseline**): One `round_core` per cycle. Retires `12` rounds in **`12` cycles**. Best balance (`544` core LUTs, `206.36 MHz` core, `3,191` engine LUTs, `123.84 MHz` engine).
- `permutation_half.sv` (**0.5 Round/Cycle Folded**): Splits each round across **2 clock cycles** (Cycle A: constant + S-box into intermediate registers; Cycle B: linear diffusion). Retires `12` rounds in **`24` cycles**. Highest core Fmax (`264.90 MHz`, tiny critical path!) and lowest engine LUTs (`2,995` LUTs, `-6.1%`), at the cost of extra intermediate flip-flops (`655` vs `335` core FFs) and half throughput per MHz.
- `permutation_serial32.sv` (**Research Paper Design Point — Inspired by Groß et al., DSD 2015**): Uses only **32 S-boxes instead of 64** by folding the `64`-bit state into two `32`-bit halves over `2` cycles (`Sub-cycle A` lower bits `[31:0]`, `Sub-cycle B` upper bits `[63:32]` + `diffusion`). Retires `12` rounds in **`24` cycles**.
  - **Key Research Finding:** While half S-box width saves silicon in **ASIC** standard cells, on a **Xilinx LUT6 FPGA** the `2:1` column multiplexers + half-round state registers actually **increase** LUT count (`722` vs `544` core; `3,353` vs `3,191` engine) while halving throughput (`0.51x` efficiency)! Measuring this honestly on real routed Vivado reports directly satisfies the research tradeoff requirement.

---

## Step 3 — Sponge Modes & Security Gate (`Demo 02` & `Demo 03`)

### 3.1 How `mode_ctrl.sv`, `hash_ctrl.sv`, and `aead_ctrl.sv` Work
`mode_ctrl.sv` is the unified **Sponge FSM** (`ST_IDLE -> ST_INIT -> ST_ABSORB_AD -> ST_ABSORB_MSG -> ST_FINALIZE -> ST_TAG_CHECK / ST_SQUEEZE -> ST_DONE`) driving the permutation core:
- **Ascon-Hash256 (`hash_ctrl.sv`, demonstrated in `tb_demo_02_hash_digest.sv`):**
  1. Loads `IV_HASH256` (`64'h0000080100cc0002`) into `s0` (zeroes `s1..s4`) and runs `p^12`.
  2. Absorbs 64-bit (`8`-byte) blocks into rate word `s0` (`s0 ^= block`), applying Little-Endian `0x01` padding after the last byte, with `p^12` between blocks.
  3. Squeezes four `64`-bit words (`s0` separated by `p^12`) to emit the `256`-bit `digest_out`.
  - **`tb_demo_02` proves:** hashing `"0001020304050607"` matches NIST SP 800-232 bit-for-bit, and flipping **1 single bit** flips **`127 / 256` (`49.6%`)** digest bits!

- **Ascon-AEAD128 (`aead_ctrl.sv`, demonstrated in `tb_demo_03_aead_and_gate.sv`):**
  1. **Init:** Loads `{IV_AEAD128, Key, Nonce}`, runs `p^12`, then XORs `Key` into `s3, s4`.
  2. **Associated Data:** Absorbs 128-bit (`16`-byte) blocks into `{s0, s1}` with `p^8`, then domain-separates (`s4 ^= 1'b1`).
  3. **Payload (128-bit rate):** XORs plaintext with `{s0, s1}` to output ciphertext (or XORs ciphertext on decrypt and writes **candidate plaintext** into `plaintext_gate.sv`).
  4. **Finalize + Tag Compare:** XORs `Key` into `{s2, s3}`, runs `p^12`, XORs `Key` into `{s3, s4}` to produce `tag_out[127:0]`. On decrypt, compares `tag_out == expected_tag`.
  - **Why `plaintext_gate.sv` Is Crucial:** In hardware, you don't want an attacker feeding forged ciphertext and reading partially decrypted bytes before the final tag check! So `mode_ctrl` writes decrypted bytes into a **shadow buffer (`plaintext_gate`)** where `rd_data` is **combinational AND-gated** (`gate_open = tag_ok && !auth_fail && !is_wiping`). If the tag fails (`auth_fail = 1`), `rd_data` stays **`0x0000000000000000`** and `mem[]` is wiped! **`tb_demo_03` proves this live in 3 steps.**

---

## Step 4 — Full Secure-Boot SoC & Formal Safety (`Demo 04` & `Demo 05`)

Look at `rtl/soc/top_bringup.sv` (wrapped for Zybo Z7-10 pins/MMCM in `top_bringup_board.sv`):

```text
  [125 MHz PHY Osc] -> [MMCME2_BASE] -> 100 MHz System Clock
  
  +-------------------+   AXI4-Lite (Port A)   +-----------------------+
  |  PicoRV32 (RV32I) | <===================>  | 16 KB Dual-Port BRAM  |
  |  Runs Boot ROM    |    [Fetch Guard Gate]  | [0x0000..0x0FFF]: ROM |
  +-------------------+                        | [0x1000..0x103F]: Hdr |
            | AXI4-Lite MMIO                   | [0x1040..0x3FFF]: App |
            v                                  +-----------------------+
  +-------------------+                                   ^ Port B (RO)
  |   axil_regs.sv    | ----> [Ascon Core] <=== 64-bit ===| dma_master.sv
  |   0x4000_0000     |          |                        +---------------+
  |                   |     ascon_digest[255:0]
  |                   |          v
  |                   | ----> [boot_ctrl.sv] ---> boot_jump_enable ---> Unlocks Fetch Guard!
  +-------------------+              |
                                boot_refuse ---> Red RGB (LD6) + LED 4'b1010 + Sticky Lockout
```

How the 4 hardware security pieces work together:
1. **`dma_master.sv` (Contention-Free Streaming):** Reads BRAM **Port B** directly (leaving AXI Port A completely free for the CPU), packs two 32-bit words into a 64-bit beat, checks misaligned/overflow bounds, and streams directly into Ascon. On the board (`top_bringup.sv` line 278), **`SW0 = 1`** flips bit `0` of word `0x410` inside the DMA read path to simulate live payload tampering!
2. **`secure_boot.c` (Boot ROM Software):** Validates header magic (`"ASCN"`), version, length, and entry point (`0x1040`), starts DMA + Ascon Hash256, compares digests in constant time, and requests jump authorization.
3. **`boot_ctrl.sv` (Hardware Root-of-Trust FSM):** Even if software has a bug, hardware independently checks `ascon_digest == active_ref_digest` (`hash_match`) in `STATE_CHECK_TAG`, latches `hash_verified_q`, and only enters `STATE_JUMP` if `hash_verified_q && !tamper_latched_q`. **`SW1 = 1` (`tamper_det`)** latches `tamper_latched_q` permanently into `STATE_HALT_REFUSE` until hardware reset!
   - **LED Meaning (`top_bringup.sv` lines 419–426):**
     - Verifying: **Blue `LD6`** (`3'b100`)
     - Boot OK: **Green `LD6`** (`3'b010`) + discrete LEDs **`4'b1111`** (`LD0..LD3` all ON)
     - Refused / Tamper: **Red `LD6`** (`3'b001`) + discrete LEDs **`4'b1010`**
   - **`tb_demo_04` proves all three scenarios (`SW0=0`, `SW0=1`, `SW1=1` sticky) in ~30 µs (`906` cycles reset-to-jump / `1,342` cycles reset-to-`test_pass` for 64 B)!**
4. **`fetch_guard.sv` (Instruction Fetch Barrier — `tb_demo_05_fetch_guard.sv`):** Intercepts CPU reads to `[0x1040..0x4000)`. Until `boot_ctrl` sets `boot_jump_enable = 1`, `fetch_guard` replaces any BRAM instruction in the app region with **`0x0000_0013` (RISC-V `NOP`)**. So even if compromised Boot ROM tries an unverified jump to `0x1040` (`forced_jump.hex`), the CPU harmlessly slides on `NOP`s and never executes app code!
5. **Formal CTL Proof (`formal/ctl/boot_safety_corrected.smv`):** Uses NuSMV `2.6.0` to mathematically prove across **every possible input sequence** (`start`, `dma_done`, `hash_done`, `hash_match`, `tamper_det`) that `AG(jump -> hash_ok)`, `AG(tamper_latched -> !EF jump)`, and `AG(refuse -> AG refuse)` all hold **TRUE** — whereas `boot_safety_broken.smv` fails in 6 steps and outputs a concrete counterexample trace!

---

## Step 5 — Complete Presentation Flow Checklist

1. **Explain Problem & Architecture:** Show diagram in Step 4 above + [`docs/final_report.md`](final_report.md).
2. **Show Golden Model & Formal Evidence:** Open [`results/kat/golden_model_pass.log`](../results/kat/golden_model_pass.log) (`2,120` NIST KATs) and [`results/formal/nuxmv/proof_corrected_nusmv.log`](../results/formal/nuxmv/proof_corrected_nusmv.log) (`5/5 CTLSPEC TRUE`).
3. **Run Live Simple Simulations in Vivado GUI (`vivado/ascon_boot/ascon_boot.xpr`):**
   - `tb_demo_01_sbox_and_perm` → prove S-box 32/32 match + `6 / 12 / 24 / 24` cycles waveform!
   - `tb_demo_02_hash_digest` → NIST Hash256 match + `49.6%` 1-bit avalanche!
   - `tb_demo_03_aead_and_gate` → Encrypt + Valid Release vs Tampered `0x97` zeroization!
   - `tb_demo_04_secure_boot` → Good Boot (`GREEN / 1111`) vs `SW0` Attack (`RED / 1010`) vs `SW1` Sticky Lockout!
   - `tb_demo_05_fetch_guard` → Forced-jump attacker trapped in `0x00000013` NOPs!
4. **Show Full Verification & Synthesis Proof of Work:**
   - Full `39/39` XSim regression: [`results/regression.log`](../results/regression.log)
   - Area/throughput tables: [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) & [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)
   - Full SoC STA & LUT/FF: [`results/synthesis/utilization_bringup.txt`](../results/synthesis/utilization_bringup.txt) (`5,088` LUTs, `5,486` FFs) & [`results/timing/timing_bringup.txt`](../results/timing/timing_bringup.txt) (`+1.510 ns` WNS, `117.79 MHz`).
5. **Run Synthesis Yourself in Vivado GUI** (follow [`README.md`](../README.md)), then transition to live Zybo Z7-10 hardware & rising-edge ILA GUI!

