// ==============================================================================
// PicoRV32 Bring-Up SoC Top-Level: top_bringup.sv
// Target: Phase 2 RISC-V Core Bring-Up (Zybo Z7-10)
// Features: PicoRV32 RV32I AXI Core, 16 KB BRAM, AXI4-Lite GPIO Peripheral
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module top_bringup #(
    parameter string FIRMWARE_HEX = "firmware/tests/gpio_toggle.hex",
    parameter int    RAM_WORDS    = 4096 // 16 KB = 4096 x 32-bit words
) (
    input  wire        clk,      // 100 MHz clock
    input  wire        rst_n,    // Active-low asynchronous reset
    output wire [3:0]  led,      // 4 discrete LEDs on Zybo Z7-10 (LD0..LD3)
    output wire [2:0]  rgb_led,  // RGB LED on Zybo Z7-10 (LD6: R, G, B)
    output wire        trap,     // CPU trap indicator
    output wire        test_pass // Simulation completion marker (bit 31 of GPIO)
);

    // =========================================================================
    // 1. AXI4-Lite Master Signals (from PicoRV32)
    // =========================================================================
    wire        axi_awvalid;
    wire        axi_awready;
    wire [31:0] axi_awaddr;
    wire [ 2:0] axi_awprot;

    wire        axi_wvalid;
    wire        axi_wready;
    wire [31:0] axi_wdata;
    wire [ 3:0] axi_wstrb;

    wire        axi_bvalid;
    wire        axi_bready;

    wire        axi_arvalid;
    wire        axi_arready;
    wire [31:0] axi_araddr;
    wire [ 2:0] axi_arprot;

    wire        axi_rvalid;
    wire        axi_rready;
    wire [31:0] axi_rdata;

    // =========================================================================
    // 2. PicoRV32 RV32I Core Instance
    // =========================================================================
    picorv32_axi #(
        .PROGADDR_RESET     (32'h0000_0000),
        .STACKADDR          (32'h0000_3FF0),
        .BARREL_SHIFTER     (1),
        .TWO_STAGE_SHIFT    (0),
        .COMPRESSED_ISA     (0),
        .ENABLE_MUL         (0),
        .ENABLE_DIV         (0),
        .ENABLE_COUNTERS    (1),
        .ENABLE_COUNTERS64  (0),
        .CATCH_MISALIGN     (1),
        .CATCH_ILLINSN      (1)
    ) u_cpu (
        .clk             (clk),
        .resetn          (rst_n),
        .trap            (trap),

        // AXI4-Lite master interface
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

        // Unused coprocessor and IRQ
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
    // 3. AXI4-Lite Address Decoding & Slave Multiplexing
    // =========================================================================
    // Address Map:
    //   0x0000_0000 - 0x0000_3FFF: BRAM (16 KB Instruction & Data)
    //   0x1000_0000 - 0x1000_000F: GPIO Control Register
    wire sel_bram_aw = (axi_awaddr[31:28] == 4'h0);
    wire sel_gpio_aw = (axi_awaddr[31:28] == 4'h1);

    wire sel_bram_ar = (axi_araddr[31:28] == 4'h0);
    wire sel_gpio_ar = (axi_araddr[31:28] == 4'h1);

    // =========================================================================
    // 4. BRAM Controller (16 KB synchronous memory with byte strobes)
    // =========================================================================
    reg [31:0] bram_mem [0:RAM_WORDS-1];
    reg [31:0] bram_rdata;
    reg        bram_rvalid;
    reg        bram_bvalid;

    // Load initial binary hex image
    initial begin
        if (FIRMWARE_HEX != "") begin
            $display("[BRAM] Initializing 16 KB BRAM from: %s", FIRMWARE_HEX);
            $readmemh(FIRMWARE_HEX, bram_mem);
        end
    end

    wire [11:0] bram_waddr = axi_awaddr[13:2];
    wire [11:0] bram_raddr = axi_araddr[13:2];

    // BRAM write port
    always @(posedge clk) begin
        if (!rst_n) begin
            bram_bvalid <= 1'b0;
        end else begin
            if (axi_awvalid && axi_wvalid && sel_bram_aw && !bram_bvalid) begin
                if (axi_wstrb[0]) bram_mem[bram_waddr][ 7: 0] <= axi_wdata[ 7: 0];
                if (axi_wstrb[1]) bram_mem[bram_waddr][15: 8] <= axi_wdata[15: 8];
                if (axi_wstrb[2]) bram_mem[bram_waddr][23:16] <= axi_wdata[23:16];
                if (axi_wstrb[3]) bram_mem[bram_waddr][31:24] <= axi_wdata[31:24];
                bram_bvalid <= 1'b1;
            end else if (axi_bready) begin
                bram_bvalid <= 1'b0;
            end
        end
    end

    // BRAM read port
    always @(posedge clk) begin
        if (!rst_n) begin
            bram_rvalid <= 1'b0;
            bram_rdata  <= 32'b0;
        end else begin
            if (axi_arvalid && sel_bram_ar && !bram_rvalid) begin
                bram_rdata  <= bram_mem[bram_raddr];
                bram_rvalid <= 1'b1;
            end else if (axi_rready) begin
                bram_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 5. GPIO Peripheral Controller (Address 0x1000_0000)
    // =========================================================================
    reg [31:0] gpio_reg;
    reg        gpio_bvalid;
    reg        gpio_rvalid;
    reg [31:0] gpio_rdata;

    always @(posedge clk) begin
        if (!rst_n) begin
            gpio_reg    <= 32'b0;
            gpio_bvalid <= 1'b0;
            gpio_rvalid <= 1'b0;
            gpio_rdata  <= 32'b0;
        end else begin
            // Write port
            if (axi_awvalid && axi_wvalid && sel_gpio_aw && !gpio_bvalid) begin
                if (axi_wstrb[0]) gpio_reg[ 7: 0] <= axi_wdata[ 7: 0];
                if (axi_wstrb[1]) gpio_reg[15: 8] <= axi_wdata[15: 8];
                if (axi_wstrb[2]) gpio_reg[23:16] <= axi_wdata[23:16];
                if (axi_wstrb[3]) gpio_reg[31:24] <= axi_wdata[31:24];
                gpio_bvalid <= 1'b1;
            end else if (axi_bready) begin
                gpio_bvalid <= 1'b0;
            end

            // Read port
            if (axi_arvalid && sel_gpio_ar && !gpio_rvalid) begin
                gpio_rdata  <= gpio_reg;
                gpio_rvalid <= 1'b1;
            end else if (axi_rready) begin
                gpio_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 6. Slave Response Multiplexing to CPU Master
    // =========================================================================
    // AW / W Ready
    assign axi_awready = sel_bram_aw ? !bram_bvalid : (sel_gpio_aw ? !gpio_bvalid : 1'b0);
    assign axi_wready  = sel_bram_aw ? !bram_bvalid : (sel_gpio_aw ? !gpio_bvalid : 1'b0);

    // Write Response (BVALID)
    assign axi_bvalid = sel_bram_aw ? bram_bvalid : (sel_gpio_aw ? gpio_bvalid : 1'b0);

    // AR Ready
    assign axi_arready = sel_bram_ar ? !bram_rvalid : (sel_gpio_ar ? !gpio_rvalid : 1'b0);

    // Read Response (RVALID & RDATA)
    assign axi_rvalid = sel_bram_ar ? bram_rvalid : (sel_gpio_ar ? gpio_rvalid : 1'b0);
    assign axi_rdata  = sel_bram_ar ? bram_rdata  : (sel_gpio_ar ? gpio_rdata  : 32'h0);

    // =========================================================================
    // 7. Output Port Assignments
    // =========================================================================
    assign led       = gpio_reg[3:0];
    assign rgb_led   = gpio_reg[6:4];
    assign test_pass = gpio_reg[31];

endmodule
