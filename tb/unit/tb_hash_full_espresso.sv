`timescale 1ns / 1ps
module tb_hash_full_espresso;
    tb_hash_full #(
        .PERM_VARIANT (1),
        .SBOX_TYPE    ("ESPRESSO"),
        .LOG_FILE     ("results/kat/rtl_hash_full_espresso_pass.log")
    ) u_tb ();
endmodule

