# Project Changelog & Consolidation Record

This document records all architectural improvements, audit remediations, verification closures, and documentation consolidations implemented for the Ascon AEAD + Hash Secure-Boot SoC Project (`Ascon-AEAD-and-HASH`).

---

## 1. Documentation Consolidation & Cleanup (November 2026)

### A. Ownership Map Implementation (Single Source of Truth)
To eliminate duplicate and contradictory claims across the codebase, a strict single-source-of-truth ownership model was enforced:
- **Hardware Performance & Implementation Metrics:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) and [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md) only.
- **Requirements Compliance & Traceability (R1–R19, PS-DEL-1–8):** [`docs/requirements_traceability.md`](requirements_traceability.md) only.
- **Current Project Status:** [`docs/status.md`](status.md) only.
- **Narrative Technical Evaluation:** [`docs/final_report.md`](final_report.md).
- **Architecture, Threat Model & Security Policy:** [`docs/architecture.md`](architecture.md) and [`docs/threat_model.md`](threat_model.md).
- **Literature Review & Research Citations:** [`docs/research_review.md`](research_review.md) and [`docs/decisions/paper_design_technique.md`](decisions/paper_design_technique.md).
- **Audit Findings & Historical Remediation Matrix:** [`docs/AUDIT_RESPONSE.md`](AUDIT_RESPONSE.md) only.

### B. Obsolete Documents Removed
Four redundant, conflicting documents were retired and removed from version control via `git rm`:
1. `docs/validation_report.md`:
   - *Rationale:* Duplicated findings, contained outdated phase summaries and obsolete marketing language ("100% verified", "ZERO DEFECTS"). Fully superseded by `docs/final_report.md` and `docs/requirements_traceability.md`.
2. `docs/ps_reevaluation.md`:
   - *Rationale:* Intermediate audit scratchpad containing unconfirmed estimates and stale negative timing claims. Fully superseded by `docs/AUDIT_RESPONSE.md` and `docs/requirements_traceability.md`.
3. `docs/research_plan.md`:
   - *Rationale:* Initial pre-implementation planning document from Phase 0. Research findings are now permanently documented in `docs/research_review.md` and `docs/decisions/*.md`.
4. `docs/implementation_plan.md`:
   - *Rationale:* Phased execution roadmap. Obsolete now that all phases are fully implemented, simulated, and synthesized. Current execution status is tracked in `docs/status.md` and `docs/requirements_traceability.md`.

---

## 2. Technical Remediation & RTL Enhancements

### A. Permutation & S-Box Datapath Fixes
- **`permutation_serial32.sv` Correctness (T1):** Resolved functional round-indexing and state synchronization bug; verified 100% bit-exact match on 135/135 differential vectors (`tb_diff_perm_serial32.sv`) and 100% PASS on exhaustive NIST KATs (1,089 AEAD, 1,025 Hash). Characterized OOC at 100 MHz (722 LUTs, +3.506 ns WNS, 153.99 MHz).
- **Algebraic Kernel S-Box (`rtl/ascon/sbox5_kernel.sv`):** Implemented algebraic kernel factorization $(\neg A \wedge B = B \oplus (A \wedge B))$ over $\mathbb{F}_2$. Proved 32/32 equivalence to NIST Table 6. Verified full KATs (1,089 AEAD, 1,025 Hash). Synthesized OOC @ 100 MHz (3,052 LUTs, 4,006 FFs, WNS +1.986 ns, Fmax 124.78 MHz), achieving 4.4% logic reduction vs baseline 1R.
- **BDD Shannon Mux S-Box (`rtl/ascon/sbox5_bdd.sv`):** Implemented Shannon expansion multiplexer hierarchy targeting 6-LUT / MUXF7 primitives. Proved 32/32 equivalence to NIST Table 6. Verified full KATs (1,089 AEAD, 1,025 Hash). Synthesized OOC @ 100 MHz (3,055 LUTs, 4,006 FFs, WNS +1.826 ns, Fmax 122.34 MHz).
- **ESPRESSO S-Box Provenance:** Verified Berkeley ESPRESSO two-level logic minimizer output (`scripts/ascon_sbox.pla` $\rightarrow$ `results/synthesis/espresso_sbox_output.pla`).

### B. SoC Timing Closure & Buffer Sizing (T2)
- **Timing Closure:** Restructured wide barrel-shifts and carry arithmetic in `mode_ctrl.sv` into LUT-based decoders (`byte_mask64` and `pad_bit_word64`). Achieved positive timing closure: $WNS = +1.570\text{ ns}$ at 100 MHz ($F_{max} = 118.62\text{ MHz}$, 0 failing endpoints).
- **Buffer Optimization:** Parameterized `BUFFER_DEPTH=32` (256 B) in `top_bringup.sv` and `axil_regs.sv`, reducing SoC resource utilization from 9,232 to 5,088 Slice LUTs (28.91% of XC7Z010).

### C. Secure Boot & Fetch Guard Verification (T3, T4, B1, B2)
- **Hardware Fetch Guard (`rtl/soc/fetch_guard.sv`):** Instantiated `u_fetch_guard` in `top_bringup.sv` to intercept instruction bus fetches to $[0\text{x}1040, 0\text{x}4000)$ and return RISC-V NOP (`0x00000013`) until hardware `boot_jump_enable=1`.
- **Fetch-Guard Negative Verification (`tb/integration/tb_forced_jump.sv`):** Tested with guard active (unauthorized jump blocked, `test_pass=0`) vs bypassed (`test_pass=1`). Simulation log recorded in `results/board/boot_matrix/forced_jump_sim.log`.
- **Boot Latency Synchronization:** Synchronized cycle-capture registers between `tb_secure_boot.sv` and `tb_payload_sizes.sv`. Exactly 906 cycles (9.06 µs) to jump and 1,342 cycles (13.42 µs) to test pass for 64 B payload. Empirical scaling benchmarked across 64 B, 1 KB, and 4 KB images: $1.874\text{ cyc/byte} + 786.5\text{ cycles}$.
- **SVA Reset Robustness (`formal/sva/boot_ctrl_sva.sv`):** Hardened temporal assertions (`p_tamper_sticky`, `p_tamper_prevents_jump`, `p_refuse_terminal`) against asynchronous/synchronous resets. Verified across 10,000 randomized stimulus cycles in XSim (`results/formal/sva/sva_boot_ctrl.log`).

### D. Formal CTL Model Checking (T5)
- **NuSMV 2.6.0 Verification:** Verified `formal/ctl/boot_safety_corrected.smv`. All 5 CTLSPECs proved TRUE (`results/formal/nuxmv/proof_corrected_nusmv.log`).
- **Counterexample Traceability:** Counterexample generated on flawed model `boot_safety_broken.smv` (`results/formal/nuxmv/counterexample_broken_nusmv.log`). Removed redundant legacy broken files.

---

## 3. Verification & CI Script Additions (A6)

- **`scripts/check_doc_links.py`:** Automated Markdown relative link validator ensuring 0 broken links across documentation (291/291 links verified).
- **`scripts/check_doc_numbers.py`:** Numerical consistency checker validating that reported LUT, FF, WNS, and Fmax figures in Markdown docs match authoritative synthesis and timing reports.
- **Removal of `scripts/patch_all_docs.py`:** Deleted brittle regex patch script.

---

## 4. Full Automated Regression Suite (B5)

- **Execution Script:** `scripts/run_regression.py`
- **Result:** **39/39 suites passed** (100% PASS in 858.38s).
- **Transcript File:** [`results/regression.log`](../results/regression.log).
- **Coverage:** Golden Model NIST KATs (2,120 vectors), NuSMV Formal CTL model checking, 30 SystemVerilog unit suites, and 7 SystemVerilog integration suites.
