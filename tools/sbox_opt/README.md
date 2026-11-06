# S-Box Optimization Toolchain and Architectural Evaluation

- **Target Component:** 5×5 Non-linear Substitution Box for Ascon (NIST SP 800-232)
- **Directory:** `tools/sbox_opt/`
- **Related Requirements:** `[SPEC]` R11, R13; `Project_PS.md` "5×5 S-box as the ESPRESSO/kernel-extraction/BDD block"

---

## 1. Executive Summary

This directory provides the automated, reproducible synthesis and optimization toolchain for evaluating the 5×5 Ascon S-box across three distinct Boolean paradigms:
1. **Two-Level Sum-of-Products Minimization (UC Berkeley ESPRESSO; SymPy SOPform cross-check):** `espresso_runner.py`
2. **Multi-Level Logic Synthesis & Kernel Extraction:** `kernel_extractor.py`
3. **Reduced Ordered Binary Decision Diagrams (ROBDDs):** `bdd_synthesizer.py`

Every variant is exhaustively proved 100% equivalent to NIST SP 800-232 Table 6 across all $2^5 = 32$ input vectors.

---

## 2. Optimization Comparison Table

| Paradigm | Primary Metric | Representation / Structure | Shared Sub-Expressions / Nodes | Status | Equivalence |
|---|:---:|---|:---:|:---:|:---:|
| **Standard Bit-Slice (`sbox5.sv`)** | Canonical Equations | 3 XOR in, 5 Keccak-$\chi$ AND-XOR, 4 XOR out | Affine input/output sharing | `DONE-VERIFIED` | 32/32 PASS |
| **ESPRESSO SOP (`sbox5_espresso.sv`)** | 30 Cubes | Two-Level Multi-Output SOP (130 input literals, 57 output connections) | Minimal multi-output cover | `DONE-VERIFIED` | 32/32 PASS |
| **Algebraic Kernel (`sbox5_kernel.sv`)** | Common Kernels | Multi-level factorized network | 6 shared kernels ($k_0..k_5$, 40.7% lit reduction) | `DONE-VERIFIED` | 32/32 PASS |
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
To run the authoritative literal counter for the ESPRESSO PLA output:
```bash
python tools/sbox_opt/count_pla_literals.py
```
To run the SystemVerilog equivalence testbench in Vivado XSim:
```bash
xvlog -sv rtl/ascon/*.sv tb/unit/tb_sbox_equiv.sv
xelab -debug typical tb_sbox_equiv -s sim_sbox
xsim sim_sbox -R
```

---

## 5. Building ESPRESSO

The minimizer runner [`espresso_runner.py`](espresso_runner.py) looks for the Berkeley ESPRESSO binary in `tools/sbox_opt/bin/espresso` (or `tools/sbox_opt/bin/espresso.exe`), in system `PATH`, or via `pyeda` (`pip install pyeda`).

Because compiled binaries in `tools/sbox_opt/bin/` are gitignored, follow these steps to build the binary on Linux or Windows WSL:

```bash
# 1. Clone classic Berkeley ESPRESSO 2.3
git clone https://github.com/classabbyamp/espresso-logic.git
cd espresso-logic

# 2. Build with make (or cmake -B build && cmake --build build)
make -j$(nproc)

# 3. Copy binary into tools/sbox_opt/bin/
mkdir -p tools/sbox_opt/bin
cp bin/espresso tools/sbox_opt/bin/espresso

# 4. Verify version string:
./tools/sbox_opt/bin/espresso -v
# Expected output:
# UC Berkeley Espresso Version #2.3 (Release date 01/31/88)
```

**Committed Run Evidence:**
The exact raw minimizer output and execution logs are committed directly in the repository:
- Raw PLA cover: [`results/synthesis/espresso_raw_output.pla`](../../results/synthesis/espresso_raw_output.pla)
- Tool execution log: [`results/synthesis/espresso_run.log`](../../results/synthesis/espresso_run.log)

A reviewer or user does not need to rebuild ESPRESSO to inspect or verify the project evidence.
