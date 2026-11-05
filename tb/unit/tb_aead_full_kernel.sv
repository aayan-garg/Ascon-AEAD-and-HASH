`timescale 1ns / 1ps
module tb_aead_full_kernel;
    tb_aead_full #(
        .PERM_VARIANT (1),
        .SBOX_TYPE    ("KERNEL"),
        .LOG_FILE     ("results/kat/rtl_aead_full_kernel_pass.log")
    ) u_tb ();
endmodule

