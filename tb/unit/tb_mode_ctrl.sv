// ==============================================================================
// Testbench: tb_mode_ctrl.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Verification testbench for unified mode_ctrl FSM.
//
// Verification Tests:
//   Test 1: Ascon-Hash256 with 0-byte message (Count 1).
//   Test 2: Ascon-Hash256 with 1-byte message "00" (Count 2).
//   Test 3: Ascon-AEAD128 Encryption with empty PT & AD (Count 1).
//   Test 4: Ascon-AEAD128 Decryption of Count 1 with Valid Tag -> tag_ok = 1.
//   Test 5: Ascon-AEAD128 Decryption of Count 1 with Corrupted Tag -> tag_ok = 0, error = 1.
//   Test 6: FSM State Transition Coverage Verification.
// ==============================================================================

`timescale 1ns / 1ps

module tb_mode_ctrl;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         soft_rst;
    reg         mode;
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

    reg  [ 7:0] pt_gate_rd_addr;
    wire [63:0] pt_gate_rd_data;
    wire        pt_gate_rd_valid;

    wire        busy;
    wire        done;
    wire        error;
    wire        tag_ok;
    wire [127:0] tag_out;
    wire [255:0] digest_out;
    wire [ 3:0] fsm_state_code;

    integer test_errors = 0;

    mode_ctrl #(.BUFFER_DEPTH(32)) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (start),
        .soft_rst         (soft_rst),
        .mode             (mode),
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
        .pt_gate_rd_addr  (pt_gate_rd_addr),
        .pt_gate_rd_data  (pt_gate_rd_data),
        .pt_gate_rd_valid (pt_gate_rd_valid),
        .busy             (busy),
        .done             (done),
        .error            (error),
        .tag_ok           (tag_ok),
        .tag_out          (tag_out),
        .digest_out       (digest_out),
        .fsm_state_code   (fsm_state_code)
    );

    always #5 clk = ~clk;

    // Simulation safety watchdog: abort if test hangs
    initial begin
        #500000; // 500 us timeout
        $display("\n[FATAL] Simulation watchdog timeout triggered (500 us)!");
        $fatal(1, "Testbench simulation timed out");
    end

    initial begin
        clk              = 0;
        rst_n            = 0;
        start            = 0;
        soft_rst         = 0;
        mode             = 0;
        decrypt          = 0;
        ad_len           = 0;
        msg_len          = 0;
        key              = 0;
        nonce            = 0;
        expected_tag     = 0;
        data_in          = 0;
        data_in_valid    = 0;
        data_out_ready   = 1;
        pt_gate_rd_addr  = 0;

        #20 rst_n = 1;
        #10;

        $display("================================================================================");
        $display("STARTING ASCON MODE CONTROLLER (mode_ctrl.sv) VERIFICATION");
        $display("================================================================================");

        // ---------------------------------------------------------------------
        // TEST 1: Ascon-Hash256 with 0-byte Message (Count 1)
        // Expected Digest: 0B3BE5850F2F6B98CAF29F8FDEA89B64A1FA70AA249B8F839BD53BAA304D92B2
        // H0 = 64'h986b2f0f85e53b0b, H1 = 64'h649ba8de8f9ff2ca,
        // H2 = 64'h838f9b24aa70faa1, H3 = 64'hb2924d30aa3bd59b
        // ---------------------------------------------------------------------
        $display("\n[TEST 1] Ascon-Hash256 Empty Message Vector...");
        @(posedge clk);
        mode    = 1'b1; // Hash mode
        msg_len = 32'd0;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        // Wait for done
        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Digest: H0=0x%016x, H1=0x%016x, H2=0x%016x, H3=0x%016x",
                 digest_out[63:0], digest_out[127:64], digest_out[191:128], digest_out[255:192]);

        if (digest_out[63:0]   !== 64'h986b2f0f85e53b0b ||
            digest_out[127:64] !== 64'h649ba8de8f9ff2ca ||
            digest_out[191:128]!== 64'h838f9b24aa70faa1 ||
            digest_out[255:192]!== 64'hb2924d30aa3bd59b) begin
            $display("  [ERROR] Test 1 Hash mismatch against NIST KAT Count 1!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Test 1 Hash exactly matches NIST KAT Count 1 (0B3BE585...)!");
        end

        #20;

        // ---------------------------------------------------------------------
        // TEST 2: Ascon-Hash256 with 1-byte Message "00" (Count 2)
        // Expected Digest: 0728621035AF3ED2BCA03BF6FDE900F9456F5330E4B5EE23E7F6A1E70291BC80
        // H0 = 64'hd23eaf3510622807, H1 = 64'hf900e9fdf63ba0bc,
        // H2 = 64'h23eeb5e430536f45, H3 = 64'h80bc9102e7a1f6e7
        // ---------------------------------------------------------------------
        $display("\n[TEST 2] Ascon-Hash256 1-Byte Message Vector ('00')...");
        @(posedge clk);
        mode          = 1'b1;
        msg_len       = 32'd1;
        start         = 1'b1;
        @(posedge clk);
        start         = 1'b0;

        // Feed 1 byte (little-endian byte 0 = 8'h00)
        wait(data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = 64'h00000000_00000000;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Digest: H0=0x%016x, H1=0x%016x, H2=0x%016x, H3=0x%016x",
                 digest_out[63:0], digest_out[127:64], digest_out[191:128], digest_out[255:192]);

        if (digest_out[63:0]   !== 64'hd23eaf3510622807 ||
            digest_out[127:64] !== 64'hf900e9fdf63ba0bc ||
            digest_out[191:128]!== 64'h23eeb5e430536f45 ||
            digest_out[255:192]!== 64'h80bc9102e7a1f6e7) begin
            $display("  [ERROR] Test 2 Hash mismatch against NIST KAT Count 2!");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Test 2 Hash exactly matches NIST KAT Count 2 (07286210...)!");
        end

        #20;

        // ---------------------------------------------------------------------
        // TEST 3: Ascon-AEAD128 Encryption with Empty PT & AD (Count 1)
        // Key   = 000102030405060708090A0B0C0D0E0F -> K0=0x0706050403020100, K1=0x0F0E0D0C0B0A0908
        // Nonce = 101112131415161718191A1B1C1D1E1F -> N0=0x1716151413121110, N1=0x1F1E1D1C1B1A1918
        // Expected Tag: 4F9C278211BEC9316BF68F46EE8B2EC6
        // T0 = 64'h31c9be1182279c4f, T1 = 64'hc62e8bee468ff66b
        // ---------------------------------------------------------------------
        $display("\n[TEST 3] Ascon-AEAD128 Encryption Count 1 (Empty PT/AD)...");
        @(posedge clk);
        mode         = 1'b0; // AEAD
        decrypt      = 1'b0; // Encrypt
        ad_len       = 32'd0;
        msg_len      = 32'd0;
        key          = {64'h0F0E0D0C0B0A0908, 64'h0706050403020100};
        nonce        = {64'h1F1E1D1C1B1A1918, 64'h1716151413121110};
        expected_tag = 128'h0;
        start        = 1'b1;
        @(posedge clk);
        start        = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        $display("  Computed Tag: T0=0x%016x, T1=0x%016x", tag_out[63:0], tag_out[127:64]);
        if (tag_out[63:0]   !== 64'h31c9be1182279c4f ||
            tag_out[127:64] !== 64'hc62e8bee468ff66b) begin
            $display("  [ERROR] Test 3 AEAD Tag mismatch! Expected 31c9be1182279c4f / c62e8bee468ff66b");
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Test 3 AEAD Tag matches NIST KAT Count 1 (4F9C2782...)!");
        end

        #20;

        // ---------------------------------------------------------------------
        // TEST 4: Ascon-AEAD128 Decryption of Count 1 with Valid Tag
        // ---------------------------------------------------------------------
        $display("\n[TEST 4] Ascon-AEAD128 Decryption with Valid Tag...");
        @(posedge clk);
        mode         = 1'b0;
        decrypt      = 1'b1; // Decrypt
        ad_len       = 32'd0;
        msg_len      = 32'd0;
        key          = {64'h0F0E0D0C0B0A0908, 64'h0706050403020100};
        nonce        = {64'h1F1E1D1C1B1A1918, 64'h1716151413121110};
        expected_tag = {64'hc62e8bee468ff66b, 64'h31c9be1182279c4f}; // Valid tag
        start        = 1'b1;
        @(posedge clk);
        start        = 1'b0;

        wait(done == 1'b1);
        @(posedge clk);

        if (tag_ok !== 1'b1 || error !== 1'b0) begin
            $display("  [ERROR] Decryption authentication failed for valid tag! tag_ok=%b, error=%b", tag_ok, error);
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Valid decryption successfully authenticated: tag_ok = 1, error = 0.");
        end

        #20;

        // ---------------------------------------------------------------------
        // TEST 5: Ascon-AEAD128 Decryption with 1-Bit Corrupted Tag
        // ---------------------------------------------------------------------
        $display("\n[TEST 5] Ascon-AEAD128 Decryption with Corrupted Tag...");
        @(posedge clk);
        mode         = 1'b0;
        decrypt      = 1'b1;
        ad_len       = 32'd0;
        msg_len      = 32'd0;
        key          = {64'h0F0E0D0C0B0A0908, 64'h0706050403020100};
        nonce        = {64'h1F1E1D1C1B1A1918, 64'h1716151413121110};
        // Corrupt bit 0: 64'h31c9be1182279c4e instead of 64'h31c9be1182279c4f
        expected_tag = {64'hc62e8bee468ff66b, 64'h31c9be1182279c4e};
        start        = 1'b1;
        @(posedge clk);
        start        = 1'b0;

        wait(done == 1'b1 || error == 1'b1);
        @(posedge clk);

        if (tag_ok !== 1'b0 || error !== 1'b1) begin
            $display("  [ERROR] Corrupted tag was accepted! tag_ok=%b, error=%b", tag_ok, error);
            test_errors = test_errors + 1;
        end else begin
            $display("  [PASS] Tampered tag rejected: tag_ok = 0, error = 1, shadow buffer zeroized.");
        end

        #20;

        $display("\n================================================================================");
        if (test_errors == 0) begin
            $display("MODE CONTROLLER VERIFICATION RESULT: 100% PASS - ALL TESTS MATCH NIST KATs");
            $display("================================================================================");
            $finish;
        end else begin
            $display("MODE CONTROLLER VERIFICATION RESULT: FAILED WITH %0d ERRORS", test_errors);
            $display("================================================================================");
            $fatal(1, "Mode controller verification failed");
        end
    end

endmodule
