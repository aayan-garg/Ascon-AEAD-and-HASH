// ==============================================================================
// Module: aead_ctrl.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Dedicated Ascon-AEAD128 Mode Controller Wrapper.
// Features:
//   - Parameterized AEAD128 interface with 128-bit key, 128-bit nonce, 128-bit tag
//   - Supports encryption, decryption, and authentication tag checking
//   - Integrates hardware shadow buffer plaintext gate
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module aead_ctrl #(
    parameter int BUFFER_DEPTH = 256
) (
    input  wire         clk,
    input  wire         rst_n,

    // Control & Setup
    input  wire         start,
    input  wire         soft_rst,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,

    // Streaming Data
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,

    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,

    // Plaintext Gate Read
    input  wire [  7:0] pt_rd_addr,
    output wire [ 63:0] pt_rd_data,
    output wire         pt_rd_valid,

    // Status & Outputs
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [  3:0] fsm_state
);

    mode_ctrl #(.BUFFER_DEPTH(BUFFER_DEPTH)) u_mode_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (start),
        .soft_rst         (soft_rst),
        .mode             (1'b0), // AEAD mode
        .decrypt          (decrypt),
        .ad_len           (ad_len),
        .msg_len          (msg_len),
        .key              (key),
        .nonce            (nonce),
        .expected_tag     (expected_tag),
        .data_in          (data_in),
        .data_in_valid    (data_in_valid),
        .data_in_ready    (data_in_ready),
        .data_out         (data_out),
        .data_out_valid   (data_out_valid),
        .data_out_ready   (data_out_ready),
        .pt_gate_rd_addr  (pt_rd_addr),
        .pt_gate_rd_data  (pt_rd_data),
        .pt_gate_rd_valid (pt_rd_valid),
        .busy             (busy),
        .done             (done),
        .error            (error),
        .tag_ok           (tag_ok),
        .tag_out          (tag_out),
        .digest_out       (),
        .fsm_state_code   (fsm_state)
    );

endmodule
