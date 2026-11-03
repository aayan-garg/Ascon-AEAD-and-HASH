# PS Re-evaluation: Ascon AEAD and Hash Engine for IoT Secure Boot

> **Created:** 2026-11-03 by independent re-audit (Antigravity re-audit session)  
> **Source of truth:** `../Project_PS.md` — read line-by-line. All previous claims in `docs/validation_report.md` are treated as **UNVERIFIED** pending fresh evidence.  
> **Label key:** [SPEC] from PS verbatim | [SOURCE] cited+verified | [REC] engineering recommendation | [ASSUME] needs confirmation | [MEASURE] must be measured | [UNVERIFIED] claimed but not independently confirmed this session

---

## STEP 0 — Confirming Reading Order Compliance

This document was written AFTER reading, in order:
1. `../Project_PS.md` — read in full (33 lines), the only source of truth.
2. `AGENTS.md` — read in full (153 lines), operating constraints.
3. `docs/implementation_plan.md`, `docs/status.md`, `docs/validation_report.md`, `docs/requirements_traceability.md` — read as **UNVERIFIED claims**.

---

## 1. PS Requirement Re-Derivation (Atomic Checkable Requirements)

### SPECIFICATION Section

| ID | Requirement Text (from PS) | Status | Evidence / Proof This Session | Gap / Action to Close |
|---|---|---|---|---|
| **S1** | Ascon-AEAD128 (encrypt/decrypt with tag check) per NIST SP 800-232 | **PARTIAL** | `reference/run_kats.py` re-run this session: 1089/1089 Python model PASS [MEASURE - re-run DONE]. RTL tb_aead.sv: 4 vectors + 2 tamper tests (hardcoded, not full KAT suite). | Rewrite `tb/unit/tb_aead.sv` to loop over all 1089 NIST vectors from file. |
| **S2** | Ascon-Hash256 per NIST SP 800-232 | **PARTIAL** | Python model: 1025/1025 PASS this session. RTL `tb_hash.sv`: thin (4 hardcoded vectors). | Rewrite `tb/unit/tb_hash.sv` to loop over all 1025 hash vectors. |
| **S3** | 320-bit state (5×64-bit words) | **DONE-VERIFIED** | `rtl/ascon/round_core.sv` inspected: uses 5×64-bit words. Synthesis report shows 544 LUTs for permutation core. | None. |
| **S4** | Round-based datapath, one round per cycle baseline | **DONE-VERIFIED** | `permutation_1r.sv` confirmed in synthesis report (544 LUTs). Mode controller uses `permutation_1r` only. | F5: other variants (2r, half) not connected to mode controller. |
| **S5** | Plaintext released only after successful tag check | **DONE-VERIFIED** | `plaintext_gate.sv` present and instantiated. `tb_security_gate.sv` tests confirmed hardcoded but logic correct. | None (logic correct; coverage thin). |
| **S6** | 100 MHz target | **DONE-VERIFIED** | Real Vivado timing reports in `results/timing/` confirm WNS=+3.098 ns on full SoC. | None (synthesis evidence is real). |
| **S7** | AXI4-Lite + DMA | **DONE-VERIFIED** | `axil_regs.sv`, `dma_master.sv` present. Integration testbenches pass. | None on bus. |
| **S8** | Boot-ROM integration | **PARTIAL** | `secure_boot.c` compiled, present. `boot_ctrl.sv` present. BUT: jump gate not enforced in HW (F3 confirmed by reading `secure_boot.c` line 169 — plain function call `app_entry()`). | Fix: hardware fetch guard on address decoder. |

### WHAT TO DEVELOP Section

| ID | Requirement Text (from PS) | Status | Evidence | Gap |
|---|---|---|---|---|
| **D1** | Golden model matching NIST KATs | **DONE-VERIFIED** | `reference/run_kats.py` re-run this session, 2114 vectors PASS. | Reproducibility: CRLF SHA-256 hardcoded (passes on Windows; may fail on Linux). |
| **D2** | Permutation round (bit-sliced S-box + linear diffusion) from hand HLS | **DONE-VERIFIED** | `round_core.sv`, `sbox5.sv`, `diffusion.sv` present and synthesized. | None. |
| **D3** | Design points: half, one, two rounds per cycle | **PARTIAL** | Three permutation modules exist and are synthesized individually. **CRITICAL GAP**: `mode_ctrl.sv` only instantiates `permutation_1r`. The 2r and half variants are not integrated with the AEAD/Hash controller (F5). | Add PERM_VARIANT parameter to mode_ctrl.sv / aead_ctrl.sv / hash_ctrl.sv. Run full KAT on all variants. |
| **D4** | Mode controller: init→AD→data→finalize→tag compare, padding, hash mode | **DONE-VERIFIED** | `mode_ctrl.sv` is 823 lines, full FSM, SP 800-232 padding. | Verify padding edge cases 0,1,7,8,9,15,16,17,31,32,33 bytes as required by F1. |
| **D5** | 5×5 S-box as ESPRESSO/kernel/BDD block | **PARTIAL** | `sbox5_espresso.sv` exists. **UNVERIFIED**: was ESPRESSO actually run? `tools/sbox_opt/README.md` claims so. `.pla` file existence TBD. See F7/R4. | Verify `tools/sbox_opt/ascon_sbox.pla` exists and is the actual ESPRESSO input. |
| **D6** | Secure-boot flow: RV32 ROM hashes via DMA, compares digest, jumps | **PARTIAL** | Flow exists. CRITICAL: jump is a plain C function call, not hardware-gated (F3). Claim "physically impossible to jump without authorization" is false. | Hardware fetch-address guard needed. |

### WHAT TO RESEARCH Section

| ID | Requirement Text (from PS) | Status | Evidence | Gap |
|---|---|---|---|---|
| **R_A** | Find a paper on Ascon hardware: low-area/serialised, unrolling, or masked | **PARTIAL** | `docs/research_review.md` lists 5 papers. Paper 1 author list was checked: the fourth author is listed as "F. Mendel" but search confirms it is "C. Ehrenhöfer" — this is an **error** in research_review.md [UNVERIFIED corrected to WRONG]. Paper 5 merges two distinct works (Gross 2017 and ePrint 2024/984) into one citation — this is **wrong** (F7/R1). | Correct citations. Verify all papers. |
| **R_B** | Implement one technique; compare area, throughput, TP/area, and (if masked) protection cost | **MISSING** | "Technique" selected is "multi-point round unrolling" — but this is the same as the PS's **required design points** (D3), not an additional research technique. ESPRESSO is not from any cited paper. No actual paper technique has been independently implemented and compared. | Implement one real paper technique (see F7 — select serialised 32-bit datapath or TI masking). |

### PROJECT-SPECIFIC DELIVERABLES Section

| ID | Requirement Text (from PS) | Status | Evidence | Gap |
|---|---|---|---|---|
| **PD1** | All NIST KATs pass for AEAD and hash, in simulation **and on board** | **PARTIAL** | Simulation: Python model PASS (re-run this session). RTL testbenches: hardcoded, not full KAT sweep. On board: hardware steps are mine to complete. | Fix RTL testbenches (F1). Board steps are user's. |
| **PD2** | Throughput/area table for each design point **and the paper design** | **WRONG** | Table exists in `comparison_table.md` but: (a) throughput formula uses 64-bit rate for AEAD (wrong — AEAD128 uses 128-bit rate, 8 rounds), and (b) no paper design with different technique (F4, F7). | Fix `parse_synth_reports.py` formula. Implement paper design variant. |
| **PD3** | CTL proof: boot jump never before `hash_ok` | **PARTIAL / WRONG** | Proof exists but is from a Python explicit-state checker (`verify_smv.py`), not a real model checker (nuXmv/NuSMV). `boot_safety.smv` model has a bug (DECIDE uses `hash_verified | hash_match` not just `hash_verified_q`) so the SMV model doesn't match the RTL (F2). | Fix `.smv` model. Obtain and run real NuSMV. Save raw tool transcript. |
| **PD4** | Boot-time measurement (cycles) for given firmware size | **WRONG** | 2,122-cycle figure comes from `tb_soc_dma` (a DMA hash test), not secure boot. Boot matrix case logs are hand-written narrative (identical timestamps, no `$fdisplay` output format). (F8). | Add cycle counter to `tb_secure_boot.sv`. Generate logs from simulator. |
| **PD5** | Demo: good image boots (LED pattern); flipping one byte via switch makes boot refuse | **PARTIAL** | SW[0] XOR logic exists in `top_bringup.sv` line 252-253. `top_bringup_board.sv` has `sw[]` ports (line 16). BUT: the board top passes `tamper_det(1'b0)` and loads `bram_case1_valid.hex` (a test case, not the secure-boot ROM + real candidate image). Tamper detection pin is hardwired to 0. (F10). | Fix board top to load secure-boot firmware, expose tamper signal, implement proper demo path. |

---

## 2. Independent Findings Verification (Re-audit Results)

### F1 — RTL KATs Not Exhaustive

**CONFIRMED.** Evidence:
- `tb/unit/tb_aead.sv` lines 1-14: test comments enumerate exactly 7 tests (4 encryption + 1 decrypt valid + 2 tamper).
- `tb/unit/tb_hash.sv`: not yet read but same pattern expected.
- The 1,089 AEAD / 1,025 hash vector count applies **only** to `reference/run_kats.py` (Python golden model).
- Resolution needed: script to convert KAT files to `$readmemh` vector files; new file-driven testbenches.

### F2 — CTL Proof Not from Real Model Checker

**CONFIRMED.** Evidence:
- `formal/ctl/verify_smv.py` is a 355-line Python explicit-state checker, NOT a nuXmv/NuSMV invocation.
- `results/formal/proof_correct.log` does not contain any nuXmv header, version string, or process metadata.
- `boot_safety.smv` line 90: `(hash_verified | hash_match) & !(tamper_latched | tamper_det)` — uses `hash_match` as a live input.
- `boot_ctrl.sv` line 145: `hash_verified_q && !(tamper_latched_q || tamper_det)` — uses only the **latched** register `hash_verified_q`.
- These are **different semantics**: the SMV model allows jumping if `hash_match` is high even if `hash_verified_q` was never set. This means the Python checker verifies the SMV model, not the RTL.
- The `boot_safety_broken.smv` file is supposedly the "deliberate flaw" but the real bug is in `boot_safety.smv` (the "correct" model).
- AG(jump→hash_ok) in the current SMV model can be violated in 6 steps as described in the prompt.

**Status of R6 (tooling):** NuSMV 2.6.0 has Windows binaries at `nusmv.fbk.eu`. nuXmv 2.2.0 Windows binaries are listed as "coming soon". **I can attempt to download and run NuSMV.exe.** See STEP 4.

### F3 — jump_enable Gates Nothing

**CONFIRMED.** Evidence:
- `firmware/bootrom/secure_boot.c` line 169: `app_entry()` — plain C function call through a function pointer.
- `top_bringup.sv` line 309: `wire boot_jump_enable` is declared and assigned from `axil_regs`.
- `top_bringup.sv` lines 389-399: `boot_jump_enable` is used only for LED/RGB output; the CPU fetch path has no hardware gate.
- The BRAM is the unified code+data memory; CPU can fetch from any address that decodes to `0x0000_xxxx` regardless of `boot_jump_enable`.
- Claim "physically impossible to jump without authorization" (`boot_matrix_summary.md` line 51): **FALSE as built**.

### F4 — Throughput Script Uses Wrong Parameters

**CONFIRMED.** Evidence:
- `scripts/parse_synth_reports.py` line 24-26: `"cycles_aead": 6` (6 rounds × 1 cycle/round), `rate = 64 bits`.
- `docs/decisions/algorithm_version.md` line 25: AEAD128 uses `b=8` data rounds, 128-bit rate.
- Correct: cycles/AEAD block = 12 (init) + 8×N_AD_blocks + 8×N_PT_blocks + 12 (final). For 1-block message: 12+8+8+12=40 cycles per complete AEAD, or 8 cycles for the "per-block" throughput calculation with 128-bit blocks.
- Current table reports 1066.67 Mbit/s for 1r baseline; correct value = (128 bits × 100 MHz) / 8 cycles = 1600 Mbit/s per block.
- The table's AEAD numbers are wrong.

### F5 — Only permutation_1r Used by Engine

**CONFIRMED.** Evidence:
- `mode_ctrl.sv` header line 8: "Unified sponge datapath shared with **permutation_1r** (1 round/cycle)".
- `permutation_2r.sv` and `permutation_half.sv` are standalone RTL files with no connection to `mode_ctrl.sv`.
- The three variants were synthesized OOC individually but have never been driven through an actual AEAD or hash operation.

### F6 — Permutation Testbenches Are Thin

**LIKELY CONFIRMED** (NOT YET READ `tb_permutation_1r.sv` line-by-line but consistent with F1 pattern).

### F7 — No Genuine Paper Design

**CONFIRMED.** Evidence:
- `docs/research_review.md` Section 2: selected technique is "Multi-Point Round Unrolling & Serialization (½, 1, and 2 Rounds per Cycle)" — this is exactly the PS-required design points D3, not an additional research technique.
- Paper 1 author "F. Mendel" is wrong: search confirms "C. Ehrenhöfer" is the 4th author [WRONG citation].
- Paper 5 merges "Generic Low-Latency Masking in Hardware" (Gross, Iusupov, Bloem, TCHES 2017) with ePrint 2024/984 — these are separate works [WRONG citation].
- ePrint 2024/984 title is "Side-Channel and Fault Resistant ASCON Implementation" — unverified, needs direct check.

### F8 — Boot Time Not Measured, Logs Hand-Written

**CONFIRMED.** Evidence:
- `results/board/boot_matrix/case_1.log` line 6: `Timestamp: 2026-10-21T21:39:11Z` — all 9 case logs have identical timestamps.
- Case 1 log lines 16-30: narrative text with nanosecond timestamps (e.g., "Time 105 ns:") that do NOT match `$fdisplay`/`$monitor` format from XSim.
- `tb/integration/tb_secure_boot.sv` has no `$fdisplay` or `$fwrite` calls to write case logs.
- 2,122-cycle figure: from `results/board/phase7_dma_summary.md` (DMA hash test `tb_soc_dma.sv`), not secure boot.

### F9 — Reproducibility Defects

**PARTIALLY CONFIRMED.** Evidence:
- `run_kats.py`: SHA-256 hardcoded hashes match CRLF files **on Windows** (re-run verified). May fail on Linux (CRLF→LF conversion changes hash). **NOT REPRODUCED on Linux this session** (Windows-only environment) — mark NOT RE-RUN for Linux.
- `.gitignore` line 13: `*.log` — this would exclude `results/**/*.log` from git tracking. [CONFIRMED DEFECT]
- `results/board/boot_matrix/case_1.log` etc. exist locally but would be ignored by git.
- `docs/validation_report.md` line 7: "NIST SP 800-232 (Initial Public Draft)" — WRONG; `algorithm_version.md` line 16 says "Final Standard, August 2025".
- `results/board/boot_matrix/boot_matrix_summary.md` line 29: `file:///c:/Users/Aayan/...` absolute links. [CONFIRMED DEFECT]

### F10 — Board-Prep RTL Gaps

**CONFIRMED.** Evidence:
- `top_bringup_board.sv` line 93: `tamper_det(1'b0)` — hardwired, never connected to a switch or pin.
- `top_bringup_board.sv` line 12: `FIRMWARE_HEX = "firmware/tests/boot_matrix/bram_case1_valid.hex"` — loads test case not secure-boot ROM.
- `board/zybo_z7_10.xdc`: should be checked for sw[] port definitions.

---

## 3. Research Verification (R1–R8)

### R1 — Citations in research_review.md

| Paper | Claimed Citation | Verified? | Finding |
|---|---|---|---|
| Paper 1 "Suit up!" | Gross, Wenger, Dobraunig, **Mendel**, DSD 2015, ePrint 2015/034 | PARTIAL | Title and venue correct [SOURCE confirmed]. 4th author is **Christoph Ehrenhöfer**, not Florian Mendel [WRONG — corrected]. |
| Paper 2 | ACM "Review and Analysis..." DOI 10.1145/3721122, 2025 | [UNVERIFIED] | DOI not independently accessed this session. Claimed figures need re-verification. |
| Paper 3 | Lee, Kim, Sensors 2025, PMC13396216 | [UNVERIFIED] | URL not independently confirmed. |
| Paper 4 | Malal, ePrint 2025/825 | PARTIAL | Title confirmed by search: "High-Performance FPGA Implementations... ASCON-128 and ASCON-128a". Author is "Ahmet Malal" (singular) not "M. Malal et al." [WRONG]. |
| Paper 5 | Gross, Iusupov, Bloem merged with ePrint 2024/984 | WRONG | These are two separate works; combining them in one citation is incorrect. |

### R2 — Paper for F7 Implementation

Selected: **ePrint 2025/825** (Malal) targeting 6-round unrolled ASCON-128a on Artix-7.  
Alternative: **Serialised 32-bit datapath** from Graz University ascon-hardware repository (published).

**Decision (F7):** Implement a **serialised 32-bit datapath** — processing 32 bits of each 64-bit state word per cycle, completing one full 64-bit word operation in 2 cycles. This is a genuinely distinct low-area technique documented in the literature (Primas/Graz reference implementations), distinct from the required ½/1/2r design points. It requires a fundamentally different micro-architecture.

Rationale recorded in `docs/decisions/paper_design_technique.md`.

### R3 — Masking Research

First-order TI for Ascon S-box requires 3 shares (Ascon S-box is not degree-1 uniform, requiring share-splitting). DOM masking is degree-1 achievable with 2 shares plus fresh randomness. Area overhead in literature: 3.15×–4.5× over unmasked [SOURCE: research_review.md Paper 5, PARTIALLY UNVERIFIED]. TVLA in simulation using toggle-count model: feasible conceptually but requires a switching-activity model not currently in the testbench infrastructure. **Decision: not implementing masking this session; documenting as architectural trade-off.**

### R4 — S-box Minimization Verification

`tools/sbox_opt/` must be checked for the `.pla` file. If ESPRESSO was actually run, the output should be committed. **Status: NOT YET RE-VERIFIED this session.**

### R5 — SP 800-232 Final Text Confirmation

CONFIRMED by web search and `docs/decisions/algorithm_version.md`:
- AEAD128: rate=128 bits, a=12, b=8
- Hash256: rate=64 bits, a=12
- Standard finalized August 2025 [SOURCE: NIST].
- KAT files are from ascon-c reference implementation, consistent with final standard.

### R6 — Formal Tooling

NuSMV 2.6.0 has Windows 64-bit binaries at `https://nusmv.fbk.eu/`. nuXmv Windows binary is "coming soon". **Plan: download NuSMV 2.6.0 for Windows, run on corrected `.smv` model, save raw transcript.** If download fails in this environment, document the exact command.

### R7 — Secure Boot Best Practice

TOCTOU risk: The candidate image is hashed from BRAM and then executed from the same BRAM. Between the hash completing and the CPU jumping, a DMA write (or any bus master) could modify the image. Mitigations: (1) disable all write paths to `0x0000_1000–0x3FFF` after hash starts, or (2) document this as an accepted risk given single-master bus. Current design: single CPU bus master; DMA only reads BRAM Port B (no write capability). **Risk level: LOW** (DMA has no write path to BRAM). Documented in threat model update.

### R8 — Vivado Fmax Methodology

`Fmax = 1000 / (Tperiod - WNS)` is the standard OOC estimation formula. It is an **approximation** — actual Fmax requires tightening the constraint until timing fails, which was not done. The OOC analysis also does not account for implementation variability. Report this as estimated Fmax, not measured. For tighter estimates, the timing constraint should be run at 150 MHz, 175 MHz, etc. until violation. **NOT re-run this session** [MEASURE — not yet obtained for tighter constraints].

---

## 4. Status Summary (STEP 1 Final Table)

| Req ID | One-Line Requirement | Status | Evidence Path |
|---|---|---|---|
| S1 | AEAD128 encrypt/decrypt with tag check | PARTIAL | `reference/run_kats.py` PASS; RTL KATs thin |
| S2 | Hash256 | PARTIAL | Python model PASS; RTL thin |
| S3 | 320-bit state | DONE-VERIFIED | Synthesis reports |
| S4 | 1r/cycle baseline | DONE-VERIFIED | `permutation_1r.sv` + synthesis |
| S5 | PT only after tag check | DONE-VERIFIED | `plaintext_gate.sv` |
| S6 | 100 MHz | DONE-VERIFIED | Real Vivado timing reports |
| S7 | AXI4-Lite + DMA | DONE-VERIFIED | `axil_regs.sv`, `dma_master.sv` |
| S8 | Boot ROM integration | PARTIAL | `secure_boot.c` + `boot_ctrl.sv`; jump not HW-gated |
| D1 | Golden model KATs | DONE-VERIFIED | `run_kats.py` re-run this session |
| D2 | Permutation from hand HLS | DONE-VERIFIED | RTL + synthesis |
| D3 | ½/1/2r design points | PARTIAL | Synthesized OOC; not integrated with mode controller |
| D4 | Mode controller with padding | PARTIAL | Logic correct; padding edge cases not tested |
| D5 | ESPRESSO S-box | PARTIAL | RTL present; origin unverified |
| D6 | Secure-boot flow | PARTIAL | Jump is plain software call |
| R_A | Find paper | PARTIAL | Citations present but contain errors |
| R_B | Implement one technique + compare | MISSING | No distinct paper technique implemented |
| PD1 | All NIST KATs in sim + board | PARTIAL | Python PASS; RTL thin; board is user step |
| PD2 | Throughput/area table + paper design | WRONG | Formula wrong (F4); paper design missing (F7) |
| PD3 | CTL proof AG(jump→hash_ok) | PARTIAL/WRONG | Python checker only; SMV model has bug vs RTL |
| PD4 | Boot-time measurement | WRONG | Source is DMA test; logs are hand-written |
| PD5 | Board demo: good/bad image via switch | PARTIAL | SW[0] logic exists; board top needs fix |

**DONE-VERIFIED:** 8/21 (38%)  
**PARTIAL:** 10/21 (48%)  
**MISSING/WRONG:** 3/21 (14%)

> This document will be updated at the end of STEP 4 with real post-fix status.

---

*Updated: 2026-11-03 by re-audit session. Next update: after F2 fix (SMV model + NuSMV attempt).*

