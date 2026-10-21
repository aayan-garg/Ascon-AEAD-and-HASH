// ==============================================================================
// Module: permutation_2r.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: 2-Rounds-per-Cycle Unrolled Ascon Permutation Core.
// Architecture:
//   - Chained dual combinational round cores (round0 -> round1)
//   - Retires 2 full permutation rounds every clock edge
//   - 12 rounds complete in 6 clock cycles; 6 rounds complete in 3 clock cycles
//   - Doubles throughput compared to 1-round baseline
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module permutation_2r (
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
        ST_IDLE = 2'b00,
        ST_RUN  = 2'b01,
        ST_DONE = 2'b10
    } state_t;

    state_t state_reg;

    reg [63:0] r_x0, r_x1, r_x2, r_x3, r_x4;
    reg [ 3:0] r_const_idx;
    reg [ 3:0] r_rounds_left;

    // Dual cascaded round cores
    wire [63:0] mid_x0, mid_x1, mid_x2, mid_x3, mid_x4;
    wire [63:0] next_x0, next_x1, next_x2, next_x3, next_x4;

    wire [ 7:0] rc0 = get_round_const(r_const_idx);
    wire [ 7:0] rc1 = get_round_const(r_const_idx + 4'd1);

    // Round 0 of the pair
    round_core u_round0 (
        .in_x0       (r_x0),
        .in_x1       (r_x1),
        .in_x2       (r_x2),
        .in_x3       (r_x3),
        .in_x4       (r_x4),
        .round_const (rc0),
        .out_x0      (mid_x0),
        .out_x1      (mid_x1),
        .out_x2      (mid_x2),
        .out_x3      (mid_x3),
        .out_x4      (mid_x4)
    );

    // Round 1 of the pair (cascaded)
    round_core u_round1 (
        .in_x0       (mid_x0),
        .in_x1       (mid_x1),
        .in_x2       (mid_x2),
        .in_x3       (mid_x3),
        .in_x4       (mid_x4),
        .round_const (rc1),
        .out_x0      (next_x0),
        .out_x1      (next_x1),
        .out_x2      (next_x2),
        .out_x3      (next_x3),
        .out_x4      (next_x4)
    );

    // Sequential state updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg     <= ST_IDLE;
            r_x0          <= 64'b0;
            r_x1          <= 64'b0;
            r_x2          <= 64'b0;
            r_x3          <= 64'b0;
            r_x4          <= 64'b0;
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
                        state_reg     <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    r_x0        <= next_x0;
                    r_x1        <= next_x1;
                    r_x2        <= next_x2;
                    r_x3        <= next_x3;
                    r_x4        <= next_x4;
                    r_const_idx <= r_const_idx + 4'd2;

                    // Each cycle retires 2 rounds
                    if (r_rounds_left <= 4'd2) begin
                        done      <= 1'b1;
                        ready     <= 1'b1;
                        state_reg <= ST_DONE;
                    end else begin
                        r_rounds_left <= r_rounds_left - 4'd2;
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
                        state_reg     <= ST_RUN;
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
