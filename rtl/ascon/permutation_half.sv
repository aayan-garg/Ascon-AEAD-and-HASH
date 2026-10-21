// ==============================================================================
// Module: permutation_half.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 1/2-Round-per-Cycle Pipelined/Folded Ascon Permutation Core.
// Architecture:
//   - Micro-step 0 (Cycle 0): Constant Addition (p_C) + S-Box Layer (p_S)
//   - Micro-step 1 (Cycle 1): Linear Diffusion Layer (p_L)
//   - 2 clock cycles per round (12 rounds in 24 cycles; 6 rounds in 12 cycles)
//   - Cuts combinational critical path delay and peak switching power in half
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module permutation_half (
    input  wire        clk,
    input  wire        rst_n,

    // Control interface
    input  wire        start,
    input  wire [ 3:0] rounds,     // Number of rounds: 12 (p^a), 6 (p^b), 8
    output reg         ready,
    output reg         done,

    // State interface (320 bits = 5 x 64 bits)
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
    // NIST SP 800-232 Table 5: 16 Base Round Constants
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
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // State Registers & FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00,
        ST_STEP0  = 2'b01, // Micro-step 0: p_C + p_S
        ST_STEP1  = 2'b10, // Micro-step 1: p_L (Diffusion)
        ST_DONE   = 2'b11
    } state_t;

    state_t state_reg;

    reg [63:0] r_x0, r_x1, r_x2, r_x3, r_x4;
    reg [63:0] mid_x0, mid_x1, mid_x2, mid_x3, mid_x4;
    reg [ 3:0] r_const_idx;
    reg [ 3:0] r_rounds_left;

    // -------------------------------------------------------------------------
    // Micro-Step 0 Combinational Logic: p_C + p_S
    // -------------------------------------------------------------------------
    wire [ 7:0] current_rc = get_round_const(r_const_idx);
    wire [63:0] pc_x0 = r_x0;
    wire [63:0] pc_x1 = r_x1;
    wire [63:0] pc_x2 = {r_x2[63:8], r_x2[7:0] ^ current_rc};
    wire [63:0] pc_x3 = r_x3;
    wire [63:0] pc_x4 = r_x4;

    wire [63:0] ps_x0, ps_x1, ps_x2, ps_x3, ps_x4;

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : gen_sbox_half
            wire [4:0] sb_in  = {pc_x0[i], pc_x1[i], pc_x2[i], pc_x3[i], pc_x4[i]};
            wire [4:0] sb_out;

            sbox5 u_sbox (
                .in_x  (sb_in),
                .out_y (sb_out)
            );

            assign ps_x0[i] = sb_out[4];
            assign ps_x1[i] = sb_out[3];
            assign ps_x2[i] = sb_out[2];
            assign ps_x3[i] = sb_out[1];
            assign ps_x4[i] = sb_out[0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Micro-Step 1 Combinational Logic: p_L (Diffusion)
    // -------------------------------------------------------------------------
    wire [63:0] diff_x0, diff_x1, diff_x2, diff_x3, diff_x4;

    diffusion u_diff (
        .in_x0  (mid_x0),
        .in_x1  (mid_x1),
        .in_x2  (mid_x2),
        .in_x3  (mid_x3),
        .in_x4  (mid_x4),
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
            mid_x0        <= 64'b0;
            mid_x1        <= 64'b0;
            mid_x2        <= 64'b0;
            mid_x3        <= 64'b0;
            mid_x4        <= 64'b0;
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
                        r_const_idx   <= 4'd16 - rounds;
                        r_rounds_left <= rounds;
                        ready         <= 1'b0;
                        state_reg     <= ST_STEP0;
                    end
                end

                // Micro-Step 0: Latch p_C + p_S into mid registers
                ST_STEP0: begin
                    mid_x0    <= ps_x0;
                    mid_x1    <= ps_x1;
                    mid_x2    <= ps_x2;
                    mid_x3    <= ps_x3;
                    mid_x4    <= ps_x4;
                    state_reg <= ST_STEP1;
                end

                // Micro-Step 1: Apply p_L (Diffusion) and update round state
                ST_STEP1: begin
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
                        state_reg     <= ST_STEP0;
                    end
                end

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
                        state_reg     <= ST_STEP0;
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
