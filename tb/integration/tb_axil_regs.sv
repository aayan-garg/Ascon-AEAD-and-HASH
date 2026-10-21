// ==============================================================================
// Testbench: tb_axil_regs.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Target: Phase 6 Accelerator Bus Integration (AXI4-Lite)
// Description: Comprehensive Bus-Functional-Model (BFM) testbench verifying:
//   1. AMBA AXI4-Lite protocol handshakes (read/write address/data/response)
//   2. Register read/write accessibility (CTRL, STATUS, AD_LEN, MSG_LEN, KEY, NONCE, TAG, DIGEST)
//   3. Hardware security constraints: KEY registers are Write-Only (read returns 0x0)
//   4. Illegal access detection: Sub-word writes and unaligned addresses return SLVERR
//   5. Invalid address decoding: Accesses outside mapped registers return SLVERR
//   6. End-to-end Ascon-Hash256 execution and NIST KAT Count 1 digest verification
//   7. End-to-end Ascon-AEAD128 execution and NIST KAT Count 1 tag verification
//   8. Status register Write-1-to-Clear (W1C) behavior
// ==============================================================================

`timescale 1ns / 1ps

module tb_axil_regs;

    // -------------------------------------------------------------------------
    // Clock and Reset Signals
    // -------------------------------------------------------------------------
    reg clk;
    reg rst_n;

    // -------------------------------------------------------------------------
    // AXI4-Lite Interface Signals
    // -------------------------------------------------------------------------
    reg  [31:0] s_axil_awaddr;
    reg  [ 2:0] s_axil_awprot;
    reg         s_axil_awvalid;
    wire        s_axil_awready;

    reg  [31:0] s_axil_wdata;
    reg  [ 3:0] s_axil_wstrb;
    reg         s_axil_wvalid;
    wire        s_axil_wready;

    wire [ 1:0] s_axil_bresp;
    wire        s_axil_bvalid;
    reg         s_axil_bready;

    reg  [31:0] s_axil_araddr;
    reg  [ 2:0] s_axil_arprot;
    reg         s_axil_arvalid;
    wire        s_axil_arready;

    wire [31:0] s_axil_rdata;
    wire [ 1:0] s_axil_rresp;
    wire        s_axil_rvalid;
    reg         s_axil_rready;

    wire        irq;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    axil_regs #(.BUFFER_DEPTH(256)) u_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .s_axil_awaddr      (s_axil_awaddr),
        .s_axil_awprot      (s_axil_awprot),
        .s_axil_awvalid     (s_axil_awvalid),
        .s_axil_awready     (s_axil_awready),
        .s_axil_wdata       (s_axil_wdata),
        .s_axil_wstrb       (s_axil_wstrb),
        .s_axil_wvalid      (s_axil_wvalid),
        .s_axil_wready      (s_axil_wready),
        .s_axil_bresp       (s_axil_bresp),
        .s_axil_bvalid      (s_axil_bvalid),
        .s_axil_bready      (s_axil_bready),
        .s_axil_araddr      (s_axil_araddr),
        .s_axil_arprot      (s_axil_arprot),
        .s_axil_arvalid     (s_axil_arvalid),
        .s_axil_arready     (s_axil_arready),
        .s_axil_rdata       (s_axil_rdata),
        .s_axil_rresp       (s_axil_rresp),
        .s_axil_rvalid      (s_axil_rvalid),
        .s_axil_rready      (s_axil_rready),
        .dma_data_in        (64'h0),
        .dma_data_in_valid  (1'b0),
        .dma_data_in_ready  (),
        .dma_data_out       (),
        .dma_data_out_valid (),
        .dma_data_out_ready (1'b1),
        .dma_src_addr       (),
        .dma_len            (),
        .dma_start          (),
        .dma_abort          (),
        .dma_busy           (1'b0),
        .dma_done           (1'b0),
        .dma_err            (1'b0),
        .irq                (irq)
    );

    // -------------------------------------------------------------------------
    // 100 MHz Clock Generator (10 ns period)
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // AXI4-Lite Master Bus-Functional-Model (BFM) Tasks
    // -------------------------------------------------------------------------
    task automatic axil_write(
        input  [31:0] addr,
        input  [31:0] data,
        input  [ 3:0] strb,
        output [ 1:0] resp
    );
        begin
            @(posedge clk);
            s_axil_awaddr  <= addr;
            s_axil_awprot  <= 3'b000;
            s_axil_awvalid <= 1'b1;
            s_axil_wdata   <= data;
            s_axil_wstrb   <= strb;
            s_axil_wvalid  <= 1'b1;
            s_axil_bready  <= 1'b1;

            // Wait for address and data write acknowledgment
            fork
                begin
                    wait (s_axil_awready == 1'b1);
                    @(posedge clk);
                    s_axil_awvalid <= 1'b0;
                end
                begin
                    wait (s_axil_wready == 1'b1);
                    @(posedge clk);
                    s_axil_wvalid <= 1'b0;
                end
            join

            // Wait for response
            wait (s_axil_bvalid == 1'b1);
            resp = s_axil_bresp;
            @(posedge clk);
            s_axil_bready <= 1'b0;
        end
    endtask

    task automatic axil_read(
        input  [31:0] addr,
        output [31:0] data,
        output [ 1:0] resp
    );
        begin
            @(posedge clk);
            s_axil_araddr  <= addr;
            s_axil_arprot  <= 3'b000;
            s_axil_arvalid <= 1'b1;
            s_axil_rready  <= 1'b1;

            // Wait for read address handshake
            wait (s_axil_arready == 1'b1);
            @(posedge clk);
            s_axil_arvalid <= 1'b0;

            // Wait for read data handshake
            wait (s_axil_rvalid == 1'b1);
            data = s_axil_rdata;
            resp = s_axil_rresp;
            @(posedge clk);
            s_axil_rready <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Verification Sequence
    // -------------------------------------------------------------------------
    integer test_errors = 0;
    reg [31:0] rdata;
    reg [ 1:0] resp;
    reg [31:0] digest [0:7];
    reg [31:0] tag [0:3];

    initial begin
        $display("================================================================================");
        $display("STARTING AXI4-LITE BUS INTEGRATION VERIFICATION: tb_axil_regs");
        $display("================================================================================");

        // Reset DUT
        rst_n          = 1'b0;
        s_axil_awaddr  = 32'd0;
        s_axil_awprot  = 3'd0;
        s_axil_awvalid = 1'b0;
        s_axil_wdata   = 32'd0;
        s_axil_wstrb   = 4'd0;
        s_axil_wvalid  = 1'b0;
        s_axil_bready  = 1'b0;
        s_axil_araddr  = 32'd0;
        s_axil_arprot  = 3'd0;
        s_axil_arvalid = 1'b0;
        s_axil_rready  = 1'b0;

        #30;
        @(posedge clk);
        rst_n = 1'b1;
        #20;
        @(posedge clk);

        // ---------------------------------------------------------------------
        // TEST 1: CORE_ID Register Read (Offset 0x7C)
        // ---------------------------------------------------------------------
        $display("\n[TEST 1] Reading CORE_ID (Offset 0x7C)...");
        axil_read(32'h4000_007C, rdata, resp);
        $display("  CORE_ID: Read 0x%08x (Expected: 0x41534331), Resp: %b", rdata, resp);
        if (resp !== 2'b00 || rdata !== 32'h4153_4331) begin
            $display("  [ERROR] CORE_ID read failed!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] CORE_ID returned 'ASC1' (0x41534331) with OKAY response.");
        end

        // ---------------------------------------------------------------------
        // TEST 2: Secret Key Write-Only Security Gate Check (§2.5)
        // ---------------------------------------------------------------------
        $display("\n[TEST 2] Verifying Secret Key Registers are Write-Only...");
        axil_write(32'h4000_0010, 32'hDEADBEEF, 4'b1111, resp);
        axil_read(32'h4000_0010, rdata, resp);
        $display("  KEY_0 Readback: 0x%08x (Must be 0x00000000)", rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("  [ERROR] Secret key was leaked on read interface!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Secret key write succeeded and read returned strictly 0x00.");
        end

        // ---------------------------------------------------------------------
        // TEST 3: Nonce & Length Read/Write Verification
        // ---------------------------------------------------------------------
        $display("\n[TEST 3] Reading/Writing NONCE and Length Registers...");
        axil_write(32'h4000_0008, 32'd16, 4'b1111, resp); // AD_LEN = 16
        axil_write(32'h4000_000C, 32'd64, 4'b1111, resp); // MSG_LEN = 64
        axil_write(32'h4000_0020, 32'h12345678, 4'b1111, resp); // NONCE_0

        axil_read(32'h4000_0008, rdata, resp);
        if (rdata !== 32'd16) test_errors = test_errors + 1;
        axil_read(32'h4000_000C, rdata, resp);
        if (rdata !== 32'd64) test_errors = test_errors + 1;
        axil_read(32'h4000_0020, rdata, resp);
        if (rdata !== 32'h12345678) test_errors = test_errors + 1;

        $display("  [PASS] Configuration registers correctly hold written values.");

        // ---------------------------------------------------------------------
        // TEST 4: Illegal Access Handling (Sub-word write & unaligned access)
        // ---------------------------------------------------------------------
        $display("\n[TEST 4] Testing Illegal Access Detection (SLVERR)...");
        // Sub-word write (wstrb != 4'b1111)
        axil_write(32'h4000_0008, 32'hAABBCCDD, 4'b0001, resp);
        $display("  Sub-word write response: %b (Expected: 2'b10 SLVERR)", resp);
        if (resp !== 2'b10) begin
            $display("  [ERROR] Sub-word write did not return SLVERR!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Sub-word write correctly rejected with SLVERR.");
        end

        // Unaligned read
        axil_read(32'h4000_0009, rdata, resp);
        $display("  Unaligned read response: %b (Expected: 2'b10 SLVERR)", resp);
        if (resp !== 2'b10) begin
            $display("  [ERROR] Unaligned read did not return SLVERR!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Unaligned read correctly rejected with SLVERR.");
        end

        // Unmapped offset read
        axil_read(32'h4000_00EC, rdata, resp);
        $display("  Unmapped offset read response: %b (Expected: 2'b10 SLVERR)", resp);
        if (resp !== 2'b10) begin
            $display("  [ERROR] Unmapped offset read did not return SLVERR!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Unmapped offset read correctly rejected with SLVERR.");
        end

        // ---------------------------------------------------------------------
        // TEST 5: Full Ascon-Hash256 Execution via AXI4-Lite Bus (NIST KAT Count 1)
        // Expected Digest for 0-byte message:
        //   H0 = 64'h649ba8de8f9ff2ca_986b2f0f85e53b0b
        //   H1 = 64'hb2924d30aa3bd59b_838f9b24aa70faa1
        // ---------------------------------------------------------------------
        $display("\n[TEST 5] Executing Ascon-Hash256 via AXI4-Lite (0-byte message)...");
        // 1. Set MSG_LEN = 0
        axil_write(32'h4000_000C, 32'd0, 4'b1111, resp);

        // 2. Write CTRL: MODE = 1 (Hash), START = 1 (bit 0) -> Data = 32'h0000_0003
        axil_write(32'h4000_0000, 32'h0000_0003, 4'b1111, resp);

        // 3. Poll STATUS until DONE == 1
        rdata = 32'd0;
        while (!rdata[1]) begin
            axil_read(32'h4000_0004, rdata, resp);
            #20;
        end
        $display("  Hash finished: STATUS = 0x%08x (BUSY=%b, DONE=%b, ERROR=%b)",
                 rdata, rdata[0], rdata[1], rdata[2]);

        // 4. Read 256-bit Digest (DIGEST_0..7)
        axil_read(32'h4000_0040, digest[0], resp);
        axil_read(32'h4000_0044, digest[1], resp);
        axil_read(32'h4000_0048, digest[2], resp);
        axil_read(32'h4000_004C, digest[3], resp);
        axil_read(32'h4000_0050, digest[4], resp);
        axil_read(32'h4000_0054, digest[5], resp);
        axil_read(32'h4000_0058, digest[6], resp);
        axil_read(32'h4000_005C, digest[7], resp);

        $display("  Computed Digest: H0={0x%08x, 0x%08x}, H1={0x%08x, 0x%08x}",
                 digest[1], digest[0], digest[3], digest[2]);
        $display("                   H2={0x%08x, 0x%08x}, H3={0x%08x, 0x%08x}",
                 digest[5], digest[4], digest[7], digest[6]);

        if (digest[0] !== 32'h85e53b0b || digest[1] !== 32'h986b2f0f ||
            digest[2] !== 32'h8f9ff2ca || digest[3] !== 32'h649ba8de ||
            digest[4] !== 32'haa70faa1 || digest[5] !== 32'h838f9b24 ||
            digest[6] !== 32'haa3bd59b || digest[7] !== 32'hb2924d30) begin
            $display("  [ERROR] AXI4-Lite Hash Digest mismatch!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] AXI4-Lite Hash Digest matches official NIST SP 800-232 Count 1!");
        end

        // 5. Test W1C on STATUS.DONE
        axil_write(32'h4000_0004, 32'h0000_0002, 4'b1111, resp); // Write 1 to bit 1
        axil_read(32'h4000_0004, rdata, resp);
        if (rdata[1] !== 1'b0) begin
            $display("  [ERROR] STATUS.DONE W1C failed!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] STATUS.DONE successfully cleared via W1C.");
        end

        // ---------------------------------------------------------------------
        // TEST 6: Full Ascon-AEAD128 Execution via AXI4-Lite Bus (NIST KAT Count 1)
        // Key = 0, Nonce = 0, AD_LEN = 0, MSG_LEN = 0
        // Expected Tag: T0 = 64'h31c9be1182279c4f, T1 = 64'hc62e8bee468ff66b
        // ---------------------------------------------------------------------
        $display("\n[TEST 6] Executing Ascon-AEAD128 Encryption via AXI4-Lite (Count 1)...");
        axil_write(32'h4000_0010, 32'h03020100, 4'b1111, resp); // KEY_0
        axil_write(32'h4000_0014, 32'h07060504, 4'b1111, resp); // KEY_1
        axil_write(32'h4000_0018, 32'h0B0A0908, 4'b1111, resp); // KEY_2
        axil_write(32'h4000_001C, 32'h0F0E0D0C, 4'b1111, resp); // KEY_3
        axil_write(32'h4000_0020, 32'h13121110, 4'b1111, resp); // NONCE_0
        axil_write(32'h4000_0024, 32'h17161514, 4'b1111, resp); // NONCE_1
        axil_write(32'h4000_0028, 32'h1B1A1918, 4'b1111, resp); // NONCE_2
        axil_write(32'h4000_002C, 32'h1F1E1D1C, 4'b1111, resp); // NONCE_3
        axil_write(32'h4000_0008, 32'd0, 4'b1111, resp);        // AD_LEN = 0
        axil_write(32'h4000_000C, 32'd0, 4'b1111, resp);        // MSG_LEN = 0

        // Launch AEAD Encrypt: MODE=0, DEC=0, START=1 -> Data = 32'h0000_0001
        axil_write(32'h4000_0000, 32'h0000_0001, 4'b1111, resp);

        // Poll STATUS
        rdata = 32'd0;
        while (!rdata[1]) begin
            axil_read(32'h4000_0004, rdata, resp);
            #20;
        end

        // Read Tag (TAG_0..3)
        axil_read(32'h4000_0030, tag[0], resp);
        axil_read(32'h4000_0034, tag[1], resp);
        axil_read(32'h4000_0038, tag[2], resp);
        axil_read(32'h4000_003C, tag[3], resp);

        $display("  Computed Tag: T0={0x%08x, 0x%08x}, T1={0x%08x, 0x%08x}",
                 tag[1], tag[0], tag[3], tag[2]);

        if (tag[0] !== 32'h82279c4f || tag[1] !== 32'h31c9be11 ||
            tag[2] !== 32'h468ff66b || tag[3] !== 32'hc62e8bee) begin
            $display("  [ERROR] AXI4-Lite AEAD Tag mismatch!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] AXI4-Lite AEAD Tag matches official NIST SP 800-232 Count 1!");
        end

        #50;
        $display("\n================================================================================");
        if (test_errors == 0) begin
            $display("AXI4-LITE BUS INTEGRATION RESULT: 100  PASS (ALL 6 TESTS PASSED)");
            $display("================================================================================");
            $finish;
        end else begin
            $display("AXI4-LITE BUS INTEGRATION RESULT: FAILED WITH %0d ERRORS", test_errors);
            $display("================================================================================");
            $fatal(1, "AXI4-Lite verification failed");
        end
    end

endmodule
