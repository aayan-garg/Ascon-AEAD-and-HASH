// ==============================================================================
// Firmware Test: accel_hash_test.c
// Target: Phase 6 Accelerator Bus Integration (AXI4-Lite)
// Description: Bare-metal C test running on PicoRV32 RISC-V core:
//   1. Reads Ascon CORE_ID at 0x4000_007C and validates "ASC1"
//   2. Launches Ascon-Hash256 (0-byte message) via AXI4-Lite
//   3. Polls STATUS register until DONE == 1
//   4. Reads 256-bit Digest (DIGEST_0..7) and verifies NIST SP 800-232 KAT Count 1
//   5. Launches Ascon-AEAD128 (Count 1) encryption via AXI4-Lite
//   6. Verifies 128-bit Authentication Tag matches NIST KAT Count 1
//   7. Asserts bit 31 on GPIO register (0x1000_0000) indicating test pass
// ==============================================================================

#include <stdint.h>

#define GPIO_REG_ADDR      ((volatile uint32_t*)0x10000000)

// Ascon Accelerator Memory-Mapped Registers (docs/register_map.md)
#define ASCON_CTRL         ((volatile uint32_t*)0x40000000)
#define ASCON_STATUS       ((volatile uint32_t*)0x40000004)
#define ASCON_AD_LEN       ((volatile uint32_t*)0x40000008)
#define ASCON_MSG_LEN      ((volatile uint32_t*)0x4000000C)
#define ASCON_KEY_0        ((volatile uint32_t*)0x40000010)
#define ASCON_KEY_1        ((volatile uint32_t*)0x40000014)
#define ASCON_KEY_2        ((volatile uint32_t*)0x40000018)
#define ASCON_KEY_3        ((volatile uint32_t*)0x4000001C)
#define ASCON_NONCE_0      ((volatile uint32_t*)0x40000020)
#define ASCON_NONCE_1      ((volatile uint32_t*)0x40000024)
#define ASCON_NONCE_2      ((volatile uint32_t*)0x40000028)
#define ASCON_NONCE_3      ((volatile uint32_t*)0x4000002C)
#define ASCON_TAG_0        ((volatile uint32_t*)0x40000030)
#define ASCON_TAG_1        ((volatile uint32_t*)0x40000034)
#define ASCON_TAG_2        ((volatile uint32_t*)0x40000038)
#define ASCON_TAG_3        ((volatile uint32_t*)0x4000003C)
#define ASCON_DIGEST_0     ((volatile uint32_t*)0x40000040)
#define ASCON_CORE_ID      ((volatile uint32_t*)0x4000007C)

// Expected NIST SP 800-232 Values
#define EXPECTED_CORE_ID   0x41534331 // "ASC1"

static const uint32_t EXPECTED_HASH_COUNT1[8] = {
    0x85e53b0b, // DIGEST_0
    0x986b2f0f, // DIGEST_1
    0x8f9ff2ca, // DIGEST_2
    0x649ba8de, // DIGEST_3
    0xaa70faa1, // DIGEST_4
    0x838f9b24, // DIGEST_5
    0xaa3bd59b, // DIGEST_6
    0xb2924d30  // DIGEST_7
};

static const uint32_t EXPECTED_AEAD_TAG_COUNT1[4] = {
    0x82279c4f, // TAG_0
    0x31c9be11, // TAG_1
    0x468ff66b, // TAG_2
    0xc62e8bee  // TAG_3
};

int main(void) {
    // Turn on yellow LED to show boot started
    *GPIO_REG_ADDR = 0x01;

    // 1. Check CORE_ID
    if (*ASCON_CORE_ID != EXPECTED_CORE_ID) {
        *GPIO_REG_ADDR = 0x04; // Error pattern
        while (1);
    }

    // -------------------------------------------------------------------------
    // 2. Run Ascon-Hash256 (0-byte message)
    // -------------------------------------------------------------------------
    *ASCON_MSG_LEN = 0;
    // CTRL: MODE=1 (Hash), START=1 -> 0x03
    *ASCON_CTRL = 0x00000003;

    // Poll STATUS until DONE (bit 1) == 1
    while (!((*ASCON_STATUS) & 0x00000002)) {
        // Spin
    }

    // Verify 256-bit Digest
    volatile uint32_t* digest_regs = ASCON_DIGEST_0;
    for (int i = 0; i < 8; i++) {
        if (digest_regs[i] != EXPECTED_HASH_COUNT1[i]) {
            *GPIO_REG_ADDR = 0x02; // Hash mismatch error
            while (1);
        }
    }

    // Clear DONE via W1C
    *ASCON_STATUS = 0x00000002;

    // -------------------------------------------------------------------------
    // 3. Run Ascon-AEAD128 Encryption (Count 1)
    // -------------------------------------------------------------------------
    *ASCON_KEY_0   = 0x03020100;
    *ASCON_KEY_1   = 0x07060504;
    *ASCON_KEY_2   = 0x0B0A0908;
    *ASCON_KEY_3   = 0x0F0E0D0C;
    *ASCON_NONCE_0 = 0x13121110;
    *ASCON_NONCE_1 = 0x17161514;
    *ASCON_NONCE_2 = 0x1B1A1918;
    *ASCON_NONCE_3 = 0x1F1E1D1C;
    *ASCON_AD_LEN  = 0;
    *ASCON_MSG_LEN = 0;

    // CTRL: MODE=0 (AEAD), DEC=0, START=1 -> 0x01
    *ASCON_CTRL = 0x00000001;

    // Poll STATUS until DONE == 1
    while (!((*ASCON_STATUS) & 0x00000002)) {
        // Spin
    }

    // Verify 128-bit Authentication Tag
    volatile uint32_t* tag_regs = ASCON_TAG_0;
    for (int i = 0; i < 4; i++) {
        if (tag_regs[i] != EXPECTED_AEAD_TAG_COUNT1[i]) {
            *GPIO_REG_ADDR = 0x03; // AEAD mismatch error
            while (1);
        }
    }

    // All tests passed! Assert bit 31 (test_pass) and all 4 LEDs on
    *GPIO_REG_ADDR = 0x8000000F;

    while (1) {
        // Success loop
    }

    return 0;
}
