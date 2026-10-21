# Register Map: Ascon Accelerator AXI4-Lite Interface

- **Standard:** ARM AMBA AXI4-Lite (ARM IHI 0022E)
- **Base Address:** `0x4000_0000` (PL Memory-Mapped Peripheral Region)
- **Address Space:** 4 KB (`0x4000_0000` - `0x4000_0FFF`)
- **Bus Width:** 32 bits (data bus `s_axil_wdata[31:0]`, `s_axil_rdata[31:0]`)
- **Byte Ordering:** Little-endian (matches RISC-V PicoRV32 native ordering)
- **Access Rule:** 32-bit aligned word access only; sub-word accesses return `SLVERR`.

---

## 1. Register Address Map

| Offset | Name | R/W | Reset Value | Description |
|:---:|:---:|:---:|:---:|---|
| `0x00` | [`CTRL`](#21-ctrl-control-register) | R/W | `0x0000_0000` | Core control and operation launch |
| `0x04` | [`STATUS`](#22-status-status-register) | RO / W1C | `0x0000_0000` | Operational status, completion, and diagnostic state |
| `0x08` | [`AD_LEN`](#23-ad_len-associated-data-length) | R/W | `0x0000_0000` | Associated data byte count (AEAD mode) |
| `0x0C` | [`MSG_LEN`](#24-msg_len-message-payload-length) | R/W | `0x0000_0000` | Plaintext/ciphertext/hash message byte count |
| `0x10` | `KEY_0` | WO | `0x0000_0000` | 128-bit Key bits [31:0] (bytes 0..3) |
| `0x14` | `KEY_1` | WO | `0x0000_0000` | 128-bit Key bits [63:32] (bytes 4..7) |
| `0x18` | `KEY_2` | WO | `0x0000_0000` | 128-bit Key bits [95:64] (bytes 8..11) |
| `0x1C` | `KEY_3` | WO | `0x0000_0000` | 128-bit Key bits [127:96] (bytes 12..15) |
| `0x20` | `NONCE_0` | R/W | `0x0000_0000` | 128-bit Nonce bits [31:0] (bytes 0..3) |
| `0x24` | `NONCE_1` | R/W | `0x0000_0000` | 128-bit Nonce bits [63:32] (bytes 4..7) |
| `0x28` | `NONCE_2` | R/W | `0x0000_0000` | 128-bit Nonce bits [95:64] (bytes 8..11) |
| `0x2C` | `NONCE_3` | R/W | `0x0000_0000` | 128-bit Nonce bits [127:96] (bytes 12..15) |
| `0x30` | `TAG_0` | R/W | `0x0000_0000` | 128-bit Tag bits [31:0] |
| `0x34` | `TAG_1` | R/W | `0x0000_0000` | 128-bit Tag bits [63:32] |
| `0x38` | `TAG_2` | R/W | `0x0000_0000` | 128-bit Tag bits [95:64] |
| `0x3C` | `TAG_3` | R/W | `0x0000_0000` | 128-bit Tag bits [127:96] |
| `0x40` | `DIGEST_0` | RO | `0x0000_0000` | 256-bit Hash Digest bits [31:0] |
| `0x44` | `DIGEST_1` | RO | `0x0000_0000` | 256-bit Hash Digest bits [63:32] |
| `0x48` | `DIGEST_2` | RO | `0x0000_0000` | 256-bit Hash Digest bits [95:64] |
| `0x4C` | `DIGEST_3` | RO | `0x0000_0000` | 256-bit Hash Digest bits [127:96] |
| `0x50` | `DIGEST_4` | RO | `0x0000_0000` | 256-bit Hash Digest bits [159:128] |
| `0x54` | `DIGEST_5` | RO | `0x0000_0000` | 256-bit Hash Digest bits [191:160] |
| `0x58` | `DIGEST_6` | RO | `0x0000_0000` | 256-bit Hash Digest bits [223:192] |
| `0x5C` | `DIGEST_7` | RO | `0x0000_0000` | 256-bit Hash Digest bits [255:224] |
| `0x60` | [`DMA_SRC_ADDR`](#25-dma_src_addr-dma-source-address) | R/W | `0x0000_0000` | BRAM source memory address for DMA |
| `0x64` | [`DMA_LEN`](#26-dma_len-dma-transfer-length) | R/W | `0x0000_0000` | DMA byte transfer count |
| `0x68` | [`DMA_CTRL`](#27-dma_ctrl-dma-control-register) | R/W | `0x0000_0000` | DMA channel launch and configuration |
| `0x6C` | [`DMA_STATUS`](#28-dma_status-dma-status-register) | RO | `0x0000_0000` | DMA engine status and progress |
| `0x70` | [`IRQ_EN`](#29-irq_en-interrupt-enable) | R/W | `0x0000_0000` | Interrupt enable mask |
| `0x7C` | [`CORE_ID`](#210-core_id-hardware-identification) | RO | `0x4153_4331` | Hardware ASCII ID (`"ASC1"`) and version |

---

## 2. Register Field Definitions

### 2.1 `CTRL` (Control Register, Offset `0x00`)

| Bits | Name | Access | Reset | Description |
|:---:|:---:|:---:|:---:|---|
| `0` | `START` | WO | `0` | Write `1` to initiate processing. Self-clearing pulse bit. Ignored if `STATUS.BUSY == 1`. |
| `1` | `MODE` | R/W | `0` | Primitive mode: `0` = Ascon-AEAD128, `1` = Ascon-Hash256. |
| `2` | `DEC` | R/W | `0` | Direction (AEAD only): `0` = Encrypt & generate Tag, `1` = Decrypt & verify Tag. |
| `3` | `SOFT_RST` | WO | `0` | Write `1` to synchronously reset coprocessor FSM and clear shadow buffer. |
| `4` | `DMA_AUTO` | R/W | `0` | If `1`, asserting `START` also triggers the internal DMA engine. |
| `31:5` | Reserved | RO | `0` | Must write 0, reads return 0. |

### 2.2 `STATUS` (Status Register, Offset `0x04`)

| Bits | Name | Access | Reset | Description |
|:---:|:---:|:---:|:---:|---|
| `0` | `BUSY` | RO | `0` | `1` when the accelerator is currently executing permutations. |
| `1` | `DONE` | W1C | `0` | `1` when operation has completed. Write `1` to clear. |
| `2` | `ERROR` | W1C | `0` | `1` if an invalid configuration, DMA boundary violation, or tag mismatch occurred. |
| `3` | `TAG_OK` | RO | `0` | **AEAD Decrypt:** `1` if received tag matches computed tag.<br>**Hash:** `1` if boot digest matches reference. |
| `7:4` | `FSM_STATE` | RO | `0` | Diagnostic encoding of internal mode controller FSM (`0`=IDLE, `1`=INIT, `2`=ABSORB_AD, `3`=ABSORB_MSG, `4`=FINALIZE, `5`=TAG_CHECK, `6`=DONE, `7`=ERROR). |
| `31:8` | Reserved | RO | `0` | Reserved for future diagnostic flags. |

### 2.3 `AD_LEN` (Associated Data Length, Offset `0x08`)
- **Bits [31:0]:** Length of associated data in bytes. If `0`, associated data phase is bypassed, and domain separation is asserted immediately after initialization.

### 2.4 `MSG_LEN` (Message Payload Length, Offset `0x0C`)
- **Bits [31:0]:** Length of plaintext (encrypt), ciphertext (decrypt), or hash message payload in bytes.

### 2.5 `KEY[0..3]` (Secret Key Registers, Offsets `0x10`–`0x1C`)
- **Security Rule:** **Write-Only.** Reading any `KEY` register returns `0x0000_0000` to prevent firmware side-channel leakage across unauthenticated reads.
- **Mapping:**
  - `KEY_0` [31:0] = $K[31:0]$ (Word $K_0$ lower 32 bits)
  - `KEY_1` [31:0] = $K[63:32]$ (Word $K_0$ upper 32 bits)
  - `KEY_2` [31:0] = $K[95:64]$ (Word $K_1$ lower 32 bits)
  - `KEY_3` [31:0] = $K[127:96]$ (Word $K_1$ upper 32 bits)

### 2.6 `NONCE[0..3]` (Nonce Registers, Offsets `0x20`–`0x2C`)
- **Mapping:**
  - `NONCE_0` [31:0] = $N[31:0]$ (Word $N_0$ lower 32 bits)
  - `NONCE_1` [31:0] = $N[63:32]$ (Word $N_0$ upper 32 bits)
  - `NONCE_2` [31:0] = $N[95:64]$ (Word $N_1$ lower 32 bits)
  - `NONCE_3` [31:0] = $N[127:96]$ (Word $N_1$ upper 32 bits)

### 2.7 `TAG[0..3]` (Authentication Tag Registers, Offsets `0x30`–`0x3C`)
- **Encrypt Mode:** Read-Only after `DONE == 1`. Holds the 128-bit computed authentication tag.
- **Decrypt Mode:** Write before asserting `START`. Holds the expected authentication tag against which the decrypted tag is compared in constant time.

### 2.8 `DIGEST[0..7]` (Hash Digest Registers, Offsets `0x40`–`0x5C`)
- **Access:** Read-Only. Holds the 256-bit Ascon-Hash256 digest output after `DONE == 1`.
  - `DIGEST_0` = $H[31:0]$ (Bytes 0..3)
  - `DIGEST_1` = $H[63:32]$ (Bytes 4..7)
  - ...
  - `DIGEST_7` = $H[255:224]$ (Bytes 28..31)

### 2.9 `DMA_SRC_ADDR` (Offset `0x60`) & `DMA_LEN` (Offset `0x64`)
- `DMA_SRC_ADDR`: 32-bit byte address in BRAM memory space where firmware/payload begins.
- `DMA_LEN`: 32-bit total byte count to be transferred by DMA.

### 2.10 `DMA_CTRL` (Offset `0x68`) & `DMA_STATUS` (Offset `0x6C`)
- `DMA_CTRL[0]` (`DMA_START`): Write `1` to start DMA streaming into Ascon core.
- `DMA_CTRL[1]` (`DMA_ABORT`): Write `1` to abort active transfer.
- `DMA_STATUS[0]` (`DMA_BUSY`): `1` while DMA master is fetching words from BRAM.
- `DMA_STATUS[1]` (`DMA_DONE`): `1` upon completed byte transfer.
- `DMA_STATUS[2]` (`DMA_ERR`): `1` if illegal address was targeted.

### 2.11 `CORE_ID` (Hardware Identification, Offset `0x7C`)
- Read returns `0x4153_4331` (ASCII `"ASC1"` for Ascon revision 1).
