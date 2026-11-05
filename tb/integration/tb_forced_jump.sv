// ==============================================================================
// Testbench: tb_forced_jump.sv
// Requirement: B1 Fetch-Guard Negative Verification
// Proves:
//   1. Guard Active (ENABLE_FETCH_GUARD=1): Unauthorized jump to candidate app
//      (0x0000_1040) is blocked by hardware fetch guard. CPU executes NOP slide,
//      test_pass remains 0, and boot_jump_enable remains 0.
//   2. Guard Disabled (ENABLE_FETCH_GUARD=0): Without hardware fetch guard,
//      unauthorized jump reaches payload, executing the GPIO marker (test_pass=1).
// ==============================================================================

`timescale 1ns / 1ps

module tb_forced_jump;

    parameter CLK_PERIOD = 10; // 100 MHz (10 ns)

    reg clk;
    reg rst_n_active;
    reg rst_n_bypass;

    wire [3:0] led_active, led_bypass;
    wire [2:0] rgb_active, rgb_bypass;
    wire trap_active, trap_bypass;
    wire test_pass_active, test_pass_bypass;

    // Instance 1: Hardware Fetch Guard Active (Normal Secure Mode)
    top_bringup #(
        .FIRMWARE_HEX        ("firmware/tests/forced_jump.hex"),
        .RAM_WORDS           (4096),
        .BUFFER_DEPTH        (32),
        .ENABLE_FETCH_GUARD  (1)
    ) dut_guard_active (
        .clk        (clk),
        .rst_n      (rst_n_active),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_active),
        .rgb_led    (rgb_active),
        .trap       (trap_active),
        .test_pass  (test_pass_active)
    );

    // Instance 2: Hardware Fetch Guard Disabled (Bypass / Control Experiment)
    top_bringup #(
        .FIRMWARE_HEX        ("firmware/tests/forced_jump.hex"),
        .RAM_WORDS           (4096),
        .BUFFER_DEPTH        (32),
        .ENABLE_FETCH_GUARD  (0)
    ) dut_guard_bypass (
        .clk        (clk),
        .rst_n      (rst_n_bypass),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_bypass),
        .rgb_led    (rgb_bypass),
        .trap       (trap_bypass),
        .test_pass  (test_pass_bypass)
    );

    // Clock generator
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer log_fd;
    integer pass_active_count = 0;
    integer pass_bypass_count = 0;

    initial begin
        $display("================================================================================");
        $display("STARTING FETCH-GUARD NEGATIVE VERIFICATION TESTBENCH (tb_forced_jump.sv)");
        $display("Target: Hardware Instruction Fetch Barrier (fetch_guard.sv)");
        $display("Firmware: firmware/tests/forced_jump.hex (attempts direct jump to 0x1040)");
        $display("================================================================================");

        rst_n_active = 0;
        rst_n_bypass = 0;
        #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // TEST 1: Guard ACTIVE (ENABLE_FETCH_GUARD = 1)
        // ---------------------------------------------------------------------
        $display("\n[TEST 1] Guard ACTIVE: Verifying unauthorized jump is blocked...");
        @(negedge clk);
        rst_n_active = 1;

        // Run for 3,000 cycles (sufficient for jump attempt and NOP slide)
        repeat (3000) @(posedge clk);

        // Assertions for Test 1
        assert (test_pass_active == 1'b0) else begin
            $display("[FATAL ERROR] Guard Active: test_pass was asserted (unauthorized code executed)!");
            $fatal(1);
        end

        assert (dut_guard_active.boot_jump_enable == 1'b0) else begin
            $display("[FATAL ERROR] Guard Active: boot_jump_enable was asserted without hash verification!");
            $fatal(1);
        end

        $display("  PASS: Guard Active successfully blocked payload execution (test_pass=0, jump_enable=0).");
        pass_active_count = 1;
        rst_n_active = 0;
        #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // TEST 2: Guard BYPASSED (ENABLE_FETCH_GUARD = 0)
        // ---------------------------------------------------------------------
        $display("\n[TEST 2] Guard BYPASSED: Verifying payload executes when guard is absent...");
        @(negedge clk);
        rst_n_bypass = 1;

        fork
            begin
                wait (test_pass_bypass == 1'b1);
                $display("  PASS: Guard Bypassed successfully reached payload (test_pass=1 asserted)!");
                pass_bypass_count = 1;
            end
            begin
                #(CLK_PERIOD * 5000);
                if (!test_pass_bypass) begin
                    $display("[FATAL ERROR] Guard Bypassed: Payload timed out without asserting test_pass!");
                    $fatal(1);
                end
            end
        join_any
        rst_n_bypass = 0;

        // ---------------------------------------------------------------------
        // Write Real Evidence Log
        // ---------------------------------------------------------------------
        log_fd = $fopen("results/board/boot_matrix/forced_jump_sim.log", "w");
        if (log_fd) begin
            $fdisplay(log_fd, "# Fetch-Guard Negative Verification Simulation Log");
            $fdisplay(log_fd, "# [SOURCE]: Generated by tb_forced_jump.sv via AMD-Xilinx Vivado XSim 2025.1");
            $fdisplay(log_fd, "# Firmware: firmware/tests/forced_jump.hex");
            $fdisplay(log_fd, "# Test 1 (Guard Active):   test_pass=%0d, jump_enable=%0d, VERDICT=%s",
                     test_pass_active, dut_guard_active.boot_jump_enable, (pass_active_count == 1) ? "PASS" : "FAIL");
            $fdisplay(log_fd, "# Test 2 (Guard Bypassed): test_pass=%0d, jump_enable=%0d, VERDICT=%s",
                     test_pass_bypass, dut_guard_bypass.boot_jump_enable, (pass_bypass_count == 1) ? "PASS" : "FAIL");
            $fdisplay(log_fd, "TOTAL_TESTS=2");
            $fdisplay(log_fd, "TOTAL_PASS=%0d", pass_active_count + pass_bypass_count);
            $fdisplay(log_fd, "TOTAL_FAIL=%0d", 2 - (pass_active_count + pass_bypass_count));
            $fdisplay(log_fd, "RESULT=%s", ((pass_active_count + pass_bypass_count) == 2) ? "PASS" : "FAIL");
            $fclose(log_fd);
        end

        $display("\n================================================================================");
        if ((pass_active_count + pass_bypass_count) == 2) begin
            $display("FETCH-GUARD VERIFICATION COMPLETE: ALL 2 TESTS PASSED");
        end else begin
            $display("FETCH-GUARD VERIFICATION COMPLETE: FAIL");
        end
        $display("  1. Guard Active:   BLOCKED (test_pass=0, jump_enable=0)");
        $display("  2. Guard Bypassed: EXECUTED (test_pass=1)");
        $display("================================================================================");
        $finish;
    end

endmodule
