// ==============================================================================
// Module: permutation_1r_espresso.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Paper-Based 1-Round Permutation Variant with Berkeley ESPRESSO S-Box.
// Target: Phase 10 Synthesis & Performance Evaluation
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module permutation_1r_espresso (
    input  wire        clk,
    input  wire        rst_n,

    // Control interface
    input  wire        start,
    input  wire [ 3:0] rounds,
    output wire        ready,
    output wire        done,

    // State interface (320 bits)
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

    permutation_1r #(.SBOX_TYPE("ESPRESSO")) u_perm_espresso (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .rounds     (rounds),
        .ready      (ready),
        .done       (done),
        .in_x0      (in_x0),
        .in_x1      (in_x1),
        .in_x2      (in_x2),
        .in_x3      (in_x3),
        .in_x4      (in_x4),
        .out_x0     (out_x0),
        .out_x1     (out_x1),
        .out_x2     (out_x2),
        .out_x3     (out_x3),
        .out_x4     (out_x4)
    );

endmodule
