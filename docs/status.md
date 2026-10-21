# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Updated after every action. Read this first at the start of every session.**

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Phase 5 — AEAD and Hash Mode Controller |
| **Last Action** | Phase 4 Datapath & Architectural Exploration 100% Complete: Designed, simulated, and verified all three Ascon permutation variants (1-round baseline `permutation_1r.sv`, 2-round unrolled `permutation_2r.sv`, and 1/2-round pipelined `permutation_half.sv`), along with ESPRESSO minimal SOP S-box (`sbox5_espresso.sv`) proven exhaustively equivalent (`tb_sbox_equiv.sv`); 11/11 regression suites passing green |
| **Date** | 2026-10-21 |
| **Overall Progress** | ██████░░░░ ~60% (Phase 0, 1, 3, 4 complete; Phase 2 bitstream ready; 11/11 regression passing) |

---

## Phase Status

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Spec Audit & Research | `✅ COMPLETED` | All R-1 through R-8 complete; all exit gates met |
| 1 | Repo & Environment | `✅ COMPLETED` | Clean repo; .gitignore active; tb_hello.sv passing; regression script passing |
| 2 | RISC-V Bring-up | `🟡 BITSTREAM BUILT` | Simulation verified in Vivado GUI; build/top_bringup.bit ready for hardware flash |
| 3 | Golden Model | `✅ COMPLETED` | 100% KAT pass in reference/run_kats.py (2,120 vectors); ready as RTL oracle |
| 4 | Permutation Datapath | `✅ COMPLETED` | All 3 variants (1R, 2R, 1/2R) bit-exact; unblocks Phase 5 |
| 5 | AEAD/Hash Controller | `🟡 READY / NEXT` | Mode FSM, absorbing/squeezing, tag verification, security plaintext gate |
| 6 | Bus Integration | `⬜ NOT STARTED` | Blocked on Phase 2 + 5 |
| 7 | DMA Integration | `⬜ NOT STARTED` | Blocked on Phase 6 |
| 8 | Secure Boot | `⬜ NOT STARTED` | Blocked on Phase 7 |
| 9 | Formal CTL | `⬜ NOT STARTED` | Blocked on Phase 8 (Model verified in Phase 0 R-7) |
| 10 | Synthesis/Performance | `⬜ NOT STARTED` | Blocked on Phase 4/5 |
| 11 | Board Validation | `⬜ NOT STARTED` | Blocked on Phase 9 + 10 |
| 12 | Final Docs/Handoff | `⬜ NOT STARTED` | Blocked on Phase 11 |

---

## Blockers & Open Questions

| # | Issue | Status | Resolution |
|---|---|---|---|
| 1 | "Half a round per cycle" definition (§18-A) | `⬜ UNRESOLVED` | Need instructor confirmation |
| 2 | ESPRESSO/kernel/BDD — one or all three? (§18-C) | `⬜ UNRESOLVED` | Need instructor confirmation |
| 3 | nuXmv acceptable for CTL proof? (§18-F) | `⬜ UNRESOLVED` | Need instructor confirmation |
| 4 | Masking: research-only or must implement? (§18-G) | `⬜ UNRESOLVED` | Need instructor confirmation |

---

## Recent Activity Log

| Date | Action | Files Changed |
|---|---|---|
| 2026-10-21 | Phase 4 Permutation Datapath & Architectural Exploration completed (1-round `permutation_1r.sv`, 2-round unrolled `permutation_2r.sv`, 1/2-round pipelined `permutation_half.sv`, Berkeley ESPRESSO minimal SOP S-box `sbox5_espresso.sv`, exhaustive equivalence verified in `tb_sbox_equiv.sv`, full regression 11/11 passing in 50.59s) | `rtl/ascon/*`, `tb/unit/*`, `docs/implementation_plan.md`, `docs/status.md` |
| 2026-10-21 | Phase 2 Bitstream Synthesis & Waveform Tools completed (Vivado 2025.1 synthesis, opt, place, route; WNS = +3.098 ns; top_bringup.bit built; program_board.tcl created; view_waveform.py & open_wave_gui.bat created) | `rtl/soc/top_bringup_board.sv`, `firmware/tests/gpio_toggle_board.*`, `scripts/build_bitstream.tcl`, `scripts/program_board.tcl`, `scripts/view_waveform.py`, `scripts/open_wave_gui.bat`, `results/board/phase2_bringup.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 2 Bring-Up Simulation completed (PicoRV32 AXI core, 16 KB BRAM, AXI4-Lite GPIO peripheral, gpio_toggle.c firmware, tb_picorv32_bringup.sv verified in XSim) | `rtl/soc/picorv32.v`, `rtl/soc/top_bringup.sv`, `firmware/linker/bringup.ld`, `firmware/startup/crt0.S`, `firmware/tests/gpio_toggle.c`, `firmware/build_firmware.py`, `tb/unit/tb_picorv32_bringup.sv`, `results/board/phase2_bringup.md`, `scripts/run_regression.py`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-8 & Phase 1 completed (Golden model KAT verification, tb_hello.sv unit test, and automated regression runner) | `reference/kat/*`, `reference/pyascon/*`, `reference/run_kats.py`, `results/kat/*`, `tb/unit/tb_hello.sv`, `scripts/run_regression.*`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-6 & R-7 completed (Hardware papers literature review, tooling audit, formal CTL specification & model checker) | `docs/research_review.md`, `docs/decisions/tooling.md`, `formal/ctl/*`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-4 & R-5 completed (AXI4-Lite/DMA bus architecture & S-box optimization methodology) | `docs/register_map.md`, `docs/architecture.md`, `tools/sbox_opt/*`, `docs/decisions/sbox_optimization.md`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-2 & R-3 completed (Zybo Z7-10 constraints & RISC-V selection) | `board/zybo_z7_10.xdc`, `docs/decisions/riscv_core.md`, `docs/architecture.md`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-1 completed (SP 800-232 algorithm audit) | `docs/architecture.md`, `docs/decisions/algorithm_version.md`, `docs/research_plan.md`, `docs/implementation_plan.md`, `reference/ascon-c/` |
| 2026-10-21 | Project structure initialized | All directories, AGENTS.md, docs/*.md |
| 2026-10-21 | GitHub repo linked | Cloned https://github.com/aayan-garg/Ascon-AEAD-and-HASH.git |

---

## Next Steps (Immediate)

1. **Proceed to Phase 5: AEAD & Hash Mode Controller**
   - Implement `rtl/ascon/mode_ctrl.sv` (Master Sponge FSM per §8.4: IDLE → INIT → ABSORB_AD → ABSORB_PT_CT → FINALIZE → TAG_CHECK → DONE)
   - Implement `rtl/ascon/plaintext_gate.sv` (Plaintext Release Security Gate: zeroization on tag mismatch per §10.3)
   - Implement unit testbench `tb/unit/tb_mode_ctrl.sv` & `tb_security_gate.sv` against NIST SP 800-232 vectors

---

*This file must be updated after every completed action. See `AGENTS.md` §1.3.*
