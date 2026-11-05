// ==============================================================================
// Testbench: tb_aead_full_serial32.sv
// Target: Task T1.c AEAD KAT verification for PERM_VARIANT=3 (serial32)
// ==============================================================================

`timescale 1ns / 1ps

module tb_aead_full_serial32;

    tb_aead_full #(
        .PERM_VARIANT (3),
        .SBOX_TYPE    ("BASELINE"),
        .LOG_FILE     ("results/kat/rtl_aead_full_serial32_pass.log")
    ) u_tb ();

endmodule

