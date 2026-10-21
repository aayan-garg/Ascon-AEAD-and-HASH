// ==============================================================================
// Module: plaintext_gate.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Hardware Plaintext Release Security Gate with Active Zeroization.
//
// Security Constraints (Project_PS.md §10.3, Threat Model T-3):
//   1. In AEAD decryption mode, candidate plaintext bytes decrypted from ciphertext
//      MUST NOT be observable on any external interface until the 128-bit
//      authentication tag is fully verified (tag_ok == 1'b1).
//   2. If authentication fails (auth_fail == 1'b1) or is aborted, all decrypted
//      plaintext residing in the shadow buffer MUST be actively zeroized.
//   3. External read attempts when tag_ok == 1'b0 MUST return strictly 0x00000000.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module plaintext_gate #(
    parameter int BUFFER_DEPTH = 256 // 256 x 64-bit words = 2,048 bytes
) (
    input  wire        clk,
    input  wire        rst_n,

    // Internal Write Interface (driven by mode_ctrl during decryption)
    input  wire        wr_clear,       // Clear buffer & reset pointers
    input  wire        wr_en,          // Write candidate word
    input  wire [ 7:0] wr_addr,        // Word index
    input  wire [63:0] wr_data,        // Decrypted candidate plaintext word

    // Security Gate Controls (driven by mode_ctrl upon tag check)
    input  wire        tag_ok,         // 1: Tag verified; release plaintext
    input  wire        auth_fail,      // 1: Tag mismatch; trigger zeroization

    // External Read Interface (read by DMA master or CPU via AXI4-Lite)
    input  wire [ 7:0] rd_addr,        // Word index to read
    output wire [63:0] rd_data,        // Plaintext output word (gated)
    output wire        rd_valid        // Valid data available
);

    // -------------------------------------------------------------------------
    // Internal Shadow Buffer Storage
    // -------------------------------------------------------------------------
    reg [63:0] mem [0:BUFFER_DEPTH-1];
    reg [ 8:0] wipe_idx;
    reg        is_wiping;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
                mem[i] <= 64'h0;
            end
            is_wiping <= 1'b0;
            wipe_idx  <= 9'd0;
        end else begin
            if (auth_fail) begin
                // Trigger active zeroization
                is_wiping <= 1'b1;
                wipe_idx  <= 9'd0;
                for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
                    mem[i] <= 64'h0;
                end
            end else if (is_wiping) begin
                mem[wipe_idx[7:0]] <= 64'h0;
                if (wipe_idx == BUFFER_DEPTH - 1) begin
                    is_wiping <= 1'b0;
                end else begin
                    wipe_idx <= wipe_idx + 1'b1;
                end
            end else if (wr_clear) begin
                for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
                    mem[i] <= 64'h0;
                end
            end else if (wr_en && !tag_ok) begin
                // Only allow writing while unauthenticated / during decryption
                mem[wr_addr] <= wr_data;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Hardware Plaintext Release Gate
    // -------------------------------------------------------------------------
    // If tag_ok is NOT asserted, rd_data is structurally forced to 0.
    // If auth_fail is asserted or wiping, rd_data is strictly 0.
    wire gate_open = tag_ok && !auth_fail && !is_wiping;

    assign rd_data  = gate_open ? mem[rd_addr] : 64'h0;
    assign rd_valid = gate_open;

endmodule
