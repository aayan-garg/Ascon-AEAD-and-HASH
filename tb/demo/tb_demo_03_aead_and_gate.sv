// ==============================================================================
// Presentation Demo 03: Ascon-AEAD128 + Hardware Plaintext Release Gate
// Target: Shows Encrypt -> Authenticated Decrypt -> Tampered Ciphertext Lockout
//
// Using NIST KAT Count 35 (AD = "30", Plaintext = "20", Key & Nonce from NIST):
//   Step 1 (Encrypt): Produces ciphertext 0x96 and 128-bit tag {T1, T0}.
//   Step 2 (Genuine Decrypt): Feeds 0x96 + valid tag -> tag_ok=1, plaintext 0x20
//                             is released from plaintext_gate!
//   Step 3 (Tampered Decrypt): Flips 1 bit of ciphertext (0x96 -> 0x97) ->
//                              tag_ok=0, error=1, pt_rd_data strictly 0x0!
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_03_aead_and_gate;

    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    logic         rst_n, start, soft_rst, decrypt;
    logic [ 31:0] ad_len, msg_len;
    logic [127:0] key, nonce, expected_tag;
    logic [ 63:0] data_in;
    logic         data_in_valid;
    wire          data_in_ready;
    wire  [ 63:0] data_out;
    wire          data_out_valid;
    logic         data_out_ready;
    logic [  7:0] pt_rd_addr;
    wire  [ 63:0] pt_rd_data;
    wire          pt_rd_valid;
    wire          busy, done, error, tag_ok;
    wire  [127:0] tag_out;
    wire  [  3:0] fsm_state;

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

    // NIST KAT Count 35 parameters
    localparam [127:0] NIST_KEY   = {64'h0F0E0D0C0B0A0908, 64'h0706050403020100};
    localparam [127:0] NIST_NONCE = {64'h1F1E1D1C1B1A1918, 64'h1716151413121110};
    localparam [  7:0] NIST_AD    = 8'h30;
    localparam [  7:0] NIST_PT    = 8'h20;
    localparam [  7:0] EXP_CT     = 8'h96;
    localparam [127:0] EXP_TAG    = {64'h86d845a28c586668, 64'hd8a7756c8316802b};

    logic [7:0] captured_ct;
    logic       gate_blocked_during_decrypt;
    int         errors = 0;

    task feed_ad_and_payload(input is_decrypt, input [7:0] payload_byte);
        @(posedge clk);
        decrypt      = is_decrypt;
        ad_len       = 32'd1;
        msg_len      = 32'd1;
        expected_tag = EXP_TAG;
        start        = 1'b1;
        @(posedge clk);
        start        = 1'b0;

        // Beat 1: Associated Data (1 byte)
        wait (data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = {56'h0, NIST_AD};
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Beat 2: Plaintext or Ciphertext (1 byte)
        wait (data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = {56'h0, payload_byte};
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Check while still busy/finalizing decrypt that gate stays CLOSED!
        if (is_decrypt) begin
            #1;
            gate_blocked_during_decrypt = (pt_rd_valid == 1'b0 && pt_rd_data == 64'h0);
        end
    endtask

    initial begin
        $display("========================================================================");
        $display("DEMO 03: ASCON-AEAD128 & HARDWARE PLAINTEXT RELEASE GATE");
        $display("========================================================================");

        rst_n          = 1'b0;
        start          = 1'b0;
        soft_rst       = 1'b0;
        decrypt        = 1'b0;
        ad_len         = 32'd0;
        msg_len        = 32'd0;
        key            = NIST_KEY;
        nonce          = NIST_NONCE;
        expected_tag   = 128'h0;
        data_in        = 64'h0;
        data_in_valid  = 1'b0;
        data_out_ready = 1'b1;
        pt_rd_addr     = 8'd0;

        #20 rst_n = 1'b1;
        #10;

        // ----------------------------------------------------------------------
        // STEP 1: Encrypt PT = 0x20 with AD = 0x30
        // ----------------------------------------------------------------------
        $display("\n[STEP 1] Encrypting Plaintext=0x%02h with AD=0x%02h...", NIST_PT, NIST_AD);
        feed_ad_and_payload(1'b0, NIST_PT);
        wait (done == 1'b1);
        captured_ct = data_out[7:0];
        @(posedge clk);

        $display("  Output Ciphertext : 0x%02h (Expected: 0x%02h)", captured_ct, EXP_CT);
        $display("  Output Tag        : 0x%032h", tag_out);
        if (captured_ct !== EXP_CT || tag_out !== EXP_TAG) begin
            $display("  [ERROR] Encryption mismatch!");
            errors++;
        end else begin
            $display("  [PASS] Ciphertext and 128-bit authentication tag match NIST KAT!");
        end
        #20;

        // ----------------------------------------------------------------------
        // STEP 2: Genuine Decrypt (CT = 0x96, valid Tag) -> Plaintext Released
        // ----------------------------------------------------------------------
        $display("\n[STEP 2] Decrypting Authentic Ciphertext 0x%02h with Valid Tag...", EXP_CT);
        feed_ad_and_payload(1'b1, EXP_CT);
        wait (done == 1'b1);
        @(posedge clk);
        #5;

        $display("  Gate during decrypt   : %s",
                 gate_blocked_during_decrypt ? "LOCKED (returned 0 before tag check)" : "LEAKED!");
        $display("  Post-tag status       : tag_ok=%b, error=%b, pt_rd_valid=%b", tag_ok, error, pt_rd_valid);
        $display("  Released Plaintext    : 0x%02h (Expected: 0x%02h)", pt_rd_data[7:0], NIST_PT);

        if (!gate_blocked_during_decrypt || tag_ok !== 1'b1 || error !== 1'b0 ||
            pt_rd_valid !== 1'b1 || pt_rd_data[7:0] !== NIST_PT) begin
            $display("  [ERROR] Genuine decryption or release-gate check failed!");
            errors++;
        end else begin
            $display("  [PASS] Tag verified -> Plaintext 0x20 released safely!");
        end
        #20;

        // ----------------------------------------------------------------------
        // STEP 3: Tampered Decrypt (CT = 0x97 = 1-bit flip) -> Refused & Zeroized
        // ----------------------------------------------------------------------
        $display("\n[STEP 3] Decrypting Tampered Ciphertext 0x97 (1-bit flipped)...");
        feed_ad_and_payload(1'b1, 8'h97);
        wait (done == 1'b1 || error == 1'b1);
        @(posedge clk);
        #5;

        $display("  Post-tag status       : tag_ok=%b, error=%b, pt_rd_valid=%b", tag_ok, error, pt_rd_valid);
        $display("  Gated Read Output     : 0x%016h (MUST be 0!)", pt_rd_data);

        if (tag_ok !== 1'b0 || error !== 1'b1 || pt_rd_valid !== 1'b0 || pt_rd_data !== 64'h0) begin
            $display("  [ERROR] Security gate leaked tampered data!");
            errors++;
        end else begin
            $display("  [PASS] Tampered ciphertext blocked and shadow buffer actively zeroized!");
        end

        $display("\n========================================================================");
        if (errors == 0) begin
            $display("DEMO 03 RESULT: PASS (AEAD Encrypt, Authentic Release & Zeroize Gate!)");
            $display("========================================================================");
            $finish;
        end else begin
            $display("DEMO 03 RESULT: FAIL (%0d errors)", errors);
            $display("========================================================================");
            $fatal(1, "Demo 03 failed");
        end
    end

endmodule

