# Phase 8: Secure Boot & Boot ROM Verification Summary

## Executive Overview
Phase 8 implements the complete **NIST SP 800-232 Authenticated Secure Boot Architecture** for the Ascon AEAD/Hash RTL Project on the Digilent Zybo Z7-10 SoC. 

The architecture features a **dual-layer hardware/software gatekeeper** model:
1. **Immutable Boot ROM Software (`firmware/bootrom/secure_boot.c`):** Executed by the PicoRV32 processor from addresses `0x0000_0000` to `0x0000_0FFF` (first 4 KB of BRAM). It validates the 64-byte candidate header, triggers the hardware boot controller FSM, coordinates DMA streaming of candidate payload into the Ascon Hash-256 accelerator, and performs constant-time reference digest verification.
2. **Hardware Secure Boot Controller (`rtl/soc/boot_ctrl.sv`):** An 8-state hardware FSM with an independent 256-bit comparator and sticky tamper register. It enforces the formal invariant `AG (jump -> hash_ok)`. The CPU cannot execute code at the application entry point unless `boot_jump_enable == 1` and `boot_refuse == 0`.

---

## Authenticated Header Specification (§12.4)

Each candidate image staged at `0x0000_1000` contains a strictly structured 64-byte authenticated header:

| Offset | Field | Width | Expected / Valid Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | `magic` | 4 Bytes | `0x4153434E` | ASCII `"ASCN"` identifier |
| `0x04` | `version` | 4 Bytes | `0x00000001` | Format specification version 1 |
| `0x08` | `payload_len` | 4 Bytes | `0x00000040` (64 B) | Candidate payload length in bytes (1 to 8192) |
| `0x0C` | `entry_point` | 4 Bytes | `0x00001040` | Execution vector after verification |
| `0x10..0x1F` | `reserved[4]` | 16 Bytes | `0x00000000` | Zero-padded future-proofing |
| `0x20..0x3F` | `expected_digest[8]` | 32 Bytes | 256-bit Hash | Expected Ascon-Hash256 reference digest |

---

## Complete 9-Case Boot Matrix (§12.5)

Verification was executed via the end-to-end integration testbench [`tb/integration/tb_secure_boot.sv`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/tb/integration/tb_secure_boot.sv). All 9 cases completed deterministically with zero hung states:

| Case | Scenario Tested | Stimulus / Fault Mechanism | Hardware LED | `test_pass` | `jump_enable` | Verdict | Artifact Log |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **1** | Valid Untampered Firmware | Untampered candidate image + matching digest | `4'b1111` | `1` | `1` | **PASS** | [`case_1.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_1.log) |
| **2** | Byte-Flipped Firmware | 1-bit modified in candidate payload byte 10 | `4'b1010` | `0` | `0` | **PASS** | [`case_2.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_2.log) |
| **3** | Wrong Reference Digest | Header contains altered expected digest | `4'b1010` | `0` | `0` | **PASS** | [`case_3.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_3.log) |
| **4** | Invalid Declared Length | Header declares `payload_len = 0` | `4'b1010` | `0` | `0` | **PASS** | [`case_4.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_4.log) |
| **5** | Malformed Header Magic | Header magic is `0xDEADBEEF` | `4'b1010` | `0` | `0` | **PASS** | [`case_5.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_5.log) |
| **6** | Injected DMA Error | DMA abort / error injected during stream | `4'b1010` | `0` | `0` | **PASS** | [`case_6.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_6.log) |
| **7** | Injected Accelerator Error | Accelerator reset/error injected during hash | `4'b1010` | `0` | `0` | **PASS** | [`case_7.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_7.log) |
| **8** | Reset Mid-Verification | Asynchronous reset asserted mid-flight | `4'b0000` | `0` | `0` | **PASS** | [`case_8.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_8.log) |
| **9** | Repeated Boot Attempt | Re-trigger start after refusal lockout | `4'b1010` | `0` | `0` | **PASS** | [`case_9.log`](file:///c:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/results/board/boot_matrix/case_9.log) |

**Total Assertions:** 31 / 31 passed (100% success rate).

---

## Key Hardware Safety Guarantees

1. **Deterministic Refusal:** Any error condition (magic mismatch, version mismatch, out-of-bounds length, corrupted reference digest, payload hash mismatch, DMA fault, accelerator fault, or tamper signal) immediately forces the system into `STATE_HALT_REFUSE`. Discrete LEDs drive `4'b1010` and execution enters an infinite dead-loop.
2. **Sticky Tamper Lockout:** The physical tamper latch register (`tamper_latched_q`) cannot be cleared by software or register writes; once set, exit from `STATE_HALT_REFUSE` requires an external hardware power-on reset.
3. **Hardware Jump Permission Gate:** `boot_jump_enable` is exclusively driven by `(state_q == STATE_JUMP)` which requires `hash_verified_q == 1` and `tamper_latched_q == 0`. Speculative execution or soft jump into candidate memory without hardware authorization is physically impossible.
