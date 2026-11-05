# S-Box Optimization Toolchain and Architectural Evaluation

- **Target Component:** 5×5 Non-linear Substitution Box for Ascon (NIST SP 800-232)
- **Directory:** `tools/sbox_opt/`
- **Related Requirements:** `[SPEC]` R11, R13; `Project_PS.md` "5×5 S-box as the ESPRESSO/kernel-extraction/BDD block"

---

## 1. Executive Summary

This directory provides the automated, reproducible synthesis and optimization toolchain for evaluating the 5×5 Ascon S-box across three distinct Boolean paradigms:
1. **Two-Level Sum-of-Products Minimization (ESPRESSO / SOPform):** `espresso_runner.py`
2. **Multi-Level Logic Synthesis & Kernel Extraction:** `kernel_extractor.py`
3. **Reduced Ordered Binary Decision Diagrams (ROBDDs):** `bdd_synthesizer.py`

Every variant is exhaustively proved 100% equivalent to NIST SP 800-232 Table 6 across all $2^5 = 32$ input vectors.

---

## 2. Optimization Comparison Table

| Paradigm | Primary Metric | Representation / Structure | Shared Sub-Expressions / Nodes | Status | Equivalence |
|---|:---:|---|:---:|:---:|:---:|
| **Standard Bit-Slice (`sbox5.sv`)** | Canonical Equations | 3 XOR in, 5 Keccak-$\chi$ AND-XOR, 4 XOR out | Affine input/output sharing | `DONE-VERIFIED` | 32/32 PASS |
| **ESPRESSO SOP (`sbox5_espresso.sv`)** | 36 Product Terms | Two-Level Sum-of-Products (140 literals) | Minimal SOP covers per output | `DONE-VERIFIED` | 32/32 PASS |
| **Algebraic Kernel (`sbox5_kernel.sv`)** | Common Kernels | Multi-level factorized network | 5 shared kernels ($K_0..K_4$) | `DONE-VERIFIED` | 32/32 PASS |
| **Shared ROBDD (`sbox5_bdd.sv`)** | 32 ITE Nodes | 2:1 Multiplexer Tree (Interleaved ordering) | 32 shared ITE multiplexers | `DONE-VERIFIED` | 32/32 PASS |

---

## 3. Variable Ordering Sensitivity in ROBDDs

The ROBDD constructor evaluated four distinct variable orderings across all five outputs:

| Variable Ordering | Independent Node Counts ($y_0..y_4$) | Total Independent Nodes | Multi-Rooted Shared BDD Nodes | Graph Sharing Reduction |
|---|:---:|:---:|:---:|:---:|
| **Natural `[x0, x1, x2, x3, x4]`** | {10, 11, 7, 11, 8} | 47 | 33 | -29.8% |
| **Reversed `[x4, x3, x2, x1, x0]`** | {13, 11, 6, 11, 9} | 50 | 39 | -22.0% |
| **Interleaved `[x1, x3, x0, x2, x4]`** | {9, 10, 9, 13, 7} | 48 | **32** | **-33.3%** |
| **Optimized `[x2, x1, x3, x0, x4]`** | {10, 9, 7, 11, 7} | 44 | 33 | -25.0% |

The **Interleaved ordering `[x1, x3, x0, x2, x4]`** maximizes subgraph sharing across outputs, reducing the entire 5×5 S-box to a compact 32-node 2:1 multiplexer network.

---

## 4. Verification Commands

To reproduce all optimizations and verify 100% equivalence against NIST SP 800-232 Table 6:
```bash
python tools/sbox_opt/run_sbox_opt.py
```
To run the SystemVerilog equivalence testbench in Vivado XSim:
```bash
xvlog -sv rtl/ascon/*.sv tb/unit/tb_sbox_equiv.sv
xelab -debug typical tb_sbox_equiv -s sim_sbox
xsim sim_sbox -R
```
