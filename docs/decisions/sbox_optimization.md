# Decision Record: S-box Optimization Strategy

- **Status:** **DONE-VERIFIED**
- **Date:** November 5, 2026 (Audit Remediation)

The baseline S-box remains the canonical bit-sliced implementation (`rtl/ascon/sbox5.sv`).

The three required Boolean optimization techniques from `Project_PS.md` are fully implemented via automated, reproducible Python tools in `tools/sbox_opt/`:

1. **Two-Level Heuristic Minimization (ESPRESSO / SOPform):**
   - Tool: [`tools/sbox_opt/espresso_runner.py`](../../tools/sbox_opt/espresso_runner.py)
   - RTL: [`rtl/ascon/sbox5_espresso.sv`](../../rtl/ascon/sbox5_espresso.sv)
   - Results: Derived minimal 36-product-term, 140-literal Sum-of-Products representation.

2. **Multi-Level Logic Synthesis & Kernel Extraction:**
   - Tool: [`tools/sbox_opt/kernel_extractor.py`](../../tools/sbox_opt/kernel_extractor.py)
   - RTL: [`rtl/ascon/sbox5_kernel.sv`](../../rtl/ascon/sbox5_kernel.sv)
   - Results: Extracted 5 common algebraic kernels ($K_0..K_4$) across output functions, factorizing XOR/AND/NOR co-kernels.

3. **Binary Decision Diagram (BDD) Decomposition & Ordering Sensitivity:**
   - Tool: [`tools/sbox_opt/bdd_synthesizer.py`](../../tools/sbox_opt/bdd_synthesizer.py)
   - RTL: [`rtl/ascon/sbox5_bdd.sv`](../../rtl/ascon/sbox5_bdd.sv)
   - Results: Evaluated 4 variable orderings; identified optimal Interleaved ordering `[x1, x3, x0, x2, x4]` achieving a compact 32-node shared ROBDD 2:1 multiplexer network (33.3% graph sharing reduction).

All variants use the standardized 5-bit interface and are exhaustively proved 100% equivalent to NIST SP 800-232 Table 6 across all $2^5 = 32$ vectors via [`tb/unit/tb_sbox_equiv.sv`](../../tb/unit/tb_sbox_equiv.sv) and [`tools/sbox_opt/run_sbox_opt.py`](../../tools/sbox_opt/run_sbox_opt.py).
