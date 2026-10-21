// ==============================================================================
// Candidate Application Payload: app_payload.c
// Linked at 0x0000_1040
// Executed ONLY after successful Secure Boot verification
// ==============================================================================

#include <stdint.h>

#define GPIO_BASE   0x10000000
#define REG32(addr) (*(volatile uint32_t *)(addr))

__attribute__((section(".text.init")))
void _app_start(void) {
    // Assert test_pass (bit 31) and illuminate 4 discrete LEDs (0xF)
    REG32(GPIO_BASE) = 0x8000000FU;

    // Steady operational loop
    while (1) {
        __asm__ volatile ("nop");
    }
}
