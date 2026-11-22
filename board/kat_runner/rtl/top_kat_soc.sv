// ==============================================================================
// Presentation Full-KAT SoC Top-Level: top_kat_soc.sv
// Target: On-Board Verification of ALL 2,114 NIST SP 800-232 KATs on Zybo Z7-10
// Design: Instantiates the UNMODIFIED Ascon-AEAD-and-HASH RTL modules
//   (picorv32_axi, axil_regs, dma_master, mode_ctrl, aead_ctrl, hash_ctrl,
//    plaintext_gate, permutation_1r) with a 128 KB BRAM + MMIO counters/CT-cap.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module top_kat_soc #(
    parameter string FIRMWARE_HEX = "",
    parameter int    RAM_WORDS    = 32768, // 128 KB = 32,768 x 32-bit words
    parameter int    BUFFER_DEPTH = 32     // 32 x 64-bit words = 256 B
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [ 3:0] sw,
    output wire [ 3:0] led,
    output wire [ 2:0] rgb_led,
    output wire        trap,
    output wire        test_pass,
    output wire        kat_done_out,
    output wire        kat_all_pass_out,
    output wire [31:0] kat_hash_pass_out,
    output wire [31:0] kat_aead_enc_pass_out,
    output wire [31:0] kat_aead_dec_pass_out,
    output wire [31:0] kat_fail_cnt_out,
    output wire [31:0] kat_cycles_out
);

    // =========================================================================
    // 1. PicoRV32 RV32I Core (with ENABLE_COUNTERS=1 for rdcycle)
    // =========================================================================
    wire        axi_awvalid, axi_awready;
    wire [31:0] axi_awaddr;
    wire [ 2:0] axi_awprot;
    wire        axi_wvalid, axi_wready;
    wire [31:0] axi_wdata;
    wire [ 3:0] axi_wstrb;
    wire        axi_bvalid, axi_bready;
    wire        axi_arvalid, axi_arready;
    wire [31:0] axi_araddr;
    wire [ 2:0] axi_arprot;
    wire        axi_rvalid, axi_rready;
    wire [31:0] axi_rdata;

    picorv32_axi #(
        .PROGADDR_RESET    (32'h0000_0000),
        .STACKADDR         (32'h0001_FFF0),
        .BARREL_SHIFTER    (1),
        .TWO_STAGE_SHIFT   (0),
        .COMPRESSED_ISA    (0),
        .ENABLE_MUL        (0),
        .ENABLE_DIV        (0),
        .ENABLE_COUNTERS   (1),
        .ENABLE_COUNTERS64 (0),
        .CATCH_MISALIGN    (1),
        .CATCH_ILLINSN     (1)
    ) u_cpu (
        .clk             (clk),
        .resetn          (rst_n),
        .trap            (trap),
        .mem_axi_awvalid (axi_awvalid),
        .mem_axi_awready (axi_awready),
        .mem_axi_awaddr  (axi_awaddr),
        .mem_axi_awprot  (axi_awprot),
        .mem_axi_wvalid  (axi_wvalid),
        .mem_axi_wready  (axi_wready),
        .mem_axi_wdata   (axi_wdata),
        .mem_axi_wstrb   (axi_wstrb),
        .mem_axi_bvalid  (axi_bvalid),
        .mem_axi_bready  (axi_bready),
        .mem_axi_arvalid (axi_arvalid),
        .mem_axi_arready (axi_arready),
        .mem_axi_araddr  (axi_araddr),
        .mem_axi_arprot  (axi_arprot),
        .mem_axi_rvalid  (axi_rvalid),
        .mem_axi_rready  (axi_rready),
        .mem_axi_rdata   (axi_rdata),
        .pcpi_valid      (),
        .pcpi_insn       (),
        .pcpi_rs1        (),
        .pcpi_rs2        (),
        .pcpi_wr         (1'b0),
        .pcpi_rd         (32'b0),
        .pcpi_wait       (1'b0),
        .pcpi_ready      (1'b0),
        .irq             (32'b0),
        .eoi             ()
    );

    // =========================================================================
    // 2. Address Decode
    //    0x0000_0000 - 0x0001_FFFF : 128 KB BRAM
    //    0x1000_0000 - 0x1000_003F : Status / Counter / Ciphertext Capture MMIO
    //    0x4000_0000 - 0x4000_0FFF : Ascon Accelerator (axil_regs)
    // =========================================================================
    wire sel_bram_aw  = (axi_awaddr[31:17] == 15'd0);
    wire sel_gpio_aw  = (axi_awaddr[31:28] == 4'h1);
    wire sel_ascon_aw = (axi_awaddr[31:28] == 4'h4);

    wire sel_bram_ar  = (axi_araddr[31:17] == 15'd0);
    wire sel_gpio_ar  = (axi_araddr[31:28] == 4'h1);
    wire sel_ascon_ar = (axi_araddr[31:28] == 4'h4);

    // =========================================================================
    // 3. 128 KB Dual-Port Block RAM
    // =========================================================================
    (* ram_style = "block" *)
    reg [31:0] bram_mem [0:RAM_WORDS-1];
    reg [31:0] bram_rdata;
    reg        bram_rvalid;
    reg        bram_bvalid;

    initial begin
        if (FIRMWARE_HEX != "") begin
            $display("[KAT-BRAM] Loading 128 KB BRAM from: %s", FIRMWARE_HEX);
            $readmemh(FIRMWARE_HEX, bram_mem);
        end
    end

    wire        cpu_bram_wr = axi_awvalid && axi_wvalid && sel_bram_aw && !bram_bvalid;
    wire        cpu_bram_rd = axi_arvalid && sel_bram_ar && !bram_rvalid && !cpu_bram_wr;
    wire [14:0] bram_port_a = cpu_bram_wr ? axi_awaddr[16:2] : axi_araddr[16:2];

    // True Dual-Port BRAM Port A (single muxed write/read address avoids BRAM duplication)
    always @(posedge clk) begin
        if (cpu_bram_wr) begin
            if (axi_wstrb[0]) bram_mem[bram_port_a][ 7: 0] <= axi_wdata[ 7: 0];
            if (axi_wstrb[1]) bram_mem[bram_port_a][15: 8] <= axi_wdata[15: 8];
            if (axi_wstrb[2]) bram_mem[bram_port_a][23:16] <= axi_wdata[23:16];
            if (axi_wstrb[3]) bram_mem[bram_port_a][31:24] <= axi_wdata[31:24];
        end else if (cpu_bram_rd) begin
            bram_rdata <= bram_mem[bram_port_a];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            bram_bvalid <= 1'b0;
        end else begin
            if (cpu_bram_wr) begin
                bram_bvalid <= 1'b1;
            end else if (axi_bready) begin
                bram_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            bram_rvalid <= 1'b0;
        end else begin
            if (cpu_bram_rd) begin
                bram_rvalid <= 1'b1;
            end else if (axi_rready) begin
                bram_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. Dedicated DMA Port B (addresses < 16 KB: 0x0000_0000 - 0x0000_3FFF)
    // =========================================================================
    wire [11:0] dma_bram_addr;
    wire        dma_bram_en;
    reg  [31:0] dma_bram_rdata;

    always @(posedge clk) begin
        if (dma_bram_en) begin
            dma_bram_rdata <= bram_mem[{3'b000, dma_bram_addr}];
        end
    end

    wire [63:0] dma_stream_data;
    wire        dma_stream_valid;
    wire        dma_stream_ready;
    wire [31:0] dma_src_addr;
    wire [31:0] dma_len;
    (* DONT_TOUCH = "TRUE" *) wire dma_start;
    wire        dma_abort;
    wire        dma_busy;
    (* DONT_TOUCH = "TRUE" *) wire dma_done;
    wire        dma_err;

    dma_master #(
        .BRAM_DATA_WIDTH (32),
        .BRAM_ADDR_WIDTH (12),
        .MAX_BYTES       (16384)
    ) u_dma_master (
        .clk             (clk),
        .rst_n           (rst_n),
        .cfg_src_addr    (dma_src_addr),
        .cfg_len         (dma_len),
        .cfg_start       (dma_start),
        .cfg_abort       (dma_abort),
        .status_busy     (dma_busy),
        .status_done     (dma_done),
        .status_err      (dma_err),
        .bram_addr       (dma_bram_addr),
        .bram_en         (dma_bram_en),
        .bram_rdata      (dma_bram_rdata),
        .stream_data     (dma_stream_data),
        .stream_valid    (dma_stream_valid),
        .stream_ready    (dma_stream_ready),
        .stream_last     (),
        .stream_rem      ()
    );

    // =========================================================================
    // 5. Ascon Accelerator Instance (Untouched axil_regs.sv -> mode_ctrl.sv)
    // =========================================================================
    wire        ascon_awready, ascon_wready, ascon_bvalid;
    wire [ 1:0] ascon_bresp;
    wire        ascon_arready, ascon_rvalid;
    wire [31:0] ascon_rdata;
    wire [ 1:0] ascon_rresp;

    wire [63:0] ascon_data_out;
    wire        ascon_data_out_valid;

    axil_regs #(
        .BUFFER_DEPTH (BUFFER_DEPTH)
    ) u_ascon (
        .clk                (clk),
        .rst_n              (rst_n),
        .s_axil_awaddr      (axi_awaddr),
        .s_axil_awprot      (axi_awprot),
        .s_axil_awvalid     (axi_awvalid && sel_ascon_aw),
        .s_axil_awready     (ascon_awready),
        .s_axil_wdata       (axi_wdata),
        .s_axil_wstrb       (axi_wstrb),
        .s_axil_wvalid      (axi_wvalid && sel_ascon_aw),
        .s_axil_wready      (ascon_wready),
        .s_axil_bresp       (ascon_bresp),
        .s_axil_bvalid      (ascon_bvalid),
        .s_axil_bready      (axi_bready && sel_ascon_aw),
        .s_axil_araddr      (axi_araddr),
        .s_axil_arprot      (axi_arprot),
        .s_axil_arvalid     (axi_arvalid && sel_ascon_ar),
        .s_axil_arready     (ascon_arready),
        .s_axil_rdata       (ascon_rdata),
        .s_axil_rresp       (ascon_rresp),
        .s_axil_rvalid      (ascon_rvalid),
        .s_axil_rready      (axi_rready && sel_ascon_ar),
        .dma_data_in        (dma_stream_data),
        .dma_data_in_valid  (dma_stream_valid),
        .dma_data_in_ready  (dma_stream_ready),
        .dma_data_out       (ascon_data_out),
        .dma_data_out_valid (ascon_data_out_valid),
        .dma_data_out_ready (1'b1),
        .dma_src_addr       (dma_src_addr),
        .dma_len            (dma_len),
        .dma_start          (dma_start),
        .dma_abort          (dma_abort),
        .dma_busy           (dma_busy),
        .dma_done           (dma_done),
        .dma_err            (dma_err),
        .irq                (),
        .tamper_det         (1'b0),
        .boot_jump_enable   (),
        .boot_refuse        (),
        .boot_led_status    ()
    );

    // =========================================================================
    // 6. Status / KAT Counters / AEAD Ciphertext Capture MMIO (0x1000_00xx)
    // =========================================================================
    reg [31:0] gpio_reg;
    (* DONT_TOUCH = "TRUE" *) reg [31:0] kat_hash_pass;
    (* DONT_TOUCH = "TRUE" *) reg [31:0] kat_aead_enc_pass;
    (* DONT_TOUCH = "TRUE" *) reg [31:0] kat_aead_dec_pass;
    (* DONT_TOUCH = "TRUE" *) reg [31:0] kat_fail_cnt;
    (* DONT_TOUCH = "TRUE" *) reg [31:0] kat_status;
    (* DONT_TOUCH = "TRUE" *) reg [31:0] kat_cycles;

    reg [31:0] ct_cap [0:7];
    reg [ 2:0] ct_beat_cnt;

    reg        gpio_bvalid;
    reg        gpio_rvalid;
    reg [31:0] gpio_rdata;

    wire gpio_wr_fire  = axi_awvalid && axi_wvalid && sel_gpio_aw && !gpio_bvalid;
    wire mmio_clear_ct = gpio_wr_fire && (axi_awaddr[5:2] == 4'h7); // 0x1000_001C

    integer k;
    always @(posedge clk) begin
        if (!rst_n) begin
            gpio_reg          <= 32'd0;
            kat_hash_pass     <= 32'd0;
            kat_aead_enc_pass <= 32'd0;
            kat_aead_dec_pass <= 32'd0;
            kat_fail_cnt      <= 32'd0;
            kat_status        <= 32'd0;
            kat_cycles        <= 32'd0;
            ct_beat_cnt       <= 3'd0;
            for (k = 0; k < 8; k = k + 1) ct_cap[k] <= 32'd0;
            gpio_bvalid       <= 1'b0;
            gpio_rvalid       <= 1'b0;
            gpio_rdata        <= 32'd0;
        end else begin
            if (mmio_clear_ct) begin
                ct_beat_cnt <= 3'd0;
                for (k = 0; k < 8; k = k + 1) ct_cap[k] <= 32'd0;
            end else if (ascon_data_out_valid && (ct_beat_cnt < 3'd4)) begin
                ct_cap[{ct_beat_cnt[1:0], 1'b0}] <= ascon_data_out[31:0];
                ct_cap[{ct_beat_cnt[1:0], 1'b1}] <= ascon_data_out[63:32];
                ct_beat_cnt <= ct_beat_cnt + 3'd1;
            end

            if (gpio_wr_fire) begin
                case (axi_awaddr[5:2])
                    4'h0: gpio_reg          <= axi_wdata;
                    4'h1: kat_hash_pass     <= axi_wdata;
                    4'h2: kat_aead_enc_pass <= axi_wdata;
                    4'h3: kat_aead_dec_pass <= axi_wdata;
                    4'h4: kat_fail_cnt      <= axi_wdata;
                    4'h5: kat_status        <= axi_wdata;
                    4'h6: kat_cycles        <= axi_wdata;
                    default: ;
                endcase
                gpio_bvalid <= 1'b1;
            end else if (axi_bready) begin
                gpio_bvalid <= 1'b0;
            end

            if (axi_arvalid && sel_gpio_ar && !gpio_rvalid) begin
                case (axi_araddr[5:2])
                    4'h0: gpio_rdata <= gpio_reg;
                    4'h1: gpio_rdata <= kat_hash_pass;
                    4'h2: gpio_rdata <= kat_aead_enc_pass;
                    4'h3: gpio_rdata <= kat_aead_dec_pass;
                    4'h4: gpio_rdata <= kat_fail_cnt;
                    4'h5: gpio_rdata <= kat_status;
                    4'h6: gpio_rdata <= kat_cycles;
                    4'h7: gpio_rdata <= {29'd0, ct_beat_cnt};
                    4'h8: gpio_rdata <= ct_cap[0];
                    4'h9: gpio_rdata <= ct_cap[1];
                    4'hA: gpio_rdata <= ct_cap[2];
                    4'hB: gpio_rdata <= ct_cap[3];
                    4'hC: gpio_rdata <= ct_cap[4];
                    4'hD: gpio_rdata <= ct_cap[5];
                    4'hE: gpio_rdata <= ct_cap[6];
                    4'hF: gpio_rdata <= ct_cap[7];
                    default: gpio_rdata <= 32'd0;
                endcase
                gpio_rvalid <= 1'b1;
            end else if (axi_rready) begin
                gpio_rvalid <= 1'b0;
            end
        end
    end

    // Expose explicit ILA-friendly scalar flags
    (* DONT_TOUCH = "TRUE" *) wire kat_done     = kat_status[0];
    (* DONT_TOUCH = "TRUE" *) wire kat_all_pass = kat_status[1];

    // =========================================================================
    // 7. AXI4-Lite Slave Multiplexing & External Outputs
    // =========================================================================
    assign axi_awready = sel_bram_aw  ? !bram_bvalid  :
                         sel_gpio_aw  ? !gpio_bvalid  :
                         sel_ascon_aw ? ascon_awready : 1'b0;

    assign axi_wready  = sel_bram_aw  ? !bram_bvalid  :
                         sel_gpio_aw  ? !gpio_bvalid  :
                         sel_ascon_aw ? ascon_wready  : 1'b0;

    assign axi_bvalid  = sel_bram_aw  ? bram_bvalid   :
                         sel_gpio_aw  ? gpio_bvalid   :
                         sel_ascon_aw ? ascon_bvalid  : 1'b0;

    assign axi_arready = sel_bram_ar  ? (!bram_rvalid && !cpu_bram_wr) :
                         sel_gpio_ar  ? !gpio_rvalid  :
                         sel_ascon_ar ? ascon_arready : 1'b0;

    assign axi_rvalid  = sel_bram_ar  ? bram_rvalid   :
                         sel_gpio_ar  ? gpio_rvalid   :
                         sel_ascon_ar ? ascon_rvalid  : 1'b0;

    assign axi_rdata   = sel_bram_ar  ? bram_rdata    :
                         sel_gpio_ar  ? gpio_rdata    :
                         sel_ascon_ar ? ascon_rdata   : 32'd0;

    assign led                   = sw[0] ? {kat_all_pass, kat_done, kat_fail_cnt[0], trap} : gpio_reg[3:0];
    assign rgb_led               = gpio_reg[6:4]; // {B, G, R}
    assign test_pass             = gpio_reg[31];
    assign kat_done_out          = kat_done;
    assign kat_all_pass_out      = kat_all_pass;
    assign kat_hash_pass_out     = kat_hash_pass;
    assign kat_aead_enc_pass_out = kat_aead_enc_pass;
    assign kat_aead_dec_pass_out = kat_aead_dec_pass;
    assign kat_fail_cnt_out      = kat_fail_cnt;
    assign kat_cycles_out        = kat_cycles;

endmodule

