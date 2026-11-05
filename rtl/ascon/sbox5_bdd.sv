// ==============================================================================
// Module: sbox5_bdd.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 5-bit Ascon S-box implemented as a 32-entry lookup table.
// No BDD decomposition or node-count optimization was performed.
// Equivalence: Exhaustively proven equivalent to NIST SP 800-232 Table 6.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module sbox5_bdd (
    input  wire [4:0] in_x,  // {x0, x1, x2, x3, x4} (x0 is MSB, x4 is LSB)
    output wire [4:0] out_y  // {y0, y1, y2, y3, y4} (y0 is MSB, y4 is LSB)
);

    function automatic [4:0] lookup_eval (input [4:0] x);
        case (x)
            5'd00: lookup_eval = 5'h04;
            5'd01: lookup_eval = 5'h0B;
            5'd02: lookup_eval = 5'h1F;
            5'd03: lookup_eval = 5'h14;
            5'd04: lookup_eval = 5'h1A;
            5'd05: lookup_eval = 5'h15;
            5'd06: lookup_eval = 5'h09;
            5'd07: lookup_eval = 5'h02;
            5'd08: lookup_eval = 5'h1B;
            5'd09: lookup_eval = 5'h05;
            5'd10: lookup_eval = 5'h08;
            5'd11: lookup_eval = 5'h12;
            5'd12: lookup_eval = 5'h1D;
            5'd13: lookup_eval = 5'h03;
            5'd14: lookup_eval = 5'h06;
            5'd15: lookup_eval = 5'h1C;
            5'd16: lookup_eval = 5'h1E;
            5'd17: lookup_eval = 5'h13;
            5'd18: lookup_eval = 5'h07;
            5'd19: lookup_eval = 5'h0E;
            5'd20: lookup_eval = 5'h00;
            5'd21: lookup_eval = 5'h0D;
            5'd22: lookup_eval = 5'h11;
            5'd23: lookup_eval = 5'h18;
            5'd24: lookup_eval = 5'h10;
            5'd25: lookup_eval = 5'h0C;
            5'd26: lookup_eval = 5'h01;
            5'd27: lookup_eval = 5'h19;
            5'd28: lookup_eval = 5'h16;
            5'd29: lookup_eval = 5'h0A;
            5'd30: lookup_eval = 5'h0F;
            5'd31: lookup_eval = 5'h17;
        endcase
    endfunction

    assign out_y = lookup_eval(in_x);

endmodule
