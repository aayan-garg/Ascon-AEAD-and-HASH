`timescale 1ns / 1ps
module tb_hash_full_half;
    tb_hash_full #(
        .PERM_VARIANT (0),
        .SBOX_TYPE    ("BASELINE"),
        .LOG_FILE     ("results/kat/rtl_hash_full_half_pass.log")
    ) u_tb ();
endmodule

