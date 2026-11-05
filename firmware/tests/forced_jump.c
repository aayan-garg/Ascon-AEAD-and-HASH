// ==============================================================================
// Negative Test Firmware: forced_jump.c
// Requirement: B1 Fetch-guard negative test
// Target: PicoRV32 Boot ROM region (0x0000_0000)
// Purpose: Attempts unauthorized execution of candidate payload without
//          running hardware boot_ctrl verification.
// ==============================================================================

#include <stdint.h>

#define CANDIDATE_ENTRY 0x00001040U

void main(void) {
    // Malicious or corrupted code attempting to bypass boot controller FSM
    // and execute candidate application payload directly.
    void (*untrusted_app)(void) = (void (*)(void))CANDIDATE_ENTRY;
    untrusted_app();

    // Dead loop if it ever returns
    while (1) {
        __asm__ volatile ("nop");
    }
}

