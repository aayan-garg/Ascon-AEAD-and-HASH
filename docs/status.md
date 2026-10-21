# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Updated after every action. Read this first at the start of every session.**

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Phase 7 — DMA Integration |
| **Last Action** | Phase 6 Accelerator Bus Integration 100% Complete: Designed, simulated, and verified `axil_regs.sv` per `docs/register_map.md`; integrated into SoC top-level `top_bringup.sv`; wrote bare-metal C test `accel_hash_test.c` compiled with RISC-V GCC; verified end-to-end SoC execution `tb_soc_ascon.sv` in 1,027 cycles; 17/17 regression suites passing green in 80.64s |
| **Date** | 2026-10-21 |
| **Overall Progress** | ████████░░ ~78% (Phases 0, 1, 3, 4, 5, 6 complete; Phase 2 bitstream ready; 17/17 regression suites passing) |

---

## Phase Status

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Spec Audit & Research | `✅ COMPLETED` | All R-1 through R-8 complete; all exit gates met |
| 1 | Repo & Environment | `✅ COMPLETED` | Clean repo; .gitignore active; tb_hello.sv passing; regression script passing |
| 2 | RISC-V Bring-up | `🟡 BITSTREAM BUILT` | Simulation verified in Vivado GUI; build/top_bringup.bit ready for hardware flash |
| 3 | Golden Model | `✅ COMPLETED` | 100% KAT pass in reference/run_kats.py (2,120 vectors); ready as RTL oracle |
| 4 | Permutation Datapath | `✅ COMPLETED` | All 3 variants (1R, 2R, 1/2R) bit-exact; unblocks Phase 5 |
| 5 | AEAD/Hash Controller | `✅ COMPLETED` | Mode FSM, absorbing/squeezing, tag verification, security plaintext gate; unblocks Phase 6 |
| 6 | Bus Integration | `✅ COMPLETED` | Register map per docs/register_map.md, AXI4-Lite slave, firmware driver, tb_axil_regs & tb_soc_ascon passing; unblocks Phase 7 |
| 7 | DMA Integration | `🟡 READY / NEXT` | Custom DMA engine dma_master.sv, streaming data plane, boundary testing |
| 8 | Secure Boot | `⬜ NOT STARTED` | Blocked on Phase 7 |
| 9 | Formal CTL | `⬜ NOT STARTED` | Blocked on Phase 8 (Model verified in Phase 0 R-7) |
| 10 | Synthesis/Performance | `⬜ NOT STARTED` | Blocked on Phase 4/5 |
| 11 | Board Validation | `⬜ NOT STARTED` | Blocked on Phase 9 + 10 |
| 12 | Final Docs/Handoff | `⬜ NOT STARTED` | Blocked on Phase 11 |

---

## Blockers & Open Questions

| # | Issue | Status | Resolution |
|---|---|---|---|
| 1 | "Half a round per cycle" definition (§18-A) | `✅ RESOLVED` | Implemented 2-stage pipelined micro-step datapath (`permutation_half.sv`: Stage 1 Constant+S-box, Stage 2 Diffusion); 100% bit-exact |
| 2 | ESPRESSO/kernel/BDD — one or all three? (§18-C) | `✅ RESOLVED` | Synthesized Berkeley ESPRESSO minimal SOP equations (`rtl/ascon/sbox5_espresso.sv`); exhaustive equivalence proven in `tb_sbox_equiv.sv` |
| 3 | nuXmv acceptable for CTL proof? (§18-F) | `✅ RESOLVED` | NuSMV/nuXmv SMV model verified (`formal/ctl/verify_smv.py`); integrated into regression suite |
| 4 | Masking: research-only or must implement? (§18-G) | `🟡 RESEARCH COMPLETE` | Literature review completed (`docs/research_review.md`); architecture trade-off table prepared |

---

## Recent Activity Log

| Date | Action | Files Changed |
|---|---|---|
| 2026-10-21 | Phase 5 AEAD & Hash Mode Controller completed (`mode_ctrl.sv`, `aead_ctrl.sv`, `hash_ctrl.sv`, hardware security shadow buffer `plaintext_gate.sv`, full testbenches `tb_security_gate.sv`, `tb_mode_ctrl.sv`, `tb_hash.sv`, `tb_aead.sv` verified bit-exact against official NIST SP 800-232 KATs, 15/15 regression suites passing green in 68.88s) | `rtl/ascon/*`, `tb/unit/*`, `results/kat/*`, `docs/implementation_plan.md`, `docs/status.md` |
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

1. **Proceed to Phase 6: Accelerator Bus Integration (AXI4-Lite)**
   - Implement `rtl/bus/axil_regs.sv` — register map per `docs/register_map.md` (`0x4000_0000` base)
   - Connect `mode_ctrl.sv` controls, status, key, nonce, tag, digest, and data ports to memory-mapped registers
   - Write integration testbench `tb/integration/tb_axil_regs.sv`
   - Write firmware test `firmware/tests/accel_hash_test.c` for PicoRV32 execution

---

*This file must be updated after every completed action. See `AGENTS.md` §1.3.*
