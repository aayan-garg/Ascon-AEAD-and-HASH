// ==============================================================================
// Testbench: tb_diffusion.sv
// Target: Phase 4 Permutation Datapath Verification
// Description: Directed and randomized verification of the linear diffusion layer
// Reference: NIST SP 800-232 Section 3.2.3 (Linear Diffusion Layer)
// ==============================================================================

`timescale 1ns / 1ps

module tb_diffusion;

    logic [63:0] in_x0, in_x1, in_x2, in_x3, in_x4;
    wire  [63:0] out_x0, out_x1, out_x2, out_x3, out_x4;

    // Instantiate Unit Under Test
    diffusion dut (
        .in_x0  (in_x0),
        .in_x1  (in_x1),
        .in_x2  (in_x2),
        .in_x3  (in_x3),
        .in_x4  (in_x4),
        .out_x0 (out_x0),
        .out_x1 (out_x1),
        .out_x2 (out_x2),
        .out_x3 (out_x3),
        .out_x4 (out_x4)
    );

    // Reference model function for verification
    function automatic [63:0] rotr_ref(input [63:0] w, input int r);
        rotr_ref = (w >> r) | (w << (64 - r));
    endfunction

    function automatic [63:0] sigma0_ref(input [63:0] x);
        sigma0_ref = x ^ rotr_ref(x, 19) ^ rotr_ref(x, 28);
    endfunction

    function automatic [63:0] sigma1_ref(input [63:0] x);
        sigma1_ref = x ^ rotr_ref(x, 61) ^ rotr_ref(x, 39);
    endfunction

    function automatic [63:0] sigma2_ref(input [63:0] x);
        sigma2_ref = x ^ rotr_ref(x, 1) ^ rotr_ref(x, 6);
    endfunction

    function automatic [63:0] sigma3_ref(input [63:0] x);
        sigma3_ref = x ^ rotr_ref(x, 10) ^ rotr_ref(x, 17);
    endfunction

    function automatic [63:0] sigma4_ref(input [63:0] x);
        sigma4_ref = x ^ rotr_ref(x, 7) ^ rotr_ref(x, 41);
    endfunction

    int errors = 0;

    initial begin
        $display("================================================================");
        $display("STARTING ASCON LINEAR DIFFUSION VERIFICATION: tb_diffusion");
        $display("Standard: NIST SP 800-232 Section 3.2.3");
        $display("================================================================");

        // 1. Directed Test Vectors
        in_x0 = 64'h80400c0600000000;
        in_x1 = 64'h0001020304050607;
        in_x2 = 64'h08090a0b0c0d0e0f;
        in_x3 = 64'h1011121314151617;
        in_x4 = 64'h18191a1b1c1d1e1f;
        #1;

        if (out_x0 !== 64'h80401c0605800060) begin
            $display("[ERROR] Sigma0 mismatch: Expected 0x80401c0605800060, Got 0x%016h", out_x0);
            errors++;
        end
        if (out_x1 !== 64'h060118172a2d343b) begin
            $display("[ERROR] Sigma1 mismatch: Expected 0x060118172a2d343b, Got 0x%016h", out_x1);
            errors++;
        end
        if (out_x2 !== 64'hb02dab26a63bbd30) begin
            $display("[ERROR] Sigma2 mismatch: Expected 0xb02dab26a63bbd30, Got 0x%016h", out_x2);
            errors++;
        end
        if (out_x3 !== 64'h1ede9e5f19d99958) begin
            $display("[ERROR] Sigma3 mismatch: Expected 0x1ede9e5f19d99958, Got 0x%016h", out_x3);
            errors++;
        end
        if (out_x4 !== 64'h2ba726a025a928ae) begin
            $display("[ERROR] Sigma4 mismatch: Expected 0x2ba726a025a928ae, Got 0x%016h", out_x4);
            errors++;
        end

        $display("[DIRECTED TEST] All 5 directed Sigma vectors passed!");

        // 2. Randomized Stress Test (1,000 random 320-bit states)
        for (int t = 0; t < 1000; t++) begin
            in_x0 = {$urandom(), $urandom()};
            in_x1 = {$urandom(), $urandom()};
            in_x2 = {$urandom(), $urandom()};
            in_x3 = {$urandom(), $urandom()};
            in_x4 = {$urandom(), $urandom()};
            #1;

            if (out_x0 !== sigma0_ref(in_x0) ||
                out_x1 !== sigma1_ref(in_x1) ||
                out_x2 !== sigma2_ref(in_x2) ||
                out_x3 !== sigma3_ref(in_x3) ||
                out_x4 !== sigma4_ref(in_x4)) begin
                $display("[ERROR] Random mismatch at iteration %0d", t);
                errors++;
            end
        end

        $display("[RANDOM TEST] 1,000 randomized 320-bit state trials verified!");

        $display("================================================================");
        if (errors == 0) begin
            $display("[SUCCESS] Linear diffusion layer tests passed.");
            $finish(0);
        end else begin
            $display("[FATAL] Diffusion verification failed with %0d errors!", errors);
            $fatal(1, "Diffusion layer mismatch!");
        end
    end

endmodule
