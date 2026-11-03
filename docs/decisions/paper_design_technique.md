# Design Decision: Paper Technique — 32-bit Serialised Ascon Datapath

**Decision Date:** 2026-11-03  
**Status:** Implemented (`rtl/ascon/permutation_serial32.sv`) — simulation pending  
**Finding Addressed:** F7 (independent review)

---

## 1. Context

The Problem Statement (PS §"WHAT TO RESEARCH") requires:
> "Find a paper, implement one technique, and compare area, throughput, throughput/area and,
> if masked, the protection cost."

The original `docs/research_review.md` incorrectly identified ½-round, 1-round, and 2-round
unrolling as the "paper technique". These are the **PS-required design points**, not an
additional research technique. The ESPRESSO S-box variant was labelled "Paper Variant" but
ESPRESSO is a logic minimisation tool, not a published cryptographic hardware technique.

---

## 2. Technique Selected: 32-bit Serialised Datapath

### Reference [SOURCE]
- **Repository:** Graz University of Technology — `ascon/ascon-hardware`
  URL: https://github.com/ascon/ascon-hardware
- **Relevant variant:** `ascon_serial` — a bit-serial or word-serial implementation that
  trades area for throughput by processing a smaller slice of the 320-bit state per cycle.
- **Related academic context:** The Ascon team (Dobraunig, Eichlseder, Mendel, Schläffer)
  documented low-area serial implementations as part of the CAESAR competition hardware
  evaluation. A 32-bit-datapath variant is a standard point on the area/throughput curve.

### Why chosen over alternatives [REC]

| Alternative | Why Not Chosen |
|---|---|
| First-order masking (TI or DOM) | Requires fresh randomness each cycle (PRNG) and a leakage test (TVLA/TLRN) on real hardware to be meaningful. No oscilloscope or power trace equipment available. [ASSUME] |
| Pipeline registers between round stages | This is micro-architecture, not a research technique; it is already implicit in ½r vs 1r vs 2r comparison. |
| FPGA-specific DSP mapping | Not relevant to the cryptographic algorithm; implementation-specific rather than algorithmic. |

---

## 3. Implementation

**Module:** `rtl/ascon/permutation_serial32.sv`  
**Interface:** Identical to `permutation_1r` — drop-in via `mode_ctrl.sv` parameter `PERM_VARIANT=3`.

### How it works

Each Ascon round = **2 clock cycles**:

| Sub-cycle | Operation |
|---|---|
| A | Constant addition to x2[7:0]; 32 parallel S-boxes on bit-columns [31:0] |
| B | 32 parallel S-boxes on bit-columns [63:32]; recombine halves; full linear diffusion |

S-box instances: **32** (vs 64 in `permutation_1r`). Linear diffusion uses the shared
`diffusion.sv` module — no area saving there (rotations are free in FPGA LUT logic).

### Cycle counts [SPEC]

| Mode | Rounds | Cycles (serial32) | Cycles (1r baseline) |
|---|---|---|---|
| AEAD init/final | p^12 | 24 | 12 |
| AEAD data block | p^8  | 16 |  8 |
| Hash block      | p^12 | 24 | 12 |

### Throughput formula [SPEC] (SP 800-232 parameters)

- AEAD-128: `TP = 128 × F_MHz / 16 = 8 × F_MHz` Mbit/s
- Hash-256: `TP = 64 × F_MHz / 24 ≈ 2.67 × F_MHz` Mbit/s

At 100 MHz: AEAD = 800 Mbit/s, Hash = 267 Mbit/s (expected — unverified until synthesis).

---

## 4. Comparison Plan

Once `permutation_serial32` synthesis is complete (requires adding it to `scripts/synth_variants.tcl`
and re-running Vivado), compare against `permutation_1r` baseline:

| Metric | serial32 (target) | 1r baseline [MEASURE] |
|---|---|---|
| Slice LUTs | ~300 [ASSUME] | 544 |
| Slice FFs  | ~340 [ASSUME] | 335 |
| AEAD Throughput @ 100 MHz | 800 Mbit/s [SPEC] | 1600 Mbit/s |
| Hash Throughput @ 100 MHz | 267 Mbit/s [SPEC] | 533 Mbit/s |
| AEAD Eff. (Mbit/s/LUT) | TBD [MEASURE] | 2.94 [MEASURE] |
| Area × Delay product | TBD [MEASURE] | TBD [MEASURE] |

**[ASSUME] Note:** Area estimate is speculative. The linear diffusion module is shared and
represents a significant fraction of total LUTs. Actual reduction will depend on Vivado
optimisation. [MEASURE] values from real tool output required.

---

## 5. Caveats and Limitations

1. **Technology difference:** The ascon-hardware repository reports results for ASIC (65 nm CMOS
   or 45 nm) and for Xilinx 7-series FPGAs. This implementation targets the same XC7Z010-1CLG400C
   (Zybo Z7-10), so direct LUT comparisons are valid. ASIC GE comparisons are **not** directly
   comparable to FPGA LUTs.

2. **Synthesis not yet run:** `permutation_serial32` must be added to `scripts/synth_variants.tcl`
   as an OOC synthesis target. Until a Vivado run completes, area figures are estimates only.
   [MEASURE — pending Vivado invocation]

3. **Bit-exactness:** The module is designed to produce identical outputs to `permutation_1r`
   for any state and round count. This must be verified by the differential testbench
   `tb/unit/tb_permutation_1r.sv` before claiming correctness. [PARTIAL]

4. **Simulation not yet run:** Full KAT suite coverage of the serial32 variant pending.

---

## 6. Research Sources Consulted

| Source | URL | Accessed | Claim |
|---|---|---|---|
| Ascon hardware repository | https://github.com/ascon/ascon-hardware | 2026-11-03 | Serial variant architecture [SOURCE] |
| NIST SP 800-232 | https://doi.org/10.6028/NIST.SP.800-232 | 2026-10-15 | Algorithm parameters [SPEC] |
| Dobraunig et al., Ascon v1.2 submission | https://ascon.iaik.tugraz.at/ | 2026-10-15 | Round function definition [SOURCE] |

