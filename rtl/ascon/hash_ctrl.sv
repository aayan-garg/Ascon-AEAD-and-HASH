// ==============================================================================
// Module: hash_ctrl.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Dedicated Ascon-Hash256 Mode Controller Wrapper.
// Features:
//   - 64-bit rate absorption (word S0), 12-round permutation
//   - 256-bit hash digest output across 4 squeeze cycles
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module hash_ctrl (
    input  wire         clk,
    input  wire         rst_n,

    // Control & Setup
    input  wire         start,
    input  wire         soft_rst,
    input  wire [ 31:0] msg_len,

    // Streaming Data Input
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,

    // Status & Outputs
    output wire         busy,
    output wire         done,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state
);

    mode_ctrl u_mode_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (start),
        .soft_rst         (soft_rst),
        .mode             (1'b1), // Hash mode
        .decrypt          (1'b0),
        .ad_len           (32'd0),
        .msg_len          (msg_len),
        .key              (128'h0),
        .nonce            (128'h0),
        .expected_tag     (128'h0),
        .data_in          (data_in),
        .data_in_valid    (data_in_valid),
        .data_in_ready    (data_in_ready),
        .data_out         (),
        .data_out_valid   (),
        .data_out_ready   (1'b1),
        .pt_gate_rd_addr  (8'd0),
        .pt_gate_rd_data  (),
        .pt_gate_rd_valid (),
        .busy             (busy),
        .done             (done),
        .error            (),
        .tag_ok           (),
        .tag_out          (),
        .digest_out       (digest_out),
        .fsm_state_code   (fsm_state)
    );

endmodule
