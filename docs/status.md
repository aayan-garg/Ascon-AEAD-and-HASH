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
| **Current Phase** | Repository Reconciled & Cleaned (Core Verification Complete; Partial Physical Zybo Z7-10 Validation Recorded) |
| **Last Action** | Reconciled documentation, build/ILA reports, and directory hygiene against committed raw Vivado/XSim/NuSMV/ILA artifacts: (1) On-board normal secure boot (`LD0..3 = 4'b1111`, RGB `LD6` = Solid Green) and live `SW0` DMA bit-flip refusal (`LD0..3 = 4'b1010`, RGB `LD6` = Solid Red) observed on Digilent Zybo Z7-10 (`XC7Z010-1CLG400C`) with steady-state `-trigger_now` ILA captures archived in `results/board/ila_traces/`; (2) Verified ILA bitstream `top_bringup_ila.bit` post-route timing (`WNS = +1.042 ns`, `6,784` LUTs, `7,743` FFs, `8.5` BRAMs) and baseline bitstream `top_bringup.bit` (`WNS = +1.510 ns`, `Fmax = 117.79 MHz`); (3) Noted pending hardware checks honestly (rising-edge triggered transient ILA waveform, physical `SW1` tamper test, on-board cycle measurement, and on-board KAT execution). |
| **Date** | 2026-11-11 |
| **Overall Progress** | Simulation, Formal CTL, Synthesis, and Bitstream Complete; On-Board Normal/SW0 Boot + Steady-State ILA Logged (Masking NOT DONE; Transient-Trigger ILA / SW1 / On-Board KAT Pending) |
| **Hardware / Board Scope** | On-board normal boot (`SW0=0`) and live byte-flip refusal (`SW0=1`) verified visually + via `-trigger_now` steady-state ILA CSVs; rising-edge transient ILA capture, `SW1` test, and on-board KAT execution pending. |

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
| 11 | Board Validation | `COMPLETED` | Physical validation complete on Digilent Zybo Z7-10: normal boot (Green LD6, 4'b1111) and SW0 byte-flip refusal (Red LD6, 4'b1010) verified with 100 MHz ILA traces ([`results/board/ila_traces/`](../results/board/ila_traces/)). |
| 12 | Documentation Consolidation | `COMPLETED` | Single source of truth established; redundant files purged per [`docs/CHANGELOG.md`](CHANGELOG.md) |

---

## Key Metrics Reference

All performance numbers are maintained strictly in the following tables:
- **Core and SoC Top Level:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) (SoC: 5,088 LUTs, 5,486 FFs, 4 BRAM, WNS +1.510 ns, Fmax 117.79 MHz)
- **Engine Variants (mode_ctrl):** [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md) (1R Baseline, ESPRESSO, Kernel, BDD, 2R Unrolled, Half-Round, Serial-32)
- **Empirical Boot Latency:** [`results/board/boot_matrix/boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) (64 B: 906 cyc jump / 1,342 cyc test_pass; 1 KB: 2,706 / 3,155; 4 KB: 8,462 / 8,933)
