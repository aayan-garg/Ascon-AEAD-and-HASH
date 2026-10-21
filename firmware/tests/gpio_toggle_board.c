/* ==============================================================================
 * Zybo Z7-10 Physical Hardware Bring-Up Firmware
 * Human-visible walking 1s and RGB LED status indicator
 * ============================================================================== */

#include <stdint.h>

#define REG_GPIO (*(volatile uint32_t *)0x10000000)

// Busy-wait delay: at 100 MHz, ~2.5 million loop iterations is approx 0.25 seconds
static void delay(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void) {
    volatile uint32_t scratch[4];
    scratch[0] = 0xAA55AA55;
    scratch[1] = 0x12345678;
    int ram_ok = (scratch[0] == 0xAA55AA55 && scratch[1] == 0x12345678);

    // RGB LED: Bit 4=R, 5=G, 6=B
    // If RAM OK, turn on GREEN (0x20). If RAM fail, turn on RED (0x10).
    uint32_t rgb_status = ram_ok ? (1 << 5) : (1 << 4);

    while (1) {
        // Walking 1s across LD0..LD3 with human-visible delay
        REG_GPIO = (1 << 0) | rgb_status; // LD0
        delay(2500000);

        REG_GPIO = (1 << 1) | rgb_status; // LD1
        delay(2500000);

        REG_GPIO = (1 << 2) | rgb_status; // LD2
        delay(2500000);

        REG_GPIO = (1 << 3) | rgb_status; // LD3
        delay(2500000);

        // Flash all 4 LEDs together twice
        REG_GPIO = 0x0F | rgb_status;
        delay(2500000);

        REG_GPIO = 0x00 | rgb_status;
        delay(2500000);

        REG_GPIO = 0x0F | rgb_status;
        delay(2500000);

        REG_GPIO = 0x00 | rgb_status;
        delay(2500000);
    }

    return 0;
}
