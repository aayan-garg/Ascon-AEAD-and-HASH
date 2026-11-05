// ==============================================================================
// Testbench: tb_sbox_equiv.sv
// Target: Phase 4 Permutation Datapath Verification & Task B4 S-Box Characterization
// Description: Exhaustive 32-vector formal equivalence testbench comparing:
//   1. Baseline bit-slice algebraic S-box (sbox5.sv)
//   2. ESPRESSO two-level minimized S-box (sbox5_espresso.sv)
//   3. ANF-restatement S-box (sbox5_kernel.sv)
//   4. 32-entry lookup-table S-box (sbox5_bdd.sv)
//   5. NIST SP 800-232 Table 6 Normative Golden Truth Table
// ==============================================================================

`timescale 1ns / 1ps

module tb_sbox_equiv;

    logic [4:0] in_x;
    wire  [4:0] out_base;
    wire  [4:0] out_espresso;
    wire  [4:0] out_kernel;
    wire  [4:0] out_bdd;

    // 1. Instantiate Baseline S-box
    sbox5 u_base (
        .in_x  (in_x),
        .out_y (out_base)
    );

    // 2. Instantiate ESPRESSO-minimized S-box
    sbox5_espresso u_espresso (
        .in_x  (in_x),
        .out_y (out_espresso)
    );

    // 3. Instantiate ANF-restatement S-box
    sbox5_kernel u_kernel (
        .in_x  (in_x),
        .out_y (out_kernel)
    );

    // 4. Instantiate lookup-table S-box
    sbox5_bdd u_bdd (
        .in_x  (in_x),
        .out_y (out_bdd)
    );

    // NIST SP 800-232 Table 6 Normative Golden Array
    const logic [4:0] SBOX_GOLDEN [0:31] = '{
        5'h04, 5'h0b, 5'h1f, 5'h14, 5'h1a, 5'h15, 5'h09, 5'h02,
        5'h1b, 5'h05, 5'h08, 5'h12, 5'h1d, 5'h03, 5'h06, 5'h1c,
        5'h1e, 5'h13, 5'h07, 5'h0e, 5'h00, 5'h0d, 5'h11, 5'h18,
        5'h10, 5'h0c, 5'h01, 5'h19, 5'h16, 5'h0a, 5'h0f, 5'h17
    };

    int errors = 0;

    initial begin
        $display("================================================================");
        $display("STARTING ASCON S-BOX QUAD-IMPLEMENTATION EQUIVALENCE CHECK");
        $display("Implementations: Baseline vs ESPRESSO vs Kernel vs BDD vs NIST Table 6");
        $display("================================================================");

        for (int i = 0; i < 32; i++) begin
            in_x = 5'(i);
            #1;

            if (out_base !== SBOX_GOLDEN[i]) begin
                $display("[ERROR] Baseline mismatch at 0x%02h: Got 0x%02h, Exp 0x%02h", i, out_base, SBOX_GOLDEN[i]);
                errors++;
            end

            if (out_espresso !== SBOX_GOLDEN[i]) begin
                $display("[ERROR] ESPRESSO mismatch at 0x%02h: Got 0x%02h, Exp 0x%02h", i, out_espresso, SBOX_GOLDEN[i]);
                errors++;
            end

            if (out_kernel !== SBOX_GOLDEN[i]) begin
                $display("[ERROR] Kernel mismatch at 0x%02h: Got 0x%02h, Exp 0x%02h", i, out_kernel, SBOX_GOLDEN[i]);
                errors++;
            end

            if (out_bdd !== SBOX_GOLDEN[i]) begin
                $display("[ERROR] BDD mismatch at 0x%02h: Got 0x%02h, Exp 0x%02h", i, out_bdd, SBOX_GOLDEN[i]);
                errors++;
            end
        end

        $display("================================================================");
        if (errors == 0) begin
            $display("[SUCCESS] Equivalence confirmed: Baseline == ESPRESSO == Kernel == BDD == NIST Golden Table.");
            $display("Total vectors checked: 32 / 32 per implementation (128 assertions, 0 mismatches)");
            $finish(0);
        end else begin
            $display("[FATAL] Equivalence check failed with %0d errors!", errors);
            $fatal(1, "S-box equivalence mismatch!");
        end
    end

endmodule
