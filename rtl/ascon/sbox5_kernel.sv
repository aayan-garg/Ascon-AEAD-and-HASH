// ==============================================================================
// Module: sbox5_kernel.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 5-bit Ascon S-box implemented as an ANF restatement of the
// standard equations. No kernel extraction was performed.
// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module sbox5_kernel (
    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4} (x0 is MSB, x4 is LSB)
    output wire [4:0] out_y  // {y0, y1, y2, y3, y4} (y0 is MSB, y4 is LSB)
);

    wire x0 = in_x[4];
    wire x1 = in_x[3];
    wire x2 = in_x[2];
    wire x3 = in_x[1];
    wire x4 = in_x[0];

    // -------------------------------------------------------------------------
    // 1. Affine Input Transformation
    // -------------------------------------------------------------------------
    wire s0 = x0 ^ x4;
    wire s1 = x1;
    wire s2 = x2 ^ x1;
    wire s3 = x3;
    wire s4 = x4 ^ x3;

    // This is an ANF restatement, not an extracted kernel decomposition.
    wire k0 = s1 & s2;
    wire k1 = s2 & s3;
    wire k2 = s3 & s4;
    wire k3 = s4 & s0;
    wire k4 = s0 & s1;

    wire t0 = s0 ^ s2 ^ k0;
    wire t1 = s1 ^ s3 ^ k1;
    wire t2 = s2 ^ s4 ^ k2;
    wire t3 = s3 ^ s0 ^ k3;
    wire t4 = s4 ^ s1 ^ k4;

    // -------------------------------------------------------------------------
    // 3. Affine Output Transformation
    // -------------------------------------------------------------------------
    wire y0 = t0 ^ t4;
    wire y1 = t1 ^ t0;
    wire y2 = ~t2;
    wire y3 = t3 ^ t2;
    wire y4 = t4;

    assign out_y = {y0, y1, y2, y3, y4};

endmodule
