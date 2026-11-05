`timescale 1ns / 1ps
module tb_hash_full_2r;
    tb_hash_full #(
        .PERM_VARIANT (2),
        .SBOX_TYPE    ("BASELINE"),
        .LOG_FILE     ("results/kat/rtl_hash_full_2r_pass.log")
    ) u_tb ();
endmodule

