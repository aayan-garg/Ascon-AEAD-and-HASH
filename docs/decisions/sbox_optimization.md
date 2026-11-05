# Decision Record: S-box Optimization Strategy

- **Status:** PARTLY DONE
- **Date:** November 5, 2026

The baseline S-box remains the canonical bit-sliced implementation. The
ESPRESSO equations were minimized externally; this repository only verifies
them against NIST SP 800-232 Table 6.

The current alternatives are intentionally described narrowly:

- **Kernel:** `rtl/ascon/sbox5_kernel.sv` is an ANF restatement of the standard
  equations; no extraction performed.
- **BDD:** `rtl/ascon/sbox5_bdd.sv` is a 32-entry lookup table; no BDD
  decomposition performed.

All variants use the same 5-bit interface and are exhaustively checked by
[`tb/unit/tb_sbox_equiv.sv`](../../tb/unit/tb_sbox_equiv.sv). Kernel
extraction, BDD decomposition, node-count reports, and regenerated
technique-specific RTL are **NOT DONE**. The existing engine measurements are
retained as measurements only; they do not prove a technique-related
reduction. S-box variants were evaluated with the 1-round permutation only.
