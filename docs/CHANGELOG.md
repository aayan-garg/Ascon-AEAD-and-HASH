# Project Changelog & Consolidation Record

This document records all architectural improvements, audit remediations, verification closures, and documentation consolidations implemented for the Ascon AEAD + Hash Secure-Boot SoC Project (`Ascon-AEAD-and-HASH`).

---

## 0. Final Metric Reconciliation & Repository Cleanup (November 11, 2026)

- **Dynamic Engine Table Fix (`scripts/generate_engine_table.py`, `results/performance/engine_comparison_table.md`)**: Refactored Section 3 ("Key Observations") to compute peak throughput (`3,691.74 Mbps`) and kernel S-box Fmax (`128.63 MHz`) dynamically from parsed `.rpt` files rather than stale hardcoded literals.
- **Metric & Narrative Reconciliation Across Docs & Decisions**: Reconciled stale OOC, SoC, and ILA metrics against committed raw `.rpt`/`.txt`/`.log` evidence across `docs/decisions/sbox_optimization.md`, `docs/decisions/paper_design_technique.md`, `docs/status.md`, `docs/requirements_traceability.md`, `docs/final_report.md`, `docs/AUDIT_RESPONSE.md`, `results/board/phase2_bringup.md`, `results/board/boot_matrix/boot_matrix_summary.md`, and `README.md` (`+1.510 ns` / `117.79 MHz` baseline `top_bringup_board` timing; `+1.042 ns` post-route ILA timing; `35/35` boot-matrix assertions; `544 LUTs / +5.154 ns / 206.36 MHz` for `permutation_1r`; `+1.598 ns / 119.02 MHz` vs `+1.925 ns / 123.84 MHz` for `mode_ctrl` wrappers; exact `bram_case2_flipped.hex` filename).
- **Hardware & ILA Verification Honesty (`results/board/ila_verification_report.md`, `docs/hardware_test_plan.md`, `results/board/HARDWARE_RUNBOOK.md`)**: Updated ILA documentation to match `scripts/build_bitstream_ila.tcl` (11 probes / 18 bits, `6,784` LUTs / `7,743` FFs / `8.5` BRAMs, `+1.042 ns` WNS), separated XSim reference cycle counts from actual `-trigger_now` steady-state hardware CSV captures (`ila_capture_normal_boot.csv`, `ila_capture_fault_injection.csv`), removed phantom UART references and unused switch descriptions, and clearly listed pending board items (`SW1` physical confirmation, rising-edge transient ILA waveform, on-board latency measurement, and on-board KAT execution).
- **Repository Hygiene & Obsolete Clutter Removal**: Fixed clean-clone broken external link in `AGENTS.md` (`Project_PS.md` referenced as outside-repo workspace doc matching `Initial Research.md`), updated `docs/directory_structure.md`, and removed obsolete/duplicate logs (`tight_setup_hold_pins.txt`, `case_*_HAND_WRITTEN_REPLACED.log`, orphaned legacy NuSMV logs, byte-identical `ila_capture_now.csv`), dead/superseded helper scripts (`scripts/reproduce_sbox_espresso.py`, `scripts/gen_espresso_pla.py`, `results/synthesis/sbox5_espresso_rtl_as_pla.pla`, `scripts/parse_engine_synth.py`, `scripts/run_full_kats.tcl`, `scripts/create_vivado_project.tcl`, `scripts/open_*.bat`, `scripts/view_waveform.py`, `scripts/sim_procedures.tcl`, `tests/.gitkeep`), and untracked local Vivado/XSim/scratch clutter.

---

## 1. Final Pre-Hardware Polish & Hygiene Pass (November 6, 2026)

### T1: Clean-Clone Link Resolution
- **What ran:** Scanned all markdown links across the repository using `scripts/check_doc_links.py`. Replaced uncommitted links pointing to gitignored bitstreams (`build/top_bringup.bit`) in `docs/requirements_traceability.md` with inline code formatting referencing the generation script `scripts/build_bitstream.tcl`.
- **Command:** `python scripts/check_doc_links.py`.
- **Results:** 341/341 relative links verified to exist on disk; 0 broken links in clean clones.
- **Evidence Paths:** [`docs/requirements_traceability.md`](requirements_traceability.md), [`scripts/check_doc_links.py`](../scripts/check_doc_links.py).

### T2: Bitstream Build Transparency & Raw Batch Log
- **What ran:** Preserved the authentic raw Vivado batch log from the bitstream run (`build/vivado_bringup.log`) into version control as `results/board/bitstream_build_raw.log`.
- **Command:** Verified against Vivado batch run `vivado -mode batch -source scripts/build_bitstream.tcl` and `Get-FileHash build/top_bringup.bit`.
- **Results:** Updated `results/board/bitstream_build.log` header stating it is a summary derived from Vivado reports and pointing to `results/board/bitstream_build_raw.log`. Verified every figure matches reports: 5,088 LUTs (28.91%), 5,486 FFs (15.59%), WNS = +1.510 ns, 0 DRC violations, SHA256 `79cef83aa8ec05081a92359999da7ca5b3f13d77ae5bee70073c39f3b8862c86` (2,083,869 bytes).
- **Evidence Paths:** [`results/board/bitstream_build_raw.log`](../results/board/bitstream_build_raw.log), [`results/board/bitstream_build.log`](../results/board/bitstream_build.log).

### T3: ESPRESSO Reproduction & Graceful Environment Fallback
- **What ran:** Documented exact compilation steps for classic Berkeley ESPRESSO (`classabbyamp/espresso-logic`) under WSL/Linux in `tools/sbox_opt/README.md#5-building-espresso`.
- **Command:** `python tools/sbox_opt/espresso_runner.py`.
- **Results:** Enhanced `tools/sbox_opt/espresso_runner.py` to catch missing binary/`pyeda` environments gracefully, printing an actionable user error without Python stack traces. Emphasized that committed raw evidence files (`results/synthesis/espresso_raw_output.pla` and `results/synthesis/espresso_run.log`) guarantee reproducibility without re-compilation.
- **Evidence Paths:** [`tools/sbox_opt/README.md`](../tools/sbox_opt/README.md), [`tools/sbox_opt/espresso_runner.py`](../tools/sbox_opt/espresso_runner.py).

### T4: PLA Literal & Connection Count Resolution
- **What ran:** Authored authoritative PLA analysis tool `tools/sbox_opt/count_pla_literals.py` to resolve discrepancies between input-plane literals and total grid connections.
- **Command:** `python tools/sbox_opt/count_pla_literals.py results/synthesis/espresso_raw_output.pla`.
- **Results:** Authoritatively determined: 30 product terms, 130 input literals (non-dash input positions), 57 output connections (1s in output plane), and 187 total grid connections (unshared single-output SOP contains 36 terms and 140 literals). Reconciled all documentation (`docs/decisions/sbox_optimization.md`, `docs/final_report.md`, `tools/sbox_opt/README.md`, `results/synthesis/espresso_run.log`).
- **Evidence Paths:** [`tools/sbox_opt/count_pla_literals.py`](../tools/sbox_opt/count_pla_literals.py), [`results/synthesis/espresso_run.log`](../results/synthesis/espresso_run.log), [`docs/decisions/sbox_optimization.md`](decisions/sbox_optimization.md).

### T5: Payload Scaling Benchmark & Simulator Neutrality
- **What ran:** Removed hard-coded simulator name in `tb/integration/tb_payload_sizes.sv` in favor of generic `(simulator log)`. Added self-checking assertions tracking 5/5 monotonicity checks (`total_pass=5`, `total_fail=0`), standard summary line `PAYLOAD SIZE BENCH: 5/5 checks passed`, and standard log footer `TOTAL_PASS=5 TOTAL_FAIL=0 RESULT=PASS`.
- **Command:** Vivado XSim simulation of `tb_payload_sizes.sv`.
- **Results:** Verified monotonic cycle counts: 64 B (906 / 1,342 cyc), 1 KB (2,706 / 3,155 cyc), 4 KB (8,462 / 8,933 cyc). Regenerated simulation evidence log.
- **Evidence Paths:** [`tb/integration/tb_payload_sizes.sv`](../tb/integration/tb_payload_sizes.sv), [`results/board/boot_matrix/boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log).

### T6: Physical Hardware Runbook Overhaul
- **What ran:** Comprehensively restructured `results/board/HARDWARE_RUNBOOK.md` to establish complete pre-hardware verification readiness.
- **Results:**
  - Prefaced with explicit status: `"No on-board result has been recorded yet"`.
  - Cross-verified all Zybo Z7-10 pin mappings against `board/zybo_z7_10.xdc` and `rtl/soc/top_bringup_board.sv`.
  - Defined step-by-step bench testing instructions: bitstream programming (`scripts/program_board.tcl`), normal boot observation (LEDs `4'b1111`, LD6 Green), SW0 live byte flip demo (LEDs `4'b1010`, LD6 Red), SW1 tamper sensor trigger (sticky LD6 Red).
  - Outlined exact bench data collection artifacts (oscilloscope captures, photos, serial console logs marked `TO BE CONFIRMED ON BOARD`).
  - Added comprehensive 9-case boot matrix table distinguishing switch-injectable scenarios from hex re-synthesis scenarios.
- **Evidence Path:** [`results/board/HARDWARE_RUNBOOK.md`](../results/board/HARDWARE_RUNBOOK.md).

---

## 2. Audit Remediation & Evidence Closure (November 6, 2026)

### T1: Real UC Berkeley ESPRESSO Minimization
- **What ran:** Built classic UC Berkeley Espresso Version 2.3 and installed `pyeda` 0.29.0. Executed `espresso -Dexact scripts/ascon_sbox.pla` directly on the NIST SP 800-232 Table 6 truth table.
- **Commands:** `espresso -Dexact scripts/ascon_sbox.pla` and `python tools/sbox_opt/espresso_runner.py`.
- **Results:** Derived exact minimal 30-product-term multi-output Boolean cover (130 input literals, 57 output connections, 187 grid connections; verified via `tools/sbox_opt/count_pla_literals.py`). Rewrote `tools/sbox_opt/espresso_runner.py` to invoke the real minimizer, verify 32/32 truth table compliance, print term/literal counts, and emit `rtl/ascon/sbox5_espresso.sv`. Retained SymPy `SOPform` as an independent cross-check.
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
- **Timing Closure:** Restructured wide barrel-shifts and carry arithmetic in `mode_ctrl.sv` into LUT-based decoders (`byte_mask64` and `pad_bit_word64`). Achieved positive timing closure in that initial SoC run: $WNS = +1.570\text{ ns}$ at 100 MHz ($F_{max} = 118.62\text{ MHz}$, 0 failing endpoints); final committed baseline `top_bringup_board` synthesis/implementation reports in `results/timing/timing_bringup.txt` close at **WNS = +1.510 ns** ($F_{max} = 117.79\text{ MHz}$).
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
- **Result:** **39/39 suites passed** (100% PASS in 858.38s in that Nov 6 pass; latest committed `results/regression.log` shows **39/39 PASS** in **1540.04s**).
- **Transcript File:** [`results/regression.log`](../results/regression.log).
- **Coverage:** Golden Model NIST KATs (2,120 vectors), NuSMV Formal CTL model checking, 30 SystemVerilog unit suites, and 7 SystemVerilog integration suites.
