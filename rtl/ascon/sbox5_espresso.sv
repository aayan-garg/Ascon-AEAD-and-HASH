// ==============================================================================
// Module: sbox5_espresso.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Generator: tools/sbox_opt/espresso_runner.py
// Tool: UC Berkeley Espresso Version #2.3 (Release date 01/31/88)
// Raw PLA: results/synthesis/espresso_raw_output.pla
// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6 across all 32 inputs.
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

    // Minimal multi-output product terms from UC Berkeley Espresso (-Dexact):
    wire p00 = x0 & x1 & x2 & x3 & ~x4; // 11110 -> 01000
    wire p01 = ~x0 & ~x1 & x2 & x3 & x4; // 00111 -> 00010
    wire p02 = ~x0 & x1 & x2 & ~x3 & ~x4; // 01100 -> 01100
    wire p03 = x0 & x1 & x2 & ~x4; // 111-0 -> 00110
    wire p04 = ~x0 & x1 & ~x2 & x3 & x4; // 01011 -> 10010
    wire p05 = ~x0 & x1 & ~x2 & ~x3 & ~x4; // 01000 -> 01010
    wire p06 = x0 & ~x1 & ~x2 & x3; // 1001- -> 00110
    wire p07 = x0 & ~x1 & x2 & x3; // 1011- -> 10000
    wire p08 = ~x0 & ~x2 & x3 & ~x4; // 0-010 -> 01000
    wire p09 = x1 & ~x2 & ~x3 & x4; // -1001 -> 00100
    wire p10 = x0 & x1 & ~x3 & x4; // 11-01 -> 01000
    wire p11 = ~x1 & ~x2 & x3 & ~x4; // -0010 -> 00010
    wire p12 = x1 & x2 & ~x3 & x4; // -1101 -> 00010
    wire p13 = ~x0 & ~x1 & x2 & ~x3 & x4; // 00101 -> 10101
    wire p14 = x0 & ~x1 & x3 & x4; // 10-11 -> 01000
    wire p15 = x0 & ~x1 & x2 & ~x3 & x4; // 10101 -> 01101
    wire p16 = x0 & ~x1 & ~x2 & ~x3 & x4; // 10001 -> 10011
    wire p17 = x0 & x1 & ~x2 & x3 & x4; // 11011 -> 11001
    wire p18 = ~x0 & ~x1 & ~x2 & ~x3 & x4; // 00001 -> 01011
    wire p19 = ~x0 & x1 & x2 & x3 & x4; // 01111 -> 11100
    wire p20 = x0 & ~x1 & ~x2 & ~x3 & ~x4; // 10000 -> 11010
    wire p21 = ~x0 & ~x1 & x2 & ~x3 & ~x4; // 00100 -> 11010
    wire p22 = ~x0 & ~x1 & ~x2 & x3; // 0001- -> 10100
    wire p23 = ~x0 & ~x1 & x3 & ~x4; // 00-10 -> 01001
    wire p24 = x1 & x2 & x3 & ~x4; // -1110 -> 00110
    wire p25 = x0 & x3 & ~x4; // 1--10 -> 00001
    wire p26 = ~x0 & x1 & ~x3; // 01-0- -> 00001
    wire p27 = ~x1 & ~x2 & ~x4; // -00-0 -> 00100
    wire p28 = x0 & x1 & x2 & x3 & x4; // 11111 -> 10111
    wire p29 = x1 & ~x3 & ~x4; // -1-00 -> 10000

    // Outputs formed by OR-ing active product terms:
    wire y0 = p04 | p07 | p13 | p16 | p17 | p19 | p20 | p21 | p22 | p28 | p29;
    wire y1 = p00 | p02 | p05 | p08 | p10 | p14 | p15 | p17 | p18 | p19 | p20 | p21 | p23;
    wire y2 = p02 | p03 | p06 | p09 | p13 | p15 | p19 | p22 | p24 | p27 | p28;
    wire y3 = p01 | p03 | p04 | p05 | p06 | p11 | p12 | p16 | p18 | p20 | p21 | p24 | p28;
    wire y4 = p13 | p15 | p16 | p17 | p18 | p23 | p25 | p26 | p28;

    assign out_y = {y0, y1, y2, y3, y4};

endmodule
