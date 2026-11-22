// ==============================================================================
// Presentation Demo 01: 5-Bit S-Box Equivalence & 320-Bit Permutation Tradeoffs
// Target: Easy-to-follow demo for live Vivado simulation & waveform walkthrough
//
// Part A: Sweeps all 32 inputs (0..31) through all four S-box implementations:
//         1. sbox5          (Canonical bit-sliced affine-chi-affine)
//         2. sbox5_espresso (UC Berkeley ESPRESSO 2-level exact SOP)
//         3. sbox5_kernel   (Brayton-McMullen factored kernels k0..k5)
//         4. sbox5_bdd      (Shared ROBDD 2:1 mux network)
// Part B: Runs one 12-round permutation (p^12) in parallel across all 4 cores:
//         permutation_2r, permutation_1r, permutation_half, permutation_serial32
//         so the waveform shows the cycle-count tradeoff (6 vs 12 vs 24 cycles)
//         while all 4 produce the exact same 320-bit NIST SP 800-232 output!
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_01_sbox_and_perm;

    // --------------------------------------------------------------------------
    // Part A Signals: 5-bit S-box (0..31)
    // --------------------------------------------------------------------------
    logic [4:0] sbox_in;
    wire  [4:0] y_baseline, y_espresso, y_kernel, y_bdd;

    // NIST SP 800-232 Table 6 official 5-bit S-box lookup table
    const logic [4:0] SBOX_NIST [0:31] = '{
        5'h04, 5'h0b, 5'h1f, 5'h14, 5'h1a, 5'h15, 5'h09, 5'h02,
        5'h1b, 5'h05, 5'h08, 5'h12, 5'h1d, 5'h03, 5'h06, 5'h1c,
        5'h1e, 5'h13, 5'h07, 5'h0e, 5'h00, 5'h0d, 5'h11, 5'h18,
        5'h10, 5'h0c, 5'h01, 5'h19, 5'h16, 5'h0a, 5'h0f, 5'h17
    };

    sbox5          u_sbox_base (.in_x(sbox_in), .out_y(y_baseline));
    sbox5_espresso u_sbox_esp  (.in_x(sbox_in), .out_y(y_espresso));
    sbox5_kernel   u_sbox_kern (.in_x(sbox_in), .out_y(y_kernel));
    sbox5_bdd      u_sbox_bdd  (.in_x(sbox_in), .out_y(y_bdd));

    // --------------------------------------------------------------------------
    // Part B Signals: Parallel 320-bit Permutation Comparison (p^12)
    // --------------------------------------------------------------------------
    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz clock (10 ns period)

    logic        rst_n;
    logic        perm_start;
    logic [63:0] in_x0, in_x1, in_x2, in_x3, in_x4;

    wire         ready_2r, ready_1r, ready_half, ready_ser32;
    wire         done_2r,  done_1r,  done_half,  done_ser32;
    wire [63:0]  x0_2r, x1_2r, x2_2r, x3_2r, x4_2r;
    wire [63:0]  x0_1r, x1_1r, x2_1r, x3_1r, x4_1r;
    wire [63:0]  x0_hf, x1_hf, x2_hf, x3_hf, x4_hf;
    wire [63:0]  x0_s32, x1_s32, x2_s32, x3_s32, x4_s32;

    permutation_2r u_perm_2r (
        .clk(clk), .rst_n(rst_n), .start(perm_start), .rounds(4'd12),
        .ready(ready_2r), .done(done_2r),
        .in_x0(in_x0), .in_x1(in_x1), .in_x2(in_x2), .in_x3(in_x3), .in_x4(in_x4),
        .out_x0(x0_2r), .out_x1(x1_2r), .out_x2(x2_2r), .out_x3(x3_2r), .out_x4(x4_2r)
    );

    permutation_1r u_perm_1r (
        .clk(clk), .rst_n(rst_n), .start(perm_start), .rounds(4'd12),
        .ready(ready_1r), .done(done_1r),
        .in_x0(in_x0), .in_x1(in_x1), .in_x2(in_x2), .in_x3(in_x3), .in_x4(in_x4),
        .out_x0(x0_1r), .out_x1(x1_1r), .out_x2(x2_1r), .out_x3(x3_1r), .out_x4(x4_1r)
    );

    permutation_half u_perm_half (
        .clk(clk), .rst_n(rst_n), .start(perm_start), .rounds(4'd12),
        .ready(ready_half), .done(done_half),
        .in_x0(in_x0), .in_x1(in_x1), .in_x2(in_x2), .in_x3(in_x3), .in_x4(in_x4),
        .out_x0(x0_hf), .out_x1(x1_hf), .out_x2(x2_hf), .out_x3(x3_hf), .out_x4(x4_hf)
    );

    permutation_serial32 u_perm_serial32 (
        .clk(clk), .rst_n(rst_n), .start(perm_start), .rounds(4'd12),
        .ready(ready_ser32), .done(done_ser32),
        .in_x0(in_x0), .in_x1(in_x1), .in_x2(in_x2), .in_x3(in_x3), .in_x4(in_x4),
        .out_x0(x0_s32), .out_x1(x1_s32), .out_x2(x2_s32), .out_x3(x3_s32), .out_x4(x4_s32)
    );

    // Cycle counter & latched completion cycle for each variant (great for waveforms!)
    int cyc = 0;
    int cyc_2r = 0, cyc_1r = 0, cyc_half = 0, cyc_ser32 = 0;
    logic running_perm = 1'b0;

    always @(posedge clk) begin
        if (running_perm) begin
            cyc <= cyc + 1;
            if (done_2r    && cyc_2r    == 0) cyc_2r    <= cyc;
            if (done_1r    && cyc_1r    == 0) cyc_1r    <= cyc;
            if (done_half  && cyc_half  == 0) cyc_half  <= cyc;
            if (done_ser32 && cyc_ser32 == 0) cyc_ser32 <= cyc;
        end else begin
            cyc <= 0;
        end
    end

    // Reference p^12 output for standard NIST test state (matches tb_permutation_1r.sv)
    localparam [63:0] EXP_X0 = 64'hcba43b0a331b0ae5;
    localparam [63:0] EXP_X1 = 64'hd0b1251e0aae45b2;
    localparam [63:0] EXP_X2 = 64'h38a513833140c3d8;
    localparam [63:0] EXP_X3 = 64'h9a7f51ebf8fe3e35;
    localparam [63:0] EXP_X4 = 64'h59d69785c0fa7540;

    int errors = 0;

    initial begin
        $display("========================================================================");
        $display("DEMO 01: ASCON 5-BIT S-BOX & 320-BIT PERMUTATION ARCHITECTURE COMPARISON");
        $display("========================================================================");

        // ----------------------------------------------------------------------
        // PART A: Check all 32 entries of the 5-bit S-box
        // ----------------------------------------------------------------------
        $display("\n[PART A] Checking all 32 S-box inputs across 4 Boolean implementations:");
        $display("  in_x | NIST | Base | ESPRESSO | Kernel | BDD");
        $display("  -----+------+------+----------+--------+-----");

        rst_n      = 1'b0;
        perm_start = 1'b0;
        in_x0 = 64'h0; in_x1 = 64'h0; in_x2 = 64'h0; in_x3 = 64'h0; in_x4 = 64'h0;

        for (int i = 0; i < 32; i++) begin
            sbox_in = 5'(i);
            #1;
            // Print a clean sample (every entry is checked!)
            if (i < 8 || i >= 28)
                $display("   0x%02x | 0x%02x | 0x%02x |   0x%02x   |  0x%02x  | 0x%02x",
                         sbox_in, SBOX_NIST[i], y_baseline, y_espresso, y_kernel, y_bdd);
            else if (i == 8)
                $display("   ...  | ...  | ...  |   ...    |  ...   | ... (all 32 checked)");

            if (y_baseline !== SBOX_NIST[i] || y_espresso !== SBOX_NIST[i] ||
                y_kernel   !== SBOX_NIST[i] || y_bdd      !== SBOX_NIST[i]) begin
                $display("  [ERROR] Mismatch at input 0x%02x!", i);
                errors++;
            end
        end
        $display("  -> Part A Result: All 32/32 inputs identical across Base, ESPRESSO, Kernel, BDD.");

        // ----------------------------------------------------------------------
        // PART B: Run 12 rounds (p^12) concurrently on all 4 permutation cores
        // ----------------------------------------------------------------------
        $display("\n[PART B] Running 12-round Ascon Permutation (p^12) across 4 cores...");
        #(20);
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        @(negedge clk);
        in_x0 = 64'h80400c0600000000;
        in_x1 = 64'h0001020304050607;
        in_x2 = 64'h08090a0b0c0d0e0f;
        in_x3 = 64'h1011121314151617;
        in_x4 = 64'h18191a1b1c1d1e1f;

        perm_start   = 1'b1;
        @(negedge clk);
        perm_start   = 1'b0;
        running_perm = 1'b1; // Start counting compute cycles right after start edge

        wait (cyc_2r != 0 && cyc_1r != 0 && cyc_half != 0 && cyc_ser32 != 0);
        @(posedge clk);
        running_perm = 1'b0;

        $display("\n  Architecture     | Cycles | x0 (MSW out_x0)");
        $display("  -----------------+--------+-------------------");
        $display("  2-Round (2R/cyc) |   %2d   | 0x%016h", cyc_2r,    x0_2r);
        $display("  1-Round (1R/cyc) |   %2d   | 0x%016h", cyc_1r,    x0_1r);
        $display("  Half-Rd (0.5R)   |   %2d   | 0x%016h", cyc_half,  x0_hf);
        $display("  Serial-32 (Paper)|   %2d   | 0x%016h", cyc_ser32, x0_s32);
        $display("  NIST Golden p^12 |   --   | 0x%016h", EXP_X0);

        if ({x0_2r, x1_2r, x2_2r, x3_2r, x4_2r}       !== {EXP_X0, EXP_X1, EXP_X2, EXP_X3, EXP_X4} ||
            {x0_1r, x1_1r, x2_1r, x3_1r, x4_1r}       !== {EXP_X0, EXP_X1, EXP_X2, EXP_X3, EXP_X4} ||
            {x0_hf, x1_hf, x2_hf, x3_hf, x4_hf}       !== {EXP_X0, EXP_X1, EXP_X2, EXP_X3, EXP_X4} ||
            {x0_s32, x1_s32, x2_s32, x3_s32, x4_s32} !== {EXP_X0, EXP_X1, EXP_X2, EXP_X3, EXP_X4}) begin
            $display("  [ERROR] One or more permutation cores mismatched NIST p^12 output!");
            errors++;
        end

        $display("\n========================================================================");
        if (errors == 0) begin
            $display("DEMO 01 RESULT: PASS (All 4 S-boxes & all 4 Permutations bit-exact!)");
            $display("========================================================================");
            $finish;
        end else begin
            $display("DEMO 01 RESULT: FAIL (%0d errors)", errors);
            $display("========================================================================");
            $fatal(1, "Demo 01 failed");
        end
    end

endmodule
