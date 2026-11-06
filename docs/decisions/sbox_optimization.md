# Decision Record: S-box Optimization Strategy

- **Status:** **DONE-VERIFIED**
- **Date:** November 6, 2026

The baseline S-box remains the canonical bit-sliced implementation (`rtl/ascon/sbox5.sv`).

The three required Boolean optimization techniques from `Project_PS.md` are fully implemented via automated, reproducible tools in `tools/sbox_opt/`:

1. **Two-Level Heuristic Minimization (UC Berkeley ESPRESSO):**
   - Tool: [`tools/sbox_opt/espresso_runner.py`](../../tools/sbox_opt/espresso_runner.py)
   - Provenance: UC Berkeley Espresso Version #2.3 (Release date 01/31/88), executed with `-Dexact` on truth table `scripts/ascon_sbox.pla`. Raw output saved to `results/synthesis/espresso_raw_output.pla`, run log to `results/synthesis/espresso_run.log`. SymPy `SOPform` is retained as an independent cross-check.
   - RTL: [`rtl/ascon/sbox5_espresso.sv`](../../rtl/ascon/sbox5_espresso.sv)
   - Results: Derived exact minimal 30-product-term multi-output Boolean cover (or 36 product terms, 140 literals in single-output mode).

2. **Multi-Level Logic Synthesis & Kernel Extraction:**
   - Tool: [`tools/sbox_opt/kernel_extractor.py`](../../tools/sbox_opt/kernel_extractor.py)
   - Method: Recursive algebraic division (Brayton-McMullen kernel/co-kernel extraction) with greedy literal savings selection. Report saved to `results/synthesis/sbox_kernel_report.log`.
   - RTL: [`rtl/ascon/sbox5_kernel.sv`](../../rtl/ascon/sbox5_kernel.sv)
   - Results: Extracted 6 common algebraic kernels ($k_0..k_5$) across output functions, reducing literal count from 140 to 83 (57 literals saved, 40.7% reduction):
     - $k_0 = (\sim x_1 \land \sim x_2) \lor (x_1 \land x_2)$ [saving: 18 lits]
     - $k_1 = (\sim x_1 \land x_2) \lor (x_1 \land \sim x_2)$ [saving: 13 lits]
     - $k_2 = (\sim x_1 \land x_2) \lor (x_1 \land \sim x_3) \lor (\sim x_2 \land x_3)$ [saving: 12 lits]
     - $k_3 = (\sim x_1 \land \sim x_2 \land \sim x_3) \lor (x_1 \land x_2 \land x_3)$ [saving: 8 lits]
     - $k_4 = (\sim x_0 \land \sim x_3) \lor (x_0 \land x_3)$ [saving: 5 lits]
     - $k_5 = (\sim x_0 \land x_3) \lor (x_0 \land \sim x_3)$ [saving: 1 lits]

3. **Binary Decision Diagram (BDD) Decomposition & Ordering Sensitivity:**
   - Tool: [`tools/sbox_opt/bdd_synthesizer.py`](../../tools/sbox_opt/bdd_synthesizer.py)
   - RTL: [`rtl/ascon/sbox5_bdd.sv`](../../rtl/ascon/sbox5_bdd.sv)
   - Results: Evaluated 4 variable orderings; identified optimal Interleaved ordering `[x1, x3, x0, x2, x4]` achieving a compact 32-node shared ROBDD 2:1 multiplexer network (33.3% graph sharing reduction).

All variants use the standardized 5-bit interface and are exhaustively proved 100% equivalent to NIST SP 800-232 Table 6 across all $2^5 = 32$ vectors via [`tb/unit/tb_sbox_equiv.sv`](../../tb/unit/tb_sbox_equiv.sv) and [`tools/sbox_opt/run_sbox_opt.py`](../../tools/sbox_opt/run_sbox_opt.py).

## 4. Physical Synthesis & Implementation Comparison

All four S-box engines were synthesized and implemented out-of-context at 100 MHz (XC7Z010-1CLG400C) in the same Vivado session using identical top wrappers:

| S-Box Architecture Variant | Engine Wrapper | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) |
|---|---|:---:|:---:|:---:|:---:|
| **Baseline (Canonical Bit-sliced)** | `mode_ctrl_1r_wrap` | 3,191 | 4,015 | +1.925 ns | 123.84 MHz |
| **ESPRESSO SOP (Exact 30-cube)** | `mode_ctrl_1r_espresso_wrap` | 3,258 | 4,015 | +1.621 ns | 119.35 MHz |
| **Kernel Extraction (Brayton-McMullen)** | `mode_ctrl_1r_kernel_wrap` | 3,192 | 4,015 | +2.226 ns | 128.64 MHz |
| **ROBDD Decomposition (Interleaved)** | `mode_ctrl_1r_bdd_wrap` | 3,225 | 4,015 | +1.856 ns | 122.79 MHz |

### Architectural Conclusion
Because a 5-bit Ascon S-box maps to only a few 6-input LUTs (LUT6) on Xilinx 7-series FPGAs, Vivado synthesis re-maps and flattens whatever Boolean form it is given into native LUT6 primitives during physical mapping. Differences within a few percent (a spread of only 67 LUTs out of >3,100, or ~2%) are synthesis placement/routing variations rather than a fundamental technique benefit unless the numbers show a clear, repeatable gap.

