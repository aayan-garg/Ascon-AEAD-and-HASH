# Golden Model Verification Summary (NIST SP 800-232)

- **Date:** 2026-10-21 15:09:38 UTC
- **Status:** `[x] 100% VERIFIED PASS`
- **Model:** `reference/pyascon/ascon.py`
- **Standard:** NIST SP 800-232 (Little-Endian)

## 1. KAT File Integrity

| File | Vectors | SHA-256 Checksum | Integrity Status |
|---|---|---|---|
| `reference/kat/LWC_AEAD_KAT_128_128.txt` | 1,089 | `37cdac1a75c35ba0fe234098027ab43bd396c147e26a4a0c41123e2db25b31bb` | `MATCH` |
| `reference/kat/LWC_HASH_KAT_128_256.txt` | 1,025 | `106f09738b1bd8fac6275665835314f589b919661f1c35a86f4c3bc146a8ce0a` | `MATCH` |

## 2. Test Execution Results

| Algorithm Suite | Vectors Tested | Passed | Failed | Pass Rate |
|---|---|---|---|---|
| **Ascon-AEAD128 (Encrypt & Decrypt)** | 1,089 | 1,089 | 0 | **100.0%** |
| **Ascon-Hash256** | 1,025 | 1,025 | 0 | **100.0%** |
| **Security Edge Cases (Corruption & Tamper)** | 6 | 6 | 0 | **100.0%** |
| **Total** | **2,120** | **2,120** | **0** | **100.0%** |

## 3. Exit Gate Confirmation
The golden model in `reference/pyascon/ascon.py` has passed 100% of the official NIST SP 800-232 Known Answer Tests without exception and is certified as the RTL simulation oracle.
