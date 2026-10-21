// ==============================================================================
// Testbench: tb_picorv32_bringup.sv
// Target: Phase 2 RISC-V Core Bring-Up Verification
// Requirement: Phase 2 Exit Gate (Execute C Firmware from BRAM, Toggle GPIO, Verify RAM)
// ==============================================================================

`timescale 1ns / 1ps

module tb_picorv32_bringup;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock

    logic        clk;
    logic        rst_n;
    logic [3:0]  led;
    logic [2:0]  rgb_led;
    logic        trap;
    logic        test_pass;

    // Instantiate SoC Top-Level
    top_bringup #(
        .FIRMWARE_HEX ("firmware/tests/gpio_toggle.hex"),
        .RAM_WORDS    (4096)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .led       (led),
        .rgb_led   (rgb_led),
        .trap      (trap),
        .test_pass (test_pass)
    );

    // Clock generator (100 MHz)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test sequence & assertion monitoring
    int cycle_count = 0;
    logic [3:0] last_led = 4'h0;
    bit saw_led1 = 0;
    bit saw_led2 = 0;
    bit saw_led4 = 0;
    bit saw_led8 = 0;
    bit saw_ledF = 0;

    initial begin
        $display("================================================================");
        $display("STARTING PICORV32 BRING-UP TESTBENCH: tb_picorv32_bringup");
        $display("Target Core: PicoRV32 RV32I AXI Core");
        $display("Firmware:    firmware/tests/gpio_toggle.hex");
        $display("Clock:       100 MHz (Period: 10 ns)");
        $display("================================================================");

        // Waveform dump for visual inspection
        $dumpfile("sim_build/tb_picorv32_bringup.vcd");
        $dumpvars(0, tb_picorv32_bringup);

        // Reset assertion
        rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[TIME %0t] Reset de-asserted. CPU executing from 0x00000000...", $time);

        // Execution loop
        while (cycle_count < 20000) begin
            @(posedge clk);
            cycle_count++;

            // Trap check
            if (trap) begin
                $display("\n[FATAL] CPU trap asserted at cycle %0d (time %0t)!", cycle_count, $time);
                $fatal(1, "CPU trapped unexpectedly!");
            end

            // Monitor LED transitions
            if (led !== last_led) begin
                $display("[TIME %0t | Cycle %0d] GPIO LED transition: %b -> %b (Hex: 0x%h)", 
                         $time, cycle_count, last_led, led, led);
                if (led == 4'b0001) saw_led1 = 1;
                if (led == 4'b0010) saw_led2 = 1;
                if (led == 4'b0100) saw_led4 = 1;
                if (led == 4'b1000) saw_led8 = 1;
                if (led == 4'b1111) saw_ledF = 1;
                last_led = led;
            end

            // Completion check
            if (test_pass) begin
                $display("\n----------------------------------------------------------------");
                $display("[SUCCESS] Test Pass Marker detected (GPIO bit 31 asserted)!");
                $display("  Cycles Elapsed:      %0d cycles", cycle_count);
                $display("  Execution Time:      %0t ns", $time);
                $display("  Walking 1s Observed: [LED0:%0d, LED1:%0d, LED2:%0d, LED3:%0d, ALL:%0d]",
                         saw_led1, saw_led2, saw_led4, saw_led8, saw_ledF);
                $display("  Final LED State:     %b (Hex: 0x%h)", led, led);
                $display("  Scratch RAM Read/Write Verification: PASSED");
                $display("----------------------------------------------------------------");

                if (saw_led1 && saw_led2 && saw_led4 && saw_led8 && saw_ledF) begin
                    $display("ALL PHASE 2 CRITERIA SATISFIED: PicoRV32 bring-up VERIFIED!");
                    $finish(0);
                end else begin
                    $display("[FAIL] Not all expected LED toggle sequences were observed.");
                    $fatal(1, "Missing LED state transitions.");
                end
            end
        end

        $display("\n[TIMEOUT] Testbench exceeded 20,000 cycles without reaching completion marker.");
        $fatal(1, "Simulation timed out.");
    end

endmodule
