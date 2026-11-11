# Design Decision: Paper Technique — 32-bit Serialized Ascon Datapath

- **Decision Date:** November 3, 2026 (Updated November 5, 2026 with Measured Tool Reports)
- **Status:** **FULLY IMPLEMENTED & EMPIRICALLY VERIFIED** (`rtl/ascon/permutation_serial32.sv`)
- **Finding Addressed:** F7 (Independent Audit Remediation)
- **Primary Citation:** Hannes Groß, Erich Wenger, Christoph Dobraunig, Christoph Ehrenhöfer, *"Suit up! — Made-to-Measure Hardware Implementations of ASCON"*, 18th Euromicro Conference on Digital System Design (DSD 2015), pp. 645-652. IACR ePrint [Report 2015/034](https://eprint.iacr.org/2015/034). The DOI was not confirmed in this audit.

---

## 1. Context

The Problem Statement (`Project_PS.md`) requires:
> *"Find a paper, implement one technique, and compare area, throughput, throughput/area and, if masked, the protection cost."*

The foundational Graz University of Technology paper explores hardware trade-offs for Ascon. The ePrint page opened for this audit does not establish that it describes this exact 32-bit-slice implementation. `permutation_serial32` is therefore our own 32-bit-slice serialisation, motivated by the serialised designs surveyed in verified papers; it is not a reimplementation of any specific published design.

---

## 2. Architecture & Implementation

### A. Sub-Word Datapath Architecture
- **Module:** [`rtl/ascon/permutation_serial32.sv`](../../rtl/ascon/permutation_serial32.sv)
- **Engine Integration:** Parameterized into [`rtl/ascon/mode_ctrl.sv`](../../rtl/ascon/mode_ctrl.sv) via `PERM_VARIANT=3`.
- **Substitution Layer Sharing:**
  - Standard `permutation_1r` instantiates **64 parallel 5-bit S-boxes** evaluating all 64 bit-slices in 1 cycle.
  - `permutation_serial32` instantiates exactly **32 parallel 5-bit S-boxes** (`gen_sbox32`), sharing them across two sequential execution phases per round:
    - **Sub-cycle A (`ST_SBOX_A`):** Injects round constant to $x_2[7:0]$; feeds low 32 bits of state rows $\{x_{0..4}[31:0]\}$ through 32 S-boxes; latches resulting 32-bit slices into intermediate state registers.
    - **Sub-cycle B (`ST_SBOX_B`):** Feeds high 32 bits of state rows $\{x_{0..4}[63:32]\}$ through the same 32 S-boxes; recombines the 64-bit words; applies the full 64-bit linear diffusion layer ([`rtl/ascon/diffusion.sv`](../../rtl/ascon/diffusion.sv)).
  - Latency: **2 clock cycles per round** (8 rounds in 16 cycles for AEAD blocks; 12 rounds in 24 cycles for Hash blocks).

### B. Functional Verification Evidence
1. **Differential Testbench ([`tb/unit/tb_diff_perm_serial32.sv`](../../tb/unit/tb_diff_perm_serial32.sv)):**
   - Compared against golden 1-round permutation across 135 vectors (120 pseudo-random states plus official sequences $p^6, p^8, p^{12}$).
   - Result: **135/135 vectors PASS (100% bit-exact match)**. Proof log: [`results/differential_perm_serial32.log`](../../results/differential_perm_serial32.log).
2. **Exhaustive NIST SP 800-232 KAT Suites:**
   - Full AEAD128 suite: **1,089 / 1,089 vectors PASS** ([`results/kat/rtl_aead_full_serial32_pass.log`](../../results/kat/rtl_aead_full_serial32_pass.log)).
   - Full Hash256 suite: **1,025 / 1,025 vectors PASS** ([`results/kat/rtl_hash_full_serial32_pass.log`](../../results/kat/rtl_hash_full_serial32_pass.log)).

---

## 3. Real Empirical Comparison (AMD-Xilinx XC7Z010 @ 100 MHz)

### A. Permutation Core Level
*Reports: [`results/synthesis/permutation_1r_util.rpt`](../../results/synthesis/permutation_1r_util.rpt), [`results/timing/permutation_1r_timing.rpt`](../../results/timing/permutation_1r_timing.rpt), [`results/synthesis/permutation_serial32_util.rpt`](../../results/synthesis/permutation_serial32_util.rpt), [`results/timing/permutation_serial32_timing.rpt`](../../results/timing/permutation_serial32_timing.rpt)*

| Architecture Variant | Style | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) |
|---|---|:---:|:---:|:---:|:---:|
| **`permutation_1r`** | Baseline (1R/cyc, 64 S-boxes) | 544 | 335 | +5.154 ns | 206.36 MHz |
| **`permutation_serial32`** | Serial-32 (2 cyc/R, 32 S-boxes) | 722 | 497 | +3.506 ns | 153.99 MHz |

*FPGA Architectural Analysis:* In ASIC standard-cell libraries, halving S-box count yields significant area savings because S-boxes dominate cell area. On modern 6-input FPGA LUTs (Xilinx 7-Series), an entire 5-input S-box function fits into single LUTs. Consequently, the additional 2:1 multiplexers required to steer 32-bit state halves into shared S-boxes, plus the extra pipeline flip-flops (497 FFs vs 335 FFs), exceed the raw S-box savings, resulting in 722 LUTs (+32.7% LUT overhead over 544 LUTs) on FPGA.

---

### B. Complete Engine Level (`mode_ctrl` Wrappers)
*Authoritative Table: [`results/performance/engine_comparison_table.md`](../../results/performance/engine_comparison_table.md)*

| Metric | Serial-32 Engine (`mode_ctrl_serial32_wrap`) | 1R Baseline Engine (`mode_ctrl_1r_wrap`) | Comparison |
|---|:---:|:---:|:---:|
| **Slice LUTs** | 3,353 | 3,191 | +5.1% |
| **Slice FFs** | 4,180 | 4,015 | +4.1% |
| **WNS @ 100 MHz** | +1.598 ns | +1.925 ns | Both `[MET]` |
| **Fmax** | 119.02 MHz | 123.84 MHz | -3.9% |
| **Cycles per 128-bit AEAD Block** | 16 cycles | 8 cycles | 2.0x latency |
| **AEAD Throughput @ 100 MHz** | 800.00 Mbps | 1,600.00 Mbps | 0.50x |
| **Area Efficiency ($TP/A$)** | 238.59 kbps/LUT | 501.41 kbps/LUT | 0.476x |

---

## 4. Masking & Protection Cost Analysis

As surveyed in [`docs/research_review.md`](../research_review.md) (Groß, Iusupov, Bloem, TCHES 2018, DOI: [10.13154/tches.v2018.i2.1-21](https://doi.org/10.13154/tches.v2018.i2.1-21)):
- **Implementation Status:** **NOT IMPLEMENTED IN RTL** (Documented as NOT DONE per project scope).
- **Protection Cost:** First-order threshold masking of Ascon requires splitting state variables into shares (2 shares for linear operations, 3 shares for non-linear degree-2 S-box AND gates to prevent glitch-induced first-order leakage). Register pipeline stages must be inserted between share evaluations to satisfy non-completeness, requiring an on-chip TRNG/PRNG to refresh masks every cycle. This expands hardware area by an estimated **3.2x to 4.5x** (>10k LUTs).
