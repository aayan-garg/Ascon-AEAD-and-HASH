# AGENTS.md — Antigravity Operating Instructions for Ascon RTL Project

> **This file is the single source of truth for how Antigravity (or any AI agent) must behave when working inside this repository.**
> Every session must start by reading this file. If a conflict exists between this file and a conversational instruction, this file wins.

---

## 1. Golden Rules

### 1.1 Never Fabricate Data
- **No invented numbers.** If a value requires measurement (synthesis LUTs, timing WNS, throughput Mbit/s, cycle counts, area figures), write `[MEASURE — not yet obtained]` instead of making up a plausible number.
- **No invented references.** If you cannot verify a URL or citation resolves, say so. Do not construct a plausible-looking DOI, paper title, or GitHub link.
- **No invented test results.** If a test has not been run, mark it `[ ] NOT RUN`. Never mark `[x]` without evidence.
- If you are uncertain whether a fact is correct, **perform research** (web search, read the spec, read the cited paper) rather than guessing. Guessing is hallucination.

### 1.2 Maintain the Directory Structure
The canonical directory layout is defined in [`docs/directory_structure.md`](docs/directory_structure.md). You MUST:
- Place RTL files only under `rtl/` in their correct subdirectory (`ascon/`, `bus/`, `dma/`, `soc/`, `top/`).
- Place testbenches only under `tb/` (`unit/`, `integration/`, `system/`).
- Place firmware only under `firmware/` (`bootrom/`, `linker/`, `startup/`, `tests/`).
- Place formal verification files only under `formal/` (`ctl/`, `sva/`).
- Place board constraints and bitstream scripts under `board/`.
- Place tool outputs, logs, and extracted results under `results/` (never commit raw Vivado `.runs/` or multi-GB dumps).
- Place reference/golden model code under `reference/`.
- Place S-box optimization tools under `tools/sbox_opt/`.
- **Never create files outside the established tree** without updating `docs/directory_structure.md` first and documenting the reason.

### 1.3 Track Status After Every Step
After completing **any** implementation task, test run, or research action:
1. Update [`docs/status.md`](docs/status.md) with:
   - What was done (one-line summary).
   - Current phase (per the Implementation Plan).
   - What changed (files created/modified).
   - What's next (the immediate next task).
   - Any blockers or open questions.
2. If a phase exit gate was attempted, record PASS/FAIL with evidence path.

### 1.4 When In Doubt, Research — Don't Guess
If a question arises about:
- **Ascon algorithm details** → Read NIST SP 800-232 or the `ascon/ascon-c` reference, not memory.
- **Zybo Z7-10 constraints** → Check the Digilent Reference Manual, not assumptions.
- **PicoRV32 bus interface** → Read the PicoRV32 README on GitHub, not a paraphrase.
- **AXI protocol** → Read the ARM AMBA AXI spec or Xilinx PG021, not a summary.
- **Any hardware figure** → Run synthesis or simulation; do not copy numbers from papers (different device, different algorithm version).

---

## 2. Reference Documents — When To Consult Each

| Document | Location | Consult When... |
|---|---|---|
| **Initial Research** | [`../Initial Research.md`](../Initial Research.md) | Needing architecture rationale; checking original requirements analysis (§3); understanding initial S-box/permutation/CTL strategy |
| **Final Technical Report** | [`docs/final_report.md`](docs/final_report.md) | Reviewing complete technical evaluation, verification results, and project closure |
| **Research Review** | [`docs/research_review.md`](docs/research_review.md) | Reviewing peer-reviewed literature, verified DOIs, and S-box optimization trade-offs |
| **Requirements Traceability** | [`docs/requirements_traceability.md`](docs/requirements_traceability.md) | Single source of truth for R1–R19 status and evidence file links |
| **Directory Structure** | [`docs/directory_structure.md`](docs/directory_structure.md) | Creating any new file or directory; doing a structural review |
| **Status Tracker** | [`docs/status.md`](docs/status.md) | Starting any session (to know where we left off); after completing any task (to update it) |
| **Project Spec** | [`../Project_PS.md`](../Project_PS.md) | Verifying a requirement is real vs. recommended; checking exact spec wording |
| **Register Map** | [`docs/register_map.md`](docs/register_map.md) | Writing bus integration RTL or firmware that accesses the accelerator |
| **Architecture** | [`docs/architecture.md`](docs/architecture.md) | Understanding FSMs, data flows, mode controller state table |
| **Threat Model** | [`docs/threat_model.md`](docs/threat_model.md) | Writing secure-boot logic; understanding trust boundaries |
| **Audit Response** | [`docs/AUDIT_RESPONSE.md`](docs/AUDIT_RESPONSE.md) | Reviewing audit findings, remediation history, and evidence artifacts |
| **Decisions Log** | [`docs/decisions/`](docs/decisions/) | Checking if an ambiguity has been resolved; recording a new decision |

---

## 3. Labeling Convention

All claims, numbers, and recommendations in documentation must be tagged:

| Tag | Meaning | Rule |
|---|---|---|
| `[SPEC]` | Taken from `Project_PS.md` verbatim/near-verbatim | Never alter the requirement |
| `[SOURCE]` | Backed by a cited, verified external source | Must include URL or DOI |
| `[REC]` | Engineering recommendation by the team/agent | Clearly marked as non-mandatory |
| `[ASSUME]` | Assumption needing instructor/team confirmation | Must be tracked in `docs/decisions/` |
| `[MEASURE]` | A number that can ONLY come from running the experiment | **NEVER fill in with a guess** |

---

## 4. Coding Standards

### 4.1 RTL (SystemVerilog)
- Use `_sv` or `.sv` file extension for all RTL.
- One module per file. Filename = module name.
- All signals use `snake_case`. Parameters use `UPPER_SNAKE_CASE`.
- Every module must have a header comment: purpose, author, date, dependencies.
- Combinational blocks use `always_comb`. Sequential blocks use `always_ff @(posedge clk)`.
- No latches unless explicitly justified and documented.
- Reset: synchronous active-high `rst` unless the chosen RISC-V core requires otherwise.

### 4.2 Firmware (C)
- RISC-V bare-metal C. No OS, no stdlib beyond what's in the linker script.
- Use `stdint.h` types (`uint32_t`, etc.).
- All hardware register accesses through `volatile` pointers defined in a single `hw_regs.h`.

### 4.3 Testbenches
- Testbench files prefixed with `tb_` (e.g., `tb_sbox5.sv`).
- Every testbench must print `PASS` or `FAIL` to stdout and return a nonzero exit code on failure.
- Golden-model comparison tests must load vectors from files, not hardcode them inline.

### 4.4 Python (Reference/Scripts)
- Python 3.10+. Use type hints.
- Reference model must be runnable standalone: `python reference/run_kats.py` produces a pass/fail log.

---

## 5. Phase Gate Protocol

Before advancing from Phase N to Phase N+1:
1. **All** requirement items in [`docs/requirements_traceability.md`](docs/requirements_traceability.md) must be verified.
2. **All** tests for Phase N must show `PASS` with evidence files in `results/`.
3. [`docs/status.md`](docs/status.md) must reflect the completed phase.
4. If a hard gate exists (e.g., "board LED toggle" for Phase 2), that evidence must be recorded before proceeding.
5. If a gate cannot be passed, document the blocker in `docs/status.md` and `docs/decisions/` and **do not proceed** — ask the user.

---

## 6. Anti-Hallucination Checklist

Before finalizing any response that includes technical claims, run this mental checklist:

- [ ] Did I verify the Ascon specification detail against SP 800-232, not memory?
- [ ] Did I check the board constraint against the Digilent Reference Manual (Z7-10, not Z7-20)?
- [ ] Are all numbers I'm reporting either `[MEASURE — not yet obtained]` or from an actual tool run I can point to?
- [ ] Did I actually read the source I'm citing, or am I reconstructing it from a snippet?
- [ ] Am I claiming a test passes? If so, where is the log file?
- [ ] Am I comparing figures across different devices/algorithm versions? If so, did I flag the caveat?

If any answer is "no" → stop and research before continuing.

---

## 7. Session Start Protocol

At the beginning of every new conversation/session:
1. Read this file (`AGENTS.md`).
2. Read [`docs/status.md`](docs/status.md) to understand current state.
3. Read [`docs/requirements_traceability.md`](docs/requirements_traceability.md) and [`docs/final_report.md`](docs/final_report.md) to understand verification status.
4. If the user gives a task, map it to a phase/requirement before starting work.
5. After completing the task, update `docs/status.md`.

---

## 8. Git Workflow

- Commit messages: `[Phase X] brief description` (e.g., `[Phase 4] Implement sbox5.sv with exhaustive truth-table test`).
- Never commit generated/binary files (`.bit`, `.ltx`, `.dcp`, `.runs/`, `__pycache__/`).
- Keep `results/` content as small text/CSV/Markdown logs, not raw tool output.
- The `.gitignore` must be maintained to exclude Vivado project files, simulation dumps, and editor temp files.

---

*This document was created on 2026-10-21 and must be updated whenever project conventions change.*
