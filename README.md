# Ascon AEAD and Hash Engine — IoT Secure Boot on Zybo Z7-10

[![NIST SP 800-232](https://img.shields.io/badge/Standard-SP%20800--232%20Final%20Aug%202025-green)]()
[![Target](https://img.shields.io/badge/FPGA-Xilinx%20XC7Z010-blue)]()
[![Vivado](https://img.shields.io/badge/Vivado-2025.1-orange)]()

Hardware implementation of **Ascon-AEAD128** and **Ascon-Hash256** per NIST SP 800-232 (Final, August 2025), integrated with a PicoRV32 RV32I SoC on the Digilent Zybo Z7-10 FPGA for cryptographically-assured secure boot.

---

## Quick Start

### Prerequisites
- Python 3.9+
- Vivado 2025.1 (for RTL simulation and synthesis)
- Icarus Verilog (optional, for lightweight unit tests)

### 1 — Reproduce Golden-Model KATs (Python only)
```bash
python reference/run_kats.py
# Expected: PASS  AEAD 1089 + HASH 1025 vectors (2114 total) + 6 edge cases
```

### 2 — Generate RTL KAT Vector Files
```bash
python scripts/kat_to_vectors.py
# Outputs: tb/vectors/aead_kat.mem (1089 × 64 words)
#          tb/vectors/hash_kat.mem  (1025 × 272 words, up to 1024-byte messages)
```

### 3 — Run Full Regression (Vivado XSim)
```bash
# Set Vivado on PATH first, then:
python scripts/run_regression.py
# Or set env var: VIVADO_PATH=C:\Xilinx\2025.1\Vivado\bin python scripts/run_regression.py
```

### 4 — Run Individual Simulation
```bash
# Example: exhaustive AEAD KAT testbench
python scripts/run_regression.py --test tb_aead_full
```

### 5 — Synthesize All Variants (OOC)
```bash
# In Vivado Tcl console or batch:
vivado -mode batch -source scripts/synth_variants.tcl
python scripts/parse_synth_reports.py   # regenerates results/performance/comparison_table.md
```

---

## Repository Map

```
rtl/
  ascon/          Cryptographic core: permutation, S-box, diffusion, AEAD/hash controllers
  soc/            PicoRV32 SoC, boot_ctrl FSM, fetch_guard, top-level wrappers
  bus/            AXI4-Lite register file
  dma/            Custom DMA streaming engine
tb/
  unit/           Unit testbenches (permutation, S-box, mode_ctrl, security gate, full KATs)
  integration/    SoC-level testbenches (AXI, DMA, secure boot)
  vectors/        Binary KAT memory files ($readmemh)
formal/
  ctl/            NuSMV SMV model + corrected model + broken-model counterexample
  sva/            SVA property files (placeholder for SymbiYosys flow)
firmware/
  bootrom/        Secure boot C firmware + linker scripts
  tests/          Peripheral test programs + boot matrix BRAM images
reference/
  pyascon/        Python golden model (Ascon reference implementation)
  kat/            NIST SP 800-232 official KAT text files
  run_kats.py     Golden model KAT verification script
scripts/
  kat_to_vectors.py      Convert KAT files → $readmemh vector files
  run_regression.py      Automated regression runner (Vivado XSim)
  parse_synth_reports.py Read Vivado reports → comparison_table.md
  synth_variants.tcl     OOC synthesis for all permutation variants
  gen_perm_vectors.py    Generate random permutation test vectors (Python oracle)
  provision_image.py     Create test BRAM images for boot matrix
board/
  zybo_z7_10.xdc         Physical constraints (pins, clock, I/O)
  timing_ooc.xdc         OOC timing constraints
docs/
  final_report.md         Comprehensive technical evaluation report
  requirements_traceability.md Single source of truth for R1-R19
  AUDIT_RESPONSE.md       Single source of truth for audit remediations
  architecture.md         System architecture and submodule design
  research_review.md      Literature survey + technique selection
  threat_model.md         Security threat model & attack surfaces
  CHANGELOG.md            Consolidation record & change history
  decisions/              Architecture decision records
results/
  kat/            KAT pass logs
  formal/nuxmv/   Real NuSMV 2.6.0 transcripts
  performance/    Synthesis comparison table
  board/          Board-level logs, boot matrix, runbook
```

---

## Results Summary

### Cryptographic Correctness
| Test | Vectors | Status |
|------|---------|--------|
| Python golden model (AEAD) | 1,089 | ✅ PASS |
| Python golden model (Hash) | 1,025 | ✅ PASS |
| RTL exhaustive AEAD KAT (`tb_aead_full.sv`) | 1,089 | Requires Vivado sim |
| RTL exhaustive Hash KAT (`tb_hash_full.sv`) | 1,025 | Requires Vivado sim |

### Permutation Variants (XC7Z010 OOC @ 100 MHz)
See [`results/performance/comparison_table.md`](results/performance/comparison_table.md) for full table.

| Variant | Fmax (MHz) | AEAD Throughput @ 100MHz | AEAD Throughput @ Fmax |
|---------|:---:|:---:|:---:|
| permutation_1r (baseline) | 206.36 | 1600.00 Mbit/s | 3301.69 Mbit/s |
| permutation_2r (unrolled) | 135.85 | 3200.00 Mbit/s | 4347.24 Mbit/s |
| permutation_half (folded) | 264.90 | 800.00 Mbit/s | 2119.21 Mbit/s |
| permutation_serial32 (paper) | 153.99 | 800.00 Mbit/s | 1231.91 Mbit/s |

### Formal Verification
- **NuSMV 2.6.0** proved `AG(jump → hash_ok)` and 4 other safety properties on `formal/ctl/boot_safety_corrected.smv`
- Transcript: [`results/formal/nuxmv/proof_corrected_nusmv.log`](results/formal/nuxmv/proof_corrected_nusmv.log)
- Counterexample on broken model: [`results/formal/nuxmv/counterexample_broken_nusmv.log`](results/formal/nuxmv/counterexample_broken_nusmv.log)

---

## Hardware Demo (Zybo Z7-10)

See [`results/board/HARDWARE_RUNBOOK.md`](results/board/HARDWARE_RUNBOOK.md) for step-by-step board instructions.

| LED Pattern | Meaning |
|-------------|---------|
| Blue RGB + LED[0] | Booting / hashing in progress |
| All 4 LEDs on (`4'b1111`) + Green RGB | **BOOT OK** — candidate firmware authentic & verified |
| Alternating LEDs (`4'b1010`) + Red RGB | **BOOT REFUSED** — hash mismatch or tamper detected |

**Deliverable Demo (Byte-Flip via Switch):**
- **SW0 = 0:** Candidate image authentic → system boots, discrete LEDs illuminate solid `4'b1111` and RGB glows GREEN.
- **SW0 = 1:** Hardware inverts bit 0 of payload byte `0x1040` during DMA stream → hash digest fails → discrete LEDs display `4'b1010` and RGB glows RED.
- **SW1 = 1:** Asserts physical `tamper_det` → immediate sticky refusal lockout.

---

## Formal Proof

```
AG(jump → hash_ok)                   — proved ✅
AG(jump → verified_before_jump)      — proved ✅
AG(tamper_latched → ¬EF jump)        — proved ✅
AG(DECIDE ∧ ¬hash_ok → AX REFUSE)   — proved ✅
AG(refuse → AG refuse)               — proved ✅
```

---

## References
- [NIST SP 800-232](https://csrc.nist.gov/pubs/sp/800/232/final) — Ascon Lightweight Cryptography Standard
- [ascon/ascon-c](https://github.com/ascon/ascon-c) — Official reference implementation + KAT vectors
- [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) — PicoRV32 RISC-V core
- [Gross et al. 2015](https://eprint.iacr.org/2015/034.pdf) — Ascon hardware implementation paper
- [eprint.iacr.org/2025/825](https://eprint.iacr.org/2025/825) — 7-series FPGA benchmarks
