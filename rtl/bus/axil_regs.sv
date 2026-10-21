// ==============================================================================
// Module: axil_regs.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: AXI4-Lite Memory-Mapped Register File & Accelerator Control Plane.
//
// Specifications (docs/register_map.md & ARM IHI 0022E):
//   - Base Address: 0x4000_0000 (4 KB window: 0x4000_0000 - 0x4000_0FFF)
//   - 32-bit Data Bus, Synchronous, Little-Endian
//   - Read/Write Registers: CTRL, STATUS, AD_LEN, MSG_LEN, KEY, NONCE, TAG,
//     DIGEST, DMA controls, IRQ_EN, DATA_IN, CORE_ID
//   - Plaintext Shadow Buffer Read Window: 0x400 - 0x7FC (256 x 32-bit words)
//   - Security: KEY registers are Write-Only (read returns 0x0)
//   - Sub-word access / unaligned access returns SLVERR
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module axil_regs #(
    parameter int BUFFER_DEPTH = 256
) (
    input  wire        clk,
    input  wire        rst_n,

    // =========================================================================
    // AXI4-Lite Slave Interface (AMBA AXI4-Lite Protocol)
    // =========================================================================
    // Write Address Channel
    input  wire [31:0] s_axil_awaddr,
    input  wire [ 2:0] s_axil_awprot,
    input  wire        s_axil_awvalid,
    output reg         s_axil_awready,

    // Write Data Channel
    input  wire [31:0] s_axil_wdata,
    input  wire [ 3:0] s_axil_wstrb,
    input  wire        s_axil_wvalid,
    output reg         s_axil_wready,

    // Write Response Channel
    output reg  [ 1:0] s_axil_bresp,
    output reg         s_axil_bvalid,
    input  wire        s_axil_bready,

    // Read Address Channel
    input  wire [31:0] s_axil_araddr,
    input  wire [ 2:0] s_axil_arprot,
    input  wire        s_axil_arvalid,
    output reg         s_axil_arready,

    // Read Data Channel
    output reg  [31:0] s_axil_rdata,
    output reg  [ 1:0] s_axil_rresp,
    output reg         s_axil_rvalid,
    input  wire        s_axil_rready,

    // =========================================================================
    // External Streaming / DMA Data Interface (Used by Phase 7 DMA Master)
    // =========================================================================
    input  wire [63:0] dma_data_in,
    input  wire        dma_data_in_valid,
    output wire        dma_data_in_ready,

    output wire [63:0] dma_data_out,
    output wire        dma_data_out_valid,
    input  wire        dma_data_out_ready,

    // DMA Configuration Output to dma_master
    output wire [31:0] dma_src_addr,
    output wire [31:0] dma_len,
    output wire        dma_start,
    output wire        dma_abort,
    input  wire        dma_busy,
    input  wire        dma_done,
    input  wire        dma_err,

    // Interrupt Line
    output wire        irq
);

    // -------------------------------------------------------------------------
    // AXI4-Lite Response Constants
    // -------------------------------------------------------------------------
    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    localparam [31:0] CORE_ID_VAL    = 32'h4153_4331; // ASCII "ASC1"

    // -------------------------------------------------------------------------
    // Internal Registers (docs/register_map.md)
    // -------------------------------------------------------------------------
    // 0x00: CTRL
    reg        r_ctrl_mode;     // Bit 1: 0=AEAD128, 1=Hash256
    reg        r_ctrl_dec;      // Bit 2: 0=Encrypt/Hash, 1=Decrypt
    reg        r_ctrl_dma_auto; // Bit 4: 1=Trigger DMA on START
    reg        r_start_pulse;
    reg        r_soft_rst_pulse;

    // 0x04: STATUS (Sticky W1C)
    reg        r_status_done;
    reg        r_status_error;

    // 0x08: AD_LEN, 0x0C: MSG_LEN
    reg [31:0] r_ad_len;
    reg [31:0] r_msg_len;

    // 0x10 - 0x1C: KEY[0..3] (Write-Only)
    reg [31:0] r_key [0:3];

    // 0x20 - 0x2C: NONCE[0..3] (R/W)
    reg [31:0] r_nonce [0:3];

    // 0x30 - 0x3C: TAG[0..3] (R/W expected tag on Decrypt; RO computed tag on Encrypt)
    reg [31:0] r_expected_tag [0:3];

    // 0x60 - 0x6C: DMA Registers
    reg [31:0] r_dma_src_addr;
    reg [31:0] r_dma_len;
    reg        r_dma_start_pulse;
    reg        r_dma_abort_pulse;

    // 0x70: IRQ_EN
    reg [31:0] r_irq_en;

    // 0x74 - 0x78: CPU Direct Data Write (PIO)
    reg [31:0] r_data_in_0;
    reg [63:0] r_pio_data;
    reg        r_pio_valid;

    // -------------------------------------------------------------------------
    // Mode Controller Connections
    // -------------------------------------------------------------------------
    wire         mc_busy;
    wire         mc_done;
    wire         mc_error;
    wire         mc_tag_ok;
    wire [127:0] mc_tag_out;
    wire [255:0] mc_digest_out;
    wire [  3:0] mc_fsm_state;

    wire [ 63:0] mc_data_in;
    wire         mc_data_in_valid;
    wire         mc_data_in_ready;

    wire [ 63:0] mc_data_out;
    wire         mc_data_out_valid;
    wire         mc_data_out_ready;

    wire [  7:0] pt_gate_rd_addr;
    wire [ 63:0] pt_gate_rd_data;
    wire         pt_gate_rd_valid;

    // Edge detectors for status latching
    reg mc_done_d;
    reg mc_error_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mc_done_d  <= 1'b0;
            mc_error_d <= 1'b0;
        end else begin
            mc_done_d  <= mc_done;
            mc_error_d <= mc_error;
        end
    end
    wire mc_done_pulse  = mc_done && !mc_done_d;
    wire mc_error_pulse = mc_error && !mc_error_d;

    // Multiplex between DMA streaming and CPU PIO streaming
    wire use_dma = r_ctrl_dma_auto || dma_busy;

    assign mc_data_in        = use_dma ? dma_data_in        : r_pio_data;
    assign mc_data_in_valid  = use_dma ? dma_data_in_valid  : r_pio_valid;
    assign dma_data_in_ready = use_dma ? mc_data_in_ready   : 1'b0;

    assign dma_data_out       = mc_data_out;
    assign dma_data_out_valid = mc_data_out_valid;
    assign mc_data_out_ready  = use_dma ? dma_data_out_ready : 1'b1;

    // Instantiate Mode Controller (core cryptographic engine)
    mode_ctrl #(.BUFFER_DEPTH(BUFFER_DEPTH)) u_mode_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (r_start_pulse),
        .soft_rst         (r_soft_rst_pulse),
        .mode             (r_ctrl_mode),
        .decrypt          (r_ctrl_dec),
        .ad_len           (r_ad_len),
        .msg_len          (r_msg_len),
        .key              ({r_key[3], r_key[2], r_key[1], r_key[0]}),
        .nonce            ({r_nonce[3], r_nonce[2], r_nonce[1], r_nonce[0]}),
        .expected_tag     ({r_expected_tag[3], r_expected_tag[2], r_expected_tag[1], r_expected_tag[0]}),
        .data_in          (mc_data_in),
        .data_in_valid    (mc_data_in_valid),
        .data_in_ready    (mc_data_in_ready),
        .data_out         (mc_data_out),
        .data_out_valid   (mc_data_out_valid),
        .data_out_ready   (mc_data_out_ready),
        .pt_gate_rd_addr  (pt_gate_rd_addr),
        .pt_gate_rd_data  (pt_gate_rd_data),
        .pt_gate_rd_valid (pt_gate_rd_valid),
        .busy             (mc_busy),
        .done             (mc_done),
        .error            (mc_error),
        .tag_ok           (mc_tag_ok),
        .tag_out          (mc_tag_out),
        .digest_out       (mc_digest_out),
        .fsm_state_code   (mc_fsm_state)
    );

    // DMA Output Assignments
    assign dma_src_addr = r_dma_src_addr;
    assign dma_len      = r_dma_len;
    assign dma_start    = r_dma_start_pulse;
    assign dma_abort    = r_dma_abort_pulse;

    // Interrupt Line
    assign irq = (r_irq_en[0] && r_status_done) || (r_irq_en[1] && r_status_error);

    // -------------------------------------------------------------------------
    // AXI4-Lite Address Latching & Handshake Control
    // -------------------------------------------------------------------------
    reg [11:0] waddr_reg;
    reg [11:0] raddr_reg;
    reg        aw_en;

    // Write address decode helper
    wire is_pt_window_w = (waddr_reg >= 12'h400 && waddr_reg < 12'h800);
    wire is_pt_window_r = (raddr_reg >= 12'h400 && raddr_reg < 12'h800);

    // Shadow buffer read indexing (256 64-bit words -> 512 32-bit words)
    wire [8:0] pt_word_idx = (raddr_reg - 12'h400) >> 2;
    assign pt_gate_rd_addr = pt_word_idx[8:1];

    // =========================================================================
    // AXI4-Lite Write Channel
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axil_awready    <= 1'b0;
            s_axil_wready     <= 1'b0;
            s_axil_bvalid     <= 1'b0;
            s_axil_bresp      <= AXI_RESP_OKAY;
            waddr_reg         <= 12'd0;
            aw_en             <= 1'b1;

            r_ctrl_mode       <= 1'b0;
            r_ctrl_dec        <= 1'b0;
            r_ctrl_dma_auto   <= 1'b0;
            r_start_pulse     <= 1'b0;
            r_soft_rst_pulse  <= 1'b0;
            r_status_done     <= 1'b0;
            r_status_error    <= 1'b0;
            r_ad_len          <= 32'd0;
            r_msg_len         <= 32'd0;
            r_key[0]          <= 32'd0;
            r_key[1]          <= 32'd0;
            r_key[2]          <= 32'd0;
            r_key[3]          <= 32'd0;
            r_nonce[0]        <= 32'd0;
            r_nonce[1]        <= 32'd0;
            r_nonce[2]        <= 32'd0;
            r_nonce[3]        <= 32'd0;
            r_expected_tag[0] <= 32'd0;
            r_expected_tag[1] <= 32'd0;
            r_expected_tag[2] <= 32'd0;
            r_expected_tag[3] <= 32'd0;
            r_dma_src_addr    <= 32'd0;
            r_dma_len         <= 32'd0;
            r_dma_start_pulse <= 1'b0;
            r_dma_abort_pulse <= 1'b0;
            r_irq_en          <= 32'd0;
            r_data_in_0       <= 32'd0;
            r_pio_data        <= 64'd0;
            r_pio_valid       <= 1'b0;
        end else begin
            // Default single-cycle pulses
            r_start_pulse     <= 1'b0;
            r_soft_rst_pulse  <= 1'b0;
            r_dma_start_pulse <= 1'b0;
            r_dma_abort_pulse <= 1'b0;

            if (r_pio_valid && mc_data_in_ready) begin
                r_pio_valid <= 1'b0;
            end

            // Capture hardware events into status bits (edge-detected)
            if (mc_done_pulse)  r_status_done  <= 1'b1;
            if (mc_error_pulse) r_status_error <= 1'b1;

            // AWREADY handshake
            if (!s_axil_awready && s_axil_awvalid && s_axil_wvalid && aw_en) begin
                s_axil_awready <= 1'b1;
                s_axil_wready  <= 1'b1;
                waddr_reg      <= s_axil_awaddr[11:0];
                aw_en          <= 1'b0;
            end else begin
                s_axil_awready <= 1'b0;
                s_axil_wready  <= 1'b0;
            end

            // Write execution & BVALID generation
            if (s_axil_awready && s_axil_wready) begin
                s_axil_bvalid <= 1'b1;

                // Sub-word write or unaligned access check
                if (s_axil_wstrb != 4'b1111 || waddr_reg[1:0] != 2'b00) begin
                    s_axil_bresp <= AXI_RESP_SLVERR;
                end else begin
                    s_axil_bresp <= AXI_RESP_OKAY;

                    case (waddr_reg)
                        // 0x00: CTRL
                        12'h000: begin
                            if (s_axil_wdata[0] && !mc_busy) begin
                                r_start_pulse  <= 1'b1;
                                r_status_done  <= 1'b0;
                                r_status_error <= 1'b0;
                                if (s_axil_wdata[4]) r_dma_start_pulse <= 1'b1;
                            end
                            r_ctrl_mode     <= s_axil_wdata[1];
                            r_ctrl_dec      <= s_axil_wdata[2];
                            if (s_axil_wdata[3]) r_soft_rst_pulse <= 1'b1;
                            r_ctrl_dma_auto <= s_axil_wdata[4];
                        end

                        // 0x04: STATUS (W1C bits)
                        12'h004: begin
                            if (s_axil_wdata[1]) r_status_done  <= 1'b0;
                            if (s_axil_wdata[2]) r_status_error <= 1'b0;
                        end

                        // 0x08: AD_LEN
                        12'h008: r_ad_len <= s_axil_wdata;

                        // 0x0C: MSG_LEN
                        12'h00C: r_msg_len <= s_axil_wdata;

                        // 0x10 - 0x1C: KEY_0 - KEY_3 (Write-Only)
                        12'h010: r_key[0] <= s_axil_wdata;
                        12'h014: r_key[1] <= s_axil_wdata;
                        12'h018: r_key[2] <= s_axil_wdata;
                        12'h01C: r_key[3] <= s_axil_wdata;

                        // 0x20 - 0x2C: NONCE_0 - NONCE_3
                        12'h020: r_nonce[0] <= s_axil_wdata;
                        12'h024: r_nonce[1] <= s_axil_wdata;
                        12'h028: r_nonce[2] <= s_axil_wdata;
                        12'h02C: r_nonce[3] <= s_axil_wdata;

                        // 0x30 - 0x3C: TAG_0 - TAG_3
                        12'h030: r_expected_tag[0] <= s_axil_wdata;
                        12'h034: r_expected_tag[1] <= s_axil_wdata;
                        12'h038: r_expected_tag[2] <= s_axil_wdata;
                        12'h03C: r_expected_tag[3] <= s_axil_wdata;

                        // 0x60: DMA_SRC_ADDR
                        12'h060: r_dma_src_addr <= s_axil_wdata;

                        // 0x64: DMA_LEN
                        12'h064: r_dma_len <= s_axil_wdata;

                        // 0x68: DMA_CTRL
                        12'h068: begin
                            if (s_axil_wdata[0]) r_dma_start_pulse <= 1'b1;
                            if (s_axil_wdata[1]) r_dma_abort_pulse <= 1'b1;
                        end

                        // 0x70: IRQ_EN
                        12'h070: r_irq_en <= s_axil_wdata;

                        // 0x74: DATA_IN_0 (Lower 32-bit word)
                        12'h074: r_data_in_0 <= s_axil_wdata;

                        // 0x78: DATA_IN_1 (Upper 32-bit word -> strobes 64-bit beat)
                        12'h078: begin
                            r_pio_data  <= {s_axil_wdata, r_data_in_0};
                            r_pio_valid <= 1'b1;
                        end

                        default: begin
                            // Plaintext window is Read-Only; writing to it or unknown registers returns SLVERR
                            s_axil_bresp <= AXI_RESP_SLVERR;
                        end
                    endcase
                end
            end

            // Complete BVALID handshake
            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
                aw_en         <= 1'b1;
            end
        end
    end

    // =========================================================================
    // AXI4-Lite Read Channel
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axil_arready <= 1'b0;
            s_axil_rvalid  <= 1'b0;
            s_axil_rdata   <= 32'd0;
            s_axil_rresp   <= AXI_RESP_OKAY;
            raddr_reg      <= 12'd0;
        end else begin
            // ARREADY handshake
            if (!s_axil_arready && s_axil_arvalid) begin
                s_axil_arready <= 1'b1;
                raddr_reg      <= s_axil_araddr[11:0];
            end else begin
                s_axil_arready <= 1'b0;
            end

            // RVALID generation & data read mux
            if (s_axil_arready && s_axil_arvalid) begin
                s_axil_rvalid <= 1'b1;

                if (raddr_reg[1:0] != 2'b00) begin
                    // Misaligned read address
                    s_axil_rresp <= AXI_RESP_SLVERR;
                    s_axil_rdata <= 32'd0;
                end else if (is_pt_window_r) begin
                    // Plaintext Shadow Buffer read (0x400 - 0x7FC)
                    s_axil_rresp <= AXI_RESP_OKAY;
                    s_axil_rdata <= pt_word_idx[0] ? pt_gate_rd_data[63:32] : pt_gate_rd_data[31:0];
                end else begin
                    s_axil_rresp <= AXI_RESP_OKAY;

                    case (raddr_reg)
                        // 0x00: CTRL
                        12'h000: s_axil_rdata <= {27'd0, r_ctrl_dma_auto, 1'b0, r_ctrl_dec, r_ctrl_mode, 1'b0};

                        // 0x04: STATUS
                        12'h004: s_axil_rdata <= {24'd0, mc_fsm_state, mc_tag_ok, r_status_error, r_status_done, mc_busy};

                        // 0x08: AD_LEN
                        12'h008: s_axil_rdata <= r_ad_len;

                        // 0x0C: MSG_LEN
                        12'h00C: s_axil_rdata <= r_msg_len;

                        // 0x10 - 0x1C: KEY[0..3] (Write-Only: reads return strictly 0x0)
                        12'h010, 12'h014, 12'h018, 12'h01C: s_axil_rdata <= 32'd0;

                        // 0x20 - 0x2C: NONCE[0..3]
                        12'h020: s_axil_rdata <= r_nonce[0];
                        12'h024: s_axil_rdata <= r_nonce[1];
                        12'h028: s_axil_rdata <= r_nonce[2];
                        12'h02C: s_axil_rdata <= r_nonce[3];

                        // 0x30 - 0x3C: TAG[0..3] (Returns computed tag if Encrypt, expected tag if Decrypt)
                        12'h030: s_axil_rdata <= r_ctrl_dec ? r_expected_tag[0] : mc_tag_out[ 31:  0];
                        12'h034: s_axil_rdata <= r_ctrl_dec ? r_expected_tag[1] : mc_tag_out[ 63: 32];
                        12'h038: s_axil_rdata <= r_ctrl_dec ? r_expected_tag[2] : mc_tag_out[ 95: 64];
                        12'h03C: s_axil_rdata <= r_ctrl_dec ? r_expected_tag[3] : mc_tag_out[127: 96];

                        // 0x40 - 0x5C: DIGEST[0..7] (256-bit Ascon-Hash256 output)
                        12'h040: s_axil_rdata <= mc_digest_out[ 31:  0];
                        12'h044: s_axil_rdata <= mc_digest_out[ 63: 32];
                        12'h048: s_axil_rdata <= mc_digest_out[ 95: 64];
                        12'h04C: s_axil_rdata <= mc_digest_out[127: 96];
                        12'h050: s_axil_rdata <= mc_digest_out[159:128];
                        12'h054: s_axil_rdata <= mc_digest_out[191:160];
                        12'h058: s_axil_rdata <= mc_digest_out[223:192];
                        12'h05C: s_axil_rdata <= mc_digest_out[255:224];

                        // 0x60: DMA_SRC_ADDR
                        12'h060: s_axil_rdata <= r_dma_src_addr;

                        // 0x64: DMA_LEN
                        12'h064: s_axil_rdata <= r_dma_len;

                        // 0x68: DMA_CTRL
                        12'h068: s_axil_rdata <= 32'd0;

                        // 0x6C: DMA_STATUS
                        12'h06C: s_axil_rdata <= {29'd0, dma_err, dma_done, dma_busy};

                        // 0x70: IRQ_EN
                        12'h070: s_axil_rdata <= r_irq_en;

                        // 0x7C: CORE_ID
                        12'h07C: s_axil_rdata <= CORE_ID_VAL;

                        default: begin
                            s_axil_rresp <= AXI_RESP_SLVERR;
                            s_axil_rdata <= 32'd0;
                        end
                    endcase
                end
            end

            // Complete RREADY handshake
            if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end
        end
    end

endmodule
