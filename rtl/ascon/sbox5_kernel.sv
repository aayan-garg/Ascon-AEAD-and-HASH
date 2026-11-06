// ==============================================================================
// Module: sbox5_kernel.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Generator: tools/sbox_opt/kernel_extractor.py
// Method: Brayton-McMullen Recursive Algebraic Kernel/Co-Kernel Factorization
// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6 across all 32 inputs.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module sbox5_kernel (
    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4}
    output wire [4:0] out_y  // {y0, y1, y2, y3, y4}
);

    wire x0 = in_x[4];
    wire x1 = in_x[3];
    wire x2 = in_x[2];
    wire x3 = in_x[1];
    wire x4 = in_x[0];

    // Extracted common algebraic kernels (shared multi-level sub-expressions):
    wire k0 = (~x1 & ~x2) | (x1 & x2);
    wire k1 = (~x1 & x2) | (x1 & ~x2);
    wire k2 = (~x1 & x2) | (x1 & ~x3) | (~x2 & x3);
    wire k3 = (~x1 & ~x2 & ~x3) | (x1 & x2 & x3);
    wire k4 = (~x0 & ~x3) | (x0 & x3);
    wire k5 = (~x0 & x3) | (x0 & ~x3);

    // Factorized outputs:
    wire y0 = (~x1 & x2 & k4) |
              (~x1 & ~x2 & k5) |
              (x1 & ~x3 & ~x4) |
              (x1 & x3 & x4);

    wire y1 = (~x0 & ~x4 & k2) |
              (x0 & x4 & k2) |
              (~x0 & x4 & k3) |
              (x0 & ~x4 & k3);

    wire y2 = (x3 & k0) |
              (~x4 & k0) |
              (~x3 & x4 & k1);

    wire y3 = (x0 & k0) |
              (~x3 & x4 & k0) |
              (x3 & ~x4 & k0) |
              (~x0 & ~x3 & ~x4 & k1) |
              (~x0 & x3 & x4 & k1);

    wire y4 = (x1 & k4) |
              (~x1 & ~x3 & x4) |
              (~x1 & x3 & ~x4);

    assign out_y = {y0, y1, y2, y3, y4};

endmodule
