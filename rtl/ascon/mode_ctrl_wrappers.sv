// ==============================================================================
// Out-of-Context Synthesis Wrappers for Ascon Engine (mode_ctrl)
// File: rtl/ascon/mode_ctrl_wrappers.sv
// Target: AMD-Xilinx 7-Series (xc7z010clg400-1) @ 100 MHz
// Fulfills Task T7: Engine-Level Area and Timing Characterization
// ==============================================================================

`timescale 1ns / 1ps

module mode_ctrl_1r_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(1),
        .SBOX_TYPE("BASELINE")
    ) u_engine (.*);
endmodule

module mode_ctrl_1r_espresso_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(1),
        .SBOX_TYPE("ESPRESSO")
    ) u_engine (.*);
endmodule

module mode_ctrl_2r_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(2),
        .SBOX_TYPE("BASELINE")
    ) u_engine (.*);
endmodule

module mode_ctrl_half_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(0),
        .SBOX_TYPE("BASELINE")
    ) u_engine (.*);
endmodule

module mode_ctrl_serial32_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(3),
        .SBOX_TYPE("BASELINE")
    ) u_engine (.*);
endmodule

module mode_ctrl_1r_kernel_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(1),
        .SBOX_TYPE("KERNEL")
    ) u_engine (.*);
endmodule

module mode_ctrl_1r_bdd_wrap (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,
    input  wire         decrypt,
    input  wire [ 31:0] ad_len,
    input  wire [ 31:0] msg_len,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire [127:0] expected_tag,
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output wire         data_in_ready,
    output wire [ 63:0] data_out,
    output wire         data_out_valid,
    input  wire         data_out_ready,
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,
    output wire         busy,
    output wire         done,
    output wire         error,
    output wire         tag_ok,
    output wire [127:0] tag_out,
    output wire [255:0] digest_out,
    output wire [  3:0] fsm_state_code
);
    mode_ctrl #(
        .BUFFER_DEPTH(32),
        .PERM_VARIANT(1),
        .SBOX_TYPE("BDD")
    ) u_engine (.*);
endmodule

