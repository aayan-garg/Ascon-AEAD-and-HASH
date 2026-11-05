// ==============================================================================
// Testbench: tb_payload_sizes.sv
// Measures real boot cycles across multiple payload sizes: 64 B, 1 KB (1024 B), 4 KB (4096 B)
// Fulfills Task T4: Empirical Boot Scaling Measurement & Linear Regression
// ==============================================================================

`timescale 1ns / 1ps

module tb_payload_sizes;

    parameter CLK_PERIOD = 10; // 100 MHz (10 ns)

    reg clk;
    reg rst_n_64, rst_n_1k, rst_n_4k;
    wire [3:0] led_64, led_1k, led_4k;
    wire [2:0] rgb_64, rgb_1k, rgb_4k;
    wire trap_64, trap_1k, trap_4k;
    wire test_pass_64, test_pass_1k, test_pass_4k;

    localparam [255:0] DIGEST_64B = {
        32'hEDB41305, 32'h12075573, 32'h11B6C8A2, 32'hAFB9E393,
        32'h7FE61055, 32'hA2267BDC, 32'h433A4F7B, 32'h777BB3DF
    };

    localparam [255:0] DIGEST_1KB = {
        32'h46AA00AA, 32'h11BE616C, 32'h3CB5F0BB, 32'hE03A25D7,
        32'h04EADC28, 32'hE7747E8B, 32'h4E428A70, 32'hADB7164E
    };

    localparam [255:0] DIGEST_4KB = {
        32'h1F3206BA, 32'hC58BE07C, 32'hC32111A1, 32'hCFBEA458,
        32'h2DEC98CD, 32'h8ECC2480, 32'hC6B3735D, 32'hACD7CC8F
    };

    // 1. Instance 64 B
    top_bringup #(
        .FIRMWARE_HEX        ("firmware/tests/boot_matrix/bram_payload_64b.hex"),
        .RAM_WORDS           (4096),
        .BUFFER_DEPTH        (32),
        .TRUSTED_PAYLOAD_LEN (32'd64),
        .TRUSTED_DIGEST      (DIGEST_64B)
    ) dut_64 (
        .clk        (clk),
        .rst_n      (rst_n_64),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_64),
        .rgb_led    (rgb_64),
        .trap       (trap_64),
        .test_pass  (test_pass_64)
    );

    // 2. Instance 1 KB (1024 B)
    top_bringup #(
        .FIRMWARE_HEX        ("firmware/tests/boot_matrix/bram_payload_1024b.hex"),
        .RAM_WORDS           (4096),
        .BUFFER_DEPTH        (32),
        .TRUSTED_PAYLOAD_LEN (32'd1024),
        .TRUSTED_DIGEST      (DIGEST_1KB)
    ) dut_1k (
        .clk        (clk),
        .rst_n      (rst_n_1k),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_1k),
        .rgb_led    (rgb_1k),
        .trap       (trap_1k),
        .test_pass  (test_pass_1k)
    );

    // 3. Instance 4 KB (4096 B)
    top_bringup #(
        .FIRMWARE_HEX        ("firmware/tests/boot_matrix/bram_payload_4096b.hex"),
        .RAM_WORDS           (4096),
        .BUFFER_DEPTH        (32),
        .TRUSTED_PAYLOAD_LEN (32'd4096),
        .TRUSTED_DIGEST      (DIGEST_4KB)
    ) dut_4k (
        .clk        (clk),
        .rst_n      (rst_n_4k),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_4k),
        .rgb_led    (rgb_4k),
        .trap       (trap_4k),
        .test_pass  (test_pass_4k)
    );

    // Clock generator
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    longint unsigned cycle_count = 0;
    always @(posedge clk) cycle_count <= cycle_count + 1;

    longint j64, p64;
    longint j1k, p1k;
    longint j4k, p4k;
    longint start_cyc;
    integer log_fd;

    initial begin
        $display("================================================================================");
        $display("STARTING EMPIRICAL BOOT LATENCY SCALING BENCHMARK (64B, 1KB, 4KB)");
        $display("Clock: 100 MHz (10 ns/cycle) | Architecture: Ascon-Hash256 + PicoRV32 + DMA");
        $display("================================================================================");

        rst_n_64 = 0;
        rst_n_1k = 0;
        rst_n_4k = 0;
        #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // Benchmark 1: 64 Bytes
        // ---------------------------------------------------------------------
        $display("\n--- Benchmarking 64 Bytes Payload ---");
        @(negedge clk);
        rst_n_64 = 1;
        start_cyc = cycle_count;
        j64 = 0;
        p64 = 0;
        fork
            begin
                wait (dut_64.boot_jump_enable == 1'b1);
                j64 = cycle_count - start_cyc;
            end
            begin
                wait (test_pass_64 == 1'b1);
                repeat(2) @(posedge clk);
                p64 = cycle_count - start_cyc;
            end
            begin
                #(CLK_PERIOD * 50000);
                $display("  [ERROR] 64B timed out!");
            end
        join_any
        // Wait until test_pass completes
        wait (test_pass_64 == 1'b1);
        repeat(2) @(posedge clk);
        p64 = cycle_count - start_cyc;
        rst_n_64 = 0;

        $display("  [64 B]   reset_to_jump = %0d cycles (%.2f us) | reset_to_pass = %0d cycles (%.2f us)",
                 j64, j64 * 10.0 / 1000.0, p64, p64 * 10.0 / 1000.0);

        // ---------------------------------------------------------------------
        // Benchmark 2: 1024 Bytes (1 KB)
        // ---------------------------------------------------------------------
        $display("\n--- Benchmarking 1024 Bytes (1 KB) Payload ---");
        #(CLK_PERIOD * 10);
        @(negedge clk);
        rst_n_1k = 1;
        start_cyc = cycle_count;
        j1k = 0;
        p1k = 0;
        fork
            begin
                wait (dut_1k.boot_jump_enable == 1'b1);
                j1k = cycle_count - start_cyc;
            end
            begin
                wait (test_pass_1k == 1'b1);
                repeat(2) @(posedge clk);
                p1k = cycle_count - start_cyc;
            end
            begin
                #(CLK_PERIOD * 100000);
                $display("  [ERROR] 1KB timed out!");
            end
        join_any
        wait (test_pass_1k == 1'b1);
        repeat(2) @(posedge clk);
        p1k = cycle_count - start_cyc;
        rst_n_1k = 0;

        $display("  [1024 B] reset_to_jump = %0d cycles (%.2f us) | reset_to_pass = %0d cycles (%.2f us)",
                 j1k, j1k * 10.0 / 1000.0, p1k, p1k * 10.0 / 1000.0);

        // ---------------------------------------------------------------------
        // Benchmark 3: 4096 Bytes (4 KB)
        // ---------------------------------------------------------------------
        $display("\n--- Benchmarking 4096 Bytes (4 KB) Payload ---");
        #(CLK_PERIOD * 10);
        @(negedge clk);
        rst_n_4k = 1;
        start_cyc = cycle_count;
        j4k = 0;
        p4k = 0;
        fork
            begin
                wait (dut_4k.boot_jump_enable == 1'b1);
                j4k = cycle_count - start_cyc;
            end
            begin
                wait (test_pass_4k == 1'b1);
                repeat(2) @(posedge clk);
                p4k = cycle_count - start_cyc;
            end
            begin
                #(CLK_PERIOD * 300000);
                $display("  [ERROR] 4KB timed out!");
            end
        join_any
        wait (test_pass_4k == 1'b1);
        repeat(2) @(posedge clk);
        p4k = cycle_count - start_cyc;
        rst_n_4k = 0;

        $display("  [4096 B] reset_to_jump = %0d cycles (%.2f us) | reset_to_pass = %0d cycles (%.2f us)",
                 j4k, j4k * 10.0 / 1000.0, p4k, p4k * 10.0 / 1000.0);

        // ---------------------------------------------------------------------
        // Write Real Evidence Log
        // ---------------------------------------------------------------------
        log_fd = $fopen("results/board/boot_matrix/boot_scaling_benchmark.log", "w");
        if (log_fd) begin
            $fdisplay(log_fd, "# Empirical Boot Latency Scaling Benchmark Log");
            $fdisplay(log_fd, "# [SOURCE]: Generated by tb_payload_sizes.sv via AMD-Xilinx Vivado XSim 2025.1");
            $fdisplay(log_fd, "# Clock: 100 MHz (10.0 ns/cycle)");
            $fdisplay(log_fd, "# Payload_Bytes,Reset_to_Jump_Cycles,Reset_to_Jump_us,Reset_to_Pass_Cycles,Reset_to_Pass_us");
            $fdisplay(log_fd, "64,%0d,%.2f,%0d,%.2f", j64, j64 * 10.0 / 1000.0, p64, p64 * 10.0 / 1000.0);
            $fdisplay(log_fd, "1024,%0d,%.2f,%0d,%.2f", j1k, j1k * 10.0 / 1000.0, p1k, p1k * 10.0 / 1000.0);
            $fdisplay(log_fd, "4096,%0d,%.2f,%0d,%.2f", j4k, j4k * 10.0 / 1000.0, p4k, p4k * 10.0 / 1000.0);
            $fclose(log_fd);
        end

        $display("\n================================================================================");
        $display("EMPIRICAL BENCHMARK SUMMARY (100 MHz):");
        $display("  Size      Reset->Jump (cyc / us)      Reset->TestPass (cyc / us)");
        $display("  64 B:     %5d cyc (%6.2f us)       %5d cyc (%6.2f us)",
                 j64, j64 * 10.0 / 1000.0, p64, p64 * 10.0 / 1000.0);
        $display("  1024 B:   %5d cyc (%6.2f us)       %5d cyc (%6.2f us)",
                 j1k, j1k * 10.0 / 1000.0, p1k, p1k * 10.0 / 1000.0);
        $display("  4096 B:   %5d cyc (%6.2f us)       %5d cyc (%6.2f us)",
                 j4k, j4k * 10.0 / 1000.0, p4k, p4k * 10.0 / 1000.0);
        $display("================================================================================");
        $finish;
    end

endmodule
