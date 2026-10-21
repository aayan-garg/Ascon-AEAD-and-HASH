// ==============================================================================
// Module: round_core.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Combinational Single-Round Core for Ascon Permutation.
// Implements:
//   1. Constant Addition Layer (p_C): x2[7:0] ^= round_const
//   2. Substitution Layer (p_S): 64 parallel 5-bit S-boxes across (x0..x4)
//   3. Linear Diffusion Layer (p_L): Sigma_0..Sigma_4 applied to (x0..x4)
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module round_core #(
    parameter SBOX_TYPE = "BASELINE" // "BASELINE" or "ESPRESSO"
) (
    input  wire [63:0] in_x0,
    input  wire [63:0] in_x1,
    input  wire [63:0] in_x2,
    input  wire [63:0] in_x3,
    input  wire [63:0] in_x4,
    input  wire [ 7:0] round_const, // 8-bit round constant c_r
    output wire [63:0] out_x0,
    output wire [63:0] out_x1,
    output wire [63:0] out_x2,
    output wire [63:0] out_x3,
    output wire [63:0] out_x4
);

    // -------------------------------------------------------------------------
    // 1. Constant Addition Layer (p_C)
    // NIST SP 800-232 Section 3.2.1: x2 ^= c_r (applied to least significant byte)
    // -------------------------------------------------------------------------
    wire [63:0] pc_x0 = in_x0;
    wire [63:0] pc_x1 = in_x1;
    wire [63:0] pc_x2 = {in_x2[63:8], in_x2[7:0] ^ round_const};
    wire [63:0] pc_x3 = in_x3;
    wire [63:0] pc_x4 = in_x4;

    // -------------------------------------------------------------------------
    // 2. Substitution Layer (p_S)
    // 64 parallel 5-bit S-boxes applied vertically across bit slices of (x0..x4)
    // -------------------------------------------------------------------------
    wire [63:0] ps_x0;
    wire [63:0] ps_x1;
    wire [63:0] ps_x2;
    wire [63:0] ps_x3;
    wire [63:0] ps_x4;

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : gen_sbox64
            wire [4:0] sbox_in  = {pc_x0[i], pc_x1[i], pc_x2[i], pc_x3[i], pc_x4[i]};
            wire [4:0] sbox_out;

            if (SBOX_TYPE == "ESPRESSO") begin : gen_espresso
                sbox5_espresso u_sbox5 (
                    .in_x  (sbox_in),
                    .out_y (sbox_out)
                );
            end else begin : gen_baseline
                sbox5 u_sbox5 (
                    .in_x  (sbox_in),
                    .out_y (sbox_out)
                );
            end

            assign ps_x0[i] = sbox_out[4];
            assign ps_x1[i] = sbox_out[3];
            assign ps_x2[i] = sbox_out[2];
            assign ps_x3[i] = sbox_out[1];
            assign ps_x4[i] = sbox_out[0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 3. Linear Diffusion Layer (p_L)
    // -------------------------------------------------------------------------
    diffusion u_diffusion (
        .in_x0  (ps_x0),
        .in_x1  (ps_x1),
        .in_x2  (ps_x2),
        .in_x3  (ps_x3),
        .in_x4  (ps_x4),
        .out_x0 (out_x0),
        .out_x1 (out_x1),
        .out_x2 (out_x2),
        .out_x3 (out_x3),
        .out_x4 (out_x4)
    );

endmodule
