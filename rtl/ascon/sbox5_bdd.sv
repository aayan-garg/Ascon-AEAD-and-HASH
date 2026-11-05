// ==============================================================================
// Module: sbox5_bdd.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 5-bit Ascon S-box synthesized from Reduced Ordered Binary Decision
//              Diagrams (ROBDD) with Variable Ordering: Interleaved [x1, x3, x0, x2, x4].
// Complexity: 32 2:1 Multiplexer (ITE) nodes.
// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module sbox5_bdd (
    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4} (x0 is MSB, x4 is LSB)
    output wire [4:0] out_y  // {y0, y1, y2, y3, y4} (y0 is MSB, y4 is LSB)
);

    wire x0 = in_x[4];
    wire x1 = in_x[3];
    wire x2 = in_x[2];
    wire x3 = in_x[1];
    wire x4 = in_x[0];

    wire [4:0] x_bus = {x0, x1, x2, x3, x4};

    // Constant Terminals
    wire term_0 = 1'b0;
    wire term_1 = 1'b1;

    // Shared ROBDD Multiplexer Network (32 ITE nodes):
    wire node_2 = x2 ? term_1 : term_0;
    wire node_3 = x2 ? term_0 : term_1;
    wire node_4 = x0 ? node_3 : node_2;
    wire node_5 = x0 ? node_2 : node_3;
    wire node_6 = x3 ? node_5 : node_4;
    wire node_7 = x4 ? term_0 : term_1;
    wire node_8 = x4 ? term_1 : term_0;
    wire node_9 = x3 ? node_8 : node_7;
    wire node_10 = x1 ? node_9 : node_6;
    wire node_11 = x2 ? node_7 : node_8;
    wire node_12 = x2 ? node_8 : node_7;
    wire node_13 = x0 ? node_12 : node_11;
    wire node_14 = x0 ? node_8 : node_7;
    wire node_15 = x3 ? node_14 : node_13;
    wire node_16 = x0 ? node_11 : node_12;
    wire node_17 = x3 ? node_16 : node_14;
    wire node_18 = x1 ? node_17 : node_15;
    wire node_19 = x3 ? node_3 : node_12;
    wire node_20 = x3 ? node_2 : node_11;
    wire node_21 = x1 ? node_20 : node_19;
    wire node_22 = x0 ? node_3 : node_11;
    wire node_23 = x0 ? node_3 : node_12;
    wire node_24 = x3 ? node_23 : node_22;
    wire node_25 = x0 ? node_2 : node_12;
    wire node_26 = x0 ? node_2 : node_11;
    wire node_27 = x3 ? node_26 : node_25;
    wire node_28 = x1 ? node_27 : node_24;
    wire node_29 = x3 ? node_7 : node_8;
    wire node_30 = x0 ? term_0 : term_1;
    wire node_31 = x0 ? term_1 : term_0;
    wire node_32 = x3 ? node_31 : node_30;
    wire node_33 = x1 ? node_32 : node_29;

    // Multi-Root Output Mapping:
    wire y0 = node_10;
    wire y1 = node_18;
    wire y2 = node_21;
    wire y3 = node_28;
    wire y4 = node_33;

    assign out_y = {y0, y1, y2, y3, y4};

endmodule
