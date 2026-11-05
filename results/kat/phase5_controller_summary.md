# Phase 5 — AEAD & Hash Mode Controller Verification Summary

- **Date:** 2026-10-21 (Updated November 5, 2026)
- **Status:** `[x] VERIFIED PASS (all unit & exhaustive full KAT suites passed)`
- **Standard:** NIST SP 800-232 (Little-Endian, revised IVs)
- **Target FPGA:** Xilinx Zynq-7000 (XC7Z010-1CLG400C)

---

## 1. Architectural Implementation Overview

Phase 5 delivers the unified master sponge control plane and security gateway connecting the permutation datapath (`permutation_1r.sv`, etc.) to higher-level AXI/DMA interfaces:

| Module | Purpose | Key Specifications |
|---|---|---|
| [`rtl/ascon/plaintext_gate.sv`](../../rtl/ascon/plaintext_gate.sv) | Hardware Plaintext Release Gate & Shadow Buffer | 32x64-bit shadow buffer; actively zeroizes on `auth_fail`; outputs `0x0` whenever `tag_ok == 0` |
| [`rtl/ascon/mode_ctrl.sv`](../../rtl/ascon/mode_ctrl.sv) | Master Sponge Mode Controller FSM | Unified FSM supporting Ascon-AEAD128 and Ascon-Hash256; handles Little-Endian padding, domain separation ($S_4[63]$), rate absorption, tag verification, and squeeze sequence; parameterized by `PERM_VARIANT` |
| [`rtl/ascon/aead_ctrl.sv`](../../rtl/ascon/aead_ctrl.sv) | Dedicated AEAD128 Mode Wrapper | Parameterized AEAD128 interface with 128-bit key, 128-bit nonce, 128-bit tag, 128-bit rate streaming |
| [`rtl/ascon/hash_ctrl.sv`](../../rtl/ascon/hash_ctrl.sv) | Dedicated Hash256 Mode Wrapper | 64-bit streaming rate interface; 256-bit output digest |

---

## 2. NIST SP 800-232 Compliance Details

1. **Initialization Vectors (Little-Endian):**
   - Ascon-AEAD128: `64'h00001000808c0001`
   - Ascon-Hash256: `64'h0000080100cc0002`
2. **Padding Scheme:**
   - 1-byte `0x01` followed by zeros to fill the rate word (`64'h01 << (rem * 8)`).
3. **Domain Separation:**
   - 1-bit domain separation injected into $S_4[63]$ (`s4 <= s4 ^ 64'h80000000_00000000`).
4. **Permutation Synchronization (`perm_running`):**
   - Synchronous handshake flag prevents premature progression on stale `done` pulses across multi-round absorption and extraction cycles.

---

## 3. Security Gate & Threat Model Verification

The plaintext release gate was rigorously tested against all 5 security test scenarios mandated by the project specification:

| Test ID | Description | Observed Result | Status |
|---|---|---|---|
| **SG-1** | Valid CT + Valid Tag | Decrypted plaintext released from shadow buffer; `tag_ok=1`, `error=0` | `PASS` |
| **SG-2** | 1-bit Corrupted Ciphertext | Tag mismatch detected; candidate plaintext suppressed; entire shadow buffer actively zeroized | `PASS` |
| **SG-3** | 1-bit Corrupted Tag | Tag mismatch detected; candidate plaintext suppressed; entire shadow buffer actively zeroized | `PASS` |
| **SG-4** | External Read Scan before Tag Check | Read attempts while unauthenticated return strictly `0x00000000_00000000` | `PASS` |
| **SG-5** | Abort / Soft Reset during Decryption | Immediate zeroization of shadow buffer; `auth_fail` strobed | `PASS` |

---

## 4. Test Suite Execution Summary

| Testbench | Component Tested | Vectors / Scenarios | Pass Rate | Evidence Log |
|---|---|---|:---:|---|
| [`tb_security_gate.sv`](../../tb/unit/tb_security_gate.sv) | `plaintext_gate.sv` | 5 Security Tests | **100%** | [`results/kat/security_gate_pass.log`](security_gate_pass.log) |
| [`tb_mode_ctrl.sv`](../../tb/unit/tb_mode_ctrl.sv) | `mode_ctrl.sv` | 5 FSM Directed Transitions | **100%** | [`results/kat/fsm_coverage.log`](fsm_coverage.log) |
| [`tb_hash.sv`](../../tb/unit/tb_hash.sv) | `hash_ctrl.sv` | NIST Counts 1, 2, 9, 17 | **100%** | [`results/kat/rtl_hash_pass.log`](rtl_hash_pass.log) |
| [`tb_aead.sv`](../../tb/unit/tb_aead.sv) | `aead_ctrl.sv` | NIST Counts 1, 2, 17, 35 | **100%** | [`results/kat/rtl_aead_pass.log`](rtl_aead_pass.log) |
| [`tb_hash_full.sv`](../../tb/unit/tb_hash_full.sv) | `mode_ctrl.sv` (Hash) | Exhaustive 1,025 Vectors (0..1024 B) | **100%** | [`results/kat/rtl_hash_full_pass.log`](rtl_hash_full_pass.log) |
| [`tb_aead_full.sv`](../../tb/unit/tb_aead_full.sv) | `mode_ctrl.sv` (AEAD) | Exhaustive 1,089 Vectors (0..1024 B) | **100%** | [`results/kat/rtl_aead_full_pass.log`](rtl_aead_full_pass.log) |
| [`tb_hash_full_serial32.sv`](../../tb/unit/tb_hash_full_serial32.sv) | `mode_ctrl` (Serial-32 Hash) | Exhaustive 1,025 Vectors | **100%** | [`results/kat/rtl_hash_full_serial32_pass.log`](rtl_hash_full_serial32_pass.log) |
| [`tb_aead_full_serial32.sv`](../../tb/unit/tb_aead_full_serial32.sv) | `mode_ctrl` (Serial-32 AEAD) | Exhaustive 1,089 Vectors | **100%** | [`results/kat/rtl_aead_full_serial32_pass.log`](rtl_aead_full_serial32_pass.log) |
| [`tb_hash_full_kernel.sv`](../../tb/unit/tb_hash_full_kernel.sv) | `mode_ctrl` (Kernel Hash) | Exhaustive 1,025 Vectors | **100%** | [`results/kat/rtl_hash_full_kernel_pass.log`](rtl_hash_full_kernel_pass.log) |
| [`tb_aead_full_kernel.sv`](../../tb/unit/tb_aead_full_kernel.sv) | `mode_ctrl` (Kernel AEAD) | Exhaustive 1,089 Vectors | **100%** | [`results/kat/rtl_aead_full_kernel_pass.log`](rtl_aead_full_kernel_pass.log) |
| [`tb_hash_full_bdd.sv`](../../tb/unit/tb_hash_full_bdd.sv) | `mode_ctrl` (BDD Hash) | Exhaustive 1,025 Vectors | **100%** | [`results/kat/rtl_hash_full_bdd_pass.log`](rtl_hash_full_bdd_pass.log) |
| [`tb_aead_full_bdd.sv`](../../tb/unit/tb_aead_full_bdd.sv) | `mode_ctrl` (BDD AEAD) | Exhaustive 1,089 Vectors | **100%** | [`results/kat/rtl_aead_full_bdd_pass.log`](rtl_aead_full_bdd_pass.log) |
