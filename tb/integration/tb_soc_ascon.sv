// ==============================================================================
// Testbench: tb_soc_ascon.sv
// Target: Phase 6 Integration Exit Gate
// Description: End-to-end SoC testbench running bare-metal C firmware
//   (firmware/tests/accel_hash_test.c) on the PicoRV32 RISC-V CPU.
//
// Verification Flow:
//   1. CPU boots from BRAM (0x0000_0000).
//   2. CPU reads Ascon CORE_ID at 0x4000_007C over AXI4-Lite.
//   3. CPU triggers Ascon-Hash256 via 0x4000_0000, polls STATUS, reads DIGEST.
//   4. CPU verifies digest matches official NIST SP 800-232 KAT Count 1.
//   5. CPU triggers Ascon-AEAD128 via 0x4000_0000, polls STATUS, reads TAG.
//   6. CPU verifies tag matches official NIST SP 800-232 KAT Count 1.
//   7. CPU writes (1 << 31) to GPIO register at 0x1000_0000.
//   8. Testbench verifies test_pass == 1 and finishes cleanly.
// ==============================================================================

`timescale 1ns / 1ps

module tb_soc_ascon;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock

    logic        clk;
    logic        rst_n;
    logic [3:0]  led;
    logic [2:0]  rgb_led;
    logic        trap;
    logic        test_pass;

    // Instantiate SoC Top-Level with Ascon accelerator & firmware
    top_bringup #(
        .FIRMWARE_HEX ("firmware/tests/accel_hash_test.hex"),
        .RAM_WORDS    (4096)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .led       (led),
        .rgb_led   (rgb_led),
        .trap      (trap),
        .test_pass (test_pass)
    );

    // 100 MHz clock generator
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    int cycle_count = 0;
    logic [3:0] last_led = 4'h0;

    initial begin
        $display("================================================================================");
        $display("STARTING PICORV32 + ASCON HARDWARE INTEGRATION TESTBENCH: tb_soc_ascon");
        $display("Target Core:  PicoRV32 RV32I AXI Core");
        $display("Coprocessor:  Ascon AEAD & Hash Engine (0x4000_0000)");
        $display("Firmware:     firmware/tests/accel_hash_test.hex");
        $display("Clock:        100 MHz (Period: 10 ns)");
        $display("================================================================================");

        // Reset sequence
        rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[TIME %0t] Reset de-asserted. CPU executing accel_hash_test from 0x00000000...", $time);

        // Execution watchdog loop
        while (cycle_count < 30000) begin
            @(posedge clk);
            cycle_count++;

            // CPU trap check
            if (trap) begin
                $display("\n[FATAL] CPU trap asserted at cycle %0d (time %0t)!", cycle_count, $time);
                $fatal(1, "CPU trapped unexpectedly!");
            end

            // Monitor GPIO LED changes
            if (led !== last_led) begin
                $display("[TIME %0t | Cycle %0d] GPIO LED transition: 0x%h -> 0x%h",
                         $time, cycle_count, last_led, led);
                last_led = led;
            end

            // Completion check
            if (test_pass) begin
                $display("\n----------------------------------------------------------------");
                $display("[SUCCESS] Test Pass Marker detected (GPIO bit 31 asserted)!");
                $display("  Cycles Elapsed: %0d cycles (%0t ns)", cycle_count, $time);
                $display("  Discrete LEDs:  4'b%b (0x%h)", led, led);
                $display("  Status: RISC-V Firmware successfully commanded Ascon Coprocessor");
                $display("          over AXI4-Lite, verified Hash256 digest & AEAD128 tag");
                $display("          against official NIST SP 800-232 Known Answer Tests!");
                $display("----------------------------------------------------------------");
                $display("ALL PHASE 6 EXIT CRITERIA SATISFIED: AXI4-Lite SoC Integration VERIFIED!");
                $finish(0);
            end
        end

        $display("\n[TIMEOUT] Testbench exceeded 30,000 cycles without reaching completion marker.");
        $fatal(1, "Simulation timed out.");
    end

endmodule
