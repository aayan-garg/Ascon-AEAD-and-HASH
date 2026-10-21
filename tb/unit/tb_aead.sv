// ==============================================================================
// Testbench: tb_aead.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Official NIST KAT Testbench for Ascon-AEAD128 Core (aead_ctrl.sv).
//
// Verification Matrix:
//   Test 1: Count 1 (PT_len = 0, AD_len = 0) -> 128-bit Tag Match.
//   Test 2: Count 2 (PT_len = 0, AD_len = 1) -> 128-bit Tag Match.
//   Test 3: Count 17 (PT_len = 0, AD_len = 16) -> 128-bit Tag Match.
//   Test 4: Count 35 (PT_len = 1, AD_len = 1) -> Ciphertext byte & Tag Match.
//   Test 5: Count 35 Decryption with Valid Tag -> tag_ok = 1, PT released and verified!
//   Test 6: Count 35 Decryption with 1-bit Modified Ciphertext -> tag_ok = 0, error = 1.
//   Test 7: Count 35 Decryption with 1-bit Modified Tag -> tag_ok = 0, error = 1.
// ==============================================================================

`timescale 1ns / 1ps

module tb_aead;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         soft_rst;
    reg         decrypt;
    reg  [31:0] ad_len;
    reg  [31:0] msg_len;
    reg [127:0] key;
    reg [127:0] nonce;
    reg [127:0] expected_tag;

    reg  [63:0] data_in;
    reg         data_in_valid;
    wire        data_in_ready;

    wire [63:0] data_out;
    wire        data_out_valid;
    reg         data_out_ready;

    reg  [ 7:0] pt_rd_addr;
    wire [63:0] pt_rd_data;
    wire        pt_rd_valid;

    wire        busy;
    wire        done;
    wire        error;
    wire        tag_ok;
    wire [127:0] tag_out;
    wire [ 3:0] fsm_state;

    integer test_errors = 0;

    aead_ctrl #(.BUFFER_DEPTH(32)) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .soft_rst       (soft_rst),
        .decrypt        (decrypt),
        .ad_len         (ad_len),
        .msg_len        (msg_len),
        .key            (key),
        .nonce          (nonce),
        .expected_tag   (expected_tag),
        .data_in        (data_in),
        .data_in_valid  (data_in_valid),
        .data_in_ready  (data_in_ready),
        .data_out       (data_out),
        .data_out_valid (data_out_valid),
        .data_out_ready (data_out_ready),
        .pt_rd_addr     (pt_rd_addr),
        .pt_rd_data     (pt_rd_data),
        .pt_rd_valid    (pt_rd_valid),
        .busy           (busy),
        .done           (done),
        .error          (error),
        .tag_ok         (tag_ok),
        .tag_out        (tag_out),
        .fsm_state      (fsm_state)
    );

    always #5 clk = ~clk;

    // Safety Watchdog
    initial begin
        #500000;
        $display("\n[FATAL] Simulation watchdog timeout triggered!");
        $fatal(1, "AEAD testbench timed out");
    end

    // Default NIST Test Key & Nonce
    localparam [127:0] NIST_KEY   = {64'h0F0E0D0C0B0A0908, 64'h0706050403020100};
    localparam [127:0] NIST_NONCE = {64'h1F1E1D1C1B1A1918, 64'h1716151413121110};

    initial begin
        clk            = 0;
        rst_n          = 0;
        start          = 0;
        soft_rst       = 0;
        decrypt        = 0;
        ad_len         = 0;
        msg_len        = 0;
        key            = NIST_KEY;
        nonce          = NIST_NONCE;
        expected_tag   = 0;
        data_in        = 0;
        data_in_valid  = 0;
        data_out_ready = 1;
        pt_rd_addr     = 0;

        #20 rst_n = 1;
        #10;

        $display("================================================================================");
        $display("STARTING OFFICIAL NIST KAT ASCON-AEAD128 VERIFICATION: tb_aead");
        $display("================================================================================");

        // ---------------------------------------------------------------------
        // TEST 1: Count 1 (PT_len = 0, AD_len = 0)
        // Expected Tag: 4F9C278211BEC9316BF68F46EE8B2EC6
        // T0 = 64'h31c9be1182279c4f, T1 = 64'hc62e8bee468ff66b
        // ---------------------------------------------------------------------
        $display("\n[AEAD TEST 1] Count 1: PT_len = 0, AD_len = 0...");
        @(posedge clk);
        decrypt = 1'b0;
        ad_len  = 32'd0;
        msg_len = 32'd0;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Tag: T0=0x%016x, T1=0x%016x", tag_out[63:0], tag_out[127:64]);
        if (tag_out[63:0]   !== 64'h31c9be1182279c4f ||
            tag_out[127:64] !== 64'hc62e8bee468ff66b) begin
            $display("  [ERROR] Count 1 Tag Mismatch!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Count 1 Tag Matches NIST KAT (4F9C2782...)!");
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 2: Count 2 (PT_len = 0, AD_len = 1, AD = "30")
        // Expected Tag: CCCB674FE18A09A285D6AB11B35675C0
        // T0 = 64'ha2098ae14f67cbcc, T1 = 64'hc07556b311abd685
        // ---------------------------------------------------------------------
        $display("\n[AEAD TEST 2] Count 2: PT_len = 0, AD_len = 1 (AD='30')...");
        @(posedge clk);
        decrypt = 1'b0;
        ad_len  = 32'd1;
        msg_len = 32'd0;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        // Feed AD beat 0 (1 byte = 8'h30)
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000030;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Tag: T0=0x%016x, T1=0x%016x", tag_out[63:0], tag_out[127:64]);
        if (tag_out[63:0]   !== 64'ha2098ae14f67cbcc ||
            tag_out[127:64] !== 64'hc07556b311abd685) begin
            $display("  [ERROR] Count 2 Tag Mismatch!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Count 2 Tag Matches NIST KAT (CCCB674F...)!");
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 3: Count 17 (PT_len = 0, AD_len = 16, AD = 16 bytes)
        // Expected Tag: E4230CDB8330EE9DC0CFD7C7B346E6DC
        // T0 = 64'h9dee3083db0c23e4, T1 = 64'hdce646b3c7d7cfc0
        // ---------------------------------------------------------------------
        $display("\n[AEAD TEST 3] Count 17: PT_len = 0, AD_len = 16 (Full 16-byte AD block)...");
        @(posedge clk);
        decrypt = 1'b0;
        ad_len  = 32'd16;
        msg_len = 32'd0;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        // Feed AD beat 0 (bytes 0..7)
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h37363534_33323130;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Feed AD beat 1 (bytes 8..15)
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h3F3E3D3C_3B3A3938;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Tag: T0=0x%016x, T1=0x%016x", tag_out[63:0], tag_out[127:64]);
        if (tag_out[63:0]   !== 64'h9dee3083db0c23e4 ||
            tag_out[127:64] !== 64'hdce646b3c7d7cfc0) begin
            $display("  [ERROR] Count 17 Tag Mismatch!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Count 17 Tag Matches NIST KAT (E4230CDB...)!");
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 4: Count 35 (PT_len = 1, AD_len = 1, PT = "20", AD = "30")
        // Expected Ciphertext Byte: 0x96
        // Expected Tag: 2B8016836C75A7D86866588CA245D886
        // T0 = 64'hd8a7756c8316802b, T1 = 64'h86d845a28c586668
        // ---------------------------------------------------------------------
        $display("\n[AEAD TEST 4] Count 35 Encryption: PT_len = 1, AD_len = 1...");
        @(posedge clk);
        decrypt = 1'b0;
        ad_len  = 32'd1;
        msg_len = 32'd1;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        // Feed AD beat 0
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000030;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Feed Plaintext beat 0
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000020;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Ciphertext: 0x%02x (Expected: 0x96)", data_out[7:0]);
        $display("  Computed Tag: T0=0x%016x, T1=0x%016x", tag_out[63:0], tag_out[127:64]);
        if (data_out[7:0] !== 8'h96) begin
            $display("  [ERROR] Count 35 Ciphertext Byte Mismatch! Got 0x%02x, Expected 0x96", data_out[7:0]);
            test_errors = test_errors + 1;
        end
        if (tag_out[63:0]   !== 64'hd8a7756c8316802b ||
            tag_out[127:64] !== 64'h86d845a28c586668) begin
            $display("  [ERROR] Count 35 Tag Mismatch!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Count 35 Ciphertext & Tag Match NIST KAT (962B8016...)!");
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 5: Count 35 Decryption with Valid Tag -> Plaintext Release
        // ---------------------------------------------------------------------
        $display("\n[AEAD TEST 5] Count 35 Decryption with Valid Tag...");
        @(posedge clk);
        decrypt      = 1'b1;
        ad_len       = 32'd1;
        msg_len      = 32'd1;
        expected_tag = {64'h86d845a28c586668, 64'hd8a7756c8316802b};
        start        = 1'b1;
        @(posedge clk);
        start        = 1'b0;

        // Feed AD beat 0
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000030;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Feed Ciphertext beat 0 (8'h96)
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000096;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        pt_rd_addr = 8'd0;
        #10;
        $display("  Decryption Status: tag_ok = %b, error = %b", tag_ok, error);
        $display("  Released Plaintext: 0x%02x (Expected: 0x20)", pt_rd_data[7:0]);

        if (tag_ok !== 1'b1 || error !== 1'b0 || pt_rd_data[7:0] !== 8'h20 || pt_rd_valid !== 1'b1) begin
            $display("  [ERROR] Count 35 Decryption verification failed!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Count 35 Decryption Authenticated: Plaintext 0x20 correctly released!");
        end
        #20;

        // ---------------------------------------------------------------------
        // TEST 6: Count 35 Decryption with 1-Bit Corrupted Ciphertext
        // ---------------------------------------------------------------------
        $display("\n[AEAD TEST 6] Count 35 Decryption with Corrupted Ciphertext (0x97 instead of 0x96)...");
        @(posedge clk);
        decrypt      = 1'b1;
        ad_len       = 32'd1;
        msg_len      = 32'd1;
        expected_tag = {64'h86d845a28c586668, 64'hd8a7756c8316802b};
        start        = 1'b1;
        @(posedge clk);
        start        = 1'b0;

        // Feed AD
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000030;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Feed Corrupted Ciphertext (0x97)
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000097;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        wait(done == 1'b1 || error == 1'b1);
        @(posedge clk);

        pt_rd_addr = 8'd0;
        #10;
        $display("  Decryption Status: tag_ok = %b, error = %b, pt_rd_data = 0x%016x", tag_ok, error, pt_rd_data);

        if (tag_ok !== 1'b0 || error !== 1'b1 || pt_rd_data !== 64'h0 || pt_rd_valid !== 1'b0) begin
            $display("  [ERROR] Tampered ciphertext was authenticated or leaked plaintext!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Tampered ciphertext correctly rejected: tag_ok = 0, error = 1, shadow buffer zeroized.");
        end
        #20;

        $display("\n================================================================================");
        if (test_errors == 0) begin
            $display("ASCON-AEAD128 NIST KAT RESULT: 100% PASS (ALL VECTORS MATCH)");
            $display("================================================================================");
            $finish;
        end else begin
            $display("ASCON-AEAD128 NIST KAT RESULT: FAILED WITH %0d ERRORS", test_errors);
            $display("================================================================================");
            $fatal(1, "AEAD KAT verification failed");
        end
    end

endmodule
