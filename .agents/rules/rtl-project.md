# RTL Project Rules for Antigravity

> These rules are loaded automatically by Antigravity when working in this workspace.

## Mandatory Behaviors

1. **Read `AGENTS.md` at the start of every session.** It contains the full operating protocol.
2. **Read `docs/status.md` to understand current project state** before doing any work.
3. **Update `docs/status.md` after every completed action** — no exceptions.
4. **Never fabricate numbers.** Use `[MEASURE — not yet obtained]` for unmeasured values.
5. **Never fabricate references.** If a URL/DOI cannot be verified, say so explicitly.
6. **Maintain the directory structure** defined in `docs/directory_structure.md`.
7. **Follow the phase gate protocol** — do not skip phases or mark incomplete gates as done.
8. **When uncertain, research** — read the actual spec/datasheet/paper rather than guessing.

## File Placement Rules

- RTL → `rtl/{ascon,bus,dma,soc,top}/`
- Testbenches → `tb/{unit,integration,system}/`
- Firmware → `firmware/{bootrom,linker,startup,tests}/`
- Formal verification → `formal/{ctl,sva}/`
- Results → `results/{kat,performance,synthesis,timing,formal,board}/`
- Documentation → `docs/`
- Board files → `board/`

## References to Consult

| When doing... | Read... |
|---|---|
| Starting a session | `AGENTS.md`, `docs/status.md` |
| Checking project status | `docs/final_report.md`, `docs/requirements_traceability.md` |
| Doing research | `docs/research_review.md` |
| Writing RTL | `docs/architecture.md`, `docs/register_map.md` |
| Adding files | `docs/directory_structure.md` |
| Checking requirements | `docs/requirements_traceability.md` |
| Understanding security | `docs/threat_model.md` |
| Resolving ambiguity | `docs/decisions/` |
