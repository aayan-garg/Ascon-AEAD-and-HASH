// ==============================================================================
// Module: permutation_serial32.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 32-bit Serialised Ascon Permutation Core (Paper Design Point).
//
// Architecture & Technique:
//   - 32-bit serialised datapath: exactly 32 parallel 5-bit S-boxes (50% S-box area of 1R core).
//   - Each Ascon round takes 2 clock cycles:
//       Sub-cycle A (ST_SBOX_A):
//         * Constant Addition (p_C) applied to lower byte of x2
//         * Lower 32 bit-columns [31:0] passed through 32 S-boxes
//         * Lower 32-bit S-box outputs latched into r_lo0..r_lo4
//         * x2 with constant addition latched into r_x2
//       Sub-cycle B (ST_SBOX_B):
//         * Upper 32 bit-columns [63:32] passed through the SAME 32 S-boxes
//         * Full 64-bit words {sbox_hi, r_lo} formed combinationally
//         * Full Linear Diffusion (p_L) applied combinationally
//         * Diffused 320-bit state registered into r_x0..r_x4
//
// Cycle Count:
//   - 2 clock cycles per round:
//     * p^12 (init / final): 24 clock cycles
//     * p^8  (AEAD data):    16 clock cycles
//     * p^6  (Hash / legacy): 12 clock cycles
//
// Interface & Handshake:
//   - Compatible with permutation_1r, permutation_2r, permutation_half.
//   - Start pulse accepted in ST_IDLE or ST_DONE (back-to-back support).
//   - Done and Ready asserted on the final cycle of the final round.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module permutation_serial32 (
    input  wire        clk,
    input  wire        rst_n,

    // Control interface
    input  wire        start,
    input  wire [ 3:0] rounds,     // 12 (p^a), 8 (p^b), 6 (hash/legacy)
    output reg         ready,
    output reg         done,

    // State interface — 320 bits (5 x 64 bits)
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

    // -------------------------------------------------------------------------
    // NIST SP 800-232 Table 5: Round Constants
    // -------------------------------------------------------------------------
    function automatic [7:0] get_round_const(input [3:0] idx);
        case (idx)
            4'd0:  get_round_const = 8'h3c;
            4'd1:  get_round_const = 8'h2d;
            4'd2:  get_round_const = 8'h1e;
            4'd3:  get_round_const = 8'h0f;
            4'd4:  get_round_const = 8'hf0; // Round 0 of 12
            4'd5:  get_round_const = 8'he1;
            4'd6:  get_round_const = 8'hd2;
            4'd7:  get_round_const = 8'hc3;
            4'd8:  get_round_const = 8'hb4; // Round 0 of 8
            4'd9:  get_round_const = 8'ha5;
            4'd10: get_round_const = 8'h96; // Round 0 of 6
            4'd11: get_round_const = 8'h87;
            4'd12: get_round_const = 8'h78;
            4'd13: get_round_const = 8'h69;
            4'd14: get_round_const = 8'h5a;
            4'd15: get_round_const = 8'h4b; // Round 11 of 12
            default: get_round_const = 8'h00;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // FSM States
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00,
        ST_SBOX_A = 2'b01, // Sub-cycle A: constant + lower 32 S-boxes
        ST_SBOX_B = 2'b10, // Sub-cycle B: upper 32 S-boxes + full diffusion
        ST_DONE   = 2'b11
    } state_t;

    state_t state_reg;

    // Working state registers
    reg [63:0] r_x0, r_x1, r_x2, r_x3, r_x4;
    reg [31:0] r_lo0, r_lo1, r_lo2, r_lo3, r_lo4;
    reg [ 3:0] r_const_idx;
    reg [ 3:0] r_rounds_left;

    // -------------------------------------------------------------------------
    // Constant Addition: applied to bits [7:0] of x2
    // -------------------------------------------------------------------------
    wire [7:0]  current_rc  = get_round_const(r_const_idx);
    wire [63:0] x2_after_rc = {r_x2[63:8], r_x2[7:0] ^ current_rc};

    // -------------------------------------------------------------------------
    // 32-bit Shared S-box Array (Exactly 32 instances)
    // In Sub-cycle A: processes bits [31:0] of (r_x0, r_x1, x2_after_rc, r_x3, r_x4)
    // In Sub-cycle B: processes bits [63:32] of (r_x0, r_x1, r_x2, r_x3, r_x4)
    // -------------------------------------------------------------------------
    wire [4:0] sbox_in  [31:0];
    wire [4:0] sbox_out [31:0];

    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_sbox32
            assign sbox_in[gi] = (state_reg == ST_SBOX_B) ?
                {r_x0[gi+32], r_x1[gi+32], r_x2[gi+32],        r_x3[gi+32], r_x4[gi+32]} :
                {r_x0[gi],    r_x1[gi],    x2_after_rc[gi],    r_x3[gi],    r_x4[gi]};

            sbox5 u_sbox (
                .in_x (sbox_in[gi]),
                .out_y(sbox_out[gi])
            );
        end
    endgenerate

    // Unpack 32-bit S-box outputs
    wire [31:0] sbox_out_x0, sbox_out_x1, sbox_out_x2, sbox_out_x3, sbox_out_x4;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_sbox_unpack
            assign sbox_out_x0[gi] = sbox_out[gi][4];
            assign sbox_out_x1[gi] = sbox_out[gi][3];
            assign sbox_out_x2[gi] = sbox_out[gi][2];
            assign sbox_out_x3[gi] = sbox_out[gi][1];
            assign sbox_out_x4[gi] = sbox_out[gi][0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Sub-cycle B: Assemble full 64-bit words {sbox_hi, r_lo} and diffuse
    // -------------------------------------------------------------------------
    wire [63:0] ps_x0_full = {sbox_out_x0, r_lo0};
    wire [63:0] ps_x1_full = {sbox_out_x1, r_lo1};
    wire [63:0] ps_x2_full = {sbox_out_x2, r_lo2};
    wire [63:0] ps_x3_full = {sbox_out_x3, r_lo3};
    wire [63:0] ps_x4_full = {sbox_out_x4, r_lo4};

    wire [63:0] diff_x0, diff_x1, diff_x2, diff_x3, diff_x4;

    diffusion u_diff (
        .in_x0  (ps_x0_full),
        .in_x1  (ps_x1_full),
        .in_x2  (ps_x2_full),
        .in_x3  (ps_x3_full),
        .in_x4  (ps_x4_full),
        .out_x0 (diff_x0),
        .out_x1 (diff_x1),
        .out_x2 (diff_x2),
        .out_x3 (diff_x3),
        .out_x4 (diff_x4)
    );

    // -------------------------------------------------------------------------
    // Sequential Control & State Updates
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg     <= ST_IDLE;
            r_x0          <= 64'b0;
            r_x1          <= 64'b0;
            r_x2          <= 64'b0;
            r_x3          <= 64'b0;
            r_x4          <= 64'b0;
            r_lo0         <= 32'b0;
            r_lo1         <= 32'b0;
            r_lo2         <= 32'b0;
            r_lo3         <= 32'b0;
            r_lo4         <= 32'b0;
            r_const_idx   <= 4'b0;
            r_rounds_left <= 4'b0;
            ready         <= 1'b1;
            done          <= 1'b0;
        end else begin
            case (state_reg)
                ST_IDLE: begin
                    done  <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        r_x0          <= in_x0;
                        r_x1          <= in_x1;
                        r_x2          <= in_x2;
                        r_x3          <= in_x3;
                        r_x4          <= in_x4;
                        // For R rounds, base constant start index is 16 - R (SP 800-232)
                        r_const_idx   <= 4'd16 - rounds;
                        r_rounds_left <= rounds;
                        ready         <= 1'b0;
                        state_reg     <= ST_SBOX_A;
                    end
                end

                // Sub-cycle A: Latch lower 32-bit S-box outputs and constant-added x2
                ST_SBOX_A: begin
                    r_lo0     <= sbox_out_x0;
                    r_lo1     <= sbox_out_x1;
                    r_lo2     <= sbox_out_x2;
                    r_lo3     <= sbox_out_x3;
                    r_lo4     <= sbox_out_x4;
                    r_x2      <= x2_after_rc;
                    state_reg <= ST_SBOX_B;
                end

                // Sub-cycle B: Apply diffusion and write back full 64-bit state words
                ST_SBOX_B: begin
                    r_x0        <= diff_x0;
                    r_x1        <= diff_x1;
                    r_x2        <= diff_x2;
                    r_x3        <= diff_x3;
                    r_x4        <= diff_x4;
                    r_const_idx <= r_const_idx + 1'b1;

                    if (r_rounds_left == 4'd1) begin
                        done      <= 1'b1;
                        ready     <= 1'b1;
                        state_reg <= ST_DONE;
                    end else begin
                        r_rounds_left <= r_rounds_left - 1'b1;
                        state_reg     <= ST_SBOX_A;
                    end
                end

                // ST_DONE: Keep done and ready high, support back-to-back start
                ST_DONE: begin
                    if (start) begin
                        r_x0          <= in_x0;
                        r_x1          <= in_x1;
                        r_x2          <= in_x2;
                        r_x3          <= in_x3;
                        r_x4          <= in_x4;
                        r_const_idx   <= 4'd16 - rounds;
                        r_rounds_left <= rounds;
                        ready         <= 1'b0;
                        done          <= 1'b0;
                        state_reg     <= ST_SBOX_A;
                    end else begin
                        done      <= 1'b1;
                        ready     <= 1'b1;
                        state_reg <= ST_IDLE;
                    end
                end

                default: state_reg <= ST_IDLE;
            endcase
        end
    end

    // Output assignments
    assign out_x0 = r_x0;
    assign out_x1 = r_x1;
    assign out_x2 = r_x2;
    assign out_x3 = r_x3;
    assign out_x4 = r_x4;

endmodule
