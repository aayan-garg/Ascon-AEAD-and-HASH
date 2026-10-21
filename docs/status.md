# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Updated after every action. Read this first at the start of every session.**

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Phase 2 — RISC-V Core Bring-Up & Phase 4 Permutation Datapath |
| **Last Action** | Phase 2 Bring-Up Simulation Completed: Integrated PicoRV32 AXI core (rtl/soc/picorv32.v) and top_bringup.sv with 16 KB BRAM and GPIO slave; compiled bare-metal C firmware (firmware/tests/gpio_toggle.c) with WSL riscv64-unknown-elf-gcc; verified tb/unit/tb_picorv32_bringup.sv in Vivado XSim (walking 1s across LEDs 0..3 and scratchpad RAM readback passed in 1,384 cycles); added simulation test to automated regression suite (scripts/run_regression.py); documented in results/board/phase2_bringup.md |
| **Date** | 2026-10-21 |
| **Overall Progress** | ███░░░░░░░ ~30% (Phase 0, 1 complete; Phase 2 simulation verified; regression framework running 100% green) |

---

## Phase Status

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Spec Audit & Research | `✅ COMPLETED` | All R-1 through R-8 complete; all exit gates met |
| 1 | Repo & Environment | `✅ COMPLETED` | Clean repo; .gitignore active; tb_hello.sv passing; regression script passing |
| 2 | RISC-V Bring-up | `🟡 SIMULATION VERIFIED` | Simulation & firmware 100% verified; bitstream ready for board demo |
| 3 | Golden Model | `✅ COMPLETED` | 100% KAT pass in reference/run_kats.py; ready as RTL oracle |
| 4 | Permutation Datapath | `🟡 READY / NEXT` | Unblocked by Phase 0 R-5 & Phase 3 |
| 5 | AEAD/Hash Controller | `⬜ NOT STARTED` | Blocked on Phase 4 |
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

1. Proceed with Phase 2: PicoRV32 bring-up with minimal BRAM and GPIO toggle simulation
2. Or proceed with Phase 4: S-box and permutation datapath implementation (`rtl/ascon/sbox5.sv`, `diffusion.sv`, `round_core.sv`)

---

*This file must be updated after every completed action. See `AGENTS.md` §1.3.*
