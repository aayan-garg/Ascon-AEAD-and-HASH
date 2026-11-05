// ==============================================================================
// Testbench: tb_round_core.sv
// Target: Phase 4 Permutation Datapath Verification
// Description: Directed and algorithmic verification of the combinational round core
// Reference: NIST SP 800-232 Section 3.2 (Round Permutation)
// ==============================================================================

`timescale 1ns / 1ps

module tb_round_core;

    logic [63:0] in_x0, in_x1, in_x2, in_x3, in_x4;
    logic [ 7:0] round_const;
    wire  [63:0] out_x0, out_x1, out_x2, out_x3, out_x4;

    // Instantiate Unit Under Test
    round_core dut (
        .in_x0       (in_x0),
        .in_x1       (in_x1),
        .in_x2       (in_x2),
        .in_x3       (in_x3),
        .in_x4       (in_x4),
        .round_const (round_const),
        .out_x0      (out_x0),
        .out_x1      (out_x1),
        .out_x2      (out_x2),
        .out_x3      (out_x3),
        .out_x4      (out_x4)
    );

    int errors = 0;

    initial begin
        $display("================================================================");
        $display("STARTING ASCON ROUND CORE VERIFICATION: tb_round_core");
        $display("Standard: NIST SP 800-232 Section 3.2 (Round Function)");
        $display("================================================================");

        // Vector 1: Ascon-128 standard initialization state at Round 0 (cr = 0xf0)
        in_x0       = 64'h80400c0600000000;
        in_x1       = 64'h0001020304050607;
        in_x2       = 64'h08090a0b0c0d0e0f;
        in_x3       = 64'h1011121314151617;
        in_x4       = 64'h18191a1b1c1d1e1f;
        round_const = 8'hf0;
        #1;

        if (out_x0 !== 64'hfa550bedbb4f9c9d) begin
            $display("[ERROR] x0 mismatch: Expected 0xfa550bedbb4f9c9d, Got 0x%016h", out_x0);
            errors++;
        end
        if (out_x1 !== 64'h88417420eb2db3c7) begin
            $display("[ERROR] x1 mismatch: Expected 0x88417420eb2db3c7, Got 0x%016h", out_x1);
            errors++;
        end
        if (out_x2 !== 64'h3fffffffffffff74) begin
            $display("[ERROR] x2 mismatch: Expected 0x3fffffffffffff74, Got 0x%016h", out_x2);
            errors++;
        end
        if (out_x3 !== 64'hbc185427038300f0) begin
            $display("[ERROR] x3 mismatch: Expected 0xbc185427038300f0, Got 0x%016h", out_x3);
            errors++;
        end
        if (out_x4 !== 64'h1d1c1c1e181c1c1c) begin
            $display("[ERROR] x4 mismatch: Expected 0x1d1c1c1e181c1c1c, Got 0x%016h", out_x4);
            errors++;
        end

        $display("================================================================");
        if (errors == 0) begin
            $display("[SUCCESS] Ascon combinational round core tests passed.");
            $finish(0);
        end else begin
            $display("[FATAL] Round core verification failed with %0d errors!", errors);
            $fatal(1, "Round core mismatch!");
        end
    end

endmodule
