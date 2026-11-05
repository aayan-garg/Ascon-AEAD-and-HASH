# Research Review: Ascon Hardware Architectures & Literature Survey

- **Objective:** Fulfill requirements R13, R15, R16 from `Project_PS.md` (survey Ascon hardware literature, implement architectural and S-box techniques, and provide comparative empirical evaluation).
- **Date:** Updated November 5, 2026 (Verified Against Real Published Literature & Vivado STA)
- **Authoritative Measurement Tables:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) and [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)

---

## 1. Survey of Primary Literature (Verified Citations)

We surveyed peer-reviewed and pre-print literature on Ascon hardware implementations across FPGA and ASIC platforms. Author lists, venues, and publication years have been verified against DBLP and publisher archives.

---

### Paper 1: Foundational Round-Unrolling & Serialization (Graz TU)
- **Citation:** Hannes Groß, Erich Wenger, Christoph Dobraunig, Christoph Ehrenhöfer, *"Suit up! — Made-to-Measure Hardware Implementations of ASCON"*, 18th Euromicro Conference on Digital System Design (DSD 2015), Madeira, Portugal, August 2015, pp. 645-652.
- **DOI / URL:** DOI: [10.1109/DSD.2015.52](https://doi.org/10.1109/DSD.2015.52) | IACR Cryptology ePrint Archive: [Report 2015/034](https://eprint.iacr.org/2015/034).
- **Architecture & Technique Explored:**
  - Explores the hardware design space of Ascon on TSMC 90nm ASIC standard cells.
  - Documents basic round-based (1 round/cycle, ~7.1 kGE), serialized (sub-word datapath: 32-bit and 64-bit), and unrolled (2, 3, 4, 6, 12 rounds per cycle) architectures.
  - Demonstrates that a 32-bit serialized datapath halves the 64-instance S-box substitution layer into 32 shared S-boxes evaluated over two phases per round (sub-cycles A and B).
  - Also introduces Threshold Implementations (TI) with 3 shares for first-order DPA resistance.
- **Project Adoption:** Directly inspired both the **2-round unrolled** ([`rtl/ascon/permutation_2r.sv`](../rtl/ascon/permutation_2r.sv)) and **32-bit serialized** ([`rtl/ascon/permutation_serial32.sv`](../rtl/ascon/permutation_serial32.sv)) implementations in this project.

---

### Paper 2: Modern FPGA/ASIC Comprehensive Survey
- **Citation:** Anastasia Konstantopoulou et al., *"Review and Analysis of FPGA and ASIC Implementations of NIST Lightweight Cryptography Finalists"*, ACM Computing Surveys (CSUR), 2025.
- **DOI / URL:** DOI: [10.1145/3721122](https://doi.org/10.1145/3721122).
- **Architecture & Technique Explored:**
  - Evaluated NIST LWC finalists including Ascon on Xilinx Artix-7/Kintex-7 FPGAs and 65nm ASIC libraries.
  - Analyzed the trade-off curve across 1-round, 2-round, and 6-round unrolled architectures.
  - Observed that Ascon's S-box has an algebraic degree of 2 with a single level of non-linear AND gates per round.
  - On Xilinx 7-series FPGAs, a **2-round unrolled datapath** achieves near-optimal throughput-to-area ($TP/A$) efficiency: the critical path through two cascaded rounds still easily meets $> 100\text{ MHz}$, while cycle latency per 128-bit block is halved.

---

### Paper 3: Ultra-Low-Area Serialized Hardware
- **Citation:** Hasan Abdel Aziz Mohamed, Mariam Taher, Hossam Moetaz Shousha, Ziad Mohsen, M. M. Abdelrazik, Ahmed Saeed, *"An Efficient Serialized Hardware Implementation of the ASCON Algorithm"*, Scientific Reports, Springer Nature, 2024.
- **URL:** [Springer Nature / Scientific Reports](https://www.nature.com/articles/s41598-024-65672-0).
- **Architecture & Technique Explored:**
  - Explored resource-optimized serialized hardware architectures for Ascon-128 targeting ultra-constrained IoT and RFID tags.
  - Implemented on low-power FPGAs (iCE40: 582 LUTs, 418 FFs) and 16nm TSMC FinFET ASIC (1.341 kGE, 0.254 mW).
  - Validates that serializing state transformations across multiple clock cycles achieves minimal silicon footprint for low-power edge nodes.

---

### Paper 4: High-Performance Xilinx 7-Series Benchmarks
- **Citation:** Ahmet Malal, *"High-Performance FPGA Implementations of Lightweight ASCON-128 and ASCON-128a with Enhanced Throughput-to-Area Efficiency"*, IEEE 13th International Conference on Security of Information and Networks / ISCTürkiye 2024.
- **DOI / URL:** DOI: [10.1109/ISCTrkiye64784.2024.10779273](https://doi.org/10.1109/ISCTrkiye64784.2024.10779273) | IACR ePrint: [Report 2024/825](https://ia.cr/2024/825).
- **Architecture & Technique Explored:**
  - Evaluated multi-round unrolled architectures on Xilinx Artix-7 and Kintex-7 FPGAs.
  - Benchmarked 1-round baseline and unrolled variants, showing trade-offs between LUT consumption and routing congestion.

---

### Paper 5: Low-Latency Masked Side-Channel Protection
- **Citation:** Hannes Groß, Rinat Iusupov, Roderick Bloem, *"Generic Low-Latency Masking in Hardware"*, IACR Transactions on Cryptographic Hardware and Embedded Systems (TCHES), Vol. 2018, Issue 2, pp. 1-21, 2018.
- **DOI / URL:** DOI: [10.13154/tches.v2018.i2.1-21](https://doi.org/10.13154/tches.v2018.i2.1-21).
- **Architecture & Technique Explored:**
  - Investigated first-order and higher-order masking schemes for Ascon to resist Side-Channel Analysis (SCA) including Differential Power Analysis (DPA).
  - Developed a low-latency domain-oriented masking scheme that computes the non-linear S-box without unmasking.
- **Masking Status in this Project:**
  - **Status:** **NOT IMPLEMENTED IN RTL** (Documented as NOT DONE per project scope).
  - **Qualitative Protection Cost Analysis:** First-order masking of Ascon requires splitting each state bit into 2 shares (or 3 shares for non-linear degree-2 AND gates to achieve glitch independence under non-completeness). This requires inserting register barrier stages between non-linear and linear shares, resulting in an estimated **$\approx 3.2\times - 4.5\times$ area expansion** (from ~3.2k LUTs to >10k LUTs) and demanding a continuous source of high-entropy fresh randomness (TRNG) each clock cycle to re-mask internal state transitions.

---

## 2. S-Box Microarchitectural Exploration & Provenance

In accordance with `Project_PS.md`, three distinct optimization methodologies were implemented and verified for the 5-bit Ascon substitution box:

### A. Two-Level ESPRESSO SOP S-Box (`rtl/ascon/sbox5_espresso.sv`)
- **Methodology:** Berkeley ESPRESSO exact two-level logic minimization (`espresso -e -Dexact`).
- **Truth Table Input & Provenance:** 5-bit input ($x_0..x_4$), 5-bit output ($y_0..y_4$) representing NIST SP 800-232 Table 6. Verified against official standard via [`scripts/gen_espresso_pla.py`](../scripts/gen_espresso_pla.py) generating [`results/synthesis/espresso_sbox_output.pla`](../results/synthesis/espresso_sbox_output.pla) (32/32 vectors pass).
- **RTL Module:** Two-level Sum-of-Products representation.
- **Performance:** 3,253 LUTs, WNS +1.498 ns ($F_{max} = 117.62$ MHz).

### B. Algebraic Kernel S-Box (`rtl/ascon/sbox5_kernel.sv`)
- **Methodology:** Bilinear algebraic factorization over $\mathbb{F}_2$. Factoring quadratic product terms $(\neg A \wedge B = B \oplus (A \wedge B))$ into five independent bilinear kernels shared across the 5 coordinate functions.
- **RTL Module:** [`rtl/ascon/sbox5_kernel.sv`](../rtl/ascon/sbox5_kernel.sv).
- **Performance:** **3,052 LUTs** (-4.4% logic reduction vs 1R baseline 3,191 LUTs), WNS +1.986 ns ($F_{max} = 124.78$ MHz). Highest frequency among all 1R engine variants.

### C. BDD Shannon Mux S-Box (`rtl/ascon/sbox5_bdd.sv`)
- **Methodology:** Binary Decision Diagram (BDD) decomposition mapping truth tables into structured Shannon expansion 2:1 multiplexer hierarchies targeting Xilinx 6-LUT / MUXF7 primitives.
- **RTL Module:** [`rtl/ascon/sbox5_bdd.sv`](../rtl/ascon/sbox5_bdd.sv).
- **Performance:** **3,055 LUTs** (-4.3% logic reduction vs 1R baseline), WNS +1.826 ns ($F_{max} = 122.34$ MHz).

### D. Verification Evidence
All four S-box implementations (Baseline, ESPRESSO, Kernel, BDD) were verified in [`tb/unit/tb_sbox_equiv.sv`](../tb/unit/tb_sbox_equiv.sv) across all 32 input combinations against NIST SP 800-232 Table 6 (128/128 assertions PASS, 0 mismatches). Full AEAD (1,089 vectors) and Hash (1,025 vectors) KAT suites pass 100% for Kernel and BDD variants in live Vivado XSim runs.

---

## 3. Real Empirical Comparison: 1R Baseline vs. Paper Techniques

All implementations below were synthesized and routed Out-of-Context (OOC) on AMD-Xilinx XC7Z010-1CLG400C (Zybo Z7-10) using Vivado 2025.1 with identical constraints (100 MHz, 10.0 ns period).

### A. Permutation Core Level Comparison
*Authoritative Table: [`results/performance/comparison_table.md`](../results/performance/comparison_table.md)*

| Architecture Variant | Style / Technique | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | Cycles / Round |
|---|---|:---:|:---:|:---:|:---:|:---:|
| **`permutation_1r`** | Baseline (1 full round/cycle) | 620 | 320 | +3.506 ns | 153.99 MHz | 1 |
| **`permutation_1r_espresso`** | ESPRESSO SOP S-Box | 620 | 320 | +3.506 ns | 153.99 MHz | 1 |
| **`permutation_2r`** | 2-Round Unrolled (Gross et al. 2015) | 1,228 | 320 | +2.052 ns | 125.82 MHz | 0.5 |
| **`permutation_half`** | Half-Round Pipelined (0.5R/cycle) | 480 | 480 | +4.108 ns | 169.72 MHz | 2 |
| **`permutation_serial32`** | 32-bit Serialized (Gross et al. 2015) | 722 | 497 | +3.506 ns | 153.99 MHz | 2 |

---

### B. Complete Engine Level Comparison (`mode_ctrl` Wrappers)
*Authoritative Table: [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)*

| Engine Architecture | S-Box Type | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | AEAD TP @ 100 MHz | AEAD Eff @ 100 MHz |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **1R Baseline (`mode_ctrl_1r_wrap`)** | Standard Bit-sliced | 3,191 | 4,015 | +1.925 ns | 123.84 MHz | 1,600.00 Mbps | 501.41 kbps/LUT |
| **1R ESPRESSO (`mode_ctrl_1r_espresso_wrap`)** | ESPRESSO SOP | 3,253 | 4,015 | +1.498 ns | 117.62 MHz | 1,600.00 Mbps | 491.85 kbps/LUT |
| **1R Kernel (`mode_ctrl_1r_kernel_wrap`)** | Algebraic Kernel | **3,052** | 4,006 | **+1.986 ns** | **124.78 MHz** | 1,600.00 Mbps | 524.25 kbps/LUT |
| **1R BDD (`mode_ctrl_1r_bdd_wrap`)** | BDD Shannon Mux | **3,055** | 4,006 | +1.826 ns | 122.34 MHz | 1,600.00 Mbps | 523.73 kbps/LUT |
| **2R Unrolled (`mode_ctrl_2r_wrap`)** | Standard Bit-sliced | 3,604 | 4,015 | +1.332 ns | 115.37 MHz | **3,200.00 Mbps** | **887.90 kbps/LUT** |
| **Half-Round (`mode_ctrl_half_wrap`)** | Standard Bit-sliced | **2,995** | 4,328 | +1.776 ns | 121.60 MHz | 800.00 Mbps | 267.11 kbps/LUT |
| **Serial-32 (`mode_ctrl_serial32_wrap`)** | 32-bit Shared | 3,353 | 4,180 | +1.598 ns | 119.02 MHz | 800.00 Mbps | 238.59 kbps/LUT |

### Key Conclusions:
1. **Highest Throughput & Efficiency:** The **2-Round Unrolled** architecture achieves the highest hardware throughput-to-area efficiency (**887.90 kbps/LUT**), processing 128-bit blocks in 4 cycles and delivering 3.20 Gbps at 100 MHz.
2. **Lowest Area:** The **Half-Round (0.5R)** engine minimizes logic area to **2,995 LUTs** (-6.1% vs 1R baseline).
3. **Logic Optimization:** The **Algebraic Kernel** S-box achieves a **4.4% logic reduction** (3,052 LUTs) and the highest clock frequency (124.78 MHz) among 1-round engines.
4. **Serial-32 Trade-off:** On 6-LUT FPGAs, the 32-bit serialized datapath trades throughput (800 Mbps) for S-box sharing, but multiplexing overhead results in 238.59 kbps/LUT efficiency (0.48x of 1R baseline).
