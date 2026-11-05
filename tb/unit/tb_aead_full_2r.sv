`timescale 1ns / 1ps
module tb_aead_full_2r;
    tb_aead_full #(
        .PERM_VARIANT (2),
        .SBOX_TYPE    ("BASELINE"),
        .LOG_FILE     ("results/kat/rtl_aead_full_2r_pass.log")
    ) u_tb ();
endmodule

