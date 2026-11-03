# Threat Model — Ascon Secure Boot System

- **Target System:** PicoRV32 RISC-V SoC + Ascon AEAD/Hash Coprocessor on Digilent Zybo Z7-10 (XC7Z010)
- **Standard:** NIST SP 800-232 (Final, August 2025)
- **Document Reference:** Initial Research Specification §12 & Requirements R14, R17

---

## 1. Executive Summary & Purpose

This document articulates the formal threat model, cryptographic trust assumptions, attack surfaces, and explicit security boundaries for the Ascon-Hash256 hardware-assisted secure boot system. 

The primary security goal of this architecture is **authenticity and integrity verification prior to execution**: ensuring that the host RISC-V processor executes instructions from an application firmware image if and only if the image is strictly untampered, fully intact, and verified against a trusted reference digest.

---

## 2. Security Trust Anchor (§12.3)

In constrained FPGA platforms lacking dedicated on-chip eFuses, secure enclaves, or battery-backed secure RAM, the trust anchor must be rooted in unalterable storage:

1. **Bitstream-Baked Reference Digest:**
   - The 256-bit golden reference digest $H_{\text{ref}}$ is baked directly into the FPGA bitstream configuration memory (within the Boot ROM BRAM initialization data or synthesized hardware comparator registers).
   - Once the FPGA bitstream is loaded into configuration SRAM, the reference digest is stored in read-only hardware structures that cannot be modified by any runtime code executing on the PicoRV32 CPU.

2. **Isolated Dual-Port BRAM Partitioning:**
   - **Boot ROM & Trust Store (`0x0000_0000` - `0x0000_0FFF`):** Contains the immutable bootloader firmware and reference parameters.
   - **Candidate Firmware Staging Region (`0x0000_1000` - `0x0000_3FFF`):** Dedicated writable memory region where untrusted or external candidate firmware images are staged for evaluation.
   - **Hardware Separation:** The candidate firmware staging area is modifiable (e.g., via communication interfaces, switches, or host loaders), but the reference digest storage in Boot ROM is completely separate from the candidate firmware buffer.

---

## 3. Threat Model & In-Scope Attack Scenarios

### 3.1 Primary Threat: Firmware-Only Modification / Corruption
- **Attacker Profile:** An adversary or transmission channel possessing read/write access to external non-volatile memory or the candidate firmware staging buffer in RAM, but lacking physical access to alter the running bitstream or FPGA configuration logic.
- **Attack Vector 1 — Arbitrary Firmware Modification:** The adversary replaces candidate firmware instructions with malicious payload (e.g. trojan, backdoor, or privilege escalation code).
  - *Countermeasure:* Ascon-Hash256 sponge permutation across the entire firmware binary. With 128-bit collision and preimage security per NIST SP 800-232, finding a modified payload that collides with $H_{\text{ref}}$ requires $\ge 2^{128}$ operations (computationally infeasible).
- **Attack Vector 2 — Single-Bit / Single-Byte Tampering:** Accidental bit-flips (cosmic ray, flash wear) or intentional bit manipulation (switch perturbation in physical demo §19).
  - *Countermeasure:* Strict cryptographic avalanche effect. Changing any single bit in the payload completely randomizes the computed 256-bit digest, causing an immediate mismatch against $H_{\text{ref}}$.
- **Attack Vector 3 — Header Spoofing & Length Truncation:** Modifying declared length in the image header to bypass validation or cause buffer overflows.
  - *Countermeasure:* Header fields are strictly bound: the declared length is verified against a hardware-baked maximum length, and the cryptographic hash covers the payload in its entirety.
- **Attack Vector 4 — Address Redirection / Entry Point Tampering:** Modifying the candidate entry vector to jump into unverified code or circumvent the bootloader.
  - *Countermeasure:* Entry point is verified to fall within legal application boundaries; furthermore, hardware `boot_ctrl.sv` maintains a hardware jump-enable gate (`jump_enable`) that only unlocks when the hardware comparator asserts `hash_ok`.

---

## 4. Explicit Limitations: What This Design Does NOT Provide

To maintain rigorous engineering honesty (§12.3), the following threat vectors are **explicitly out of scope**:

1. **Bitstream Reprogramming Attack:** If an attacker can reflash the FPGA bitstream itself (via JTAG, SPI flash, or physical programmer), they can replace the entire circuit, including the reference digest and the CPU. Protection against bitstream tampering relies on external hardware features (e.g., Xilinx 7-series bitstream encryption with battery-backed RAM AES keys), which is orthogonal to this RTL design.
2. **Invasive Silicon / Physical Probing:** Microprobing of internal FPGA routing, decapping, or focused ion beam (FIB) modification of Block RAM cells is not prevented.
3. **Power / EM Side-Channel Attacks:** While the mode controller enforces constant-time tag comparison, the baseline unmasked permutation datapath does not implement DPA/CPA masking countermeasures (evaluated as a literature research trade-off in `docs/research_review.md`).
4. **Anti-Rollback Without Monotonic Counter:** Without non-volatile monotonic counters (eFuses), an attacker who can flash a legitimate older version of firmware with an older valid digest could execute a rollback attack unless the bitstream is updated.

---

## 6. Fetch Guard Hardware Implementation (F3 Fix)

**Threat addressed:** CPU jumping into unverified application code before `boot_ctrl` asserts `jump_enable`.

**Implementation (`rtl/soc/fetch_guard.sv` + `rtl/soc/top_bringup.sv`):**
- A combinational gate intercepts `bram_rdata` on the instruction bus.
- Application region is defined as addresses ≥ `APP_BASE` (default `0x1040`).
- While `boot_jump_enable = 0`, any fetch from the application region returns `32'h0000_0013` (RISC-V NOP / ADDI x0, x0, 0), preventing execution of unverified code.
- Once `boot_ctrl.sv` sets `jump_enable = 1` (only after `hash_ok` is asserted), the gate opens and real instructions are fetched.

**Limitations [ASSUME]:**
- Protection is address-based (instruction address decode), not bus-protocol enforcement. A speculative or mis-predicted fetch cannot cause harm since the NOP is benign.
- The TOCTOU risk (image modified between hash completion and fetch) is LOW: the DMA engine uses a read-only port (Port B) and the boot ROM does not write to the application region after hashing.
- This does not prevent an attacker who can modify the bitstream or BRAM init data from bypassing the gate entirely (see §4 limitations).

**Updated threat claim:** The claim "physically impossible to jump without authorization" is revised to: "A CPU executing Boot ROM firmware cannot fetch executable instructions from the application region until `boot_ctrl` asserts `jump_enable`, which is conditioned on `hash_ok`. An attacker with bitstream or JTAG access remains out of scope."


---

## 5. Digest Provenance & Provisioning Flow

```
+------------------------------------+
|  Application Source (app.c / .bin) |
+------------------+-----------------+
                   |
                   v
+------------------------------------+
| scripts/provision_image.py         |
| 1. Computes 256-bit Ascon-Hash256  |
| 2. Prepends 64-byte Header         |
| 3. Emits trusted_manifest.h        |
+------------------+-----------------+
                   |
       +-----------+-----------+
       |                       |
       v                       v
+------------------+   +-------------------+
| Candidate Image  |   | Boot ROM Firmware |
| (image.hex)      |   | (trusted digest   |
| Staged in RAM    |   |  baked in ROM)    |
+------------------+   +-------------------+
```

1. **Deterministic Build Pipeline:** The application binary is compiled using `riscv64-unknown-elf-gcc`.
2. **Golden Cryptographic Hashing:** `scripts/provision_image.py` invokes the official NIST SP 800-232 reference implementation (`reference/pyascon/ascon.py`) to hash the application payload.
3. **Artifact Generation:** The script produces:
   - `trusted_manifest.h`: Header with `TRUSTED_DIGEST`, `TRUSTED_LEN`, and `TRUSTED_ENTRY`, compiled into `secure_boot.c`.
   - `image.bin` / `image.hex`: Packaged binary with 64-byte header and application payload.

---

## 6. Firmware Image Format (§12.4)

The candidate firmware image uses a structured 64-byte authenticated header followed immediately by the executable payload:

| Offset | Field | Type | Description |
|:---:|:---:|:---:|---|
| `0x00` | `magic` | `uint32_t` | Magic identifier string: `0x4153_434E` (`"ASCN"`) |
| `0x04` | `version` | `uint32_t` | Image format version (`0x0000_0001`) |
| `0x08` | `payload_len` | `uint32_t` | Application payload size in bytes (must be word-aligned) |
| `0x0C` | `entry_point` | `uint32_t` | Execution entry address in BRAM (e.g., `0x0000_1040`) |
| `0x10..0x1F` | `reserved[4]` | `uint32_t[4]` | Reserved for flags and alignment padding |
| `0x20..0x3F` | `expected_digest[8]` | `uint32_t[8]` | 256-bit Ascon-Hash256 reference digest |
| `0x40..` | `payload` | `uint8_t[]` | Executable application instructions and rodata |

---

## 7. Refusal & Lockout Determinism (§12.5)

In every failure or attack scenario, the system must guarantee a **deterministic, non-hung failure state**:
- The Boot ROM calls `refusal_lockout(reason)`.
- Refusal LED pattern (`4'b1010`) is driven to Zybo Z7-10 discrete LEDs.
- Hardware `boot_ctrl.sv` transitions to `STATE_HALT_REFUSE`, permanently de-asserting `jump_enable`.
- Execution halts in a safe dead-loop (`while(1)`), preventing speculative execution or jump into untrusted code.
