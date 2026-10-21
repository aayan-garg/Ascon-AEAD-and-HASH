# Decision Record: Adoption of NIST SP 800-232 (Final Standard)

- **Status:** `ACCEPTED`
- **Date:** 2026-10-21
- **Deciders:** Antigravity Agent, System Architect
- **Requirement Reference:** `[SPEC]` Project_PS.md §Deliverables; `[SOURCE]` NIST SP 800-232 (DOI: 10.6028/NIST.SP.800-232)

---

## 1. Context and Problem Statement

`Project_PS.md` mandates building an authenticated-encryption and hash engine implementing **Ascon-AEAD128** and **Ascon-Hash256** per **NIST SP 800-232**.

Historically, Ascon underwent multiple evolutionary milestones:
1. **Ascon v1.2 (2019/2021 NIST LWC Submission):** Used **big-endian** word-to-byte mapping, different naming conventions (`Ascon-128`, `Ascon-128a`, `Ascon-Hash`), and legacy Initialization Vectors (IVs).
2. **NIST SP 800-232 (Final Standard, August 2025):** Standardized lightweight cryptography primitives with **little-endian** byte mapping, revised structured IVs, and selected `Ascon-128a` (128-bit rate, $a=12, b=8$ rounds) as the standardized **Ascon-AEAD128**.

Many open-source RTL cores (such as OpenTitan's early Ascon IP or legacy GitHub repositories) implemented Ascon v1.2. We must explicitly define the normative baseline and strictly reject v1.2 artifacts.

---

## 2. Decision

We adopt **NIST SP 800-232 (Final)** as the sole normative cryptographic standard for this project:
- **AEAD Primitive:** `Ascon-AEAD128` (128-bit key, 128-bit nonce, 128-bit tag, 128-bit rate, $a=12$ init/finalization rounds, $b=8$ data rounds).
- **Hash Primitive:** `Ascon-Hash256` (256-bit digest, 64-bit rate, $a=12, b=12$ rounds).
- **Byte Ordering:** Strict **little-endian** conventions per SP 800-232 and `ascon/ascon-c`.
- **Golden Reference Oracle:** Official C reference implementation from `ascon/ascon-c` (branch `main` / release v1.3+) and official NIST KAT vector files.

---

## 3. Key Differences: NIST SP 800-232 vs. Legacy Ascon v1.2

| Parameter / Feature | Legacy Ascon v1.2 (`Ascon-128a` / `Ascon-Hash`) | NIST SP 800-232 (`Ascon-AEAD128` / `Ascon-Hash256`) | Impact on Implementation |
|---|---|---|---|
| **Byte Ordering** | Big-endian (`bytes[0]` is MSB of word $S_i$) | **Little-endian** (`bytes[0]` is LSB of word $S_i$) | **Incompatible.** Word loading/storing must place `bytes[i]` at `(bytes[i] << (8*i))`. |
| **Padding Byte** | `0x80` at byte position $i$ in big-endian | **`0x01`** at byte position $i$ in little-endian (`0x01 << (8*i)`) | Padding bit is the first bit following data in byte order (LSB of the next byte). |
| **AEAD Rate ($r$)** | `Ascon-128`: 64 bits (8 bytes); `Ascon-128a`: 128 bits (16 bytes) | **Ascon-AEAD128:** 128 bits (16 bytes) | 2 words ($S_0, S_1$) absorbed/squeezed per data block. |
| **AEAD Rounds ($a, b$)** | `Ascon-128`: 12, 6; `Ascon-128a`: 12, 8 | **Ascon-AEAD128:** $a=12, b=8$ | Permutation controller must sequence 12 rounds for init/final, 8 rounds for AD/data. |
| **Hash Rate ($r$)** | 64 bits (8 bytes) | **Ascon-Hash256:** 64 bits (8 bytes) | 1 word ($S_0$) absorbed/squeezed per data block. |
| **Hash Rounds ($a, b$)** | 12, 12 | **Ascon-Hash256:** $a=12, b=12$ | Permutation controller always sequences 12 rounds. |
| **AEAD IV** | `0x80800c0800000000` (big-endian encoding) | **`0x00001000808c0001`** (little-endian structured) | Loaded into state word $S_0$ during initialization. |
| **Hash IV** | `0x00400c0000000100` (big-endian encoding) | **`0x0000080100cc0002`** (little-endian structured) | Loaded into state word $S_0$ during initialization. |
| **Domain Separation** | Bit 0 of word $S_4$ in big-endian (`0x01`) | **Bit 63 of word $S_4$** in little-endian (`0x8000000000000000`) | XORed into $S_4$ upon completion of Associated Data. |

---

## 4. Consequences and Verification Gates

1. **RTL Design Rule:** No pre-2025 Ascon RTL can be copied or integrated without verifying little-endian word formatting and revised IVs.
2. **KAT Compliance:** All RTL testbenches must validate against SP 800-232 KAT vectors (`LWC_AEAD_KAT_128_128.txt` and `LWC_HASH_KAT_128_256.txt`).
3. **Firmware Consistency:** The RISC-V PicoRV32 processor natively operates with 32-bit little-endian byte ordering, making little-endian data alignment natural over AXI4-Lite and DMA.
