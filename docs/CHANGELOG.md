# Project Changelog & Consolidation Record

This document records all architectural improvements, audit remediations, verification closures, and documentation consolidations implemented for the Ascon AEAD + Hash Secure-Boot SoC Project (`Ascon-AEAD-and-HASH`).

---

## 1. Final Audit Remediation & Evidence Closure (November 6, 2026)

### T1: Real UC Berkeley ESPRESSO Minimization
- **What ran:** Built classic UC Berkeley Espresso Version 2.3 and installed `pyeda` 0.29.0. Executed `espresso -Dexact scripts/ascon_sbox.pla` directly on the NIST SP 800-232 Table 6 truth table.
- **Commands:** `espresso -Dexact scripts/ascon_sbox.pla` and `python tools/sbox_opt/espresso_runner.py`.
- **Results:** Derived exact minimal 30-product-term multi-output Boolean cover (126 unique literals across 30 shared products). Rewrote `tools/sbox_opt/espresso_runner.py` to invoke the real minimizer, verify 32/32 truth table compliance, print term/literal counts, and emit `rtl/ascon/sbox5_espresso.sv`. Retained SymPy `SOPform` as an independent cross-check.
- **Evidence Paths:** [`results/synthesis/espresso_raw_output.pla`](../results/synthesis/espresso_raw_output.pla), [`results/synthesis/espresso_run.log`](../results/synthesis/espresso_run.log), [`rtl/ascon/sbox5_espresso.sv`](../rtl/ascon/sbox5_espresso.sv).

### T2: Real Brayton-McMullen Algebraic Kernel/Co-Kernel Extraction
- **What ran:** Implemented recursive Brayton-McMullen algebraic division and greedy literal savings factorization in `tools/sbox_opt/kernel_extractor.py`.
- **Command:** `python tools/sbox_opt/kernel_extractor.py`.
- **Results:** Extracted 6 common algebraic kernels ($k_0..k_5$) across output functions, reducing flat literal count from 140 to 83 (57 literals saved, 40.7% reduction). Emitted `rtl/ascon/sbox5_kernel.sv` entirely from data structures (zero hardcoded strings/equations) and verified 32/32 against NIST Table 6.
- **Evidence Paths:** [`results/synthesis/sbox_kernel_report.log`](../results/synthesis/sbox_kernel_report.log), [`rtl/ascon/sbox5_kernel.sv`](../rtl/ascon/sbox5_kernel.sv), [`docs/decisions/sbox_optimization.md`](decisions/sbox_optimization.md).

### T3: Re-verification and Out-of-Context Synthesis of all 4 S-Box Engine Variants
- **What ran:** Executed `tb_sbox_equiv` and all 6 full KAT suites (`tb_{aead,hash}_full_{espresso,kernel,bdd}`) in Vivado XSim; executed Vivado batch out-of-context synthesis and implementation for all four S-box engine variants in the same session (`xc7z010clg400-1` @ 100 MHz OOC).
- **Commands:** `vivado -mode batch -source scripts/synth_engine_variants.tcl -tclargs sbox`, `python scripts/parse_synth_reports.py`, `python scripts/generate_engine_table.py`.
- **Results:** All 7 S-box test suites passed cleanly with 100% bit-exact NIST compliance (1,089 AEAD and 1,025 Hash vectors each). Fresh utilization and timing reports generated for `mode_ctrl_1r_wrap` (3,191 LUTs, +1.925 ns WNS), `mode_ctrl_1r_espresso_wrap` (3,258 LUTs, +1.621 ns WNS), `mode_ctrl_1r_kernel_wrap` (3,192 LUTs, +2.226 ns WNS), and `mode_ctrl_1r_bdd_wrap` (3,225 LUTs, +1.856 ns WNS), all using exactly 4,015 FFs. Documented that small differences (~2%) reflect synthesis mapping variation into native LUT6 primitives rather than fundamental architecture benefits.
- **Evidence Paths:** [`results/kat/rtl_aead_full_espresso_pass.log`](../results/kat/rtl_aead_full_espresso_pass.log), [`results/kat/rtl_hash_full_espresso_pass.log`](../results/kat/rtl_hash_full_espresso_pass.log), [`results/kat/rtl_aead_full_kernel_pass.log`](../results/kat/rtl_aead_full_kernel_pass.log), [`results/kat/rtl_hash_full_kernel_pass.log`](../results/kat/rtl_hash_full_kernel_pass.log), [`results/kat/rtl_aead_full_bdd_pass.log`](../results/kat/rtl_aead_full_bdd_pass.log), [`results/kat/rtl_hash_full_bdd_pass.log`](../results/kat/rtl_hash_full_bdd_pass.log), [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md).

### T4: Full Regression Suite Verification
- **What ran:** Diagnosed and resolved premature timeout on `tb_hash_full_2r.sv` (verified standalone pass in 149.73s; increased step timeout to 600s in `scripts/run_regression.py`). Executed full 39-suite automated regression harness.
- **Command:** `python -u scripts/run_regression.py 2>&1 | Tee-Object -FilePath results/regression.log`.
- **Results:** 39/39 suites passed cleanly ("Overall Result: SUCCESS - ALL SUITES PASSED").
- **Evidence Path:** [`results/regression.log`](../results/regression.log).

### T5: Elimination of Secure Boot Timing Race
- **What ran:** Refactored `tb/integration/tb_secure_boot.sv` to eliminate the simulator-dependent race between testbench reset deassertion and the cycle counter sampling block.
- **Command:** `xvlog -sv ... && xelab ... && xsim tb_secure_boot_sim -R`.
- **Results:** Replaced racy blocking assignments in the reset task with synchronous `timing_measure_en` gating and nonblocking assignments. Added self-checking assertions ensuring `delta_jump == 906`, `delta_pass == 1342`, `delta_jump > 0`, and `delta_pass > delta_jump`. Verified that `tb_payload_sizes.sv` strictly enforces positive, monotonically increasing latency across payload sizes.
- **Evidence Paths:** [`tb/integration/tb_secure_boot.sv`](../tb/integration/tb_secure_boot.sv), [`results/board/boot_matrix/boot_timing_sim.log`](../results/board/boot_matrix/boot_timing_sim.log).

### T6: Bitstream Generation & Documentation Reconciliation
- **What ran:** Reconciled conflicting statements between `docs/status.md` and `docs/AUDIT_RESPONSE.md`. Documented the completed Vivado physical bitstream implementation.
- **Command:** `vivado -mode batch -source scripts/build_bitstream.tcl`.
- **Results:** Documented synthesis and implementation of `build/top_bringup.bit` under Vivado v2025.1 with target device `xc7z010clg400-1`, achieved routed timing closure with WNS = +1.510 ns (0 failing endpoints), and recorded the cryptographic SHA256 checksum (`79cef83aa8ec05081a92359999da7ca5b3f13d77ae5bee70073c39f3b8862c86`).
- **Evidence Paths:** [`results/board/bitstream_build.log`](../results/board/bitstream_build.log), [`docs/status.md`](status.md), [`docs/AUDIT_RESPONSE.md`](AUDIT_RESPONSE.md).

---

## 2. Documentation Consolidation & Cleanup (November 2026)

- Regenerated `results/board/dma_boundary.log` by running `tb/integration/tb_dma.sv` with Vivado XSim; the testbench now writes the evidence log itself.
- Rewrote the stale T6.3 row in `docs/AUDIT_RESPONSE.md` to identify external ESPRESSO minimization, RTL-to-PLA conversion, and the NOT DONE extraction/decomposition status.
- Attempted to refresh `results/regression.log` with `python scripts/run_regression.py` from a clean clone; 38 suites passed, but `tb_hash_full_2r.sv` exceeded the runner timeout, so the transcript records a failure rather than claiming a full pass. The forced-jump and SoC-DMA integration evidence was regenerated with XSim.
- Retried `tb/unit/tb_hash_full_2r.sv` with Vivado XSim using an extended timeout; all 1,025 Hash-256 vectors passed and the fresh KAT log was regenerated.

- **November 5, 2026 audit correction:** Renamed the circular PLA artifact,
  removed the unexecuted ESPRESSO provenance claim, and documented that the
  kernel and BDD variants are respectively an ANF restatement and a lookup
  table. Corrected citation status, removed unsupported reduction claims,
  fixed the fetch-guard banner and DMA watchdog, and made the board wrapper
  hard-wire the guard enabled.

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
   - *Rationale:* Duplicated findings, contained outdated phase summaries and obsolete absolute verification language. Fully superseded by `docs/final_report.md` and `docs/requirements_traceability.md`.
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
- **Algebraic Kernel S-Box (`rtl/ascon/sbox5_kernel.sv`):** Corrected description: ANF restatement of the standard equations; no extraction performed. Existing 32/32 and KAT evidence remains functional evidence only.
- **BDD S-Box (`rtl/ascon/sbox5_bdd.sv`):** Corrected description: 32-entry lookup table; no BDD decomposition performed. Existing 32/32 and KAT evidence remains functional evidence only.
- **ESPRESSO S-Box Provenance:** Corrected to state that equations were minimized externally with ESPRESSO; this repository only verifies them against NIST Table 6.

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
