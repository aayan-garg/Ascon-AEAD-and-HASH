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
| **Current Phase** | Complete & Ready for Board Flashing (Simulation, Synthesis, STA, Formal Sign-off, and Bitstream Clean) |
| **Last Action** | Complete pre-hardware audit and remediation: (1) Resolved BRAM synthesis bug in `top_bringup.sv` so Block RAM initializes properly during bitstream generation; (2) Commented unused `btn[1..3]` constraints in `zybo_z7_10.xdc` eliminating all Critical Warnings; (3) Built automated Python toolchain for S-Box optimization in `tools/sbox_opt/` (ESPRESSO SOPform, algebraic kernel extraction, and 32-node shared ROBDD multiplexer tree); (4) Authored comprehensive Hand HLS derivation in `docs/hand_hls_derivation.md`; (5) Aligned `HARDWARE_RUNBOOK.md` and `README.md` with SW0 byte-flip demo and measured boot cycles. |
| **Date** | 2026-11-05 |
| **Overall Progress** | 100% of Simulation, Formal, RTL, S-box Optimization, Hand HLS, and Synthesis Verification Complete |
| **Hardware / Board Scope** | Ready for Physical Hardware Deployment. Bitstream build scripts verified with authentic Boot ROM + candidate payload. |

---

## Phase Status Summary

| Phase | Name | Status | Authoritative Artifact / Evidence |
|---|---|:---:|---|
| 0 | Spec Audit & Research | `COMPLETED` | [`docs/research_review.md`](research_review.md), [`docs/decisions/`](decisions/) |
| 1 | Repo & Environment | `COMPLETED` | Clean repo, automated regression runner [`scripts/run_regression.py`](../scripts/run_regression.py) |
| 2 | RISC-V SoC Bring-up | `COMPLETED` | Routed with WNS +1.570 ns at 100 MHz ([`results/timing/timing_bringup.txt`](../results/timing/timing_bringup.txt)) |
| 3 | Golden Model | `COMPLETED` | 2,120 NIST KAT vectors pass in [`reference/run_kats.py`](../reference/run_kats.py) |
| 4 | Permutation Datapath & Hand HLS | `COMPLETED` | Hand HLS derived in [`docs/hand_hls_derivation.md`](hand_hls_derivation.md); 1R, 2R, Half-Round, Serial-32, ESPRESSO, Kernel, BDD bit-exact ([`tb_sbox_equiv.sv`](../tb/unit/tb_sbox_equiv.sv)) |
| 5 | Mode Controller & Security Gate | `COMPLETED` | 1,089 AEAD and 1,025 Hash KATs pass; plaintext gate suppresses unauthenticated data |
| 6 | AXI4-Lite Bus Integration | `COMPLETED` | Memory-mapped register file verified in [`tb_axil_regs.sv`](../tb/integration/tb_axil_regs.sv) |
| 7 | Contention-Free DMA Engine | `COMPLETED` | Port B BRAM streaming verified in [`tb_dma.sv`](../tb/integration/tb_dma.sv) and [`tb_soc_dma.sv`](../tb/integration/tb_soc_dma.sv) |
| 8 | Secure Boot Flow & Matrix | `COMPLETED` | Boot ROM + hardware boot_ctrl + fetch_guard verified on 9 matrix cases ([`tb_secure_boot.sv`](../tb/integration/tb_secure_boot.sv)) |
| 9 | Formal CTL Verification | `COMPLETED` | All 5 CTLSPECs proved in NuSMV 2.6.0 ([`results/formal/nuxmv/proof_corrected_nusmv.log`](../results/formal/nuxmv/proof_corrected_nusmv.log)) |
| 10 | Synthesis & Implementation | `COMPLETED` | All cores and SoC meet 100 MHz timing; see [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) |
| 11 | Board Validation | `READY-FOR-BOARD` | Hardware runbook updated ([`results/board/HARDWARE_RUNBOOK.md`](../results/board/HARDWARE_RUNBOOK.md)); bitstream generation verified. |
| 12 | Documentation Consolidation | `COMPLETED` | Single source of truth established; redundant files purged per [`docs/CHANGELOG.md`](CHANGELOG.md) |

---

## Key Metrics Reference

All performance numbers are maintained strictly in the following tables:
- **Core and SoC Top Level:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) (SoC: 5,088 LUTs, 5,486 FFs, 4 BRAM, WNS +1.570 ns, Fmax 118.62 MHz)
- **Engine Variants (mode_ctrl):** [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md) (1R Baseline, ESPRESSO, Kernel, BDD, 2R Unrolled, Half-Round, Serial-32)
- **Empirical Boot Latency:** [`results/board/boot_matrix/boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) (64 B: 906 cyc jump / 1,342 cyc test_pass; 1 KB: 2,706 / 3,155; 4 KB: 8,462 / 8,933)
