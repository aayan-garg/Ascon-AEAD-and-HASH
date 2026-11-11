# Final Comprehensive Project Audit & Verification Report
## Ascon-128 AEAD & Ascon-Hash256 Cryptographic Engine with RISC-V Secure Boot for Digilent Zybo Z7-10

- **Date:** November 11, 2026  
- **Target Device:** AMD-Xilinx Zynq-7000 SoC XC7Z010-1CLG400C (Digilent Zybo Z7-10)  
- **Normative Standard:** NIST SP 800-232 (Final Standard, August 2025)  
- **System Architecture:** PicoRV32 RV32I CPU + AXI4-Lite Control + Contention-Free BRAM Port B DMA Streaming + Ascon Permutation Engine + Hardware Security Plaintext Gate + Hardware Fetch Guard  
- **Authoritative Traceability:** [`docs/requirements_traceability.md`](requirements_traceability.md)  
- **Authoritative Audit Response:** [`docs/AUDIT_RESPONSE.md`](AUDIT_RESPONSE.md)  
- **Change Log:** [`docs/CHANGELOG.md`](CHANGELOG.md)  

---

## Executive Summary

This report documents the comprehensive implementation, formal verification, and empirical characterization of the `Ascon-AEAD-and-HASH` hardware project. The design implements the complete lightweight cryptographic algorithms specified in NIST SP 800-232 (Ascon-AEAD128 and Ascon-Hash256) integrated into a secure RISC-V SoC targeting the AMD-Xilinx XC7Z010 FPGA at 100 MHz.

All components—including the 320-bit permutation datapath across seven distinct architectural variants, the dual-mode controller FSM with Little-Endian rate formatting, the hardware plaintext release shadow buffer, the contention-free DMA engine, the secure boot controller with hardware fetch guard, and the formal CTL state safety properties—have been implemented and verified using live tool runs:
- **NIST Known Answer Tests (KATs):** 100% bit-exact compliance across all 1,089 AEAD vectors and 1,025 Hash vectors in live Vivado XSim simulations.
- **Formal CTL Model Checking:** Proved all 5 safety properties in NuSMV 2.6.0 on the secure boot controller model, with an automated 6-step counterexample synthesized on a flawed model.
- **Physical Synthesis & STA:** Closed timing at 100 MHz across all standalone permutation cores, full engine wrappers, the baseline SoC bitstream (`WNS = +1.510 ns`, $F_{max} = 117.79$ MHz), and the ILA-instrumented bitstream (`WNS = +1.042 ns`).
- **Dual-Gate Defense Verification:** Verified through both the 9-case boot matrix and a dedicated forced-jump negative testbench (`tb_forced_jump.sv`), proving that untrusted application execution is blocked until cryptographically authorized.

---

## 1. Audit History and Remediation

For the complete itemized audit findings (F1–F10) and their technical remediations, see [`docs/AUDIT_RESPONSE.md`](AUDIT_RESPONSE.md).

Summary of major remediation achievements:
1. **Exhaustive KATs:** Implemented full 1,089 AEAD and 1,025 Hash vector testbenches (`tb_aead_full.sv`, `tb_hash_full.sv`) verifying msg lengths 0 to 1,024 bytes.
2. **Formal CTL Model Checking:** Replaced legacy Python simulation with the NuSMV 2.6.0 model checker, verifying all 5 CTLSPECs on `formal/ctl/boot_safety_corrected.smv` and producing counterexamples on `boot_safety_broken.smv`.
3. **Hardware Fetch Guard:** Wired `rtl/soc/fetch_guard.sv` combinational gating between BRAM Port A and the PicoRV32 instruction bus, forcing NOP instructions (`0x00000013`) whenever the candidate firmware region ($\ge \text{0x1040}$) is fetched without `jump_enable`.
4. **Permutation Serial-32:** Fully debugged the 32-bit serialized datapath (`permutation_serial32.sv`), proving 100% equivalence on 135 differential vectors and passing full KAT suites.
5. **SoC Timing Closure:** Pipelined critical control signals in `mode_ctrl.sv` to improve SoC setup slack from -2.657 ns to **+1.510 ns** at 100 MHz ($F_{max} = 117.79$ MHz).
6. **Cycle-Accurate Boot Benchmarks:** Synchronously benchmarked boot latency across 64 B, 1 KB, and 4 KB payload sizes, deriving an empirical linear scaling equation.

---

## 2. Requirements Compliance Summary

All project requirements from `Project_PS.md` are mapped to implementation artifacts, testbenches, and verification logs in [`docs/requirements_traceability.md`](requirements_traceability.md).

Key highlights:
- **SP 800-232 Compliance (`R1`, `R2`, `R3`, `R9`):** Complete adherence to the August 2025 standard, including Little-Endian byte ordering, 128-bit AEAD rate ($b=8$ rounds), 64-bit Hash rate ($a=12$ rounds), and revised initialization vectors.
- **Hardware Plaintext Gating (`R5`):** Shadow buffer (`plaintext_gate.sv`) enforces the security contract that unauthenticated plaintext is never observable on external busses before tag verification (`tag_ok == 1`), and triggers active zeroization upon authentication failure.
- **Bus & DMA Streaming Architecture (`R7`):** Memory-mapped AXI4-Lite control plane (`axil_regs.sv`) and independent Port B BRAM DMA master (`dma_master.sv`) provide contention-free data streaming without stalling host CPU execution.
- **Hardware Secure Boot Flow (`R8`, `R14`):** Dual-gate security combining software cryptographic hash comparison in Boot ROM firmware with hardware latching and instruction bus fetch-guard interception.
- **Physical Board Scope (`R19`):** Bitstream generation succeeded for both baseline (`build/top_bringup.bit`, WNS `+1.510 ns`, $F_{max} = 117.79$ MHz) and ILA-instrumented (`build/top_bringup_ila.bit`, WNS `+1.042 ns`) builds. On a physical Digilent Zybo Z7-10 (`xc7z010_1`), normal boot (`LD0..3 = 4'b1111`, RGB `LD6` = Green) and live `SW0` DMA bit-flip refusal (`LD0..3 = 4'b1010`, RGB `LD6` = Red) were verified visually and sampled in steady state via Vivado ILA (`-trigger_now`); rising-edge transient boot ILA capture, physical `SW1` tamper testing, on-board cycle measurement, and on-board KAT execution remain pending ([`HARDWARE_RUNBOOK.md`](../results/board/HARDWARE_RUNBOOK.md), [`ila_verification_report.md`](../results/board/ila_verification_report.md)).

---

## 3. Physical Synthesis and Architectural Evaluation

Complete post-route implementation metrics and comparisons are maintained in the authoritative tables:
- **Top-Level SoC & Standalone Permutation Cores:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md)
- **Full Engine Out-of-Context Wrappers (`mode_ctrl`):** [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)

### Key Architectural Findings:
1. **Full SoC Implementation:** Implemented with physical board constraints (`top_bringup_board` + `board/zybo_z7_10.xdc`) on AMD-Xilinx XC7Z010 at 100 MHz using 5,088 Slice LUTs (28.91%), 5,486 Slice FFs (15.59%), and 4 Block RAMs (RAMB36E1), achieving **WNS = +1.510 ns** ($F_{max} = 117.79$ MHz).
2. **Throughput-to-Area Efficiency Leader:** The 2-round unrolled engine (`mode_ctrl_2r_wrap`) achieves **887.90 kbps/LUT** at 100 MHz (3,200.00 Mbps AEAD throughput, 3,604 LUTs), retiring 128 bits of ciphertext every 4 clock cycles.
3. **Logic Footprint Leader:** The half-round folded pipeline (`mode_ctrl_half_wrap`) minimizes logic resources to **2,995 LUTs** (-6.1% vs. 1R baseline) by time-multiplexing substitution and linear diffusion over 2 clock cycles.
4. **S-Box Design Variations:**
   - **Baseline (`sbox5.sv` in `mode_ctrl_1r_wrap`):** 3,191 LUTs, 4,015 FFs, WNS +1.925 ns (123.84 MHz).
   - **ESPRESSO SOP (`sbox5_espresso.sv` in `mode_ctrl_1r_espresso_wrap`):** 3,258 LUTs, 4,015 FFs, WNS +1.621 ns (119.35 MHz), generated via UC Berkeley ESPRESSO (`-Dexact`, 30-cube exact cover, 130 input literals).
   - **Kernel Extraction (`sbox5_kernel.sv` in `mode_ctrl_1r_kernel_wrap`):** 3,192 LUTs, 4,015 FFs, WNS +2.226 ns (128.63 MHz), synthesized via Brayton-McMullen algebraic kernel/co-kernel extraction.
   - **ROBDD Decomposition (`sbox5_bdd.sv` in `mode_ctrl_1r_bdd_wrap`):** 3,225 LUTs, 4,015 FFs, WNS +1.856 ns (122.79 MHz), decomposed using optimal interleaved variable ordering.
   - **Hardware Mapping Context:** Because the 5-bit Ascon S-box maps to only a few 6-input LUTs (LUT6), Vivado synthesis re-maps whatever Boolean form it is given into native LUT6 primitives. Differences within ~2% (a spread of 67 LUTs out of >3,100) across the four variants represent synthesis placement/routing variations rather than a fundamental technique benefit, confirming all three optimization paradigms achieve equivalent high-quality hardware realization.
5. **Serial-32 Trade-off Analysis:** The 32-bit serialized datapath (`permutation_serial32.sv`, inspired by Groß et al., DSD 2015) evaluates 32 shared S-boxes over two clock cycles per round. On modern 6-input FPGA LUTs, the multiplexing logic and pipeline registers exceed the S-box logic savings (3,353 LUTs, 4,180 FFs), resulting in 238.59 kbps/LUT (0.48x of 1R baseline efficiency). It remains advantageous on ASICs or 4-LUT architectures where raw gate count dominates multiplexer cost.

---

## 4. Formal CTL Model Checking

The secure boot controller FSM was formally specified in SMV (`formal/ctl/boot_safety_corrected.smv`) matching the exact register-transfer logic of `rtl/soc/boot_ctrl.sv`. The model was verified using **NuSMV 2.6.0** (transcript: [`results/formal/nuxmv/proof_corrected_nusmv.log`](../results/formal/nuxmv/proof_corrected_nusmv.log)):

- **Property 1 ($AG(\text{jump} \rightarrow \text{hash\_ok})$):** Proved TRUE across all reachable states.
- **Property 2 ($AG(\text{jump} \rightarrow \text{verified\_before\_jump})$):** Proved TRUE, confirming jump requires prior verification.
- **Property 3 ($AG(\text{tamper\_latched} \rightarrow \neg EF(\text{jump}))$):** Proved TRUE, confirming tamper detection irreversibly locks out execution.
- **Property 4 ($AG(\text{DECIDE} \land \neg\text{hash\_ok} \rightarrow AX(\text{REFUSE}))$):** Proved TRUE, ensuring unauthenticated payloads trigger immediate refusal.
- **Property 5 ($AG(\text{refuse} \rightarrow AG(\text{refuse}))$):** Proved TRUE, establishing terminal lockout behavior.

### Counterexample Demonstration:
A flawed model (`formal/ctl/boot_safety_broken.smv`) with unlatched decision logic was evaluated in NuSMV 2.6.0. The tool synthesized a 6-step counterexample trace ([`results/formal/nuxmv/counterexample_broken_nusmv.log`](../results/formal/nuxmv/counterexample_broken_nusmv.log)) demonstrating an authentication bypass, proving that the verification suite detects safety vulnerabilities.

---

## 5. Secure Boot Dual-Gate Defense and Latency Benchmarks

### 5.1 Dual-Gate Hardware Defense
The secure boot subsystem enforces two distinct layers of hardware protection:
1. **Hardware Boot Controller (`boot_ctrl.sv`):** Computes firmware digest over DMA Port B, performs 256-bit equality comparison against the authenticated header, and asserts `jump_enable` only upon valid match without tamper.
2. **Instruction Fetch Guard (`fetch_guard.sv`):** Intercepts instruction fetches from BRAM Port A for memory addresses $\ge \text{0x1040}$. If `jump_enable == 0`, fetch data is combinational substituted with `32'h00000013` (RISC-V NOP: `addi x0, x0, 0`). Even if program control is forced to the application entry point, the CPU executes harmless NOPs.

**Negative Test Verification:**
The dedicated testbench [`tb/integration/tb_forced_jump.sv`](../tb/integration/tb_forced_jump.sv) and firmware binary [`firmware/tests/forced_jump.hex`](../firmware/tests/forced_jump.hex) verified this mechanism:
- **Guard Active (`ENABLE_FETCH_GUARD = 1`):** Execution of candidate code is blocked; test pass flag remains 0 (`results/board/boot_matrix/forced_jump_sim.log`).
- **Guard Bypassed (`ENABLE_FETCH_GUARD = 0`):** Candidate code executes and asserts test pass flag.

### 5.2 Boot Latency Characterization
Boot latency was measured cycle-accurately in Vivado 2025.1 XSim via [`tb/integration/tb_payload_sizes.sv`](../tb/integration/tb_payload_sizes.sv) using provisioned images generated by [`scripts/provision_image.py`](../scripts/provision_image.py):

| Payload Size | Reset Release $\rightarrow$ `jump_enable` | Time to Jump (@ 100 MHz) | Reset Release $\rightarrow$ `test_pass` | Total Boot Time (@ 100 MHz) | Evidence Log |
|---|:---:|:---:|:---:|:---:|---|
| **64 Bytes** | **906 cycles** | 9.06 µs | **1,342 cycles** | 13.42 µs | [`boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) |
| **1,024 Bytes (1 KB)** | **2,706 cycles** | 27.06 µs | **3,155 cycles** | 31.55 µs | [`boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) |
| **4,096 Bytes (4 KB)** | **8,462 cycles** | 84.62 µs | **8,933 cycles** | 89.33 µs | [`boot_scaling_benchmark.log`](../results/board/boot_matrix/boot_scaling_benchmark.log) |

**Empirical Linear Scaling Model ($L$ in bytes):**
$$\text{Cycles to Jump}(L) = 1.874 \times L + 786.5\quad (18.74\text{ ns/byte} + 7.865\ \mu\text{s})$$
$$\text{Cycles to Pass}(L) = 1.882 \times L + 1225.2\quad (18.82\text{ ns/byte} + 12.252\ \mu\text{s})$$

The base overhead represents Boot ROM initialization, header parsing, BRAM bus setup, and post-jump CPU execution.

---

## 6. Audit Verdict and Sign-off

Every simulation, formal CTL, RTL, and synthesis requirement from `Project_PS.md` is implemented and verified with committed artifacts; physical normal boot and `SW0` byte-flip refusal are logged on Zybo Z7-10 with steady-state ILA traces, while hardware masking remains NOT DONE and rising-edge transient ILA capture, `SW1` bench logging, on-board latency measurement, and on-board KAT execution remain pending.

**Final Audit Verdict:** `SIMULATION, FORMAL CTL, RTL, AND SYNTHESIS VERIFIED; NORMAL & SW0 BOARD BOOT LOGGED (MASKING NOT DONE; EDGE-ILA / SW1 / ON-BOARD KAT PENDING).`
