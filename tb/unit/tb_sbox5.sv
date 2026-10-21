// ==============================================================================
// Testbench: tb_sbox5.sv
// Target: Phase 4 Permutation Datapath Verification
// Description: Exhaustive 32-vector verification of the 5-bit Ascon S-box
// Reference: NIST SP 800-232 Table 6 (Section 3.2.1)
// ==============================================================================

`timescale 1ns / 1ps

module tb_sbox5;

    logic [4:0] in_x;
    wire  [4:0] out_y;

    // Instantiate Unit Under Test
    sbox5 dut (
        .in_x  (in_x),
        .out_y (out_y)
    );

    // NIST SP 800-232 Table 6 Normative Golden S-box Output Array
    const logic [4:0] SBOX_GOLDEN [0:31] = '{
        5'h04, 5'h0b, 5'h1f, 5'h14, 5'h1a, 5'h15, 5'h09, 5'h02,
        5'h1b, 5'h05, 5'h08, 5'h12, 5'h1d, 5'h03, 5'h06, 5'h1c,
        5'h1e, 5'h13, 5'h07, 5'h0e, 5'h00, 5'h0d, 5'h11, 5'h18,
        5'h10, 5'h0c, 5'h01, 5'h19, 5'h16, 5'h0a, 5'h0f, 5'h17
    };

    int errors = 0;

    initial begin
        $display("================================================================");
        $display("STARTING ASCON S-BOX EXHAUSTIVE VERIFICATION: tb_sbox5");
        $display("Standard: NIST SP 800-232 Table 6");
        $display("Total Vectors: 32 exhaustive inputs (0x00 .. 0x1F)");
        $display("================================================================");

        for (int i = 0; i < 32; i++) begin
            in_x = 5'(i);
            #1; // Combinational propagation delay

            if (out_y !== SBOX_GOLDEN[i]) begin
                $display("[ERROR] S-box mismatch for input 0x%02h (binary %05b): Expected 0x%02h, Got 0x%02h",
                         i, in_x, SBOX_GOLDEN[i], out_y);
                errors++;
            end else begin
                $display("  Vector %2d: in=0x%02h (%05b) -> out=0x%02h (%05b) [MATCH]",
                         i, in_x, in_x, out_y, out_y);
            end
        end

        $display("================================================================");
        if (errors == 0) begin
            $display("[SUCCESS] ALL 32 S-BOX VECTORS MATCHED NIST SP 800-232 TABLE 6!");
            $display("Mismatches: 0 / 32");
            $finish(0);
        end else begin
            $display("[FATAL] S-box verification failed with %0d errors!", errors);
            $fatal(1, "S-box truth table mismatch!");
        end
    end

endmodule
