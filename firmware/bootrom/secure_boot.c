// ==============================================================================
// Boot ROM Secure Boot Verification Firmware: secure_boot.c
// Requirement: [SPEC] R14, R17, Initial Research §12, §13
// Target: PicoRV32 RV32I Processor executing from 0x0000_0000
// ==============================================================================

#include <stdint.h>
#include "trusted_manifest.h"

// -----------------------------------------------------------------------------
// Memory Map Offsets
// -----------------------------------------------------------------------------
#define GPIO_BASE           0x10000000U
#define ASCON_BASE          0x40000000U
#define CANDIDATE_HDR_ADDR  0x00001000U
#define CANDIDATE_PAYLOAD   0x00001040U

#define REG32(addr) (*(volatile uint32_t *)(addr))

// Ascon Accelerator Register Offsets
#define ASCON_CTRL          (ASCON_BASE + 0x00U)
#define ASCON_STATUS        (ASCON_BASE + 0x04U)
#define ASCON_MSG_LEN       (ASCON_BASE + 0x0CU)
#define ASCON_DIGEST_BASE   (ASCON_BASE + 0x40U)
#define DMA_SRC_ADDR        (ASCON_BASE + 0x60U)
#define DMA_LEN             (ASCON_BASE + 0x64U)
#define DMA_CTRL            (ASCON_BASE + 0x68U)
#define DMA_STATUS          (ASCON_BASE + 0x6CU)
#define BOOT_CTRL           (ASCON_BASE + 0x80U)
#define BOOT_STATUS         (ASCON_BASE + 0x84U)

// Boot Status Flags
#define BOOT_STAT_BUSY      (1U << 0)
#define BOOT_STAT_JUMP_EN   (1U << 1)
#define BOOT_STAT_REFUSE    (1U << 2)
#define BOOT_STAT_HASH_OK   (1U << 3)
#define BOOT_STAT_TAMPER    (1U << 4)

// -----------------------------------------------------------------------------
// Firmware Header Structure (§12.4, 64 Bytes)
// -----------------------------------------------------------------------------
typedef struct {
    uint32_t magic;              // Offset 0x00: ASCII "ASCN" (0x4153434E)
    uint32_t version;            // Offset 0x04: Format version
    uint32_t payload_len;        // Offset 0x08: Length of application payload in bytes
    uint32_t entry_point;        // Offset 0x0C: Execution vector (0x00001040)
    uint32_t reserved[4];        // Offset 0x10..0x1F: Reserved padding
    uint32_t expected_digest[8]; // Offset 0x20..0x3F: 256-bit Ascon-Hash256 reference
} fw_header_t;

// -----------------------------------------------------------------------------
// Failure Lockout: Deterministic Refusal State (§12.5)
// -----------------------------------------------------------------------------
void refusal_lockout(uint32_t reason_code) {
    // Assert hardware refusal / tamper lockout in boot_ctrl FSM
    REG32(BOOT_CTRL) = 0x02U;

    // Drive refusal LED pattern: 4'b1010 (0xA) on discrete LEDs
    // Bit 31 (test_pass) remains 0 to mark refusal
    REG32(GPIO_BASE) = 0x0000000AU | (reason_code << 16);

    // Infinite dead-loop preventing speculative execution or jump into untrusted code
    while (1) {
        __asm__ volatile ("nop");
    }
}

// -----------------------------------------------------------------------------
// Constant-Time Digest Comparison
// -----------------------------------------------------------------------------
static inline int constant_time_compare_digest(const volatile uint32_t *a, const uint32_t *b) {
    uint32_t diff = 0;
    for (int i = 0; i < 8; i++) {
        diff |= (a[i] ^ b[i]);
    }
    return (diff == 0);
}

// -----------------------------------------------------------------------------
// Secure Boot Main Routine
// -----------------------------------------------------------------------------
int main(void) {
    // 1. Initial diagnostic: signal boot verification starting (LED = 0x1)
    REG32(GPIO_BASE) = 0x00000001U;

    const volatile fw_header_t *header = (const volatile fw_header_t *)CANDIDATE_HDR_ADDR;

    // 2. Validate Candidate Header Magic
    if (header->magic != TRUSTED_MAGIC) {
        refusal_lockout(1); // Error 1: Bad Magic
    }

    // 3. Validate Header Version
    if (header->version != TRUSTED_VERSION) {
        refusal_lockout(2); // Error 2: Bad Version
    }

    // 4. Validate Declared Payload Length
    if (header->payload_len != TRUSTED_PAYLOAD_LEN || header->payload_len == 0 || header->payload_len > 8192) {
        refusal_lockout(3); // Error 3: Bad Payload Length
    }

    // 5. Validate Entry Point
    if (header->entry_point != TRUSTED_ENTRY_POINT) {
        refusal_lockout(4); // Error 4: Bad Entry Point
    }

    // 5b. Validate Candidate Expected Digest against Trusted Reference Digest (§12.5 Case 3)
    if (!constant_time_compare_digest(header->expected_digest, TRUSTED_DIGEST)) {
        refusal_lockout(10); // Error 10: Wrong Reference Digest in Manifest
    }

    // 6. Start Hardware Secure Boot Controller FSM
    REG32(BOOT_CTRL) = 0x01U; // Pulse START

    // 7. Configure Ascon Coprocessor for Hash-256
    REG32(ASCON_STATUS)  = 0x06U; // W1C clear DONE and ERROR
    REG32(ASCON_MSG_LEN) = header->payload_len;
    REG32(ASCON_CTRL)    = 0x03U; // START=1, MODE=1 (Hash)

    // 8. Launch Streaming DMA from BRAM Port B into Ascon Absorbing Port
    REG32(DMA_SRC_ADDR) = CANDIDATE_PAYLOAD;
    REG32(DMA_LEN)      = header->payload_len;
    REG32(DMA_CTRL)     = 0x01U; // START

    // 9. Poll DMA Engine with Timeout Protection
    uint32_t timeout = 1000U;
    while (!(REG32(DMA_STATUS) & (1U << 1))) { // Wait for dma_done
        if (REG32(DMA_STATUS) & (1U << 2)) {
            refusal_lockout(5); // Error 5: DMA Engine Error
        }
        if (--timeout == 0) {
            refusal_lockout(6); // Error 6: DMA Timeout
        }
    }

    // 10. Poll Ascon Coprocessor for Completion
    timeout = 1000U;
    while (!(REG32(ASCON_STATUS) & (1U << 1))) { // Wait for done
        if (REG32(ASCON_STATUS) & (1U << 2)) {
            refusal_lockout(7); // Error 7: Accelerator Processing Error
        }
        if (--timeout == 0) {
            refusal_lockout(8); // Error 8: Accelerator Timeout
        }
    }

    // 11. Dual Verification: Software Constant-Time Comparison
    volatile uint32_t *computed_digest = (volatile uint32_t *)ASCON_DIGEST_BASE;
    int sw_match = constant_time_compare_digest(computed_digest, TRUSTED_DIGEST);

    // 12. Hardware Authorization Request
    REG32(BOOT_CTRL) = 0x04U; // Request hardware jump permission (REQ_JUMP)

    // Sample hardware boot status
    uint32_t boot_stat = REG32(BOOT_STATUS);
    int hw_authorized = (boot_stat & BOOT_STAT_JUMP_EN) && 
                        (boot_stat & BOOT_STAT_HASH_OK) && 
                       !(boot_stat & BOOT_STAT_REFUSE);

    // 13. Irrevocable Jump Decision: Both SW and HW must strictly agree
    if (sw_match && hw_authorized) {
        // Verification PASSED!
        // Assert initial jump status on LEDs
        REG32(GPIO_BASE) = 0x0000000FU; // 4 discrete LEDs ON

        // Jump to verified candidate application entry point
        typedef void (*entry_fn_t)(void);
        entry_fn_t app_entry = (entry_fn_t)(header->entry_point);
        app_entry();
    } else {
        // Integrity check failed: permanent refusal lockout
        refusal_lockout(9); // Error 9: Cryptographic Hash Mismatch
    }

    return 0;
}
