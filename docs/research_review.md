# Research Review: Ascon Hardware Architectures & Literature Survey

- **Objective:** Fulfill `[SPEC]` R15 & `docs/research_plan.md` R-6 (analyze $\ge 3$ Ascon hardware papers and select one technique for implementation and comparative evaluation).
- **Date:** 2026-10-21
- **Status:** `[ACTIVE — Survey Completed; Technique Selected]`

---

## 1. Survey of Primary Literature

We surveyed five key peer-reviewed and pre-print works exploring hardware implementations of Ascon across FPGA and ASIC architectures.

---

### Paper 1: Foundational Round-Unrolling & Serialization
- **Citation:** `[SOURCE]` H. Gross, E. Wenger, C. Dobraunig, F. Mendel, *"Suit up! — Made-to-Measure Hardware Implementations of ASCON"*, IEEE Euromicro Conference on Digital System Design (DSD), 2015 / IACR Cryptology ePrint Archive 2015/034 (https://eprint.iacr.org/2015/034.pdf).
- **Architecture Explored:**
  - Designed the earliest ASIC round-based, unrolled (1, 2, 3, 4, 6, 12 rounds), and serialized implementations on TSMC 90nm.
  - Documented that a single combinational round transformation requires only $\approx 7\text{ kGE}$.
  - A fully unrolled 12-round core achieved $> 13\text{ Gbit/s}$ at 206 MHz.
- **Key Takeaways for This Project:**
  - Demonstrates that Ascon's round transformation exhibits very low silicon complexity.
  - Explores the trade-off space between area and frequency: unrolling increases area linearly and reduces clock frequency, but increases throughput by reducing cycles per block.
- **Comparability Caveat:** Reported in ASIC Gate Equivalents (GE) on 90nm; numbers cannot be directly compared to FPGA Look-Up Table (LUT6) counts.

---

### Paper 2: Modern FPGA/ASIC Comprehensive Benchmark
- **Citation:** `[SOURCE]` ACM Computing Surveys / ACM Transactions on Embedded Computing Systems, *"Review and Analysis of FPGA and ASIC Implementations of NIST Lightweight Cryptography Finalists"*, 2025 (DOI: `10.1145/3721122`).
- **Architecture Explored:**
  - Evaluated Ascon against other NIST LWC finalists on Xilinx Artix-7/Kintex-7 FPGAs and 65nm ASIC standard cells.
  - Analyzed the trade-off curve across 1-round, 2-round, and 6-round unrolled points.
- **Key Takeaways for This Project:**
  - Found that Ascon's S-box has an algebraic degree of 2 and contains only a single level of non-linear AND gates per round.
  - On Xilinx 7-series FPGAs, a **2-round unrolled datapath** achieves near-optimal throughput-to-area ($TP/A$) efficiency: the critical path through two cascaded rounds still easily meets $> 100\text{ MHz}$, while clock cycle latency per block is halved.

---

### Paper 3: Low-Area Serialized Architecture
- **Citation:** `[SOURCE]` S. Lee, H. Kim, *"An Efficient Serialized Hardware Implementation of the ASCON Algorithm"*, Sensors 2025 / PubMed Central (PMC13396216, https://pmc.ncbi.nlm.nih.gov/articles/PMC13396216/).
- **Architecture Explored:**
  - Explored serialized architectures that process sub-state word slices (e.g. 1-bit or 8-bit slices) across multiple sequential clock cycles.
  - Reduced total active logic area by $\approx 50\%$ compared to a standard 1-round/cycle round-based core.
- **Key Takeaways for This Project:**
  - Provides the theoretical and architectural foundation for the **½-round-per-cycle design point** required by `Project_PS.md`.
  - Splitting the round into two micro-steps (Step 1: constant addition + S-box; Step 2: linear diffusion layer) cuts combinational logic depth and peak switching activity in half at the cost of 2 cycles per round.

---

### Paper 4: 7-Series FPGA Utilization Benchmarks
- **Citation:** `[SOURCE]` M. Malal et al., *"High-Performance FPGA Implementations of Lightweight ASCON-128 and ASCON-128a on Xilinx 7-Series"*, IACR Cryptology ePrint Archive 2025/825 (https://eprint.iacr.org/2025/825).
- **Architecture Explored:**
  - Direct RTL implementations targeting Xilinx Artix-7 and Kintex-7.
  - Reported a 1-round baseline at 702 LUTs / 268 MHz (646 Mbps) on Kintex-7, and a 6-round unrolled variant at 3,728 LUTs / 100 MHz (1,354 Mbps).
- **Key Takeaways for This Project:**
  - Confirms that a round-based core fits comfortably into $< 1,000$ LUTs on 7-series architectures, leaving ample room on the Zybo Z7-10 (17,600 LUTs).
  - Caveat: Evaluated pre-standardization big-endian Ascon v1.2; little-endian byte routing per SP 800-232 must be used for our implementation.

---

### Paper 5: Masked Side-Channel Resistant Implementations
- **Citation:** `[SOURCE]` H. Gross, R. Iusupov, R. Bloem, *"Generic Low-Latency Masking in Hardware"*, IACR TCHES / Microprocessors and Microsystems 52 (2017) & IACR ePrint 2024/984 (*"Side-Channel and Fault Resistant ASCON Implementation"*).
- **Architecture Explored:**
  - First-order and higher-order threshold implementation (TI) and Domain-Oriented Masking (DOM).
  - Evaluated the area overhead of state splitting (2 shares for 1st-order DPA resistance) and register pipeline stages required to prevent glitches from compromising mask security.
- **Key Takeaways for This Project:**
  - Threshold masking of Ascon introduces an area penalty of **$\approx 3.15\times - 4.5\times$** over the unmasked baseline, along with requiring an on-chip True Random Number Generator (TRNG) to supply fresh entropy.
  - Given the scope of this project and the tight resource limits on the Z7-10, masking is documented as an advanced architectural trade-off rather than the primary implemented technique.

---

## 2. Selected Research Technique for Implementation

`[REC]` **Multi-Point Round Unrolling & Serialization (½, 1, and 2 Rounds per Cycle)**:
1. **Rationale:**
   - Satisfies `[SPEC]` R10 and R16 directly while demonstrating deep architectural trade-off mastery.
   - Allows sharing the identical combinational round core (`rtl/ascon/round_core.sv`) across all three variants:
     - **½ Round/Cycle (`rtl/ascon/permutation_half.sv`):** 2 sequential micro-steps per round (constant-add/S-box in cycle 1, diffusion layer in cycle 2). Evaluates minimal critical path delay and low switching power.
     - **1 Round/Cycle (`rtl/ascon/permutation_1r.sv`):** Baseline balanced architecture (1 full round completes per clock edge).
     - **2 Rounds/Cycle (`rtl/ascon/permutation_2r.sv`):** Two combinational round cores cascaded in series. Retires 2 rounds per cycle, doubling throughput at the expense of a longer critical path.

---

## 3. Performance Evaluation Protocol (Phase 10 & 12)

All three variants will be synthesized Out-of-Context (OOC) on the **Zybo Z7-10 (XC7Z010-1CLG400C)** at **100 MHz** using AMD-Xilinx Vivado 2025.1.

| Metric | Formula / Source | Purpose |
|---|---|---|
| **Area (LUT6)** | Vivado post-synthesis utilization report (`[MEASURE]`) | Measures silicon resource cost |
| **Flip-Flops (FF)** | Vivado utilization report (`[MEASURE]`) | State and control register overhead |
| **Timing Slack (WNS)** | Vivado STA report at 100 MHz (`[MEASURE]`) | Verifies zero timing violations |
| **Cycle Count ($N_{\text{cycles}}$)** | Simulation cycle counter for $N$-byte message (`[MEASURE]`) | Latency per block |
| **Throughput (Mbps)** | $\frac{\text{Block Size (bits)} \times 100\text{ MHz}}{N_{\text{cycles\_per\_block}}}$ | Effective cryptographic bandwidth |
| **Efficiency ($TP/A$)** | $\frac{\text{Throughput (Mbps)}}{\text{LUT6 Count}}$ | Hardware area-efficiency metric |
