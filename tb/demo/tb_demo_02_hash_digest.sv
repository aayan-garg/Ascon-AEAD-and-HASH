// ==============================================================================
// Presentation Demo 02: Ascon-Hash256 (NIST KAT Match + 1-Bit Avalanche Demo)
// Target: Easy-to-follow demo of hash_ctrl.sv sponge hashing
//
// Shows two visual checks:
//   1. Computes Ascon-Hash256 of the official 8-byte NIST vector "0001020304050607"
//      and proves bit-exact match with NIST SP 800-232.
//   2. Flips JUST ONE BIT in that message ("0101020304050607") and counts how many
//      of the 256 digest bits flip (avalanche effect ~50%!) to prove why even a
//      1-bit firmware tamper guarantees boot hash rejection.
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_02_hash_digest;

    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    logic         rst_n;
    logic         start;
    logic         soft_rst;
    logic [ 31:0] msg_len;
    logic [ 63:0] data_in;
    logic         data_in_valid;
    wire          data_in_ready;
    wire          busy;
    wire          done;
    wire  [255:0] digest_out;
    wire  [  3:0] fsm_state;

    hash_ctrl dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .soft_rst      (soft_rst),
        .msg_len       (msg_len),
        .data_in       (data_in),
        .data_in_valid (data_in_valid),
        .data_in_ready (data_in_ready),
        .busy          (busy),
        .done          (done),
        .digest_out    (digest_out),
        .fsm_state     (fsm_state)
    );

    // Official NIST KAT Count 9 (8-byte message: 00 01 02 03 04 05 06 07)
    // Little-endian 64-bit word = 64'h07060504_03020100
    localparam [ 63:0] MSG_VALID   = 64'h07060504_03020100;
    localparam [ 63:0] MSG_1BIT_FLIP = 64'h07060504_03020101; // Only bit 0 flipped!
    localparam [255:0] EXP_DIGEST  = {
        64'h4f76ba9910cf7a16,
        64'hbefe7f3f3895eda0,
        64'hfcf2b82e62ef871b,
        64'h64fbe6e87a498eb8
    };

    logic [255:0] digest_valid, digest_flipped;
    int           flipped_bits;
    int           errors = 0;

    task run_8byte_hash(input [63:0] word, output [255:0] result_digest);
        @(posedge clk);
        msg_len = 32'd8;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        // Handshake 1 x 64-bit message beat into the sponge
        wait (data_in_ready == 1'b1);
        @(posedge clk);
        data_in       = word;
        data_in_valid = 1'b1;
        @(posedge clk);
        data_in_valid = 1'b0;

        // Wait for 12-round absorption + 4 x 64-bit digest squeeze
        wait (done == 1'b1);
        @(posedge clk);
        result_digest = digest_out;
        #20;
    endtask

    initial begin
        $display("========================================================================");
        $display("DEMO 02: ASCON-HASH256 SPONGE ENGINE & 1-BIT AVALANCHE EFFECT");
        $display("========================================================================");

        rst_n         = 1'b0;
        start         = 1'b0;
        soft_rst      = 1'b0;
        msg_len       = 32'd0;
        data_in       = 64'h0;
        data_in_valid = 1'b0;
        #20 rst_n = 1'b1;
        #10;

        // Step 1: Valid NIST 8-byte message
        $display("\n[STEP 1] Hashing 8-byte NIST message: 0x%016h", MSG_VALID);
        run_8byte_hash(MSG_VALID, digest_valid);
        $display("  Computed Digest : 0x%064h", digest_valid);
        $display("  NIST Expected   : 0x%064h", EXP_DIGEST);

        if (digest_valid !== EXP_DIGEST) begin
            $display("  [ERROR] NIST digest mismatch!");
            errors++;
        end else begin
            $display("  [PASS] Exact 256-bit NIST SP 800-232 KAT match!");
        end

        // Step 2: Same message with 1 bit flipped (LSB = 1 instead of 0)
        $display("\n[STEP 2] Flipping 1 bit in input message: 0x%016h", MSG_1BIT_FLIP);
        run_8byte_hash(MSG_1BIT_FLIP, digest_flipped);
        $display("  Tampered Digest : 0x%064h", digest_flipped);

        flipped_bits = $countones(digest_valid ^ digest_flipped);
        $display("  Avalanche Check : %0d / 256 output bits flipped (%.1f%%)",
                 flipped_bits, (flipped_bits * 100.0) / 256.0);

        if (digest_flipped == digest_valid || flipped_bits < 64) begin
            $display("  [ERROR] Digest did not strongly avalanche on 1-bit flip!");
            errors++;
        end else begin
            $display("  [PASS] Strong avalanche confirmed — tamper is immediately detectable!");
        end

        $display("\n========================================================================");
        if (errors == 0) begin
            $display("DEMO 02 RESULT: PASS (NIST KAT matched + Avalanche Verified)");
            $display("========================================================================");
            $finish;
        end else begin
            $display("DEMO 02 RESULT: FAIL (%0d errors)", errors);
            $display("========================================================================");
            $fatal(1, "Demo 02 failed");
        end
    end

endmodule

