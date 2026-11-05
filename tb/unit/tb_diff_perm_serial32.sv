// ==============================================================================
// Testbench: tb_diff_perm_serial32.sv
// Target: Task T1.a Differential Verification of permutation_serial32
// Description:
//   Instantiates BOTH permutation_1r (golden reference) and permutation_serial32.
//   Feeds identical inputs, triggers start simultaneously, waits for both to
//   assert done, and compares all five 64-bit output state words (out_x0..out_x4).
//   Tests:
//     1. 12-round permutation (p^12) known vector
//     2. 8-round permutation  (p^8)  known vector
//     3. 6-round permutation  (p^6)  known vector
//     4. All 132 directed and random vectors from tb/vectors/perm_random_vectors.svh
// ==============================================================================

`timescale 1ns / 1ps

module tb_diff_perm_serial32;

    localparam time CLK_PERIOD = 10ns;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [ 3:0] rounds;

    logic [63:0] in_x0, in_x1, in_x2, in_x3, in_x4;

    // 1R reference core
    wire         ready_1r, done_1r;
    wire  [63:0] out_1r_x0, out_1r_x1, out_1r_x2, out_1r_x3, out_1r_x4;

    // Serial32 UUT
    wire         ready_s32, done_s32;
    wire  [63:0] out_s32_x0, out_s32_x1, out_s32_x2, out_s32_x3, out_s32_x4;

    permutation_1r u_ref_1r (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .rounds  (rounds),
        .ready   (ready_1r),
        .done    (done_1r),
        .in_x0   (in_x0),
        .in_x1   (in_x1),
        .in_x2   (in_x2),
        .in_x3   (in_x3),
        .in_x4   (in_x4),
        .out_x0  (out_1r_x0),
        .out_x1  (out_1r_x1),
        .out_x2  (out_1r_x2),
        .out_x3  (out_1r_x3),
        .out_x4  (out_1r_x4)
    );

    permutation_serial32 u_uut_s32 (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .rounds  (rounds),
        .ready   (ready_s32),
        .done    (done_s32),
        .in_x0   (in_x0),
        .in_x1   (in_x1),
        .in_x2   (in_x2),
        .in_x3   (in_x3),
        .in_x4   (in_x4),
        .out_x0  (out_s32_x0),
        .out_x1  (out_s32_x1),
        .out_x2  (out_s32_x2),
        .out_x3  (out_s32_x3),
        .out_x4  (out_s32_x4)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    `include "tb/vectors/perm_random_vectors.svh"

    int errors = 0;
    int pass_count = 0;

    task automatic run_single_check(
        input string label,
        input [3:0]  r,
        input [63:0] x0, input [63:0] x1, input [63:0] x2, input [63:0] x3, input [63:0] x4
    );
        int cyc_1r, cyc_s32;
        @(negedge clk);
        rounds = r;
        in_x0 = x0; in_x1 = x1; in_x2 = x2; in_x3 = x3; in_x4 = x4;
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // Monitor done flags
        fork
            begin : wait_1r
                cyc_1r = 0;
                while (!done_1r && cyc_1r < 100) begin
                    @(posedge clk);
                    cyc_1r++;
                end
            end
            begin : wait_s32
                cyc_s32 = 0;
                while (!done_s32 && cyc_s32 < 100) begin
                    @(posedge clk);
                    cyc_s32++;
                end
            end
        join

        // Wait one cycle for state stabilization at done
        @(negedge clk);

        $display("  [CYC] %s: cyc_1r=%0d, cyc_s32=%0d", label, cyc_1r, cyc_s32);

        if (out_s32_x0 !== out_1r_x0 ||
            out_s32_x1 !== out_1r_x1 ||
            out_s32_x2 !== out_1r_x2 ||
            out_s32_x3 !== out_1r_x3 ||
            out_s32_x4 !== out_1r_x4) begin
            $display("[FAIL] %s (rounds=%0d): MISMATCH!", label, r);
            $display("  1R:  x0=%h x1=%h x2=%h x3=%h x4=%h", out_1r_x0, out_1r_x1, out_1r_x2, out_1r_x3, out_1r_x4);
            $display("  S32: x0=%h x1=%h x2=%h x3=%h x4=%h", out_s32_x0, out_s32_x1, out_s32_x2, out_s32_x3, out_s32_x4);
            errors++;
        end else begin
            pass_count++;
        end

        // Verify exact execution cycle count: 1R takes r cycles, serial32 takes 2*r cycles (+1 testbench start cycle)
        if ((cyc_s32 - 1) != r * 2) begin
            $display("[FAIL] %s cycle count wrong! Expected %0d cycles, got %0d cycles", label, r*2, cyc_s32 - 1);
            errors++;
        end
        if ((cyc_1r - 1) != r) begin
            $display("[FAIL] %s 1R cycle count wrong! Expected %0d cycles, got %0d cycles", label, r, cyc_1r - 1);
            errors++;
        end
    endtask

    initial begin
        $display("================================================================");
        $display("STARTING DIFFERENTIAL TEST: tb_diff_perm_serial32");
        $display("Comparing permutation_serial32 vs permutation_1r (golden)");
        $display("================================================================");

        rst_n = 1'b0;
        start = 1'b0;
        rounds = 4'd0;
        in_x0 = 64'b0; in_x1 = 64'b0; in_x2 = 64'b0; in_x3 = 64'b0; in_x4 = 64'b0;
        #(CLK_PERIOD * 4);
        @(negedge clk);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        // 1. Directed Vector p^12
        run_single_check("Directed p^12", 4'd12,
            64'h80400c0600000000, 64'h0001020304050607, 64'h08090a0b0c0d0e0f,
            64'h1011121314151617, 64'h18191a1b1c1d1e1f);

        // 2. Directed Vector p^8
        run_single_check("Directed p^8", 4'd8,
            64'h80400c0600000000, 64'h0001020304050607, 64'h08090a0b0c0d0e0f,
            64'h1011121314151617, 64'h18191a1b1c1d1e1f);

        // 3. Directed Vector p^6
        run_single_check("Directed p^6", 4'd6,
            64'h80400c0600000000, 64'h0001020304050607, 64'h08090a0b0c0d0e0f,
            64'h1011121314151617, 64'h18191a1b1c1d1e1f);

        // 4. All vectors in perm_random_vectors.svh
        $display("\nRunning %0d random & directed vectors from perm_random_vectors.svh...", PERM_N_VECS);
        for (int i = 0; i < PERM_N_VECS; i++) begin
            run_single_check($sformatf("Vector[%0d]", i), PERM_ROUNDS[i],
                PERM_IN_X0[i], PERM_IN_X1[i], PERM_IN_X2[i], PERM_IN_X3[i], PERM_IN_X4[i]);
        end

        $display("\n================================================================");
        $display("DIFFERENTIAL TEST RESULTS: PASS=%0d, FAIL=%0d", pass_count, errors);
        if (errors == 0) begin
            $display("[SUCCESS] permutation_serial32 IS 100%% BIT-EXACT MATCH TO 1R!");
            $finish(0);
        end else begin
            $fatal(1, "[FATAL] Differential permutation verification FAILED!");
        end
    end

endmodule
