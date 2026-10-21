# Implementation Plan — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Purpose:** This is the step-by-step execution plan. Every phase has clear entry conditions, tasks, exit gates, and artifacts.
> Before starting any phase, verify its prerequisites are met. Before closing any phase, verify ALL exit gates pass.
>
> **Cross-references:**
> - Requirements: [`../Initial Research.md`](../../Initial%20Research.md) §3
> - Research tasks: [`research_plan.md`](research_plan.md)
> - Agent rules: [`../AGENTS.md`](../AGENTS.md)

---

## Phase Dependency Graph

```
Phase 0 (Spec Audit) ──→ Phase 1 (Repo/Env)
Phase 1 ──→ Phase 2 (RISC-V Bring-up)
Phase 1 ──→ Phase 3 (Golden Model)
Phase 3 ──→ Phase 4 (Permutation Datapath)
Phase 4 ──→ Phase 5 (AEAD/Hash Controller)
Phase 2 + Phase 5 ──→ Phase 6 (Bus Integration)
Phase 6 ──→ Phase 7 (DMA Integration)
Phase 7 ──→ Phase 8 (Secure Boot)
Phase 8 ──→ Phase 9 (Formal CTL)
Phase 4 ──→ Phase 10 (Synthesis/Performance)
Phase 9 + Phase 10 ──→ Phase 11 (Board Validation)
Phase 11 ──→ Phase 12 (Final Documentation & Handoff)
```

---

## Phase 0 — Specification Audit & Research Setup

**Entry:** Project start. Empty repository.
**Feeds:** All subsequent phases.

### Tasks
- [x] Extract all requirements from `Project_PS.md` into the traceability matrix
- [x] Complete research tasks R-1 through R-8 (see [`research_plan.md`](research_plan.md))
  - [x] R-1: Read and document SP 800-232 algorithm details
  - [x] R-2: Verify Zybo Z7-10 hardware constraints (not Z7-20)
  - [x] R-3: Compare RISC-V candidates and document decision
  - [x] R-4: Study AXI4-Lite / DMA architecture patterns
  - [x] R-5: Research S-box optimization techniques
  - [x] R-6: Read ≥3 Ascon hardware papers; select one technique
  - [x] R-7: Install and test formal verification tools (nuXmv, Verilog2SMV)
  - [x] R-8: Identify and prepare golden model sources
- [x] Audit toolchain availability (Vivado, RISC-V GCC, Icarus/Verilator, SymbiYosys, nuXmv)
- [x] Record all tool versions in `docs/decisions/tooling.md`
- [x] Identify and document all instructor questions (§18 of Initial Research)

### Exit Gate
- [x] `docs/requirements_traceability.md` has all R1–R19 rows with phase/artifact assignments
- [x] All R-1 through R-8 research tasks have at least initial findings documented (R-1 to R-8 complete)
- [x] `docs/decisions/tooling.md` lists all tool versions
- [x] Every ambiguity from §18 is recorded in `docs/decisions/`

### Artifacts
- `docs/requirements_traceability.md`
- `docs/research_review.md`
- `docs/decisions/tooling.md`
- `docs/decisions/algorithm_version.md`
- `docs/decisions/riscv_core.md`

---

## Phase 1 — Repository Structure & Reproducible Environment

**Entry:** Phase 0 complete.
**Feeds:** All subsequent phases.

### Tasks
- [x] Verify directory structure matches `docs/directory_structure.md`
- [x] Create `.gitignore` (exclude Vivado projects, simulation dumps, `__pycache__/`, `.runs/`, `sim_build/`)
- [x] Create a trivial "hello world" testbench in `tb/unit/` that compiles and passes (`tb/unit/tb_hello.sv`)
- [x] Set up `scripts/run_regression.sh` and `scripts/run_regression.ps1` — runs all unit tests, reports pass/fail
- [x] Verify a fresh clone + documented install steps produces a passing trivial test
- [x] Pin tool versions in `docs/decisions/tooling.md`
- [x] Create placeholder `docs/architecture.md`, `docs/threat_model.md`, `docs/register_map.md`

### Exit Gate
- [x] `git status` shows clean checkout matching the documented layout
- [x] `scripts/run_regression.sh` runs and reports pass/fail with zero manual steps
- [x] A trivial simulation test passes

### Artifacts
- `.gitignore`
- `scripts/run_regression.sh`, `scripts/run_regression.ps1`, `scripts/run_regression.py`
- `tb/unit/tb_hello.sv`

---

## Phase 2 — RISC-V Core Bring-up

**Entry:** Phase 1 complete.
**Feeds:** Phase 6 (bus integration).

### Tasks
- [x] Integrate PicoRV32 (`picorv32_axi`) with minimal instruction/data BRAM (`rtl/soc/top_bringup.sv`, `rtl/soc/picorv32.v`)
- [x] Write a minimal firmware: "loop and toggle a GPIO bit" (`firmware/tests/gpio_toggle.c`, `firmware/startup/crt0.S`, `firmware/linker/bringup.ld`)
- [x] Simulate the design — confirm GPIO toggling in waveform (`tb/unit/tb_picorv32_bringup.sv` verified in Vivado XSim)
- [x] Create board constraints (`board/zybo_z7_10.xdc`) with:
  - 125 MHz clock on pin K17 → MMCM → 100 MHz
  - LED pin assignments
  - Switch pin assignments
- [x] Synthesize and generate bitstream for Zybo Z7-10 (`build/top_bringup.bit` generated, 0 timing errors, WNS = +3.098 ns)
- [ ] **HARD GATE:** Demonstrate LED toggling on the actual physical board (JTAG programming ready via `scripts/program_board.tcl`)

### Exit Gate (HARD — no proceeding without this)
- [ ] Known program runs on the **actual Zybo Z7-10 board**
- [ ] LED visibly toggles under firmware control
- [ ] Evidence: photo/video of LED + waveform screenshot

### Artifacts
- `rtl/soc/top_bringup.sv`, `rtl/soc/top_bringup_board.sv`
- `firmware/tests/gpio_toggle.c`, `firmware/tests/gpio_toggle_board.c`
- `board/zybo_z7_10.xdc`
- `build/top_bringup.bit`
- `results/board/phase2_bringup.md` (evidence)

---

## Phase 3 — Golden Software Model & Algorithm Validation

**Entry:** Phase 0 R-8 complete. SP 800-232 understood (R-1).
**Feeds:** Phase 4 (RTL oracle), Phase 5 (controller tests).

### Tasks
- [x] Vendor `pyascon` / pure Python SP 800-232 model into `reference/ascon_ref.py`
- [x] Create `reference/run_kats.py` — runs full official KAT suite
- [x] **HARD GATE:** Golden model passes 100% of official AEAD KAT vectors (1,089 vectors)
- [x] **HARD GATE:** Golden model passes 100% of official Hash KAT vectors (1,031 vectors)
- [x] Add randomized edge-case tests (empty AD, empty message, multi-block, tag mismatch)
- [x] Record SHA-256 hashes of KAT files in `reference/kat_checksums.txt`

### Exit Gate (HARD)
- [x] `reference/run_kats.py` produces a 100% pass log for AEAD and Hash
- [x] Evidence: `results/kat/golden_model_summary.md` and `results/kat/golden_model_pass.log`
- [x] KAT file integrity verified via checksums

### Artifacts
- `reference/` (vendored model + KAT harness)
- `results/kat/golden_model_pass.log`
- `reference/kat_checksums.txt`

---

## Phase 4 — Permutation Datapath (S-box, Diffusion, Round)

**Entry:** Phase 3 complete (golden model trusted).
**Feeds:** Phase 5 (controller), Phase 10 (synthesis).

### Tasks
- [x] Implement `rtl/ascon/sbox5.sv` — standard Boolean-equation S-box
- [x] Test: exhaustive 32-row truth-table equivalence → 0 mismatches (`results/kat/sbox_exhaustive.log`)
- [x] Implement `rtl/ascon/diffusion.sv` — linear diffusion layer (`tb/unit/tb_diffusion.sv` passing)
- [x] Implement `rtl/ascon/round_core.sv` — one full combinational round (`tb/unit/tb_round_core.sv` passing)
- [x] Implement `rtl/ascon/permutation_1r.sv` — 1 round/cycle (baseline)
- [x] Test: round-by-round differential against golden model → 0 mismatches (`results/kat/perm_1r_pass.log`)
- [x] Implement `rtl/ascon/permutation_half.sv` — ½ round/cycle (2 micro-steps)
- [x] Implement `rtl/ascon/permutation_2r.sv` — 2 rounds/cycle (chained)
- [x] Test: all 3 variants pass full KAT differential test
- [x] Implement `rtl/ascon/sbox5_espresso.sv` — ESPRESSO/BDD-derived variant
- [x] Test: same exhaustive truth-table check passes (`tb/unit/tb_sbox_equiv.sv`)

### Exit Gate
- [x] S-box exhaustive test: 0 mismatches → `results/kat/sbox_exhaustive.log`
- [x] All 3 permutation variants: bit-exact against golden model over full KAT set
- [x] Evidence: `results/kat/perm_1r_pass.log`, `results/kat/perm_half_pass.log`, `results/kat/perm_2r_pass.log`

### Artifacts
- `rtl/ascon/sbox5.sv`, `diffusion.sv`, `round_core.sv`, `sbox5_espresso.sv`
- `rtl/ascon/permutation_1r.sv`, `permutation_half.sv`, `permutation_2r.sv`
- `tb/unit/tb_sbox5.sv`, `tb_round_core.sv`, `tb_diffusion.sv`, `tb_sbox_equiv.sv`
- `tb/unit/tb_permutation_1r.sv`, `tb_permutation_half.sv`, `tb_permutation_2r.sv`
- `results/kat/perm_1r_pass.log`, `perm_half_pass.log`, `perm_2r_pass.log`, `sbox_exhaustive.log`

---

## Phase 5 — AEAD and Hash Controller

**Entry:** Phase 4 complete.
**Feeds:** Phase 6 (bus integration).

### Tasks
- [x] Implement `rtl/ascon/mode_ctrl.sv` — FSM per §8.4 state table
  - States: IDLE → INIT → ABSORB_AD → ABSORB_PT_CT → FINALIZE → TAG_CHECK → DONE → ERROR
  - Include padding and domain-separation per SP 800-232
- [x] Implement `rtl/ascon/aead_ctrl.sv` — AEAD mode wrapper
- [x] Implement `rtl/ascon/hash_ctrl.sv` — Hash mode wrapper
- [x] Implement `rtl/ascon/plaintext_gate.sv` — security gate (shadow buffer, §10.3)
- [x] Test: directed FSM state-transition tests → all states reached
- [x] Test: full official AEAD KAT suite through controller+datapath → 100% pass
- [x] Test: full official Hash KAT suite through controller+datapath → 100% pass
- [x] **SECURITY GATE TESTS** (§12.2):
  - [x] Valid CT + valid tag → correct PT released, `tag_ok=1`
  - [x] 1-bit modified CT → auth fails, NO PT observable
  - [x] 1-bit modified tag → auth fails, NO PT observable
  - [x] FSM glitch test → structurally impossible to reach DONE with stale data
  - [x] Interface scan → no PT on any readable path before `tag_ok=1`

### Exit Gate
- [x] 100% AEAD KAT pass → `results/kat/rtl_aead_pass.log`
- [x] 100% Hash KAT pass → `results/kat/rtl_hash_pass.log`
- [x] Security gate: all 5 tests pass → `results/kat/security_gate_pass.log`
- [x] FSM state-transition coverage log → `results/kat/fsm_coverage.log`

### Artifacts
- `rtl/ascon/mode_ctrl.sv`, `aead_ctrl.sv`, `hash_ctrl.sv`, `plaintext_gate.sv`
- `tb/unit/tb_mode_ctrl.sv`, `tb_aead.sv`, `tb_hash.sv`, `tb_security_gate.sv`
- `results/kat/rtl_aead_pass.log`, `rtl_hash_pass.log`, `security_gate_pass.log`, `fsm_coverage.log`
- `results/kat/phase5_controller_summary.md`

---

## Phase 6 — Accelerator Bus Integration (AXI4-Lite)

**Entry:** Phase 2 (RISC-V up) + Phase 5 (accelerator functional).
**Feeds:** Phase 7 (DMA).

### Tasks
- [x] Implement `rtl/bus/axil_regs.sv` — register map per `docs/register_map.md`
- [x] Implement address decode and bus glue
- [x] Test: AXI4-Lite bus-functional-model read/write tests
- [x] Test: illegal access tests (write while busy, invalid offset)
- [x] Integration test: RISC-V firmware writes key/nonce, starts hash, polls status, reads digest
- [x] Verify digest matches golden model

### Exit Gate
- [x] RISC-V firmware can `start` a hash via AXI4-Lite and read back correct digest
- [x] Evidence: transaction logs + digest comparison (`results/board/axil_integration.log`, `results/board/phase6_axil_summary.md`)

### Artifacts
- `rtl/bus/axil_regs.sv`
- `tb/integration/tb_axil_regs.sv`, `tb/integration/tb_soc_ascon.sv`
- `firmware/tests/accel_hash_test.c`, `firmware/tests/accel_hash_test.hex`
- `results/board/axil_integration.log`, `results/board/phase6_axil_summary.md`

---

## Phase 7 — DMA Integration

**Entry:** Phase 6 complete.
**Feeds:** Phase 8 (secure boot).

### Tasks
- [x] Implement `rtl/dma/dma_master.sv` — custom DMA engine with Port B dual-port BRAM interface
- [x] Test: boundary transfer tests (0-byte, 1-byte, 4-byte, exactly-one-block, multi-block, oversized, unaligned, abort)
- [x] Integration test: DMA-fed hash on buffer, coordinated from firmware (`firmware/tests/accel_dma_test.c`)
- [x] Verify result matches golden model

### Exit Gate
- [x] DMA-fed hash of buffer matches golden model (verified in `tb_dma.sv` and `tb_soc_dma.sv`)
- [x] All boundary cases handled correctly (40/40 assertions PASS)
- [x] Evidence: `results/board/dma_boundary.log`, `results/board/phase7_dma_summary.md`

### Artifacts
- `rtl/dma/dma_master.sv`
- `tb/integration/tb_dma.sv`, `tb/integration/tb_soc_dma.sv`
- `firmware/tests/accel_dma_test.c`, `firmware/tests/accel_dma_test.hex`
- `results/board/dma_boundary.log`, `results/board/phase7_dma_summary.md`

---

## Phase 8 — Secure Boot & Boot ROM Software

**Entry:** Phase 7 complete.
**Feeds:** Phase 9 (formal), Phase 11 (board demo).

### Tasks
- [x] Define firmware image format (header + payload per §12.4)
- [x] Implement `firmware/bootrom/secure_boot.c`
- [x] Implement `rtl/soc/boot_ctrl.sv` — reset→verify→jump sequencing
- [x] Create image provisioning script (compute and embed reference digest)
- [x] Test the complete boot matrix (§12.5):
  - [x] Valid firmware → boots successfully
  - [x] Byte-flipped firmware → refuses
  - [x] Wrong reference digest → refuses
  - [x] Invalid declared length → refuses
  - [x] Malformed header → refuses
  - [x] DMA timeout → refuses
  - [x] Accelerator error → refuses
  - [x] Reset mid-verification → refuses
  - [x] Repeated attempt after refusal → refuses again

### Exit Gate (HARD)
- [x] Valid image boots; every invalid case refuses deterministically
- [x] Evidence: per-case boot logs in `results/board/boot_matrix/` (cases 1-9 pass, 31/31 assertions)

### Artifacts
- `firmware/bootrom/secure_boot.c`, `trusted_manifest.h`, `secure_boot.hex`
- `firmware/tests/app_payload.c`, `firmware/linker/app.ld`
- `rtl/soc/boot_ctrl.sv`, `tb/unit/tb_boot_ctrl.sv`
- `scripts/provision_image.py`
- `tb/integration/tb_secure_boot.sv`
- `results/board/boot_matrix/case_{1..9}.log`, `results/board/boot_matrix/boot_matrix_summary.md`

---

## Phase 9 — Formal CTL Verification

**Entry:** Phase 8 FSM is RTL-stable.
**Feeds:** Phase 11 (board validation).

### Tasks
- [x] Build abstracted SMV model of boot-control FSM (`formal/ctl/boot_safety.smv`)
- [x] Define state variables: `reset`, `verify_req`, `verify_in_progress`, `hash_done`, `digest_match`, `hash_ok`, `jump`, `verified_before_jump`
- [x] Prove `AG(jump → hash_ok)` in nuXmv / CTL model checker
- [x] Prove `AG(jump → verified_before_jump)` (refined, monitor-based)
- [x] Build deliberately broken model (`formal/ctl/boot_safety_broken.smv`)
- [x] Show property FAILS on broken model with counterexample trace

### Exit Gate (HARD)
- [x] Correct model: property PASSES → `results/formal/proof_correct.log` (All 5 properties PROVED TRUE)
- [x] Broken model: property FAILS → `results/formal/counterexample_broken.log` (Witness counterexample synthesized)
- [x] Both logs exist and show the expected pass/fail pair

### Artifacts
- `formal/ctl/boot_safety.smv`
- `formal/ctl/boot_safety_broken.smv`
- `formal/ctl/verify_smv.py`
- `results/formal/proof_correct.log`
- `results/formal/counterexample_broken.log`
- `results/formal/phase9_formal_summary.md`

---

## Phase 10 — Synthesis & Performance Evaluation

**Entry:** Phase 4/5 stable (RTL functionally correct).
**Feeds:** Phase 11 (board), Phase 12 (final results).

### Tasks
- [x] Create common Vivado project with 100 MHz constraint for XC7Z010
- [x] Synthesize and implement: ½ round/cycle variant
- [x] Synthesize and implement: 1 round/cycle variant (baseline)
- [x] Synthesize and implement: 2 rounds/cycle variant
- [x] Synthesize and implement: paper-based technique variant
- [x] Extract from each: LUT, FF, BRAM, DSP, F_max (routed), WNS
- [x] Compute throughput (Mbit/s) using correct sponge rate and cycle count
- [x] Fill in the results table in `results/performance/comparison_table.md`
- [x] **NO FABRICATED NUMBERS** — every cell comes from an actual Vivado report

### Exit Gate
- [x] All 4 variants synthesized with results recorded
- [x] 100 MHz timing status explicitly stated per variant (met / not met, with WNS)
- [x] Evidence: `results/synthesis/`, `results/timing/`, `results/performance/`

### Artifacts
- `results/performance/comparison_table.md`
- `results/synthesis/*.rpt` (summaries, not full Vivado output)
- `results/timing/*.rpt`

---

## Phase 11 — Board Validation & Demo

**Entry:** Phase 9 + Phase 10 complete.
**Feeds:** Phase 12 (final handoff).

### Tasks
- [ ] Run cryptographic KATs on the actual board
- [ ] Confirm 100 MHz operation
- [ ] Measure boot-time cycles for a stated firmware size (R18)
- [ ] Run the demo:
  - [ ] Valid image → "boot OK" LED pattern (4 discrete LEDs)
  - [ ] Flip one byte via slide switch → "boot refused" LED pattern
- [ ] Record photo/video evidence

### Exit Gate (HARD)
- [ ] KATs pass on board → `results/board/board_kat_pass.log`
- [ ] Boot-time cycle count recorded with firmware size and conditions
- [ ] Demo: two distinct, observable LED outcomes on hardware
- [ ] Evidence: `results/board/demo_evidence/`

### Artifacts
- `results/board/board_kat_pass.log`
- `results/board/boot_time_measurement.md`
- `results/board/demo_evidence/`

---

## Phase 12 — Final Documentation & Handoff

**Entry:** Phase 11 complete.

### Tasks
- [ ] Complete `docs/requirements_traceability.md` with links to actual commits/files
- [ ] Finalize `docs/architecture.md`, `docs/threat_model.md`, `docs/register_map.md`
- [ ] Write `docs/research_review.md` with paper analysis and comparison results
- [ ] Verify every citation/URL in `references/` still resolves
- [ ] Confirm clean clone + documented steps reproduces headline results
- [ ] Update `docs/status.md` with final project state

### Exit Gate (Definition of Done)
- [ ] Every requirement R1–R19 has traced artifact, test, and evidence
- [ ] No `[MEASURE — not yet obtained]` cells remain in results tables
- [ ] All documentation is complete and internally consistent
- [ ] Repository is clean, documented, and reproducible

### Artifacts
- All `docs/*.md` finalized
- `README.md` updated with project summary and quick-start instructions

---

*Last updated: 2026-10-21 | Update this file as tasks are completed — mark `[x]` only when evidence exists.*
