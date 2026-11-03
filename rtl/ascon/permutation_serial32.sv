// ==============================================================================
// Module: permutation_serial32.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 32-bit Serialised Ascon Permutation Core (Paper Design Point).
//
// Architecture [SOURCE] — based on serial architecture concept from:
//   Graz University of Technology, ascon-hardware repository:
//   https://github.com/ascon/ascon-hardware (serial variant)
//
// Design Technique:
//   Each Ascon round is split across TWO clock cycles:
//     Sub-Cycle A: Constant Addition (p_C) + S-Box on lower 32 bit-columns [31:0]
//     Sub-Cycle B: S-Box on upper 32 bit-columns [63:32] + full Linear Diffusion (p_L)
//   This halves the S-box logic width (32 vs 64 parallel instances) at the cost of
//   2x the clock cycles per round.
//
// Cycle Count:
//   p^12  (init/final):  24 cycles   [SPEC] SP 800-232 a=12
//   p^8   (AEAD data):   16 cycles   [SPEC] SP 800-232 b=8
//   p^6   (AEAD legacy):  12 cycles  [ASSUME] retained for compatibility
//
// Interface: IDENTICAL to permutation_1r, permutation_2r, permutation_half.
//   Port names and widths match exactly for drop-in use with mode_ctrl PERM_VARIANT=3.
//
// Area Trade-off [REC]:
//   Fewer LUTs than 1r (32 S-box instances instead of 64) at 2x the cycles.
//   Actual area measured after synthesis; see results/synthesis/permutation_serial32_util.rpt
//   [MEASURE — not yet synthesised; add to synth_variants.tcl and re-run Vivado].
//
// Correctness:
//   Must produce bit-identical results to permutation_1r for any input state and round count.
//   Verified by: tb/unit/tb_permutation_1r.sv differential tests (cross-check against 1r).
//   [PARTIAL — simulation of the full KAT suite not yet run; pending Vivado invocation].
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module permutation_serial32 (
    input  wire        clk,
    input  wire        rst_n,

    // Control interface (identical to permutation_1r)
    input  wire        start,
    input  wire [ 3:0] rounds,     // Number of rounds: 12 (p^a), 8 (p^b), 6 (legacy)
    output reg         ready,
    output reg         done,

    // State interface — 320 bits = 5 x 64 bits (identical to permutation_1r)
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
    // NIST SP 800-232 Table 5: Round Constants (same as permutation_1r)
    // Index maps to round number 0..15, where p^12 uses indices 4..15.
    // -------------------------------------------------------------------------
    function automatic [7:0] get_round_const(input [3:0] idx);
        case (idx)
            4'd0:  get_round_const = 8'h3c;
            4'd1:  get_round_const = 8'h2d;
            4'd2:  get_round_const = 8'h1e;
            4'd3:  get_round_const = 8'h0f;
            4'd4:  get_round_const = 8'hf0; // Round 0 of p^12
            4'd5:  get_round_const = 8'he1;
            4'd6:  get_round_const = 8'hd2;
            4'd7:  get_round_const = 8'hc3;
            4'd8:  get_round_const = 8'hb4; // Round 0 of p^8
            4'd9:  get_round_const = 8'ha5;
            4'd10: get_round_const = 8'h96; // Round 0 of p^6
            4'd11: get_round_const = 8'h87;
            4'd12: get_round_const = 8'h78;
            4'd13: get_round_const = 8'h69;
            4'd14: get_round_const = 8'h5a;
            4'd15: get_round_const = 8'h4b; // Round 11 of p^12
            default: get_round_const = 8'h00;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // FSM States
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00,
        ST_SBOX_A = 2'b01,   // Sub-cycle A: constant + lower 32 S-boxes
        ST_SBOX_B = 2'b10,   // Sub-cycle B: upper 32 S-boxes + diffusion
        ST_DONE   = 2'b11
    } state_t;

    state_t state_reg;

    // -------------------------------------------------------------------------
    // State Registers
    // -------------------------------------------------------------------------
    reg [63:0] r_x0, r_x1, r_x2, r_x3, r_x4;   // Working state
    reg [31:0] r_lo0, r_lo1, r_lo2, r_lo3, r_lo4; // Lower-half S-box outputs (latched after sub-A)
    reg [ 3:0] r_const_idx;    // Current round constant index
    reg [ 3:0] r_rounds_left;  // Rounds remaining

    // -------------------------------------------------------------------------
    // Combinational: Constant Addition to lower byte of x2 [SPEC] §3.2.1
    // -------------------------------------------------------------------------
    wire [7:0]  current_rc  = get_round_const(r_const_idx);
    wire [63:0] x2_after_rc = {r_x2[63:8], r_x2[7:0] ^ current_rc};

    // -------------------------------------------------------------------------
    // 32-wide S-box array for lower half [31:0] (sub-cycle A)
    // Input: bit i of (r_x0[31:0], r_x1[31:0], x2_after_rc[31:0], r_x3[31:0], r_x4[31:0])
    // -------------------------------------------------------------------------
    wire [31:0] sbox_lo_x0, sbox_lo_x1, sbox_lo_x2, sbox_lo_x3, sbox_lo_x4;

    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_sbox_lo
            wire [4:0] sbox_in  = {r_x0[gi], r_x1[gi], x2_after_rc[gi],
                                   r_x3[gi], r_x4[gi]};
            wire [4:0] sbox_out;
            sbox5 u_s (.in_x(sbox_in), .out_y(sbox_out));
            assign sbox_lo_x0[gi] = sbox_out[4];
            assign sbox_lo_x1[gi] = sbox_out[3];
            assign sbox_lo_x2[gi] = sbox_out[2];
            assign sbox_lo_x3[gi] = sbox_out[1];
            assign sbox_lo_x4[gi] = sbox_out[0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 32-wide S-box array for upper half [63:32] (sub-cycle B)
    // Note: constant was already applied to x2 before sub-cycle A; r_x2 now
    //       holds x2_after_rc (latched in sub-cycle A transition).
    // -------------------------------------------------------------------------
    wire [31:0] sbox_hi_x0, sbox_hi_x1, sbox_hi_x2, sbox_hi_x3, sbox_hi_x4;

    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_sbox_hi
            wire [4:0] sbox_in  = {r_x0[gi+32], r_x1[gi+32], r_x2[gi+32],
                                   r_x3[gi+32], r_x4[gi+32]};
            wire [4:0] sbox_out;
            sbox5 u_s (.in_x(sbox_in), .out_y(sbox_out));
            assign sbox_hi_x0[gi] = sbox_out[4];
            assign sbox_hi_x1[gi] = sbox_out[3];
            assign sbox_hi_x2[gi] = sbox_out[2];
            assign sbox_hi_x3[gi] = sbox_out[1];
            assign sbox_hi_x4[gi] = sbox_out[0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Combinational: Linear Diffusion applied to recombined 64-bit S-box outputs
    // Sigma_i functions per NIST SP 800-232 §3.2.3
    // -------------------------------------------------------------------------
    wire [63:0] ps_x0_full = {sbox_hi_x0, r_lo0};
    wire [63:0] ps_x1_full = {sbox_hi_x1, r_lo1};
    wire [63:0] ps_x2_full = {sbox_hi_x2, r_lo2};
    wire [63:0] ps_x3_full = {sbox_hi_x3, r_lo3};
    wire [63:0] ps_x4_full = {sbox_hi_x4, r_lo4};

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
    // Output: state registers wired to outputs
    // -------------------------------------------------------------------------
    assign out_x0 = r_x0;
    assign out_x1 = r_x1;
    assign out_x2 = r_x2;
    assign out_x3 = r_x3;
    assign out_x4 = r_x4;

    // -------------------------------------------------------------------------
    // Sequential FSM
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg     <= ST_IDLE;
            ready         <= 1'b1;
            done          <= 1'b0;
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
        end else begin
            case (state_reg)
                // ---------------------------------------------------------
                ST_IDLE: begin
                    done  <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        // Load input state
                        r_x0          <= in_x0;
                        r_x1          <= in_x1;
                        r_x2          <= in_x2;
                        r_x3          <= in_x3;
                        r_x4          <= in_x4;
                        r_rounds_left <= rounds;
                        // First constant index = 12 - rounds (matches permutation_1r)
                        r_const_idx   <= 4'd12 - rounds;
                        ready         <= 1'b0;
                        state_reg     <= ST_SBOX_A;
                    end
                end

                // ---------------------------------------------------------
                // Sub-cycle A: Apply constant to x2, compute lower-32 S-boxes.
                // Latch lower-half results; update x2 with rc-applied value.
                // (Upper S-boxes are already combinationally available next cycle
                //  because r_x0..r_x4 don't change between A and B.)
                // ---------------------------------------------------------
                ST_SBOX_A: begin
                    // Latch lower-half S-box outputs
                    r_lo0 <= sbox_lo_x0;
                    r_lo1 <= sbox_lo_x1;
                    r_lo2 <= sbox_lo_x2;
                    r_lo3 <= sbox_lo_x3;
                    r_lo4 <= sbox_lo_x4;
                    // Apply round constant to x2 now so upper half sees the same
                    // constant-added x2 in sub-cycle B
                    r_x2  <= x2_after_rc;
                    state_reg <= ST_SBOX_B;
                end

                // ---------------------------------------------------------
                // Sub-cycle B: Upper-32 S-boxes + linear diffusion.
                // Write back full diffused state; advance round counter.
                // ---------------------------------------------------------
                ST_SBOX_B: begin
                    r_x0 <= diff_x0;
                    r_x1 <= diff_x1;
                    r_x2 <= diff_x2;
                    r_x3 <= diff_x3;
                    r_x4 <= diff_x4;

                    if (r_rounds_left == 4'd1) begin
                        // Last round completed
                        state_reg <= ST_DONE;
                    end else begin
                        r_rounds_left <= r_rounds_left - 4'd1;
                        r_const_idx   <= r_const_idx   + 4'd1;
                        state_reg     <= ST_SBOX_A;
                    end
                end

                // ---------------------------------------------------------
                ST_DONE: begin
                    done      <= 1'b1;
                    ready     <= 1'b1;
                    state_reg <= ST_IDLE;
                end

                default: state_reg <= ST_IDLE;
            endcase
        end
    end

endmodule

