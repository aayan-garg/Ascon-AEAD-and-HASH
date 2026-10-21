// ==============================================================================
// Trivial Environment Verification Testbench: tb_hello.sv
// Target: Phase 1 Environment & Regression Bring-Up
// Requirement: Phase 1 Exit Gate (IEEE-1800 SystemVerilog Compilation & Sim)
// ==============================================================================

`timescale 1ns / 1ps

module tb_hello;

    logic [63:0] test_val;
    logic [63:0] expected_val;
    int error_count = 0;

    initial begin
        $display("----------------------------------------------------------------");
        $display("Ascon AEAD/Hash RTL Test Environment Bring-Up: tb_hello");
        $display("Simulator: Vivado Simulator / IEEE-1800-2017 SystemVerilog");
        $display("----------------------------------------------------------------");

        // Simple bitwise test verifying 64-bit word operations and constants
        // Ascon round constant for round 0 is 0xf0
        test_val = 64'h0000000000000000;
        test_val = test_val ^ 64'h00000000000000f0;
        expected_val = 64'h00000000000000f0;

        if (test_val !== expected_val) begin
            $display("[FAIL] Expected %h, got %h", expected_val, test_val);
            error_count++;
        end else begin
            $display("[PASS] 64-bit round constant XOR verified: %h", test_val);
        end

        // Rotation test (Ascon linear diffusion relies on circular right shifts)
        // rotr64(0x0123456789ABCDEF, 19)
        test_val = (64'h0123456789ABCDEF >> 19) | (64'h0123456789ABCDEF << (64 - 19));
        if (test_val !== 64'h79BDE02468ACF135) begin
            $display("[FAIL] 64-bit circular shift mismatch: got %h", test_val);
            error_count++;
        end else begin
            $display("[PASS] 64-bit circular rotation (rotr 19) verified: %h", test_val);
        end

        $display("----------------------------------------------------------------");
        if (error_count == 0) begin
            $display("ALL TESTS PASSED: tb_hello environment verified successfully.");
            $finish(0);
        end else begin
            $display("TEST FAILED with %0d errors.", error_count);
            $fatal(1, "tb_hello failed.");
        end
    end

endmodule
