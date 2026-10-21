// ==============================================================================
// Module: sbox5.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 5-bit non-linear Ascon S-box implementation.
// Architecture: Bit-slice algebraic form using Keccak chi non-linear layer.
// Multiplicative complexity: 5 AND gates, Algebraic degree: 2.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module sbox5 (
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

    // -------------------------------------------------------------------------
    // 2. Keccak Chi Non-Linear Layer (Degree 2)
    // -------------------------------------------------------------------------
    wire t0 = s0 ^ (~s1 & s2);
    wire t1 = s1 ^ (~s2 & s3);
    wire t2 = s2 ^ (~s3 & s4);
    wire t3 = s3 ^ (~s4 & s0);
    wire t4 = s4 ^ (~s0 & s1);

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
