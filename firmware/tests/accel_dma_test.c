// ==============================================================================
// Firmware Test: accel_dma_test.c
// Target: Phase 7 Custom Streaming DMA Integration
// Description: Bare-metal C test running on PicoRV32 RISC-V core:
//   1. Prepares 64-byte payload (0x00..0x3F) in BRAM buffer
//   2. Configures Ascon DMA registers (DMA_SRC_ADDR, DMA_LEN) over AXI4-Lite
//   3. Configures Ascon message length (MSG_LEN = 64)
//   4. Triggers Ascon-Hash256 with DMA_AUTO=1 and START=1
//   5. Polls DMA_STATUS until DMA_DONE == 1, verifying DMA_ERR == 0
//   6. Polls ASCON_STATUS until ASCON_DONE == 1
//   7. Reads 256-bit Digest (DIGEST_0..7) and verifies against Python golden model
//   8. Asserts bit 31 on GPIO register (0x1000_0000) indicating test pass
// ==============================================================================

#include <stdint.h>

#define GPIO_REG_ADDR      ((volatile uint32_t*)0x10000000)

// Ascon Accelerator Memory-Mapped Registers (docs/register_map.md)
#define ASCON_CTRL         ((volatile uint32_t*)0x40000000)
#define ASCON_STATUS       ((volatile uint32_t*)0x40000004)
#define ASCON_AD_LEN       ((volatile uint32_t*)0x40000008)
#define ASCON_MSG_LEN      ((volatile uint32_t*)0x4000000C)
#define ASCON_DIGEST_0     ((volatile uint32_t*)0x40000040)
#define ASCON_DMA_SRC_ADDR ((volatile uint32_t*)0x40000060)
#define ASCON_DMA_LEN      ((volatile uint32_t*)0x40000064)
#define ASCON_DMA_CTRL     ((volatile uint32_t*)0x40000068)
#define ASCON_DMA_STATUS   ((volatile uint32_t*)0x4000006C)
#define ASCON_CORE_ID      ((volatile uint32_t*)0x4000007C)

#define EXPECTED_CORE_ID   0x41534331 // "ASC1"

// 64-byte NIST SP 800-232 / Python golden model expected digest
// Message: bytes 0x00, 0x01, 0x02, ..., 0x3F (64 bytes)
static const uint32_t EXPECTED_DMA_HASH[8] = {
    0xbe41f2a6, // DIGEST_0
    0x0564d1a5, // DIGEST_1
    0x01062c81, // DIGEST_2
    0xd6729f9d, // DIGEST_3
    0x7cbd3201, // DIGEST_4
    0x54609c08, // DIGEST_5
    0xbb562e9b, // DIGEST_6
    0x484fc601  // DIGEST_7
};

// 64-byte aligned payload buffer in BRAM (16 words)
static volatile uint32_t payload_buffer[16] __attribute__((aligned(8)));

int main(void) {
    // LED 0: Firmware boot started
    *GPIO_REG_ADDR = 0x01;

    // 1. Verify Core ID
    if (*ASCON_CORE_ID != EXPECTED_CORE_ID) {
        *GPIO_REG_ADDR = 0x04; // Hardware ID error
        while (1);
    }

    // 2. Initialize 64-byte payload: 0x00, 0x01, ..., 0x3F
    for (int i = 0; i < 16; i++) {
        uint32_t b0 = (uint32_t)(i * 4 + 0);
        uint32_t b1 = (uint32_t)(i * 4 + 1);
        uint32_t b2 = (uint32_t)(i * 4 + 2);
        uint32_t b3 = (uint32_t)(i * 4 + 3);
        payload_buffer[i] = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
    }

    // 3. Configure DMA and Ascon parameters
    *ASCON_AD_LEN       = 0;
    *ASCON_MSG_LEN      = 64;
    *ASCON_DMA_SRC_ADDR = (uint32_t)payload_buffer;
    *ASCON_DMA_LEN      = 64;

    // 4. Trigger Ascon-Hash256 with DMA_AUTO=1, MODE=1, START=1
    // Bit 0 = START, Bit 1 = MODE (1=Hash), Bit 4 = DMA_AUTO
    *ASCON_CTRL = 0x00000013;

    // 5. Poll DMA_STATUS until DMA_DONE (bit 1) == 1
    while (!((*ASCON_DMA_STATUS) & 0x00000002)) {
        if ((*ASCON_DMA_STATUS) & 0x00000004) {
            *GPIO_REG_ADDR = 0x05; // DMA error
            while (1);
        }
    }

    // 6. Poll ASCON_STATUS until ASCON_DONE (bit 1) == 1
    while (!((*ASCON_STATUS) & 0x00000002)) {
        if ((*ASCON_STATUS) & 0x00000004) {
            *GPIO_REG_ADDR = 0x06; // Ascon controller error
            while (1);
        }
    }

    // 7. Verify 256-bit Digest against Golden Model
    volatile uint32_t* digest_regs = ASCON_DIGEST_0;
    for (int i = 0; i < 8; i++) {
        if (digest_regs[i] != EXPECTED_DMA_HASH[i]) {
            *GPIO_REG_ADDR = 0x02; // Hash digest mismatch
            while (1);
        }
    }

    // 8. All checks passed! Assert bit 31 (test_pass) and all 4 discrete LEDs
    *GPIO_REG_ADDR = 0x8000000F;

    while (1) {
        // Success loop
    }

    return 0;
}
