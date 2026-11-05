# Golden Model Verification Summary (NIST SP 800-232)

- **Date:** 2026-11-05 00:58:37 UTC
- **Status:** `[x] VERIFIED PASS (2,120 NIST KAT vectors)`
- **Model:** `reference/pyascon/ascon.py`
- **Standard:** NIST SP 800-232 (Little-Endian)

## 1. KAT File Integrity

| File | Vectors | SHA-256 Checksum | Integrity Status |
|---|---|---|---|
| `reference/kat/LWC_AEAD_KAT_128_128.txt` | 1,089 | `bbbc34692fe05e5fda0a3b025585622ab3e3747495e5e3655b29aae8c2a4bd33` | `MATCH` |
| `reference/kat/LWC_HASH_KAT_128_256.txt` | 1,025 | `b7d6fbc51362f0d62bc7e57b21f3e83242983434a7c92320a4956d915749df17` | `MATCH` |

## 2. Test Execution Results

| Algorithm Suite | Vectors Tested | Passed | Failed | Pass Rate |
|---|---|---|---|---|
| **Ascon-AEAD128 (Encrypt & Decrypt)** | 1,089 | 1,089 | 0 | **100.0%** |
| **Ascon-Hash256** | 1,025 | 1,025 | 0 | **100.0%** |
| **Security Edge Cases (Corruption & Tamper)** | 6 | 6 | 0 | **100.0%** |
| **Total** | **2,120** | **2,120** | **0** | **100.0%** |

## 3. Exit Gate Confirmation
The golden model in `reference/pyascon/ascon.py` has passed 100% of the official NIST SP 800-232 Known Answer Tests without exception and is certified as the RTL simulation oracle.
