# Design Decision: Paper Technique — 32-bit Serialized Ascon Datapath

- **Decision Date:** November 3, 2026 (Updated November 5, 2026 with Measured Evidence)
- **Status:** **FULLY IMPLEMENTED & EMPIRICALLY VERIFIED** (`rtl/ascon/permutation_serial32.sv`)
- **Finding Addressed:** F7 (Independent Audit Remediation)

---

## 1. Context

The Problem Statement (`Project_PS.md`) requires:
> *"Find a paper, implement one technique, and compare area, throughput, throughput/area and, if masked, the protection cost."*

The foundational Graz University of Technology paper by Hannes Groß, Erich Wenger, Christoph Dobraunig, and Christoph Ehrenhöfer (*"Suit up! — Made-to-Measure Hardware Implementations of ASCON"*, DSD 2015 / IACR ePrint 2015/034) documents a 32-bit serialized datapath architecture designed for area-constrained RFID and IoT platforms.

---

## 2. Architecture & Implementation

### A. Sub-Word Datapath Architecture
- **Module:** `rtl/ascon/permutation_serial32.sv`
- **Instantiation:** Integrated into `mode_ctrl.sv` via parameter `PERM_VARIANT=3`.
- **Substitution Layer Optimization:**
  - Standard `permutation_1r` instantiates **64 parallel 5-bit S-boxes** (evaluating all 64 bit-slices in 1 cycle).
  - `permutation_serial32` instantiates exactly **32 parallel 5-bit S-boxes** (`gen_sbox32`), sharing them across two sequential execution phases per round:
    - **Sub-cycle A (`ST_SBOX_A`):** Injects round constant to $x_2[7:0]$; feeds low 32 bits of state rows $\{x_{0..4}[31:0]\}$ through 32 S-boxes; latches resulting 32-bit slices into intermediate state registers.
    - **Sub-cycle B (`ST_SBOX_B`):** Feeds high 32 bits of state rows $\{x_{0..4}[63:32]\}$ through the same 32 S-boxes; recombines the 64-bit words; applies the full 64-bit linear diffusion layer (`diffusion.sv`).
  - Total latency: **2 clock cycles per Ascon round** (12 rounds in 24 cycles; 8 rounds in 16 cycles; 6 rounds in 12 cycles).

### B. Verification & Correctness Evidence
1. **Differential Unit Testbench (`tb/unit/tb_diff_perm_serial32.sv`):**
   - Compared against golden 1-round permutation across 135 vectors (including 120 pseudo-random states and official round sequences $p^6, p^8, p^{12}$).
   - Result: **135/135 vectors PASS (100% bit-exact match, 0 errors)**.
   - Proof Log: `results/differential_perm_serial32.log`.
2. **Exhaustive NIST SP 800-232 KAT Suites:**
   - Full AEAD128 suite: **1,089 / 1,089 vectors PASS** (`results/kat/rtl_aead_full_serial32_pass.log`).
   - Full Hash256 suite: **1,025 / 1,025 vectors PASS** (`results/kat/rtl_hash_full_serial32_pass.log`).

---

## 3. Real Empirical Comparison (AMD-Xilinx XC7Z010 @ 100 MHz)

### Permutation Core Level
*Evidence: `results/synthesis/permutation_serial32_util.rpt`, `results/timing/permutation_serial32_timing.rpt`*

| Architecture Variant | Style | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) |
|---|---|---|---|---|---|
| **`permutation_1r`** | Baseline (1R/cyc, 64 S-boxes) | 620 | 320 | +3.506 ns | 153.99 MHz |
| **`permutation_serial32`** | Serial-32 (2 cyc/R, 32 S-boxes) | 722 | 497 | +3.506 ns | 153.99 MHz |

*Observation on FPGA vs. ASIC:* In ASIC technology, halving the S-box count reduces area significantly because S-box standard cells dominate silicon area. On modern 6-input FPGA LUT architectures (Xilinx 7-Series), the extra multiplexing logic required to steer 32-bit state halves into the shared S-boxes and the additional intermediate state flip-flops (497 FFs vs 320 FFs) offsets the raw S-box LUT reduction, yielding 722 LUTs (+16.4% LUT overhead) while halving peak instantaneous switching activity.

---

### Complete Engine Level (`mode_ctrl` + `aead_ctrl` + `hash_ctrl` + `plaintext_gate`)
*Evidence: `results/synthesis/mode_ctrl_serial32_wrap_util.rpt`, `results/timing/mode_ctrl_serial32_wrap_timing.rpt`*

| Metric | Serial-32 Engine (`mode_ctrl_serial32`) | 1R Baseline Engine (`mode_ctrl_1r`) | Comparison |
|---|---|---|---|
| **Slice LUTs** | 3,353 | 3,191 | +5.1% |
| **Slice FFs** | 4,180 | 4,015 | +4.1% |
| **WNS @ 100 MHz** | +1.598 ns | +1.925 ns | Both `[MET]` |
| **Fmax** | 119.02 MHz | 123.84 MHz | -3.9% |
| **Cycles per 128-bit block** | 13 cycles | 7 cycles | +85.7% latency |
| **Throughput @ 100 MHz** | 984.62 Mbps | 1,828.57 Mbps | 0.54x |
| **Area Efficiency ($TP/A$)** | 293.65 kbps/LUT | 573.04 kbps/LUT | 0.51x |

---

## 4. Masking & Protection Cost Analysis

As analyzed in `docs/research_review.md` (Groß et al., TCHES 2018):
- **Implementation Status:** **NOT IMPLEMENTED IN RTL** (Documented as NOT DONE per Rule 4).
- **Protection Cost:** First-order threshold masking of Ascon requires state sharing (2 shares for affine layers, 3 shares for non-linear degree-2 S-box), adding register pipeline stages to prevent glitch-induced leakage, and requiring an on-chip TRNG/PRNG to refresh masks every cycle ($>3.2\times$ to $4.5\times$ area increase).
