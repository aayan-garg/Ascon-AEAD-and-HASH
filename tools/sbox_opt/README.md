# S-Box Optimization Toolchain and Methodologies

- **Target Component:** 5×5 Non-linear Substitution Box for Ascon (NIST SP 800-232)
- **Directory:** `tools/sbox_opt/`
- **Related Requirements:** `[SPEC]` R11, R13; `docs/requirements_traceability.md` R11, R15; `Initial Research.md` §5.4, §7.5, §18-C

---

## 1. Overview and Objectives

`Project_PS.md` mandates a hand-built 5×5 S-box design exercise:
> *"Implement the 5×5 S-box using Boolean minimization techniques (e.g., ESPRESSO, kernel extraction, or BDDs) and compare its resource utilization and timing against a standard lookup table / baseline equation implementation."*

This directory houses the scripts, truth table definitions, minimization tools, and comparison flow for evaluating the 5×5 Ascon S-box across multiple synthesis paradigms.

---

## 2. Directory Contents

- `ascon_sbox.pla`: Truth table of the Ascon S-box in standard Berkeley ESPRESSO format (5 inputs, 5 outputs, 32 product terms).
- `generate_sbox_pla.py`: Python generator verifying 100% equivalence between SP 800-232 Table 6 and the Keccak $\chi$ bit-slice equations.
- `espresso_runner.py`: (Phase 4) Automated runner executing ESPRESSO or PyEDA two-level heuristic minimization.
- `bdd_synthesizer.py`: (Phase 4) ROBDD constructor extracting If-Then-Else (ITE) multiplexer networks.

---

## 3. Optimization Techniques Evaluated

### Technique 1: Two-Level Logic Minimization (ESPRESSO)
- **Concept:** Minimizes the sum-of-products (SOP) representation by expanding, reducing, and eliminating redundant product terms.
- **Hypothesis:** Evaluating whether a 2-level SOP cover maps cleanly into AMD-Xilinx 6-input LUTs (`LUT6`), where any 5-variable Boolean function can theoretically fit into a single LUT per output bit.
- **Input:** `ascon_sbox.pla`.

### Technique 2: Multi-Level Logic Synthesis & Kernel Extraction
- **Concept:** Uses algebraic division to extract common sub-expressions (kernels and co-kernels) across the five output equations $(y_0, y_1, y_2, y_3, y_4)$.
- **Hypothesis:** Multi-level sharing reduces literal counts and area in ASIC gate equivalents (GE), but may increase logic levels (depth) in FPGA LUT hierarchies.

### Technique 3: Binary Decision Diagrams (BDD)
- **Concept:** Constructs Reduced Ordered Binary Decision Diagrams (ROBDDs) for each output bit and converts each BDD node into a 2:1 multiplexer (`MUXF7`/`MUXF8`).
- **Hypothesis:** Tests FPGA architectures that feature dedicated fast multiplexer silicon.

---

## 4. Verification & Evaluation Protocol

1. **Exhaustive Equivalence Test:**
   Every synthesized variant (`sbox5_espresso.sv`, `sbox5_bdd.sv`) must be exhaustively compared against the standard bit-sliced module (`sbox5.sv`) across all $2^5 = 32$ input vectors using `tb/unit/tb_sbox_equiv.sv`. Zero mismatches are permitted.
2. **Out-of-Context (OOC) Synthesis:**
   Each module is synthesized in Vivado targeting the `XC7Z010-1CLG400C`:
   - LUT Count (LUT6, LUT5, LUT4)
   - Logic Depth / Levels of Logic
   - Worst Negative Slack (WNS) at 100 MHz
   - Cell Area / Gate Equivalents (GE)
