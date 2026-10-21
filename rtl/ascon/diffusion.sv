// ==============================================================================
// Module: diffusion.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Linear Diffusion Layer (p_L) for 320-bit Ascon state.
// Applies linear transformation functions Sigma_0..Sigma_4 to 64-bit words x0..x4.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module diffusion (
    input  wire [63:0] in_x0,
    input  wire [63:0] in_x1,
    input  wire [63:0] in_x2,
    input  wire [63:0] in_x3,
    input  wire [63:0] in_x4,
    output wire [63:0] out_x0,
    output wire [63:0] out_x1,
    output wire [63:0] out_x2,
    output wire [63:0] out_x3,
    output wire [63:0] out_x4
);

    // Circular right rotation helper functions (64-bit)
    function automatic [63:0] rotr(input [63:0] w, input int r);
        rotr = (w >> r) | (w << (64 - r));
    endfunction

    // Sigma_0(x0) = x0 ^ (x0 >>> 19) ^ (x0 >>> 28)
    assign out_x0 = in_x0 ^ rotr(in_x0, 19) ^ rotr(in_x0, 28);

    // Sigma_1(x1) = x1 ^ (x1 >>> 61) ^ (x1 >>> 39)
    assign out_x1 = in_x1 ^ rotr(in_x1, 61) ^ rotr(in_x1, 39);

    // Sigma_2(x2) = x2 ^ (x2 >>> 1) ^ (x2 >>> 6)
    assign out_x2 = in_x2 ^ rotr(in_x2, 1) ^ rotr(in_x2, 6);

    // Sigma_3(x3) = x3 ^ (x3 >>> 10) ^ (x3 >>> 17)
    assign out_x3 = in_x3 ^ rotr(in_x3, 10) ^ rotr(in_x3, 17);

    // Sigma_4(x4) = x4 ^ (x4 >>> 7) ^ (x4 >>> 41)
    assign out_x4 = in_x4 ^ rotr(in_x4, 7) ^ rotr(in_x4, 41);

endmodule
