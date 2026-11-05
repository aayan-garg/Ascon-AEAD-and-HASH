# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Current single source of truth for repository status. Read this first at the start of every session.**
> For detailed technical reports and audit responses, see:
> - **Performance Measurements:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) and [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)
> - **Requirements Traceability:** [`docs/requirements_traceability.md`](requirements_traceability.md)
> - **Final Technical Report:** [`docs/final_report.md`](final_report.md)
> - **Audit History & Finding Responses:** [`docs/AUDIT_RESPONSE.md`](AUDIT_RESPONSE.md)
> - **Repository Changes:** [`docs/CHANGELOG.md`](CHANGELOG.md)

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Complete (Simulation, Synthesis, STA, and Formal Sign-off) |
| **Last Action** | Fresh Vivado 2025.1 OOC synthesis completed for five permutation variants and seven engine wrappers. Engine reports now record same-session measurements: baseline 3,191 LUTs/+2.130 ns, ESPRESSO 3,253/+1.879 ns, kernel 3,052/+2.142 ns, and BDD 3,055/+2.086 ns. Kernel and BDD remain documented as ANF restatement and lookup table, not extracted techniques. |
| **Date** | 2026-11-05 |
| **Overall Progress** | 100% of Simulation, Formal, RTL, and Synthesis Verification Complete |
| **Hardware / Board Scope** | On-board physical testing out of scope per rules. Bitstream generation not attempted (implementation stopped at route_design with WNS +1.570 ns). |

---

## Phase Status Summary

| Phase | Name | Status | Authoritative Artifact / Evidence |
|---|---|:---:|---|
| 0 | Spec Audit & Research | `COMPLETED` | [`docs/research_review.md`](research_review.md), [`docs/decisions/`](decisions/) |
| 1 | Repo & Environment | `COMPLETED` | Clean repo, automated regression runner [`scripts/run_regression.py`](../scripts/run_regression.py) |
| 2 | RISC-V SoC Bring-up | `COMPLETED` | Routed with WNS +1.570 ns at 100 MHz ([`results/timing/timing_bringup.txt`](../results/timing/timing_bringup.txt)) |
| 3 | Golden Model | `COMPLETED` | 2,120 NIST KAT vectors pass in [`reference/run_kats.py`](../reference/run_kats.py) |
| 4 | Permutation Datapath | `COMPLETED` | 1R, 2R, Half-Round, Serial-32, ESPRESSO, Kernel, BDD bit-exact ([`tb_sbox_equiv.sv`](../tb/unit/tb_sbox_equiv.sv)) |
| 5 | Mode Controller & Security Gate | `COMPLETED` | 1,089 AEAD and 1,025 Hash KATs pass; plaintext gate suppresses unauthenticated data |
| 6 | AXI4-Lite Bus Integration | `COMPLETED` | Memory-mapped register file verified in [`tb_axil_regs.sv`](../tb/integration/tb_axil_regs.sv) |
| 7 | Contention-Free DMA Engine | `COMPLETED` | Port B BRAM streaming verified in [`tb_dma.sv`](../tb/integration/tb_dma.sv) and [`tb_soc_dma.sv`](../tb/integration/tb_soc_dma.sv) |
| 8 | Secure Boot Flow & Matrix | `COMPLETED` | Boot ROM + hardware boot_ctrl + fetch_guard verified on 9 matrix cases ([`tb_secure_boot.sv`](../tb/integration/tb_secure_boot.sv)) |
| 9 | Formal CTL Verification | `COMPLETED` | All 5 CTLSPECs proved in NuSMV 2.6.0 ([`results/formal/nuxmv/proof_corrected_nusmv.log`](../results/formal/nuxmv/proof_corrected_nusmv.log)) |
| 10 | Synthesis & Implementation | `COMPLETED` | All cores and SoC meet 100 MHz timing; see [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) |
| 11 | Board Validation | `OUT OF SCOPE` | Physical board testing out of scope per rules. |
| 12 | Documentation Consolidation | `COMPLETED` | Single source of truth established; redundant files purged per [`docs/CHANGELOG.md`](CHANGELOG.md) |

---

## Key Metrics Reference

All performance numbers are maintained strictly in the following tables:
- **Core and SoC Top Level:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md) (SoC: 5,088 LUTs, 5,486 FFs, 4 BRAM, WNS +1.570 ns, Fmax 118.62 MHz)
- **Engine Variants (mode_ctrl):** [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md) (1R Baseline, ESPRESSO, Kernel, BDD, 2R Unrolled, Half-Round, Serial-32)
- **Empirical Boot Latency:** [`results/board/boot_matrix/boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) (64 B: 906 cyc jump / 1,342 cyc test_pass; 1 KB: 2,706 / 3,155; 4 KB: 8,462 / 8,933)
