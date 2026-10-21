// ==============================================================================
// Module: dma_master.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Custom Burst-to-Stream Direct Memory Access (DMA) Engine.
//
// Specifications (docs/architecture.md §7.2 & docs/register_map.md §2.9-2.10):
//   - Dedicated BRAM Port B master reader (no AXI crossbar contention).
//   - Synchronous pipelined read from 32-bit BRAM into 64-bit streaming beats.
//   - Standard valid/ready streaming interface to Ascon mode controller.
//   - Supports arbitrary byte transfer counts:
//       * 0-byte transfer: Immediate completion, no memory read.
//       * 1-byte transfer: Reads 1 word, emits 1 beat with stream_rem = 1.
//       * Single-block: 8 bytes (Hash) or 16 bytes (AEAD).
//       * Multi-block / Multi-KB: Continuously streams with backpressure handling.
//       * Oversized / Misaligned / Out-of-bounds: Triggers status_err.
//   - Abort capability (cfg_abort) terminates transfer immediately.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module dma_master #(
    parameter int BRAM_DATA_WIDTH = 32,
    parameter int BRAM_ADDR_WIDTH = 12,    // 4096 words = 16 KB
    parameter int MAX_BYTES       = 16384  // 16 KB BRAM address boundary
) (
    input  wire        clk,
    input  wire        rst_n,

    // =========================================================================
    // Control & Configuration Interface (from axil_regs)
    // =========================================================================
    input  wire [31:0] cfg_src_addr,
    input  wire [31:0] cfg_len,
    input  wire        cfg_start,
    input  wire        cfg_abort,

    output reg         status_busy,
    output reg         status_done,
    output reg         status_err,

    // =========================================================================
    // Dual-Port BRAM Port B Interface (Synchronous Read)
    // =========================================================================
    output reg  [BRAM_ADDR_WIDTH-1:0] bram_addr,
    output reg                        bram_en,
    input  wire [BRAM_DATA_WIDTH-1:0] bram_rdata,

    // =========================================================================
    // Streaming Data Interface (to mode_ctrl via axil_regs)
    // =========================================================================
    output reg  [63:0] stream_data,
    output reg         stream_valid,
    input  wire        stream_ready,
    output reg         stream_last,
    output reg  [ 2:0] stream_rem
);

    // -------------------------------------------------------------------------
    // DMA State Machine Definition
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        DMA_IDLE          = 3'd0,
        DMA_FETCH_W0      = 3'd1,
        DMA_WAIT_SINGLE   = 3'd2,
        DMA_FETCH_W1      = 3'd3,
        DMA_ASSEMBLE_BEAT = 3'd4,
        DMA_STREAM_WAIT   = 3'd5
    } dma_state_t;

    dma_state_t state_reg;

    // Internal registers
    reg [BRAM_ADDR_WIDTH-1:0] curr_word_addr;
    reg [31:0]                bytes_remaining;
    reg [31:0]                w0_reg;

    // Address & boundary calculation
    wire        is_misaligned = (cfg_src_addr[1:0] != 2'b00);
    wire        addr_out_of_range = (cfg_src_addr[31:14] != 18'd0) || (cfg_src_addr >= MAX_BYTES);
    wire [32:0] end_addr_calc = {1'b0, cfg_src_addr} + {1'b0, cfg_len};
    wire        is_overflow   = (cfg_len[31:15] != 17'd0) || (end_addr_calc > MAX_BYTES);
    wire        param_error   = is_misaligned || addr_out_of_range || is_overflow;

    // -------------------------------------------------------------------------
    // Main DMA Controller
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg       <= DMA_IDLE;
            status_busy     <= 1'b0;
            status_done     <= 1'b0;
            status_err      <= 1'b0;
            bram_addr       <= {BRAM_ADDR_WIDTH{1'b0}};
            bram_en         <= 1'b0;
            stream_data     <= 64'd0;
            stream_valid    <= 1'b0;
            stream_last     <= 1'b0;
            stream_rem      <= 3'd0;
            curr_word_addr  <= {BRAM_ADDR_WIDTH{1'b0}};
            bytes_remaining <= 32'd0;
            w0_reg          <= 32'd0;
        end else begin
            // Global Abort has priority during active transfer
            if (cfg_abort && status_busy) begin
                state_reg    <= DMA_IDLE;
                status_busy  <= 1'b0;
                status_done  <= 1'b0;
                status_err   <= 1'b1;
                bram_en      <= 1'b0;
                stream_valid <= 1'b0;
                stream_last  <= 1'b0;
            end else begin
                case (state_reg)
                    // ---------------------------------------------------------
                    // DMA_IDLE: Await launch pulse
                    // ---------------------------------------------------------
                    DMA_IDLE: begin
                        bram_en      <= 1'b0;
                        stream_valid <= 1'b0;
                        stream_last  <= 1'b0;

                        if (cfg_start) begin
                            status_done <= 1'b0;
                            status_err  <= 1'b0;

                            if (param_error) begin
                                // Invalid boundary, misaligned, or oversized
                                status_busy <= 1'b0;
                                status_err  <= 1'b1;
                                state_reg   <= DMA_IDLE;
                            end else if (cfg_len == 32'd0) begin
                                // 0-byte transfer completes immediately with zero beats
                                status_busy <= 1'b0;
                                status_done <= 1'b1;
                                state_reg   <= DMA_IDLE;
                            end else begin
                                // Launch memory transfer: assert BRAM read for word 0
                                status_busy     <= 1'b1;
                                curr_word_addr  <= cfg_src_addr[BRAM_ADDR_WIDTH+1:2];
                                bytes_remaining <= cfg_len;
                                bram_addr       <= cfg_src_addr[BRAM_ADDR_WIDTH+1:2];
                                bram_en         <= 1'b1;
                                state_reg       <= DMA_FETCH_W0;
                            end
                        end
                    end

                    // ---------------------------------------------------------
                    // DMA_FETCH_W0: BRAM is sampling word 0 address
                    // ---------------------------------------------------------
                    DMA_FETCH_W0: begin
                        if (bytes_remaining <= 32'd4) begin
                            // Only 1 word needed: disable further BRAM reads
                            bram_en   <= 1'b0;
                            state_reg <= DMA_WAIT_SINGLE;
                        end else begin
                            // 2 words needed: initiate BRAM read for word 1
                            bram_addr <= curr_word_addr + 1'b1;
                            bram_en   <= 1'b1;
                            state_reg <= DMA_FETCH_W1;
                        end
                    end

                    // ---------------------------------------------------------
                    // DMA_WAIT_SINGLE: BRAM presents word 0 for <= 4 bytes
                    // ---------------------------------------------------------
                    DMA_WAIT_SINGLE: begin
                        bram_en      <= 1'b0;
                        stream_data  <= {32'd0, bram_rdata};
                        stream_valid <= 1'b1;
                        stream_last  <= 1'b1;
                        stream_rem   <= bytes_remaining[2:0];
                        state_reg    <= DMA_STREAM_WAIT;
                    end

                    // ---------------------------------------------------------
                    // DMA_FETCH_W1: BRAM presents word 0; BRAM is sampling word 1
                    // ---------------------------------------------------------
                    DMA_FETCH_W1: begin
                        w0_reg    <= bram_rdata;  // Capture word 0
                        bram_en   <= 1'b0;        // Word 1 already sampled by BRAM
                        state_reg <= DMA_ASSEMBLE_BEAT;
                    end

                    // ---------------------------------------------------------
                    // DMA_ASSEMBLE_BEAT: BRAM presents word 1; assemble 64-bit beat
                    // ---------------------------------------------------------
                    DMA_ASSEMBLE_BEAT: begin
                        stream_data  <= {bram_rdata, w0_reg}; // {W1, W0}
                        stream_valid <= 1'b1;

                        if (bytes_remaining <= 32'd8) begin
                            stream_last <= 1'b1;
                            stream_rem  <= bytes_remaining[2:0]; // 0 = exactly 8 bytes, 1..7 = remainder
                        end else begin
                            stream_last <= 1'b0;
                            stream_rem  <= 3'd0;
                        end

                        state_reg <= DMA_STREAM_WAIT;
                    end

                    // ---------------------------------------------------------
                    // DMA_STREAM_WAIT: Handshake with Ascon absorption engine
                    // ---------------------------------------------------------
                    DMA_STREAM_WAIT: begin
                        if (stream_valid && stream_ready) begin
                            stream_valid <= 1'b0;

                            if (stream_last) begin
                                // Final word of transfer has been accepted
                                status_busy <= 1'b0;
                                status_done <= 1'b1;
                                state_reg   <= DMA_IDLE;
                            end else begin
                                // More blocks remain to be fetched
                                bytes_remaining <= bytes_remaining - 32'd8;
                                curr_word_addr  <= curr_word_addr + 2'd2;
                                bram_addr       <= curr_word_addr + 2'd2;
                                bram_en         <= 1'b1;
                                state_reg       <= DMA_FETCH_W0;
                            end
                        end
                    end

                    default: state_reg <= DMA_IDLE;
                endcase
            end
        end
    end

endmodule
