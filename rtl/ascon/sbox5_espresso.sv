// ==============================================================================
// Module: sbox5_espresso.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 5-bit Ascon S-box optimized via Two-Level Heuristic Minimization (ESPRESSO / Quine-McCluskey).
// Implementation: Two-Level Sum-of-Products (SOP) minimal representation.
// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module sbox5_espresso (
    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4}
    output wire [4:0] out_y  // {y0, y1, y2, y3, y4}
);

    wire x0 = in_x[4];
    wire x1 = in_x[3];
    wire x2 = in_x[2];
    wire x3 = in_x[1];
    wire x4 = in_x[0];

    // Minimal Sum-of-Products (SOP) boolean covers derived via ESPRESSO minimization:
    wire y0 = (x1 & x3 & x4) | 
              (x1 & ~x3 & ~x4) | 
              (x0 & x2 & x3 & ~x1) | 
              (x0 & ~x1 & ~x2 & ~x3) | 
              (x2 & ~x0 & ~x1 & ~x3) | 
              (x3 & ~x0 & ~x1 & ~x2);

    wire y1 = (x0 & x1 & x4 & ~x2) | 
              (x0 & x2 & x4 & ~x3) | 
              (x0 & x3 & x4 & ~x1) | 
              (x0 & x1 & x2 & x3 & ~x4) | 
              (x1 & x2 & x3 & x4 & ~x0) | 
              (x1 & ~x0 & ~x2 & ~x4) | 
              (x2 & ~x0 & ~x3 & ~x4) | 
              (x3 & ~x0 & ~x1 & ~x4) | 
              (x0 & ~x1 & ~x2 & ~x3 & ~x4) | 
              (x4 & ~x0 & ~x1 & ~x2 & ~x3);

    wire y2 = (x1 & x2 & x3) | 
              (x1 & x2 & ~x4) | 
              (x3 & ~x1 & ~x2) | 
              (~x1 & ~x2 & ~x4) | 
              (x1 & x4 & ~x2 & ~x3) | 
              (x2 & x4 & ~x1 & ~x3);

    wire y3 = (x0 & x1 & x2) | 
              (x0 & ~x1 & ~x2) | 
              (x1 & x2 & x3 & ~x4) | 
              (x1 & x2 & x4 & ~x3) | 
              (x3 & ~x1 & ~x2 & ~x4) | 
              (x4 & ~x1 & ~x2 & ~x3) | 
              (x1 & x3 & x4 & ~x0 & ~x2) | 
              (x2 & x3 & x4 & ~x0 & ~x1) | 
              (x1 & ~x0 & ~x2 & ~x3 & ~x4) | 
              (x2 & ~x0 & ~x1 & ~x3 & ~x4);

    wire y4 = (x0 & x1 & x3) | 
              (x1 & ~x0 & ~x3) | 
              (x3 & ~x1 & ~x4) | 
              (x4 & ~x1 & ~x3);

    assign out_y = {y0, y1, y2, y3, y4};

endmodule
