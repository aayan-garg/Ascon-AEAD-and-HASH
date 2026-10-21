/* Minimal GPIO Toggle Test for PicoRV32 Bringup */
/* Address Map: GPIO Register at 0x1000_0000 */

#include <stdint.h>

#define REG_GPIO (*(volatile uint32_t *)0x10000000)

static void delay(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void) {
    // 1. Initial pattern: LED 0
    REG_GPIO = 0x00000001;
    delay(5);

    // 2. Walking 1s across LEDs 0..3
    REG_GPIO = 0x00000002;
    delay(5);

    REG_GPIO = 0x00000004;
    delay(5);

    REG_GPIO = 0x00000008;
    delay(5);

    // 3. All LEDs ON
    REG_GPIO = 0x0000000F;
    delay(5);

    // 4. Memory read-modify-write test to verify RAM and bus access
    volatile uint32_t scratch[4];
    scratch[0] = 0xAA55AA55;
    scratch[1] = 0x12345678;
    if (scratch[0] == 0xAA55AA55 && scratch[1] == 0x12345678) {
        // RAM readback verified: write pass marker (bit 31 set + LEDs active)
        REG_GPIO = 0x8000000F;
    } else {
        // Memory verification failed
        REG_GPIO = 0xDEADBEEF;
    }

    // Loop indefinitely
    while (1) {
        delay(10);
    }

    return 0;
}
