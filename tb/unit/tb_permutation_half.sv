// ==============================================================================
// Testbench: tb_permutation_half.sv
// Target: Phase 4 Permutation Datapath Verification (1/2-Round Pipelined)
// Description: Multi-round permutation verification (p^12 in 24 cycles, p^6 in 12 cycles)
// Reference: NIST SP 800-232 Section 3.2 & Golden Reference Model
// ==============================================================================

`timescale 1ns / 1ps

module tb_permutation_half;

    localparam time CLK_PERIOD = 10ns;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [ 3:0] rounds;
    wire         ready;
    wire         done;

    logic [63:0] in_x0, in_x1, in_x2, in_x3, in_x4;
    wire  [63:0] out_x0, out_x1, out_x2, out_x3, out_x4;

    // Instantiate Unit Under Test
    permutation_half dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .rounds  (rounds),
        .ready   (ready),
        .done    (done),
        .in_x0   (in_x0),
        .in_x1   (in_x1),
        .in_x2   (in_x2),
        .in_x3   (in_x3),
        .in_x4   (in_x4),
        .out_x0  (out_x0),
        .out_x1  (out_x1),
        .out_x2  (out_x2),
        .out_x3  (out_x3),
        .out_x4  (out_x4)
    );

    // Clock generator
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    int errors = 0;
    int cycle_cnt;

    initial begin
        $display("================================================================");
        $display("STARTING ASCON PERMUTATION HALF-ROUND VERIFICATION: tb_permutation_half");
        $display("Target: 1/2-round/cycle pipelined sequential permutation core");
        $display("Standard: NIST SP 800-232 Section 3.2");
        $display("================================================================");

        // Reset
        rst_n = 1'b0;
        start = 1'b0;
        rounds = 4'd0;
        in_x0 = 64'b0; in_x1 = 64'b0; in_x2 = 64'b0; in_x3 = 64'b0; in_x4 = 64'b0;
        #(CLK_PERIOD * 3);
        @(negedge clk);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 1: 12-round Permutation p^12 (Expected: 24 computation cycles)
        // ---------------------------------------------------------------------
        $display("\n[TEST 1] Testing 12-round permutation (p^12) with 1/2-round pipelining...");
        in_x0 = 64'h80400c0600000000;
        in_x1 = 64'h0001020304050607;
        in_x2 = 64'h08090a0b0c0d0e0f;
        in_x3 = 64'h1011121314151617;
        in_x4 = 64'h18191a1b1c1d1e1f;
        rounds = 4'd12;

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        cycle_cnt = 0;
        while (!done && cycle_cnt < 40) begin
            @(posedge clk);
            cycle_cnt++;
        end

        $display("  p^12 Completed in %0d clock cycles (Expected: 24 computation cycles)", cycle_cnt);

        // Verify against golden values
        if (out_x0 !== 64'hcba43b0a331b0ae5) begin
            $display("[ERROR] p^12 out_x0 mismatch! Got: 0x%016h, Expected: 0xcba43b0a331b0ae5", out_x0);
            errors++;
        end
        if (out_x1 !== 64'hd0b1251e0aae45b2) begin
            $display("[ERROR] p^12 out_x1 mismatch! Got: 0x%016h, Expected: 0xd0b1251e0aae45b2", out_x1);
            errors++;
        end
        if (out_x2 !== 64'h38a513833140c3d8) begin
            $display("[ERROR] p^12 out_x2 mismatch! Got: 0x%016h, Expected: 0x38a513833140c3d8", out_x2);
            errors++;
        end
        if (out_x3 !== 64'h9a7f51ebf8fe3e35) begin
            $display("[ERROR] p^12 out_x3 mismatch! Got: 0x%016h, Expected: 0x9a7f51ebf8fe3e35", out_x3);
            errors++;
        end
        if (out_x4 !== 64'h59d69785c0fa7540) begin
            $display("[ERROR] p^12 out_x4 mismatch! Got: 0x%016h, Expected: 0x59d69785c0fa7540", out_x4);
            errors++;
        end

        if (errors == 0) begin
            $display("[PASS] 12-round permutation (p^12) bit-exact match!");
        end

        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 2: 6-round Permutation p^6 (Expected: 12 computation cycles)
        // ---------------------------------------------------------------------
        $display("\n[TEST 2] Testing 6-round permutation (p^6) with 1/2-round pipelining...");
        in_x0 = 64'h80400c0600000000;
        in_x1 = 64'h0001020304050607;
        in_x2 = 64'h08090a0b0c0d0e0f;
        in_x3 = 64'h1011121314151617;
        in_x4 = 64'h18191a1b1c1d1e1f;
        rounds = 4'd6;

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        cycle_cnt = 0;
        while (!done && cycle_cnt < 25) begin
            @(posedge clk);
            cycle_cnt++;
        end

        $display("  p^6 Completed in %0d clock cycles (Expected: 12 computation cycles)", cycle_cnt);

        if (out_x0 !== 64'ha43b13dc0b9a309d) begin
            $display("[ERROR] p^6 out_x0 mismatch! Got: 0x%016h, Expected: 0xa43b13dc0b9a309d", out_x0);
            errors++;
        end
        if (out_x1 !== 64'hba81690fc1f3cbe2) begin
            $display("[ERROR] p^6 out_x1 mismatch! Got: 0x%016h, Expected: 0xba81690fc1f3cbe2", out_x1);
            errors++;
        end
        if (out_x2 !== 64'h9abb863d41ef1406) begin
            $display("[ERROR] p^6 out_x2 mismatch! Got: 0x%016h, Expected: 0x9abb863d41ef1406", out_x2);
            errors++;
        end
        if (out_x3 !== 64'h0056ecf95f5785cb) begin
            $display("[ERROR] p^6 out_x3 mismatch! Got: 0x%016h, Expected: 0x0056ecf95f5785cb", out_x3);
            errors++;
        end
        if (out_x4 !== 64'hbe9f15ede55c7e7f) begin
            $display("[ERROR] p^6 out_x4 mismatch! Got: 0x%016h, Expected: 0xbe9f15ede55c7e7f", out_x4);
            errors++;
        end

        if (errors == 0) begin
            $display("[PASS] 6-round permutation (p^6) bit-exact match!");
        end

        $display("================================================================");
        if (errors == 0) begin
            $display("[SUCCESS] ALL PERMUTATION HALF-ROUND TESTS PASSED (100% BIT-EXACT)!");
            $finish(0);
        end else begin
            $display("[FATAL] Permutation Half-Round test failed with %0d errors!", errors);
            $fatal(1, "Permutation Half-Round mismatch!");
        end
    end

    // =========================================================================
    // F6 — Random + Directed Vector Testing (gen_perm_vectors.py)
    // =========================================================================
    `include "tb/vectors/perm_random_vectors.svh"

    initial begin : rand_test
        automatic int rpass = 0, rfail = 0;
        @(posedge rst_n); // wait for first test to finish
        #200;

        $display("\n--- tb_permutation_1r: Random/Directed Vector Test (%0d vectors) ---", PERM_N_VECS);

        for (int i = 0; i < PERM_N_VECS; i++) begin
            @(negedge clk);
            rounds = PERM_ROUNDS[i];
            in_x0 = PERM_IN_X0[i]; in_x1 = PERM_IN_X1[i]; in_x2 = PERM_IN_X2[i];
            in_x3 = PERM_IN_X3[i]; in_x4 = PERM_IN_X4[i];
            start = 1'b1;
            @(negedge clk); start = 1'b0;
            wait (done == 1'b1); @(negedge clk);

            if (out_x0===PERM_OUT_X0[i] && out_x1===PERM_OUT_X1[i] &&
                out_x2===PERM_OUT_X2[i] && out_x3===PERM_OUT_X3[i] &&
                out_x4===PERM_OUT_X4[i]) begin
                rpass++;
            end else begin
                rfail++;
                $display("  [RAND FAIL] vec=%0d rounds=%0d", i, PERM_ROUNDS[i]);
                $display("    got  x0=%h x1=%h", out_x0, out_x1);
                $display("    exp  x0=%h x1=%h", PERM_OUT_X0[i], PERM_OUT_X1[i]);
            end
        end
        $display("Random test: PASS=%0d FAIL=%0d", rpass, rfail);
        if (rfail > 0) $fatal(1, "Random permutation test FAILED");
    end

endmodule
