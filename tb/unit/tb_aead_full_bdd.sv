`timescale 1ns / 1ps
module tb_aead_full_bdd;
    tb_aead_full #(
        .PERM_VARIANT (1),
        .SBOX_TYPE    ("BDD"),
        .LOG_FILE     ("results/kat/rtl_aead_full_bdd_pass.log")
    ) u_tb ();
endmodule

