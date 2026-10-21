// ==============================================================================
// Testbench: tb_hash.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Official NIST KAT Testbench for Ascon-Hash256 Core (hash_ctrl.sv).
//
// Vectors from reference/ascon-c/crypto_hash/asconhash256/LWC_HASH_KAT_128_256.txt:
//   Vector 1: Length = 0 bytes (Empty Message)
//   Vector 2: Length = 1 byte  ("00")
//   Vector 3: Length = 8 bytes ("0001020304050607")
//   Vector 4: Length = 16 bytes ("000102030405060708090A0B0C0D0E0F")
// ==============================================================================

`timescale 1ns / 1ps

module tb_hash;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         soft_rst;
    reg  [31:0] msg_len;
    reg  [63:0] data_in;
    reg         data_in_valid;
    wire        data_in_ready;
    wire        busy;
    wire        done;
    wire [255:0] digest_out;
    wire [ 3:0] fsm_state;

    integer test_errors = 0;

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

    always #5 clk = ~clk;

    // Watchdog
    initial begin
        #500000;
        $display("\n[FATAL] Simulation watchdog timeout triggered!");
        $fatal(1, "Hash testbench timed out");
    end

    // Task to run one hash test
    task run_hash_test(
        input [ 31:0] len,
        input [ 63:0] word0,
        input [ 63:0] word1,
        input [255:0] exp_digest,
        input [127:0] test_name
    );
        begin
            $display("\n[HASH TEST] %0s (Length = %0d bytes)...", test_name, len);
            @(posedge clk);
            msg_len = len;
            start   = 1'b1;
            @(posedge clk);
            start   = 1'b0;

            if (len > 0) begin
                // Beat 0
                wait(data_in_ready == 1'b1);
                @(posedge clk);
                data_in       = word0;
                data_in_valid = 1'b1;
                @(posedge clk);
                data_in_valid = 1'b0;

                if (len > 8) begin
                    // Beat 1
                    wait(data_in_ready == 1'b1);
                    @(posedge clk);
                    data_in       = word1;
                    data_in_valid = 1'b1;
                    @(posedge clk);
                    data_in_valid = 1'b0;
                end
            end

            wait(done == 1'b1);
            @(posedge clk);

            $display("  Computed: H0=0x%016x, H1=0x%016x, H2=0x%016x, H3=0x%016x",
                     digest_out[63:0], digest_out[127:64], digest_out[191:128], digest_out[255:192]);
            $display("  Expected: H0=0x%016x, H1=0x%016x, H2=0x%016x, H3=0x%016x",
                     exp_digest[63:0], exp_digest[127:64], exp_digest[191:128], exp_digest[255:192]);

            if (digest_out !== exp_digest) begin
                $display("  [ERROR] %0s Digest Mismatch!", test_name);
                test_errors = test_errors + 1;
            end else begin
                $display("  [PASS] %0s Exact NIST KAT Match!", test_name);
            end
            #20;
        end
    endtask

    initial begin
        clk           = 0;
        rst_n         = 0;
        start         = 0;
        soft_rst      = 0;
        msg_len       = 0;
        data_in       = 0;
        data_in_valid = 0;

        #20 rst_n = 1;
        #10;

        $display("================================================================================");
        $display("STARTING OFFICIAL NIST KAT ASCON-HASH256 VERIFICATION: tb_hash");
        $display("================================================================================");

        // Vector 1: 0-byte Message
        run_hash_test(
            32'd0,
            64'h0,
            64'h0,
            {64'hb2924d30aa3bd59b, 64'h838f9b24aa70faa1, 64'h649ba8de8f9ff2ca, 64'h986b2f0f85e53b0b},
            "KAT Count 1 (0-byte)"
        );

        // Vector 2: 1-byte Message ("00")
        run_hash_test(
            32'd1,
            64'h00000000_00000000,
            64'h0,
            {64'h80bc9102e7a1f6e7, 64'h23eeb5e430536f45, 64'hf900e9fdf63ba0bc, 64'hd23eaf3510622807},
            "KAT Count 2 (1-byte)"
        );

        // Vector 3: 8-byte Message ("0001020304050607") -> word0 = 64'h0706050403020100
        run_hash_test(
            32'd8,
            64'h0706050403020100,
            64'h0,
            {64'h4f76ba9910cf7a16, 64'hbefe7f3f3895eda0, 64'hfcf2b82e62ef871b, 64'h64fbe6e87a498eb8},
            "KAT Count 9 (8-byte)"
        );

        // Vector 4: 16-byte Message ("000102030405060708090A0B0C0D0E0F")
        // word0 = 64'h0706050403020100, word1 = 64'h0F0E0D0C0B0A0908
        run_hash_test(
            32'd16,
            64'h0706050403020100,
            64'h0F0E0D0C0B0A0908,
            {64'h385c8341d6dd7a46, 64'h115937fc4e9e684a, 64'hb959787761b68ad6, 64'hdbba2f0a94c15831},
            "KAT Count 17 (16-byte)"
        );

        $display("\n================================================================================");
        if (test_errors == 0) begin
            $display("ASCON-HASH256 NIST KAT RESULT: 100% PASS (ALL VECTORS MATCH)");
            $display("================================================================================");
            $finish;
        end else begin
            $display("ASCON-HASH256 NIST KAT RESULT: FAILED WITH %0d ERRORS", test_errors);
            $display("================================================================================");
            $fatal(1, "Hash KAT verification failed");
        end
    end

endmodule
