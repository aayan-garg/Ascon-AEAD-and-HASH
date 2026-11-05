// ==============================================================================
// Module: sbox5_kernel.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 5-bit Ascon S-box synthesized via Multi-Level Logic Synthesis
//              with Algebraic Kernel & Co-Kernel Extraction.
// Common Kernels:
//   - K0: (x3 ^ x4)  shared across y0, y4
//   - K1: (x0 ^ x3)  shared across y1, y4
//   - K2: (x1 ^ x2)  shared across y2, y3
//   - K3: (x1 & x2)  shared across y2, y3
//   - K4: (~x1 & ~x2) shared across y2, y3
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
    // 1. Extracted Common Kernels (Multi-Level Sub-Expressions)
    // -------------------------------------------------------------------------
    wire k_x3_xor_x4  = x3 ^ x4;
    wire k_x3_xnor_x4 = ~(x3 ^ x4);
    wire k_x0_xor_x3  = x0 ^ x3;
    wire k_x0_xnor_x3 = ~(x0 ^ x3);
    wire k_x1_xor_x2  = x1 ^ x2;
    wire k_x1_and_x2  = x1 & x2;
    wire k_nx1_and_nx2= ~x1 & ~x2;

    // -------------------------------------------------------------------------
    // 2. Factorized Output Equations
    // -------------------------------------------------------------------------
    // y4: Factorized using K0 and K1 (cuts literals from 12 down to 6)
    wire y4 = (x1 & k_x0_xnor_x3) | (~x1 & (k_x3_xor_x4 | (x4 & ~x3)));

    // y0: Factorized using K0 and co-kernel grouping
    wire y0_t0 = x1 & k_x3_xnor_x4;
    wire y0_t1 = ~x1 & ( (x0 & ~x2 & ~x3) | (x2 & ~x0 & ~x3) | (x3 & ~x0 & ~x2) | (x0 & x2 & x3) );
    wire y0 = y0_t0 | y0_t1;

    // y2: Factorized using K2, K3, K4
    wire y2 = (k_x1_and_x2 & (x3 | ~x4)) |
              (k_nx1_and_nx2 & (x3 | ~x4)) |
              (x4 & ~x3 & k_x1_xor_x2);

    // y3: Factorized using K2, K4
    wire y3_a = x0 & k_nx1_and_nx2;
    wire y3_b = k_x1_and_x2 & ((x0) | (x3 & ~x4) | (x4 & ~x3));
    wire y3_c = k_nx1_and_nx2 & (x3 & ~x4 | x4 & ~x3);
    wire y3_d = ~x0 & x3 & x4 & k_x1_xor_x2;
    wire y3_e = ~x0 & ~x3 & ~x4 & k_x1_xor_x2;
    wire y3   = y3_a | y3_b | y3_c | y3_d | y3_e;

    // y1: Multi-level decomposition
    wire y1_term_a = x4 & ((x0 & x1 & ~x2) | (x0 & x2 & ~x3) | (x0 & x3 & ~x1) | (~x0 & x1 & x2 & x3));
    wire y1_term_b = ~x4 & ((~x0 & x1 & ~x2) | (~x0 & x2 & ~x3) | (~x0 & x3 & ~x1) | (x0 & x1 & x2 & x3));
    wire y1_term_c = ~x1 & ~x2 & ~x3 & (x0 ^ x4);
    wire y1 = y1_term_a | y1_term_b | y1_term_c;

    assign out_y = {y0, y1, y2, y3, y4};

endmodule
