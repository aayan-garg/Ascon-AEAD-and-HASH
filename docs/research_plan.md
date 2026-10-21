# Research Plan — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Purpose:** This document lists every research task required before or during implementation, organized by topic. Each task has a clear objective, authoritative sources, deliverables, and a link to the implementation phase it feeds.
>
> **Rule:** No research finding may be assumed complete until the source has been opened and the specific claim verified. Use the `[SOURCE]`/`[ASSUME]`/`[MEASURE]` tags from `AGENTS.md`.

---

## Status Summary

| # | Research Area | Status | Phase Dependency |
|---|---|---|---|
| R-1 | Ascon Algorithm (SP 800-232) | `[x] COMPLETED` | Phase 0, 3 |
| R-2 | Zybo Z7-10 Hardware Constraints | `[x] COMPLETED` | Phase 0, 2 |
| R-3 | RISC-V Core Selection | `[x] COMPLETED` | Phase 0, 2 |
| R-4 | AXI4-Lite / DMA Architecture | `[x] COMPLETED` | Phase 0, 6, 7 |
| R-5 | S-box Optimization Techniques | `[x] COMPLETED` | Phase 0, 4 |
| R-6 | Ascon Hardware Papers (Mandatory Research) | `[x] COMPLETED` | Phase 0, 12 |
| R-7 | Formal Verification (CTL) Tooling | `[x] COMPLETED` | Phase 0, 9 |
| R-8 | Golden Model & KAT Vectors | `[x] COMPLETED` | Phase 0, 3 |

---

## R-1: Ascon Algorithm Specification

### Objective
Fully understand the Ascon-AEAD128 and Ascon-Hash256 algorithms per NIST SP 800-232 (the *final* standard, not pre-2025 Ascon v1.2).

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| NIST SP 800-232 (Final) | https://csrc.nist.gov/pubs/sp/800/232/final | State structure, permutation rounds (pa=12, pb=8/12), rate/capacity, padding, domain separation, byte ordering (little-endian) |
| ascon/ascon-c (official reference) | https://github.com/ascon/ascon-c | KAT vectors, reference C code, byte-order conventions |
| meichlseder/pyascon | https://github.com/meichlseder/pyascon | Python reference for golden model |
| ascon/ascon_collection | https://github.com/ascon/ascon_collection | Index of verified SP 800-232 implementations |

### Critical Warning
SP 800-232 uses **little-endian** byte/word conventions. Pre-2025 "Ascon v1.2" (Ascon-128/128a) used big-endian. These are NOT byte-for-byte compatible. Any pre-2025 RTL (including OpenTitan's Ascon IP) must be re-validated.

### Tasks
- [x] Download and read SP 800-232 §3–§5 (state definition, permutation, AEAD, Hash modes)
- [x] Extract the exact S-box truth table from the standard
- [x] Document the exact round constants (p_a, p_b round counts and constant-addition values)
- [x] Document padding and domain-separation rules for AEAD and Hash
- [x] Verify byte ordering (little-endian) against the `ascon-c` reference code
- [x] Document the sponge rate for AEAD (128 bits / 16 bytes) and Hash (64 bits / 8 bytes) per SP 800-232
- [x] Create `docs/decisions/algorithm_version.md` confirming SP 800-232 (not v1.2)

### Deliverables
- `docs/architecture.md` §Algorithm — detailed Ascon specification summary (Completed)
- `docs/decisions/algorithm_version.md` — version confirmation (Completed)
- `reference/ascon-c` — official reference implementation cloned and verified with KAT tests (Completed)

---

## R-2: Zybo Z7-10 Hardware Constraints

### Objective
Verify all hardware constraints for the **Z7-10** variant (NOT the Z7-20, which has different resources).

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| Zybo Z7 Reference Manual | https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual | Part number, BRAM, LUT, DSP, clocking, I/O |
| Zybo Z7 Start Page | https://digilent.com/reference/programmable-logic/zybo-z7/start | Z7-10 vs Z7-20 comparison |
| XC7Z010 Datasheet | AMD/Xilinx DS190 | PL resource counts, speed grades |

### Tasks
- [x] Confirm part number: XC7Z010-1CLG400C
- [x] Confirm PL cells: 35,200 (not 106,400 = Z7-20)
- [x] Confirm BRAM: 270 KB (not 630 KB = Z7-20)
- [x] Confirm DSP slices: 80 (not 220 = Z7-20)
- [x] Confirm clock sources: 125 MHz on pin K17 (PL), 33.333 MHz PS_CLK
- [x] Confirm I/O: 4 LEDs, 1 RGB LED, 4 switches, 4 buttons
- [x] Document DDR3L is PS-side only (not directly PL-attached)
- [x] Document the MMCM plan: 125 MHz → 100 MHz via MMCM

### Deliverables
- `docs/architecture.md` §Hardware Constraints (Completed)
- `board/zybo_z7_10.xdc` (Completed)

---

## R-3: RISC-V Core Selection

### Objective
Compare PicoRV32, VexRiscv, and Ibex for this project's needs and justify the final choice.

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| PicoRV32 | https://github.com/YosysHQ/picorv32 | AXI4-Lite variant, native bus, area, features |
| VexRiscv | https://github.com/SpinalHDL/VexRiscv | Configurability, bus plugins, toolchain needs |
| Ibex | https://github.com/lowRISC/ibex | Verification maturity, SystemVerilog, bus adapters |

### Decision Criteria
1. Native AXI4-Lite master support (critical for Phase 6)
2. Integration complexity (time-boxed student project)
3. Toolchain requirements (no JVM/Scala dependency preferred)
4. Area footprint on XC7Z010

### Tasks
- [x] Read PicoRV32 README — confirm `picorv32_axi` variant and `picorv32_axi_adapter`
- [x] Read VexRiscv docs — confirm AXI4 plugin (note: full AXI4, not AXI4-Lite)
- [x] Read Ibex README — confirm bus interface situation
- [x] Document decision in `docs/decisions/riscv_core.md`

### Deliverables
- `docs/decisions/riscv_core.md` — comparison table and final choice (Completed)
- Recommendation: **PicoRV32** (primary), **VexRiscv** (fallback)

---

## R-4: AXI4-Lite / DMA Architecture

### Objective
Design the bus topology separating control-plane (AXI4-Lite) from data-plane (custom DMA).

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| AXI DMA v7.1 PG021 | https://www.amd.com/content/dam/xilinx/support/documents/ip_documentation/axi_dma/v7_1/pg021_axi_dma.pdf | AXI4-Lite control + AXI4 data separation pattern |
| ARM AMBA AXI Specification | ARM IHI 0022 | AXI4-Lite protocol details |

### Tasks
- [x] Study the Xilinx AXI DMA IP architecture (control vs. data path separation)
- [x] Design the register map (see Initial Research §11.2 for proposal)
- [x] Define the custom DMA master interface (valid/ready streaming, not full AXI4 burst)
- [x] Document in `docs/register_map.md` and `docs/architecture.md`

### Deliverables
- `docs/register_map.md` — complete register map with field definitions (Completed)
- `docs/architecture.md` §Bus Architecture (Completed)

---

## R-5: S-box Optimization Techniques

### Objective
Understand ESPRESSO, kernel extraction, and BDD techniques for the 5×5 Ascon S-box, and plan the comparison experiment.

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| Stoffelen, ePrint 2016/198 | https://eprint.iacr.org/2016/198.pdf | Ascon S-box multiplicative complexity = 5 |
| TCHES 2026, ePrint 2026/726 | https://eprint.iacr.org/2026/726 | First 4-gate-depth Ascon S-box circuit (SLICE technique) |
| NIST LWC Workshop 2023 | https://csrc.nist.gov/csrc/media/Events/2023/lightweight-cryptography-workshop-2023/documents/accepted-papers/07-hardware-implementation-of-ascon.pdf | Hardware S-box implementation details |

### Tasks
- [x] Extract the normative 5×5 S-box truth table from SP 800-232
- [x] Research ESPRESSO minimization for the 5-bit S-box (5 output functions of 5 inputs)
- [x] Research kernel extraction for multi-level logic optimization
- [x] Research BDD-based optimization
- [x] Plan the comparison experiment: standard Boolean-equation vs. optimized variant(s)
- [x] Clarify with instructor: are all three techniques required, or just one? (`[ASSUME]` — §18-C)

### Deliverables
- `docs/decisions/sbox_optimization.md` — methodology and plan (Completed)
- `tools/sbox_opt/` — optimization scripts and PLA truth table (Completed)
- `docs/architecture.md` §Substitution Layer (Completed)

---

## R-6: Ascon Hardware Papers (Mandatory Research Requirement)

### Objective
Find and analyze at least one Ascon hardware paper; select one technique to implement.

### Key Sources (Verified)
| Source | URL | Focus |
|---|---|---|
| Gross et al., DSD 2015 | https://eprint.iacr.org/2015/034.pdf | Unrolled/high-throughput ASIC implementations |
| ACM Review (2025) | https://dl.acm.org/doi/full/10.1145/3721122 | FPGA/ASIC comparison of LWC finalists |
| PMC Serialized (2025) | https://pmc.ncbi.nlm.nih.gov/articles/PMC13396216/ | Low-area serialized implementation |
| Malal, ePrint 2025/825 | https://eprint.iacr.org/2025/825 | FPGA throughput/area numbers (Kintex-7/Artix-7) |
| Gross et al., 2017 | Microprocessors and Microsystems 52 (2017) | DOM/UMA masked Ascon |
| ePrint 2024/984 | https://eprint.iacr.org/2024/984.pdf | Threshold implementation, ~3.15×–4.5× area overhead |

### Tasks
- [x] Read at least 3 papers from the list above (analyzed 5 papers: Gross DSD 2015, ACM Survey 2025, PMC Serialized 2025, Malal ePrint 2025/825, Gross 2017/2024 Masking)
- [x] Document findings in `docs/research_review.md`
- [x] Select one technique for implementation (recommendation: multi-point round-unrolling / serialization: ½, 1, 2 rounds/cycle)
- [x] Note comparability caveats: ASIC kGE ≠ FPGA LUTs; pre-standard Ascon ≠ SP 800-232
- [x] Plan the comparison: area, throughput (Mbit/s), throughput/area for the chosen technique vs. baseline

### Deliverables
- `docs/research_review.md` — paper summaries with citations, selected technique, comparison plan (Completed)
- One implemented technique (Phase 12/14 of implementation plan)

---

## R-7: Formal Verification (CTL) Tooling

### Objective
Establish the toolchain for proving `AG(jump → hash_ok)` using CTL model checking.

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| nuXmv User Manual | https://nuxmv.fbk.eu/downloads/nuxmv-user-manual.pdf | CTLSPEC syntax, usage |
| Verilog2SMV (DATE 2016) | https://es-static.fbk.eu/tools/verilog2smv/dload/date2016-paper-verilog2smv.pdf | Verilog → SMV translation |
| REDS 2024 SymbiYosys talk | https://indico.cern.ch/event/1381060/contributions/5923296/attachments/2874315/5037748/REDS_2024_06_13_Thoma_formal_verif.pdf | Confirms no CTL support in SymbiYosys |
| SymbiYosys | https://github.com/YosysHQ/SymbiYosys | SVA-based bounded model checking (not CTL) |

### Key Decision
- **nuXmv/NuSMV** for the CTL proof (native CTL support)
- **SymbiYosys** for auxiliary SVA assertions only (NOT for the CTL requirement)
- **Verilog2SMV** to translate RTL FSM → SMV model

### Tasks
- [x] Install / configure nuXmv and verify model checking execution path
- [x] Plan Verilog2SMV translation and SMV modeling structure
- [x] Confirm SymbiYosys scope (bounded LTL / SVA for bus interfaces)
- [x] Create formal SMV specification and model checking runner: proved `AG(jump -> hash_ok)`
- [x] Document tool versions in `docs/decisions/tooling.md`
- [x] Plan the abstracted model boundary (boot-control FSM only, §13.2 of Initial Research)

### Deliverables
- `docs/decisions/tooling.md` — all tool versions pinned (Completed)
- `formal/ctl/` — nuXmv scripts, SMV model (`boot_safety.smv`), explicit model checker (`verify_smv.py`), and documentation (`README.md`) (Completed)

---

## R-8: Golden Model & KAT Vectors

### Objective
Establish a trusted golden software model that passes all official NIST KATs before it is used as the RTL oracle.

### Key Sources
| Source | URL | What to extract |
|---|---|---|
| ascon/ascon-c | https://github.com/ascon/ascon-c | Official KAT files, reference C code |
| meichlseder/pyascon | https://github.com/meichlseder/pyascon | Python reference implementation |
| ashiduDissanayake/ASCON | https://github.com/ashiduDissanayake/ASCON | 3-layer verification chain example |

### Tasks
- [x] Clone/vendor `pyascon` into `reference/pyascon`
- [x] Download official KAT files from `ascon-c` and organize into `reference/kat/`
- [x] Run the golden model against ALL official KAT vectors (1,089 AEAD + 1,025 Hash = 2,114 vectors)
- [x] Record SHA-256 hashes of the KAT files for integrity
- [x] Add edge-case tests: empty AD, empty message, multi-block, tag mismatch/corruption
- [x] Create `reference/run_kats.py` that produces a pass/fail log and summary

### Exit Gate (Hard)
The golden model must pass **100% of official vectors** before it is trusted as the RTL oracle. This is the Phase 3 exit gate. (`[x] PASSED 100% — 2,120/2,120 vectors passed`)

### Deliverables
- `reference/` — vendored golden model (`reference/pyascon/ascon.py`) + KAT harness (`reference/run_kats.py`) (Completed)
- `results/kat/golden_model_pass.log` & `results/kat/golden_model_summary.md` — evidence of full KAT pass (Completed)

---

## Cross-Reference: Research → Implementation Phase

| Research Area | Feeds Implementation Phase(s) |
|---|---|
| R-1: Ascon Algorithm | Phase 3 (Golden Model), Phase 4 (Permutation), Phase 5 (Controller) |
| R-2: Zybo Z7-10 | Phase 2 (Bring-up), Phase 10 (Synthesis), Phase 11 (Board) |
| R-3: RISC-V Core | Phase 2 (Bring-up) |
| R-4: AXI/DMA | Phase 6 (Bus), Phase 7 (DMA) |
| R-5: S-box Optimization | Phase 4 (Permutation) |
| R-6: Hardware Papers | Phase 12 (Research Technique Implementation) |
| R-7: CTL Tooling | Phase 9 (Formal Verification) |
| R-8: Golden Model | Phase 3 (Golden Model), Phase 4–5 (RTL Oracle) |

---

*Last updated: 2026-10-21 | Update this document whenever a research task is completed or a new research need is identified.*
