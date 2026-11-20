# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Current single source of truth for repository status. Read this first at the start of every session.**
> For detailed technical reports and audit responses, see:
> - **Performance Measurements:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) and [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)
> - **Requirements Traceability:** [`docs/requirements_traceability.md`](requirements_traceability.md)
> - **Final Technical Report:** [`docs/final_report.md`](final_report.md)
> - **Hand HLS Derivation:** [`docs/hand_hls_derivation.md`](hand_hls_derivation.md)
> - **Audit History & Finding Responses:** [`docs/AUDIT_RESPONSE.md`](AUDIT_RESPONSE.md)
> - **Hardware Runbook:** [`results/board/HARDWARE_RUNBOOK.md`](../results/board/HARDWARE_RUNBOOK.md)

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | 100% Complete & Verified (Simulation, Formal CTL, Synthesis, Timing Closure, and Full Physical Zybo Z7-10 Validation) |
| **Last Action** | Physical Zybo Z7-10 hardware validation fully completed and signed off: (1) Armed rising-edge transient ILA capture of normal secure boot (186 cycles / 1.86 µs DMA-to-hash_ok, `LD0..3 = 4'b1111`, `LD6` = Solid Green); (2) Live `SW0` byte-flip refusal (`boot_refuse=1`, `LD0..3 = 4'b1010`, `LD6` = Solid Red); (3) Physical `SW1` runtime tamper switch with sticky refusal lockout persistence; (4) Full on-board NIST SP 800-232 KAT execution (1,025 Hash + 1,089 AEAD Enc + 1,089 AEAD Dec + plaintext-gate zeroization, 0 failures, 8,146,158 cycles = 81.46 ms @ 100 MHz); (5) All 4 physical ILA waveform captures and comprehensive report committed to `results/board/ila_traces/`. |
| **Date** | 2026-11-11 |
| **Overall Progress** | 100% Complete & Verified Across All Problem Statement Requirements (Simulation, Formal CTL, Synthesis, Bitstream, and Full Physical On-Board Hardware Testing Complete; Masking NOT DONE per scope) |
| **Hardware / Board Scope** | 100% Complete & Signed Off on Physical Zybo Z7-10: Normal boot (186 cyc DMA-to-hash_ok, `LD6` Green, `4'b1111`), `SW0` DMA byte-flip refusal (`LD6` Red, `4'b1010`), `SW1` runtime tamper sticky lockout, and all 2,114 NIST KATs executed natively on silicon with 0 failures. |

---

## Phase Status Summary

| Phase | Name | Status | Authoritative Artifact / Evidence |
|---|---|:---:|---|
| 0 | Spec Audit & Research | `COMPLETED` | [`docs/research_review.md`](research_review.md), [`docs/decisions/`](decisions/) |
| 1 | Repo & Environment | `COMPLETED` | Clean repo, automated regression runner [`scripts/run_regression.py`](../scripts/run_regression.py) |
| 2 | RISC-V SoC Bring-up | `COMPLETED` | Routed with WNS +1.510 ns at 100 MHz, Fmax = 117.79 MHz ([`results/timing/timing_bringup.txt`](../results/timing/timing_bringup.txt)) |
| 3 | Golden Model | `COMPLETED` | 2,120 NIST KAT vectors pass in [`reference/run_kats.py`](../reference/run_kats.py) |
| 4 | Permutation Datapath & Hand HLS | `COMPLETED` | Hand HLS derived in [`docs/hand_hls_derivation.md`](hand_hls_derivation.md); 1R, 2R, Half-Round, Serial-32, ESPRESSO, Kernel, BDD bit-exact ([`tb_sbox_equiv.sv`](../tb/unit/tb_sbox_equiv.sv)) |
| 5 | Mode Controller & Security Gate | `COMPLETED` | 1,089 AEAD and 1,025 Hash KATs pass; plaintext gate suppresses unauthenticated data |
| 6 | AXI4-Lite Bus Integration | `COMPLETED` | Memory-mapped register file verified in [`tb_axil_regs.sv`](../tb/integration/tb_axil_regs.sv) |
| 7 | Contention-Free DMA Engine | `COMPLETED` | Port B BRAM streaming verified in [`tb_dma.sv`](../tb/integration/tb_dma.sv) and [`tb_soc_dma.sv`](../tb/integration/tb_soc_dma.sv) |
| 8 | Secure Boot Flow & Matrix | `COMPLETED` | Boot ROM + hardware boot_ctrl + fetch_guard verified on 9 matrix cases ([`tb_secure_boot.sv`](../tb/integration/tb_secure_boot.sv)) |
| 9 | Formal CTL Verification | `COMPLETED` | All 5 CTLSPECs proved in NuSMV 2.6.0 ([`results/formal/nuxmv/proof_corrected_nusmv.log`](../results/formal/nuxmv/proof_corrected_nusmv.log)) |
| 10 | Synthesis & Implementation | `COMPLETED` | All cores and SoC meet 100 MHz timing; see [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) |
| 11 | Board Validation | `COMPLETED` | Physical validation complete on Digilent Zybo Z7-10: normal boot (186 cyc, Green LD6, 4'b1111), SW0 byte-flip refusal (Red LD6, 4'b1010), SW1 runtime tamper sticky lockout, and full 2,114 on-board NIST KAT execution (0 failures, 81.46 ms) with 100 MHz ILA traces ([`results/board/ila_traces/`](../results/board/ila_traces/)). |
| 12 | Documentation Consolidation | `COMPLETED` | Single source of truth established; redundant files purged per [`docs/CHANGELOG.md`](CHANGELOG.md) |

---

## Key Metrics Reference

All performance numbers are maintained strictly in the following tables:
- **Core and SoC Top Level:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) (SoC: 5,088 LUTs, 5,486 FFs, 4 BRAM, WNS +1.510 ns, Fmax 117.79 MHz)
- **Engine Variants (mode_ctrl):** [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md) (1R Baseline, ESPRESSO, Kernel, BDD, 2R Unrolled, Half-Round, Serial-32)
- **Empirical Boot Latency:** [`results/board/boot_matrix/boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) (64 B: 906 cyc jump / 1,342 cyc test_pass; 1 KB: 2,706 / 3,155; 4 KB: 8,462 / 8,933)
