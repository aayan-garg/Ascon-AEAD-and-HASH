# Register Map — Ascon Accelerator AXI4-Lite Interface

> **Purpose:** Complete register map for the AXI4-Lite slave interface.
> **Status:** `[PLACEHOLDER — to be finalized during Phase 6]`

## Proposed Register Map

| Offset | Name | R/W | Width | Reset | Meaning |
|---|---|---|---|---|---|
| 0x00 | `CTRL` | R/W | 32 | 0 | bit0 `start`, bit1 `mode`, bit2 `encrypt_n_decrypt`, bit3 `soft_reset` |
| 0x04 | `STATUS` | RO | 32 | 0 | bit0 `busy`, bit1 `done`, bit2 `error`, bit3 `tag_ok`/`hash_ok` |
| 0x08 | `AD_LEN` | R/W | 32 | 0 | Associated-data length in bytes |
| 0x0C | `MSG_LEN` | R/W | 32 | 0 | Plaintext/ciphertext/hash-input length in bytes |
| 0x10–0x1C | `KEY[0..3]` | WO | 32×4 | 0 | 128-bit AEAD key (reads as 0) |
| 0x20–0x2C | `NONCE[0..3]` | WO | 32×4 | 0 | 128-bit nonce |
| 0x30–0x3C | `TAG[0..3]` | R/W | 32×4 | 0 | Expected/produced tag |
| 0x40–0x5C | `DIGEST[0..7]` | RO | 32×8 | 0 | 256-bit hash digest |
| 0x60 | `DMA_SRC_ADDR` | R/W | 32 | 0 | Firmware source BRAM address |
| 0x64 | `DMA_LEN` | R/W | 32 | 0 | DMA transfer length in bytes |
| 0x68 | `DMA_CTRL` | R/W | 32 | 0 | bit0 `dma_start` |
| 0x6C | `DMA_STATUS` | RO | 32 | 0 | bit0 `dma_busy`, bit1 `dma_done`, bit2 `dma_error` |

---

*See [Initial Research](../../Initial%20Research.md) §11 for the full register map rationale.*
