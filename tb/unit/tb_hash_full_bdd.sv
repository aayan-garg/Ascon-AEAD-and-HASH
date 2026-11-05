`timescale 1ns / 1ps
module tb_hash_full_bdd;
    tb_hash_full #(
        .PERM_VARIANT (1),
        .SBOX_TYPE    ("BDD"),
        .LOG_FILE     ("results/kat/rtl_hash_full_bdd_pass.log")
    ) u_tb ();
endmodule

