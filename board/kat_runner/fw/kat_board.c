// ==============================================================================
// Bare-Metal Firmware: kat_board.c
// Target: Digilent Zybo Z7-10 Full On-Board NIST SP 800-232 KAT Verification
// Executes on PicoRV32 + Live Ascon RTL Engine (100 MHz, 128 KB BRAM):
//   - Security negative test: Tampered Tag must assert ERR, tag_ok=0, zeroize PT
//   - 1,025 Ascon-Hash256 KATs (Msg 0..1024 B): verifies 256-bit DIGEST_0..7
//   - 1,089 Ascon-AEAD128 KATs (AD 0..32 B x PT 0..32 B):
//       * Encrypt: verifies ciphertext CT (via dma_data_out capture) + 128-bit TAG_0..3
//       * Decrypt: feeds official CT + Tag, verifies tag_ok=1, ERR=0, + PT shadow gate
// ==============================================================================

#include <stdint.h>
#include "kat_vectors.h"

#define REG32(addr) (*(volatile uint32_t *)(addr))

// Status / Counter / Ciphertext Capture MMIO (0x1000_0000 - 0x1000_003F)
#define MMIO_GPIO          0x10000000U // [3:0]=LEDs, [6:4]=RGB(B,G,R), [31]=test_pass
#define MMIO_HASH_PASS     0x10000004U
#define MMIO_AEAD_ENC_PASS 0x10000008U
#define MMIO_AEAD_DEC_PASS 0x1000000CU
#define MMIO_FAIL_CNT      0x10000010U
#define MMIO_KAT_STATUS    0x10000014U // [0]=done,[1]=all_pass,[3:2]=stage,[15:4]=cur_idx,[31:16]=first_fail
#define MMIO_CYCLE_CNT     0x10000018U
#define MMIO_CT_CLR_CNT    0x1000001CU // Write clears ct_cap; Read returns beat count
#define MMIO_CT_CAP_BASE   0x10000020U // 8 x 32-bit captured ciphertext words

// Ascon Accelerator MMIO (0x4000_0000 - 0x4000_07FC)
#define ASCON_CTRL         0x40000000U
#define ASCON_STATUS       0x40000004U
#define ASCON_AD_LEN       0x40000008U
#define ASCON_MSG_LEN      0x4000000CU
#define ASCON_KEY_BASE     0x40000010U
#define ASCON_NONCE_BASE   0x40000020U
#define ASCON_TAG_BASE     0x40000030U
#define ASCON_DIGEST_BASE  0x40000040U
#define ASCON_DMA_SRC_ADDR 0x40000060U
#define ASCON_DMA_LEN      0x40000064U
#define ASCON_DMA_CTRL     0x40000068U
#define ASCON_DMA_STATUS   0x4000006CU
#define ASCON_CORE_ID      0x4000007CU
#define ASCON_PT_WIN_BASE  0x40000400U

#define EXPECTED_CORE_ID   0x41534331U // "ASC1"
#define DMA_BUF_ADDR       0x00001000U

// Fixed 1 KB DMA scratch buffer located strictly < 0x4000
static volatile uint32_t dma_scratch_words[256] __attribute__((section(".dma_buf"), aligned(8)));
static volatile uint8_t * const dma_scratch_bytes = (volatile uint8_t *)dma_scratch_words;

static uint32_t g_hash_pass = 0;
static uint32_t g_enc_pass  = 0;
static uint32_t g_dec_pass  = 0;
static uint32_t g_fail_cnt  = 0;
static uint32_t g_first_fail = 0;

static inline uint32_t read_cycles(void) {
    uint32_t c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}

static inline void record_fail(uint32_t stage, uint32_t idx) {
    if (g_fail_cnt == 0U) {
        g_first_fail = ((stage & 0xFU) << 12) | (idx & 0xFFFU);
    }
    g_fail_cnt++;
    REG32(MMIO_FAIL_CNT) = g_fail_cnt;
}

static inline void update_status(uint32_t done, uint32_t all_pass, uint32_t stage, uint32_t idx) {
    uint32_t val = (done & 1U)
                 | ((all_pass & 1U) << 1)
                 | ((stage & 3U) << 2)
                 | ((idx & 0xFFFU) << 4)
                 | ((g_first_fail & 0xFFFFU) << 16);
    REG32(MMIO_KAT_STATUS) = val;
}

static int wait_ascon_done(uint32_t check_dma, int expect_err) {
    uint32_t timeout = 200000U;
    if (check_dma) {
        while (!(REG32(ASCON_DMA_STATUS) & 0x2U)) {
            if (REG32(ASCON_DMA_STATUS) & 0x4U) return 0;
            if (--timeout == 0U) return 0;
        }
    }
    timeout = 200000U;
    while (!(REG32(ASCON_STATUS) & 0x2U)) {
        if (--timeout == 0U) return 0;
    }
    uint32_t err_bit = (REG32(ASCON_STATUS) >> 2) & 1U;
    if ((int)err_bit != expect_err) return 0;
    return 1;
}

static void load_key_nonce(void) {
    // Deterministic NIST LWC KAT Key = 00..0F, Nonce = 10..1F
    REG32(ASCON_KEY_BASE + 0x0U)   = 0x03020100U;
    REG32(ASCON_KEY_BASE + 0x4U)   = 0x07060504U;
    REG32(ASCON_KEY_BASE + 0x8U)   = 0x0B0A0908U;
    REG32(ASCON_KEY_BASE + 0xCU)   = 0x0F0E0D0CU;
    REG32(ASCON_NONCE_BASE + 0x0U) = 0x13121110U;
    REG32(ASCON_NONCE_BASE + 0x4U) = 0x17161514U;
    REG32(ASCON_NONCE_BASE + 0x8U) = 0x1B1A1918U;
    REG32(ASCON_NONCE_BASE + 0xCU) = 0x1F1E1D1CU;
}

static inline uint32_t read_u32_le(const uint8_t *p) {
    return ((uint32_t)p[0])
         | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16)
         | ((uint32_t)p[3] << 24);
}

static int run_tamper_gate_negative_test(void) {
    // Use AEAD KAT with AD=0, PT=16B (idx = 16*33 = 528), flip 1 bit of Expected Tag
    const uint32_t idx = 528U;
    if (idx >= NUM_AEAD_KATS) return 1;

    uint32_t pt_len = AEAD_META[idx].pt_len;
    const uint8_t *exp_ct_tag = &AEAD_EXP_BLOB[AEAD_META[idx].offset];

    // Put valid 16B ciphertext into DMA buffer
    for (uint32_t i = 0; i < 16U; i++) {
        dma_scratch_bytes[i] = exp_ct_tag[i];
    }

    load_key_nonce();
    REG32(ASCON_AD_LEN)       = 0U;
    REG32(ASCON_MSG_LEN)      = pt_len;
    REG32(ASCON_TAG_BASE+0x0U) = read_u32_le(&exp_ct_tag[pt_len + 0U]) ^ 0x00000001U; // Flip 1 bit
    REG32(ASCON_TAG_BASE+0x4U) = read_u32_le(&exp_ct_tag[pt_len + 4U]);
    REG32(ASCON_TAG_BASE+0x8U) = read_u32_le(&exp_ct_tag[pt_len + 8U]);
    REG32(ASCON_TAG_BASE+0xCU) = read_u32_le(&exp_ct_tag[pt_len + 12U]);
    REG32(ASCON_DMA_SRC_ADDR)  = DMA_BUF_ADDR;
    REG32(ASCON_DMA_LEN)       = pt_len;
    REG32(ASCON_STATUS)        = 0x6U;
    // CTRL: MODE=0 (AEAD), DEC=1 (Decrypt), START=1, DMA_AUTO=1 -> 0x15
    REG32(ASCON_CTRL)          = 0x15U;

    if (!wait_ascon_done(1U, 1)) return 0; // Must assert error=1
    if (REG32(ASCON_STATUS) & (1U << 3)) return 0; // tag_ok MUST be 0

    // Plaintext release gate MUST return strictly 0 on every word
    for (uint32_t w = 0; w < 4U; w++) {
        if (REG32(ASCON_PT_WIN_BASE + (w << 2)) != 0U) return 0;
    }
    REG32(ASCON_STATUS) = 0x6U;
    return 1;
}

static void run_hash_kats(void) {
    // Fill 1024-byte deterministic pattern once: 0x00, 0x01, ..., 0xFF repeating
    for (uint32_t i = 0; i < 256U; i++) {
        uint32_t b0 = (i << 2) & 0xFFU;
        dma_scratch_words[i] = b0 | ((b0 + 1U) << 8) | ((b0 + 2U) << 16) | ((b0 + 3U) << 24);
    }

    REG32(ASCON_AD_LEN) = 0U;
    REG32(ASCON_DMA_SRC_ADDR) = DMA_BUF_ADDR;

    for (uint32_t len = 0U; len < NUM_HASH_KATS; len++) {
        update_status(0U, 0U, 2U, len);
        // Blink discrete LEDs softly during long runs (LD6 stays BLUE=0x40)
        REG32(MMIO_GPIO) = 0x40U | (1U << ((len >> 6) & 3U));

        REG32(ASCON_STATUS)  = 0x6U;
        REG32(ASCON_MSG_LEN) = len;
        if (len > 0U) {
            REG32(ASCON_DMA_LEN) = len;
            REG32(ASCON_CTRL)    = 0x13U; // MODE=1 (Hash), START=1, DMA_AUTO=1
            if (!wait_ascon_done(1U, 0)) {
                record_fail(2U, len);
                continue;
            }
        } else {
            REG32(ASCON_CTRL)    = 0x03U; // MODE=1 (Hash), START=1, DMA_AUTO=0
            if (!wait_ascon_done(0U, 0)) {
                record_fail(2U, len);
                continue;
            }
        }

        int ok = 1;
        for (uint32_t w = 0; w < 8U; w++) {
            if (REG32(ASCON_DIGEST_BASE + (w << 2)) != HASH_EXP_MD[len][w]) {
                ok = 0;
                break;
            }
        }
        if (ok) {
            g_hash_pass++;
            REG32(MMIO_HASH_PASS) = g_hash_pass;
        } else {
            record_fail(2U, len);
        }
    }
}

static void run_aead_kats(void) {
    load_key_nonce();
    REG32(ASCON_DMA_SRC_ADDR) = DMA_BUF_ADDR;

    for (uint32_t idx = 0U; idx < NUM_AEAD_KATS; idx++) {
        update_status(0U, 0U, 3U, idx);
        REG32(MMIO_GPIO) = 0x40U | (1U << ((idx >> 6) & 3U));

        uint32_t ad_len  = AEAD_META[idx].ad_len;
        uint32_t pt_len  = AEAD_META[idx].pt_len;
        uint32_t ad_pad  = (ad_len + 7U) & ~7U;
        uint32_t pt_pad  = (pt_len + 7U) & ~7U;
        uint32_t dma_len = ad_pad + pt_pad;
        const uint8_t *exp_ct_tag = &AEAD_EXP_BLOB[AEAD_META[idx].offset];

        // Pack 64-bit aligned AD followed by 64-bit aligned PT
        for (uint32_t i = 0; i < ad_pad; i++) {
            dma_scratch_bytes[i] = (i < ad_len) ? (uint8_t)((0x30U + i) & 0xFFU) : 0U;
        }
        for (uint32_t i = 0; i < pt_pad; i++) {
            dma_scratch_bytes[ad_pad + i] = (i < pt_len) ? (uint8_t)((0x20U + i) & 0xFFU) : 0U;
        }

        // ---- AEAD Encrypt ----
        REG32(MMIO_CT_CLR_CNT) = 0U;
        REG32(ASCON_STATUS)    = 0x6U;
        REG32(ASCON_AD_LEN)    = ad_len;
        REG32(ASCON_MSG_LEN)   = pt_len;
        if (dma_len > 0U) {
            REG32(ASCON_DMA_LEN) = dma_len;
            REG32(ASCON_CTRL)    = 0x11U; // MODE=0, DEC=0, DMA_AUTO=1, START=1
        } else {
            REG32(ASCON_CTRL)    = 0x01U;
        }

        int enc_ok = wait_ascon_done(dma_len > 0U, 0);
        if (enc_ok) {
            // Check 128-bit authentication tag
            for (uint32_t w = 0; w < 4U; w++) {
                uint32_t exp_tw = read_u32_le(&exp_ct_tag[pt_len + (w << 2)]);
                if (REG32(ASCON_TAG_BASE + (w << 2)) != exp_tw) {
                    enc_ok = 0;
                    break;
                }
            }
            // Check captured ciphertext bytes
            for (uint32_t b = 0; b < pt_len && enc_ok; b += 4U) {
                uint32_t got_w = REG32(MMIO_CT_CAP_BASE + b);
                uint32_t rem   = pt_len - b;
                uint32_t mask  = (rem >= 4U) ? 0xFFFFFFFFU : ((1U << (rem << 3)) - 1U);
                uint32_t exp_w = 0U;
                for (uint32_t k = 0; k < 4U && (b + k) < pt_len; k++) {
                    exp_w |= ((uint32_t)exp_ct_tag[b + k]) << (k << 3);
                }
                if ((got_w & mask) != exp_w) {
                    enc_ok = 0;
                }
            }
        }
        if (enc_ok) {
            g_enc_pass++;
            REG32(MMIO_AEAD_ENC_PASS) = g_enc_pass;
        } else {
            record_fail(3U, idx);
        }

        // ---- AEAD Decrypt (replace PT region with official CT + set Expected Tag) ----
        for (uint32_t i = 0; i < pt_pad; i++) {
            dma_scratch_bytes[ad_pad + i] = (i < pt_len) ? exp_ct_tag[i] : 0U;
        }
        for (uint32_t w = 0; w < 4U; w++) {
            REG32(ASCON_TAG_BASE + (w << 2)) = read_u32_le(&exp_ct_tag[pt_len + (w << 2)]);
        }

        REG32(ASCON_STATUS) = 0x6U;
        if (dma_len > 0U) {
            REG32(ASCON_DMA_LEN) = dma_len;
            REG32(ASCON_CTRL)    = 0x15U; // MODE=0, DEC=1, DMA_AUTO=1, START=1
        } else {
            REG32(ASCON_CTRL)    = 0x05U; // MODE=0, DEC=1, DMA_AUTO=0, START=1
        }

        int dec_ok = wait_ascon_done(dma_len > 0U, 0);
        if (dec_ok) {
            if (!(REG32(ASCON_STATUS) & (1U << 3))) {
                dec_ok = 0; // tag_ok bit MUST be 1
            }
            for (uint32_t b = 0; b < pt_len && dec_ok; b += 4U) {
                uint32_t got_w = REG32(ASCON_PT_WIN_BASE + b);
                uint32_t rem   = pt_len - b;
                uint32_t mask  = (rem >= 4U) ? 0xFFFFFFFFU : ((1U << (rem << 3)) - 1U);
                uint32_t exp_w = 0U;
                for (uint32_t k = 0; k < 4U && (b + k) < pt_len; k++) {
                    exp_w |= ((uint32_t)((0x20U + b + k) & 0xFFU)) << (k << 3);
                }
                if ((got_w & mask) != exp_w) {
                    dec_ok = 0;
                }
            }
        }
        if (dec_ok) {
            g_dec_pass++;
            REG32(MMIO_AEAD_DEC_PASS) = g_dec_pass;
        } else {
            record_fail(4U, idx);
        }
    }
}

int main(void) {
    uint32_t t0 = read_cycles();

    REG32(MMIO_HASH_PASS)     = 0U;
    REG32(MMIO_AEAD_ENC_PASS) = 0U;
    REG32(MMIO_AEAD_DEC_PASS) = 0U;
    REG32(MMIO_FAIL_CNT)      = 0U;
    REG32(MMIO_CYCLE_CNT)     = 0U;
    update_status(0U, 0U, 0U, 0U);
    REG32(MMIO_GPIO) = 0x41U; // Blue LD6 + LD0 during startup

    // 1. Validate Core ID
    if (REG32(ASCON_CORE_ID) != EXPECTED_CORE_ID) {
        record_fail(0U, 0U);
        REG32(MMIO_GPIO) = 0x1AU; // Red + 4'b1010
        update_status(1U, 0U, 0U, 0U);
        while (1);
    }

    // 2. Verify Tampered-Tag Plaintext Release Gate Zeroization
    update_status(0U, 0U, 1U, 0U);
    if (!run_tamper_gate_negative_test()) {
        record_fail(1U, 0U);
    }

    // 3. Execute all 1,025 NIST SP 800-232 Ascon-Hash256 KATs (0..1024 B)
    run_hash_kats();

    // 4. Execute all 1,089 NIST SP 800-232 Ascon-AEAD128 KATs (Encrypt + Decrypt)
    run_aead_kats();

    uint32_t elapsed = read_cycles() - t0;
    REG32(MMIO_CYCLE_CNT) = elapsed;

    uint32_t all_pass = (g_fail_cnt == 0U)
                     && (g_hash_pass == NUM_HASH_KATS)
                     && (g_enc_pass  == NUM_AEAD_KATS)
                     && (g_dec_pass  == NUM_AEAD_KATS);

    if (all_pass) {
        // Done + All Passed -> Green LD6 (bit 5 = 0x20), LD0..3 = 0xF, test_pass (bit 31) = 1
        REG32(MMIO_GPIO) = 0x8000002FU;
        update_status(1U, 1U, 3U, NUM_AEAD_KATS);
    } else {
        // Done + Failure -> Red LD6 (bit 4 = 0x10), LD0..3 = 0xA (4'b1010)
        REG32(MMIO_GPIO) = 0x0000001AU;
        update_status(1U, 0U, 3U, 0U);
    }

    while (1) {
        __asm__ volatile ("nop");
    }
    return 0;
}

