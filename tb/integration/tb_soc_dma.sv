// ==============================================================================
// Testbench: tb_soc_dma.sv
// Target: Phase 7 DMA Integration Exit Gate
// Description: End-to-end SoC testbench running bare-metal C firmware
//   (firmware/tests/accel_dma_test.c) on the PicoRV32 RISC-V CPU.
//
// Verification Flow:
//   1. CPU boots from BRAM (0x0000_0000).
//   2. CPU sets up 64-byte payload in BRAM.
//   3. CPU configures Ascon DMA engine over AXI4-Lite (DMA_SRC_ADDR, DMA_LEN).
//   4. CPU triggers DMA-fed Ascon-Hash256 with DMA_AUTO=1 and START=1.
//   5. DMA master reads from BRAM Port B and streams into Ascon coprocessor.
//   6. CPU polls DMA_STATUS and ASCON_STATUS until both report completion.
//   7. CPU reads 256-bit Digest (0x4000_0040..0x4000_005C) and verifies against
//      Python reference golden model.
//   8. CPU writes (1 << 31) to GPIO register at 0x1000_0000.
//   9. Testbench verifies test_pass == 1 and finishes cleanly.
// ==============================================================================

`timescale 1ns / 1ps

module tb_soc_dma;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock

    logic        clk;
    logic        rst_n;
    logic [3:0]  led;
    logic [2:0]  rgb_led;
    logic        trap;
    logic        test_pass;

    // Instantiate SoC Top-Level with Ascon accelerator, DMA engine, & firmware
    top_bringup #(
        .FIRMWARE_HEX ("firmware/tests/accel_dma_test.hex"),
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
    logic test_pass_seen = 1'b0;

    initial begin
        $display("================================================================================");
        $display("STARTING PICORV32 + ASCON DMA INTEGRATION TESTBENCH: tb_soc_dma");
        $display("Target Core:  PicoRV32 RV32I AXI Core");
        $display("Data Plane:   Custom Streaming DMA Master (dma_master.sv)");
        $display("Coprocessor:  Ascon AEAD & Hash Engine (0x4000_0000)");
        $display("Firmware:     firmware/tests/accel_dma_test.hex");
        $display("Clock:        100 MHz (Period: 10 ns)");
        $display("================================================================================");

        // Reset sequence
        rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[TIME %0t] Reset de-asserted. CPU executing accel_dma_test from 0x00000000...", $time);

        // Execution watchdog loop
        while ((cycle_count < 30000) && !test_pass_seen) begin
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
                test_pass_seen = 1'b1;
                $display("\n----------------------------------------------------------------");
                $display("[SUCCESS] Test Pass Marker detected (GPIO bit 31 asserted)!");
                $display("  Cycles Elapsed: %0d cycles (%0t ns)", cycle_count, $time);
                $display("  Discrete LEDs:  4'b%b (0x%h)", led, led);
                $display("  Status: RISC-V Firmware successfully commanded DMA transfer");
                $display("          over AXI4-Lite, streamed 64 bytes from BRAM into Ascon,");
                $display("          and verified Hash256 digest against Golden Reference!");
                $display("----------------------------------------------------------------");
                $display("ALL PHASE 7 EXIT CRITERIA SATISFIED: DMA Integration verification complete.");
                $finish(0);
            end
        end

        if (!test_pass_seen) begin
            $display("\n[FATAL] Simulation timeout after %0d cycles!", cycle_count);
            $fatal(1, "Watchdog timeout!");
        end
    end

endmodule
