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

### 4 — Run Regression & Simulations
```bash
# Full regression (KATs + NuSMV formal + Vivado XSim 39/39 tests):
python scripts/run_regression.py

# Or simulation-only / custom XSim run:
python scripts/run_regression.py --skip-kats --skip-formal
```

### 5 — Synthesize Variants & Generate Tables
```bash
# Permutation variants (OOC)
vivado -mode batch -source scripts/synth_variants.tcl
python scripts/parse_synth_reports.py   # regenerates results/performance/comparison_table.md

# Full AEAD+Hash engine variants
vivado -mode batch -source scripts/synth_engine_variants.tcl
python scripts/generate_engine_table.py # regenerates results/performance/engine_comparison_table.md
```

---

## Repository Map

```
rtl/
  ascon/          Cryptographic core: permutation variants, S-box (LUT/BDD/ESPRESSO/kernel), AEAD/hash/mode controllers
  soc/            PicoRV32 SoC, boot_ctrl FSM, fetch_guard, top_bringup & top_bringup_board
  bus/            AXI4-Lite register file (axil_regs.sv)
  dma/            Custom DMA streaming engine (dma_master.sv)
tb/
  unit/           Unit testbenches (permutation, S-box, mode_ctrl, security gate, full KATs)
  integration/    SoC-level testbenches (AXI, DMA, secure boot, payload scaling)
  vectors/        Binary KAT memory files ($readmemh)
formal/
  ctl/            NuSMV SMV models + verify_smv.py
  sva/            SVA properties (boot_ctrl_sva.sv)
firmware/
  bootrom/        Secure boot C firmware + trusted manifest header
  tests/          Peripheral test programs + boot matrix BRAM hex images
reference/
  pyascon/        Python golden model (Ascon reference implementation)
  kat/            NIST SP 800-232 official KAT text files
  run_kats.py     Golden model KAT verification script
tools/
  sbox_opt/       Berkeley ESPRESSO, BDD & kernel S-box optimization scripts + PLA literal counter
scripts/
  build_bitstream.tcl / build_bitstream_ila.tcl   Vivado bitstream & ILA build scripts
  program_board.tcl / program_board.bat           Hardware JTAG programming scripts
  capture_ila.tcl / diagnose_jtag.tcl             Hardware ILA CSV capture & JTAG diagnostics
  run_regression.py (.ps1 / .sh)                  Automated regression runner (KATs + NuSMV + XSim)
  check_doc_links.py / check_doc_numbers.py       Repository consistency checkers
board/
  zybo_z7_10.xdc         Physical constraints (pins, clock, I/O)
  timing_ooc.xdc         OOC timing constraints
docs/
  status.md                      Current project & hardware-bringup status
  hardware_test_plan.md          Hardware bringup & ILA test plan
  final_report.md                Comprehensive technical evaluation report
  requirements_traceability.md   Single source of truth for R1-R19
  AUDIT_RESPONSE.md              Audit remediation record
  directory_structure.md         Verified repository inventory
  CHANGELOG.md                   Change history & consolidation record
  decisions/                     Architecture decision records
results/
  kat/            KAT pass logs
  formal/         Formal & SVA logs (NuSMV 2.6.0 transcripts + SymbiYosys placeholder log)
  performance/    Synthesis comparison tables (variants & engines)
  synthesis/      Vivado utilization reports & ESPRESSO raw PLA/log
  timing/         Vivado timing reports
  board/          HARDWARE_RUNBOOK.md, bitstream logs, boot_matrix/, ila_verification_report.md, ila_traces/
```

---

## Results Summary

### Cryptographic Correctness
| Test | Vectors | Status |
|------|---------|--------|
| Python golden model (AEAD) | 1,089 | ✅ PASS |
| Python golden model (Hash) | 1,025 | ✅ PASS |
| RTL exhaustive AEAD KAT (`tb_aead_full.sv`) | 1,089 | ✅ PASS (Vivado XSim, 39/39 regression) |
| RTL exhaustive Hash KAT (`tb_hash_full.sv`) | 1,025 | ✅ PASS (Vivado XSim, 39/39 regression) |

### Permutation Variants & Hardware Bring-Up (XC7Z010 @ 100 MHz)
- Engine & permutation comparison tables: [`results/performance/comparison_table.md`](results/performance/comparison_table.md), [`results/performance/engine_comparison_table.md`](results/performance/engine_comparison_table.md)
- Board runbook & ILA verification report (normal boot + `SW0` fault refusal verified on Zybo Z7-10; `SW1` & rising-edge transient ILA pending): [`results/board/HARDWARE_RUNBOOK.md`](results/board/HARDWARE_RUNBOOK.md), [`results/board/ila_verification_report.md`](results/board/ila_verification_report.md)

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
