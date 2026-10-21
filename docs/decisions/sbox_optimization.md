# Decision Record: S-Box Optimization Strategy and Comparative Methodology

- **Status:** `ACCEPTED`
- **Date:** 2026-10-21
- **Deciders:** Antigravity Agent, System Architect
- **Requirement Reference:** `[SPEC]` Project_PS.md R11, R13; `[SOURCE]` Initial Research §5.4, §7.5, §18-C; `docs/research_plan.md` R-5

---

## 1. Context and Problem Statement

`Project_PS.md` specifies:
> *"Implement the 5×5 S-box using Boolean minimization techniques (e.g., ESPRESSO, kernel extraction, or BDDs) and compare its resource utilization and timing against a standard lookup table / baseline equation implementation."*

The Ascon S-box is a 5-bit to 5-bit permutation with algebraic degree 2 and multiplicative complexity 5 (`[SOURCE]` Stoffelen 2016, IACR ePrint 2016/198). We must establish a clear, reproducible plan to:
1. Provide a clean, robust baseline for the 320-bit permutation datapath.
2. Implement optimized variant(s) using Boolean minimization tooling.
3. Formally prove 100% equivalence before any hardware performance measurements are taken.
4. Compare FPGA LUT utilization, logic levels, and delay on the target XC7Z010-1CLG400C.

---

## 2. FPGA Architectural Context (AMD-Xilinx 7-Series)

An essential architectural reality on modern FPGAs:
- The AMD-Xilinx 7-series Slice contains **6-input Look-Up Tables (`LUT6`)**.
- A single `LUT6` can implement **any arbitrary Boolean function of up to 6 variables**.
- Because the Ascon S-box has only 5 inputs $(x_0, x_1, x_2, x_3, x_4)$, each of the 5 output bits $(y_0, y_1, y_2, y_3, y_4)$ can theoretically be mapped directly into **1 LUT6** (or dual-output `LUT5`s if inputs are shared).
- Consequently, on an FPGA, Boolean minimization primarily affects whether synthesis tools pack outputs into shared dual-output LUTs (`LUT5:O5/O6`), reduce logic depth to a single level, and minimize routing wire congestion across the 64 bit-slices in the 320-bit state.

---

## 3. Decision

1. **Baseline RTL (`rtl/ascon/sbox5.sv`):**
   - Implement the canonical bit-sliced Boolean equation form (Keccak $\chi$ equivalent):
     - Affine input XORs: 3 gates.
     - Keccak $\chi$ non-linear layer: 5 AND, 5 XOR.
     - Affine output XORs & inversion: 3 XOR, 1 NOT.
     - Total: 20 basic gates (11 XOR, 5 AND, 1 NOT).
   - This baseline will be the primary engine used in `round_core.sv`.

2. **Optimized Variant (`rtl/ascon/sbox5_espresso.sv`):**
   - Implement a two-level sum-of-products representation minimized using Berkeley ESPRESSO (`tools/sbox_opt/ascon_sbox.pla`).
   - Package both behind an identical 5-in / 5-out interface (`input logic [4:0] in`, `output logic [4:0] out`) so that `round_core.sv` can select between them via a Verilog parameter (`parameter SBOX_TYPE = "BASELINE"` vs `"ESPRESSO"`).

3. **Exhaustive Equivalence Verification Gate (Phase 4):**
   - An automated testbench (`tb/unit/tb_sbox_equiv.sv`) will apply all $2^5 = 32$ vectors to both implementations in parallel.
   - Any difference in any output bit will fail the testbench and block Phase 4 exit.

4. **Measurement Framework (Phase 10):**
   - Both modules will be synthesized Out-of-Context (OOC) in Vivado:
     - Number of LUTs (`[MEASURE]`)
     - Number of Logic Levels (`[MEASURE]`)
     - Critical Path Delay in ns (`[MEASURE]`)
     - Estimated dynamic power at 100 MHz (`[MEASURE]`)
   - Results will be reported in a formal comparison table in `results/performance/sbox_comparison.md`.
