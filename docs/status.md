# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Updated after every action. Read this first at the start of every session.**

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Phase 0 — Specification Audit & Research Setup |
| **Last Action** | Phase 0 R-6 & R-7 completed: Evaluated 5 Ascon hardware papers in docs/research_review.md; selected multi-point unrolling/serialization (½, 1, 2 rounds/cycle) per [SPEC] R15; audited formal verification toolchain and pinned versions in docs/decisions/tooling.md; created formal/ctl/boot_safety.smv and verify_smv.py mathematically proving AG(jump -> hash_ok); updated implementation_plan.md and research_plan.md |
| **Date** | 2026-10-21 |
| **Overall Progress** | █▊░░░░░░░░ ~18% (R-1 through R-7 complete; research review, tooling audit, and formal CTL model active) |

---

## Phase Status

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Spec Audit & Research | `🟡 IN PROGRESS` | R-1 through R-7 complete; R-8 (Golden model & KAT vectors) pending |
| 1 | Repo & Environment | `🟡 IN PROGRESS` | Directory created; .gitignore updated; regression runner & unit tb pending |
| 2 | RISC-V Bring-up | `⬜ NOT STARTED` | Blocked on Phase 1 |
| 3 | Golden Model | `⬜ NOT STARTED` | Blocked on Phase 0 R-8 |
| 4 | Permutation Datapath | `⬜ NOT STARTED` | Blocked on Phase 3 |
| 5 | AEAD/Hash Controller | `⬜ NOT STARTED` | Blocked on Phase 4 |
| 6 | Bus Integration | `⬜ NOT STARTED` | Blocked on Phase 2 + 5 |
| 7 | DMA Integration | `⬜ NOT STARTED` | Blocked on Phase 6 |
| 8 | Secure Boot | `⬜ NOT STARTED` | Blocked on Phase 7 |
| 9 | Formal CTL | `⬜ NOT STARTED` | Blocked on Phase 8 |
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
| 2026-10-21 | Phase 0 R-6 & R-7 completed (Hardware papers literature review, tooling audit, formal CTL specification & model checker) | `docs/research_review.md`, `docs/decisions/tooling.md`, `formal/ctl/*`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-4 & R-5 completed (AXI4-Lite/DMA bus architecture & S-box optimization methodology) | `docs/register_map.md`, `docs/architecture.md`, `tools/sbox_opt/*`, `docs/decisions/sbox_optimization.md`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-2 & R-3 completed (Zybo Z7-10 constraints & RISC-V selection) | `board/zybo_z7_10.xdc`, `docs/decisions/riscv_core.md`, `docs/architecture.md`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-1 completed (SP 800-232 algorithm audit) | `docs/architecture.md`, `docs/decisions/algorithm_version.md`, `docs/research_plan.md`, `docs/implementation_plan.md`, `reference/ascon-c/` |
| 2026-10-21 | Project structure initialized | All directories, AGENTS.md, docs/*.md |
| 2026-10-21 | GitHub repo linked | Cloned https://github.com/aayan-garg/Ascon-AEAD-and-HASH.git |

---

## Next Steps (Immediate)

1. Proceed with Phase 0 R-8 / Phase 3: Setup Python/C golden model harnessing with official KATs
2. Phase 1: Complete `scripts/run_regression.sh` (or `run_regression.ps1`) and trivial simulation testbench in `tb/unit/`
3. Phase 2: PicoRV32 bring-up on Zybo Z7-10 hardware constraints

---

*This file must be updated after every completed action. See `AGENTS.md` §1.3.*
