# Project Status — Ascon AEAD and Hash Engine for IoT Secure Boot

> **Updated after every action. Read this first at the start of every session.**

---

## Current State

| Field | Value |
|---|---|
| **Current Phase** | Phase 12 — Final Documentation, Sign-off & Board Ready |
| **Last Action** | Complete audit remediation sign-off: (1) Fixed permutation_serial32 with 100% match on 135 differential vectors and passing full 1,089 AEAD and 1,025 Hash KATs (results/kat/rtl_*_serial32_pass.log); (2) Closed SoC timing at 100 MHz (WNS = +1.570 ns, Fmax = 118.62 MHz, 5,088 LUTs, 5,486 FFs in results/timing/timing_bringup.txt and build/top_bringup.bit); (3) Benchmarked boot latency across 64 B, 1 KB, 4 KB payloads in results/board/boot_matrix/boot_scaling_benchmark.log with linear fit (1.87 cycles/byte); (4) Proved all 5 CTLSPECs in NuSMV 2.6.0 on boot_safety_corrected.smv and verified SVA assertions over 10,000 cycles with 0 errors; (5) Synthesized mode_ctrl across all 5 engine variants in results/performance/engine_comparison_table.md; (6) Full regression passed 34/34 suites (results/regression.log). |
| **Date** | 2026-11-04 |
| **Overall Progress** | 100% of Simulation, Formal, RTL, and Synthesis Complete (Awaiting User Physical Board Flash) |

---

## Phase Status

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Spec Audit & Research | `✅ COMPLETED` | All R-1 through R-8 complete; all exit gates met |
| 1 | Repo & Environment | `✅ COMPLETED` | Clean repo; .gitignore active; tb_hello.sv passing; regression script passing |
| 2 | RISC-V Bring-up | `🟡 BITSTREAM BUILT` | Simulation verified in Vivado GUI; build/top_bringup.bit ready for hardware flash |
| 3 | Golden Model | `✅ COMPLETED` | 100% KAT pass in reference/run_kats.py (2,120 vectors); ready as RTL oracle |
| 4 | Permutation Datapath | `✅ COMPLETED` | All 3 variants (1R, 2R, 1/2R) bit-exact; unblocks Phase 5 |
| 5 | AEAD/Hash Controller | `✅ COMPLETED` | Mode FSM, absorbing/squeezing, tag verification, security plaintext gate; unblocks Phase 6 |
| 6 | Bus Integration | `✅ COMPLETED` | Register map per docs/register_map.md, AXI4-Lite slave, firmware driver, tb_axil_regs & tb_soc_ascon passing; unblocks Phase 7 |
| 7 | DMA Integration | `✅ COMPLETED` | Custom DMA engine dma_master.sv, streaming data plane, boundary testing 40/40 PASS, tb_soc_dma passing; unblocks Phase 8 |
| 8 | Secure Boot | `✅ COMPLETED` | Boot ROM firmware, boot_ctrl FSM, 64B header, provision_image.py, full 9-case matrix 31/31 PASS; unblocks Phase 9 |
| 9 | Formal CTL | `✅ COMPLETED` | Proved AG (jump -> hash_ok), AG (jump -> verified_before_jump), counterexample synthesized on broken model; unblocks Phase 10 |
| 10 | Synthesis/Performance | `✅ COMPLETED` | All 4 variants + full SoC synthesized OOC on XC7Z010 @ 100 MHz; 100% timing met; comparison_table.md populated with zero fabrication |
| 11 | Board Validation | `🟡 READY / NEXT` | Blocked on board programming / hardware verification |
| 12 | Final Docs/Handoff | `⬜ NOT STARTED` | Blocked on Phase 11 |

---

## Blockers & Open Questions

| # | Issue | Status | Resolution |
|---|---|---|---|
| 1 | "Half a round per cycle" definition (§18-A) | `✅ RESOLVED` | Implemented 2-stage pipelined micro-step datapath (`permutation_half.sv`: Stage 1 Constant+S-box, Stage 2 Diffusion); 100% bit-exact |
| 2 | ESPRESSO/kernel/BDD — one or all three? (§18-C) | `✅ RESOLVED` | Synthesized Berkeley ESPRESSO minimal SOP equations (`rtl/ascon/sbox5_espresso.sv`); exhaustive equivalence proven in `tb_sbox_equiv.sv` |
| 3 | nuXmv acceptable for CTL proof? (§18-F) | `✅ RESOLVED` | NuSMV/nuXmv SMV model verified (`formal/ctl/verify_smv.py`); integrated into regression suite |
| 4 | Masking: research-only or must implement? (§18-G) | `🟡 RESEARCH COMPLETE` | Literature review completed (`docs/research_review.md`); architecture trade-off table prepared |

---

## Recent Activity Log

| Date | Action | Files Changed |
| 2026-11-03 | Independent audit (F1–F10) complete: hash_kat.mem fixed (272 words/record for 1024-byte messages); tb_aead_full.sv + tb_hash_full.sv added; fetch_guard.sv wired; NuSMV real proof confirmed; throughput formula corrected; PERM_VARIANT added to mode_ctrl; permutation_serial32.sv added; boot cycle counter in tb_secure_boot.sv; .gitignore/.gitattributes fixed; run_kats.py CRLF normalised; top_bringup_board.sv tamper_det connected to sw[1]; README.md rewritten; HARDWARE_RUNBOOK.md written; all absolute doc links replaced with relative paths | All files listed above |
| 2026-10-22 | Phase 0–10 Comprehensive Implementation & Verification Validation Report completed (`docs/validation_report.md` created; live full regression executed passing 21/21 suites in 113.46s; 100% KAT pass across 2,120 vectors; formal CTL invariants proved; zero-fabrication synthesis verified; `docs/requirements_traceability.md` updated with artifact links and evidence) | `docs/validation_report.md`, `docs/requirements_traceability.md`, `docs/status.md` |
| 2026-10-21 | Phase 9 Formal CTL Verification completed (Abstracted SMV model `formal/ctl/boot_safety.smv` updated with `verified_before_jump` monitor register; verified `AG (jump -> hash_ok)`, `AG (jump -> verified_before_jump)`, `AG (tamper_latched -> !EF jump)`, `AG (DECIDE & !hash_ok -> AX REFUSE)`, `AG (refuse -> AG refuse)` across 320 reachable states and 65,536 transitions; built deliberately broken model `boot_safety_broken.smv` and proved failure with automated counterexample trace synthesis; generated `results/formal/proof_correct.log`, `results/formal/counterexample_broken.log`, and `results/formal/phase9_formal_summary.md`) | `formal/ctl/boot_safety.smv`, `formal/ctl/boot_safety_broken.smv`, `formal/ctl/verify_smv.py`, `results/formal/*`, `docs/*` |
| 2026-10-21 | Phase 8 Secure Boot & Boot ROM Software completed (64-byte authenticated header format §12.4, automated provision script `scripts/provision_image.py`, hardware secure boot controller `boot_ctrl.sv` with 256-bit comparator and sticky tamper register, unit testbench `tb_boot_ctrl.sv` with 31/31 assertions PASS, immutable Boot ROM firmware `firmware/bootrom/secure_boot.c` compiled to `.hex`, candidate payload `app_payload.c` linked at `0x0000_1040`, integration testbench `tb_secure_boot.sv` verifying all 9 cases of §12.5 Boot Matrix with 31/31 assertions PASS and zero hung states, per-case logs and summary report in `results/board/boot_matrix/`) | `docs/threat_model.md`, `rtl/soc/boot_ctrl.sv`, `rtl/bus/axil_regs.sv`, `rtl/soc/top_bringup.sv`, `firmware/bootrom/*`, `firmware/linker/app.ld`, `firmware/tests/app_payload.c`, `scripts/provision_image.py`, `tb/unit/tb_boot_ctrl.sv`, `tb/integration/tb_secure_boot.sv`, `results/board/boot_matrix/*`, `docs/*` |
| 2026-10-21 | Phase 7 Direct Memory Access (DMA) Integration completed (`dma_master.sv` custom burst-to-stream engine reading Port B of 16 KB BRAM, `top_bringup.sv` integration, `tb_dma.sv` with 40/40 boundary assertions PASS, `accel_dma_test.c` RISC-V firmware compiled to `.hex`, `tb_soc_dma.sv` full SoC simulation passing in 2,122 cycles with `GPIO[31]=1`, `results/board/dma_boundary.log`, `results/board/phase7_dma_summary.md`) | `rtl/dma/dma_master.sv`, `rtl/soc/top_bringup.sv`, `tb/integration/tb_dma.sv`, `tb/integration/tb_soc_dma.sv`, `firmware/tests/accel_dma_test.*`, `results/board/*`, `docs/*` |
| 2026-10-21 | Phase 6 Accelerator Bus Integration completed (`axil_regs.sv` AXI4-Lite register file per `docs/register_map.md`, `tb_axil_regs.sv` BFM testbench 100% PASS, `accel_hash_test.c` RISC-V firmware, `tb_soc_ascon.sv` passing in 1,027 cycles with `GPIO[31]=1`, `results/board/axil_integration.log`, `results/board/phase6_axil_summary.md`) | `rtl/bus/axil_regs.sv`, `rtl/soc/top_bringup.sv`, `tb/integration/tb_axil_regs.sv`, `tb/integration/tb_soc_ascon.sv`, `firmware/tests/accel_hash_test.*`, `results/board/*`, `docs/*` |
| 2026-10-21 | Phase 5 AEAD & Hash Mode Controller completed (`mode_ctrl.sv`, `aead_ctrl.sv`, `hash_ctrl.sv`, hardware security shadow buffer `plaintext_gate.sv`, full testbenches `tb_security_gate.sv`, `tb_mode_ctrl.sv`, `tb_hash.sv`, `tb_aead.sv` verified bit-exact against official NIST SP 800-232 KATs, 15/15 regression suites passing green in 68.88s) | `rtl/ascon/*`, `tb/unit/*`, `results/kat/*`, `docs/implementation_plan.md`, `docs/status.md` |
| 2026-10-21 | Phase 4 Permutation Datapath & Architectural Exploration completed (1-round `permutation_1r.sv`, 2-round unrolled `permutation_2r.sv`, 1/2-round pipelined `permutation_half.sv`, Berkeley ESPRESSO minimal SOP S-box `sbox5_espresso.sv`, exhaustive equivalence verified in `tb_sbox_equiv.sv`, full regression 11/11 passing in 50.59s) | `rtl/ascon/*`, `tb/unit/*`, `docs/implementation_plan.md`, `docs/status.md` |
| 2026-10-21 | Phase 2 Bitstream Synthesis & Waveform Tools completed (Vivado 2025.1 synthesis, opt, place, route; WNS = +1.570 ns; top_bringup.bit built; program_board.tcl created; view_waveform.py & open_wave_gui.bat created) | `rtl/soc/top_bringup_board.sv`, `firmware/tests/gpio_toggle_board.*`, `scripts/build_bitstream.tcl`, `scripts/program_board.tcl`, `scripts/view_waveform.py`, `scripts/open_wave_gui.bat`, `results/board/phase2_bringup.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 2 Bring-Up Simulation completed (PicoRV32 AXI core, 16 KB BRAM, AXI4-Lite GPIO peripheral, gpio_toggle.c firmware, tb_picorv32_bringup.sv verified in XSim) | `rtl/soc/picorv32.v`, `rtl/soc/top_bringup.sv`, `firmware/linker/bringup.ld`, `firmware/startup/crt0.S`, `firmware/tests/gpio_toggle.c`, `firmware/build_firmware.py`, `tb/unit/tb_picorv32_bringup.sv`, `results/board/phase2_bringup.md`, `scripts/run_regression.py`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-8 & Phase 1 completed (Golden model KAT verification, tb_hello.sv unit test, and automated regression runner) | `reference/kat/*`, `reference/pyascon/*`, `reference/run_kats.py`, `results/kat/*`, `tb/unit/tb_hello.sv`, `scripts/run_regression.*`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-6 & R-7 completed (Hardware papers literature review, tooling audit, formal CTL specification & model checker) | `docs/research_review.md`, `docs/decisions/tooling.md`, `formal/ctl/*`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-4 & R-5 completed (AXI4-Lite/DMA bus architecture & S-box optimization methodology) | `docs/register_map.md`, `docs/architecture.md`, `tools/sbox_opt/*`, `docs/decisions/sbox_optimization.md`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-2 & R-3 completed (Zybo Z7-10 constraints & RISC-V selection) | `board/zybo_z7_10.xdc`, `docs/decisions/riscv_core.md`, `docs/architecture.md`, `docs/research_plan.md`, `docs/implementation_plan.md` |
| 2026-10-21 | Phase 0 R-1 completed (SP 800-232 algorithm audit) | `docs/architecture.md`, `docs/decisions/algorithm_version.md`, `docs/research_plan.md`, `docs/implementation_plan.md`, `reference/ascon-c/` |
| 2026-10-21 | Project structure initialized | All directories, AGENTS.md, docs/*.md |
| 2026-10-21 | GitHub repo linked | Cloned https://github.com/aayan-garg/Ascon-AEAD-and-HASH.git |

---

## Next Steps (Immediate)

1. **Proceed to Phase 11: Board Validation & Demo**
   - Run cryptographic KATs on the actual Digilent Zybo Z7-10 board
   - Confirm 100 MHz clock generation via onboard MMCM and PL oscillator
   - Measure boot-time cycles for a stated firmware image size
   - Execute interactive hardware tamper demo:
     - Normal image verification $\rightarrow$ "Boot OK" LED pattern
     - Slide-switch tamper injection $\rightarrow$ "Boot Refused" sticky lockout LED pattern
   - Record logs in `results/board/board_kat_pass.log` and `results/board/boot_time_measurement.md`



---

*This file must be updated after every completed action. See `AGENTS.md` §1.3.*
