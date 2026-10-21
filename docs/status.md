# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Updated after every action. Read this first at the start of every session.**

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Phase 0 — Specification Audit & Research Setup |
| **Last Action** | Project initialized: directory structure, AGENTS.md, research plan, implementation plan created |
| **Date** | 2026-10-21 |
| **Overall Progress** | ██░░░░░░░░ ~5% (structure established, no implementation yet) |

---

## Phase Status

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Spec Audit & Research | `🟡 IN PROGRESS` | Directory structure created; research tasks not yet started |
| 1 | Repo & Environment | `🟡 IN PROGRESS` | Directory created; .gitignore and regression script pending |
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
| 2026-10-21 | Project structure initialized | All directories, AGENTS.md, docs/*.md |
| 2026-10-21 | GitHub repo linked | Cloned https://github.com/aayan-garg/Ascon-AEAD-and-HASH.git |

---

## Next Steps (Immediate)

1. Complete `.gitignore` and `scripts/run_regression.sh` (Phase 1)
2. Begin research tasks R-1 through R-8 (Phase 0)
3. Create placeholder documentation files
4. Set up simulation environment

---

*This file must be updated after every completed action. See `AGENTS.md` §1.3.*
