// ==============================================================================
// Presentation Demo 04: End-to-End RISC-V Secure Boot SoC Demo
// Target: Visualizes PicoRV32 + DMA + Ascon-Hash256 + boot_ctrl + fetch_guard
//
// Mirrors the exact 3 Zybo Z7-10 physical board demonstrations in simulation:
//   Scenario A: Valid image (SW0=0, SW1=0)  -> Hash OK -> boot_jump_enable=1 ->
//               GPIO test_pass=1, LEDs=4'b1111, RGB=GREEN (3'b010).
//   Scenario B: Live SW0 byte-flip (SW0=1)  -> DMA corrupts bit 0 of word 0x410 ->
//               Digest mismatch -> boot_refuse=1, LEDs=4'b1010, RGB=RED (3'b001).
//   Scenario C: Live SW1 tamper pulse       -> Sticky hardware tamper latch ->
//               Even after SW1 returns 0, boot remains locked in STATE_HALT_REFUSE!
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_04_secure_boot;

    localparam time CLK_PERIOD = 10ns; // 100 MHz

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    logic       rst_n;
    logic       tamper_det;
    logic [3:0] sw;
    wire  [3:0] led;
    wire  [2:0] rgb_led;
    wire        trap;
    wire        test_pass;

    // Pass FIRMWARE_HEX="" so testbench resolves the hex path cleanly in both GUI & CLI XSim
    top_bringup #(
        .FIRMWARE_HEX       (""),
        .RAM_WORDS          (4096),
        .BUFFER_DEPTH       (32),
        .ENABLE_FETCH_GUARD (1)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .tamper_det (tamper_det),
        .sw         (sw),
        .led        (led),
        .rgb_led    (rgb_led),
        .trap       (trap),
        .test_pass  (test_pass)
    );

    // Helper signals for crystal-clear waveform viewing in Vivado GUI
    wire       boot_jump_enable = dut.boot_jump_enable;
    wire       boot_refuse      = dut.boot_refuse;
    wire       dma_start        = dut.dma_start;
    wire       dma_done         = dut.dma_done;
    wire       hash_ok          = dut.u_ascon.u_boot_ctrl.hash_ok;
    wire       tamper_latched   = dut.u_ascon.u_boot_ctrl.tamper_latched;
    wire [3:0] boot_fsm_state   = dut.u_ascon.u_boot_ctrl.fsm_state;

    // Cycle counter measured from reset release
    int cycle_cnt;
    always @(posedge clk) begin
        if (!rst_n) cycle_cnt <= 0;
        else        cycle_cnt <= cycle_cnt + 1;
    end

    // Finds bram_case1_valid.hex regardless of Vivado GUI vs CLI working folder
    function automatic string resolve_valid_hex();
        int fd;
        string candidates[8] = '{
            "bram_case1_valid.hex",
            "tb/demo/hex/bram_case1_valid.hex",
            "firmware/tests/boot_matrix/bram_case1_valid.hex",
            "../../../../../../firmware/tests/boot_matrix/bram_case1_valid.hex",
            "../../../../../../tb/demo/hex/bram_case1_valid.hex",
            "../../../../firmware/tests/boot_matrix/bram_case1_valid.hex",
            "C:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/firmware/tests/boot_matrix/bram_case1_valid.hex",
            "C:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/tb/demo/hex/bram_case1_valid.hex"
        };
        foreach (candidates[idx]) begin
            fd = $fopen(candidates[idx], "r");
            if (fd != 0) begin
                $fclose(fd);
                return candidates[idx];
            end
        end
        $fatal(1, "Could not locate bram_case1_valid.hex!");
        return "";
    endfunction

    string hex_path;
    int    jump_cyc = 0;
    int    pass_cyc = 0;
    int    errors   = 0;

    task reset_with_image(input logic [3:0] sw_val);
        rst_n      = 1'b0;
        tamper_det = 1'b0;
        sw         = sw_val;
        $readmemh(hex_path, dut.bram_mem);
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    endtask

    initial begin
        hex_path = resolve_valid_hex();
        $display("========================================================================");
        $display("DEMO 04: FULL RISC-V SECURE BOOT SoC (VALID / SW0 ATTACK / SW1 TAMPER)");
        $display("Firmware image: %s", hex_path);
        $display("========================================================================");

        // ----------------------------------------------------------------------
        // SCENARIO A: Normal Untampered Boot (SW0=0, SW1=0)
        // ----------------------------------------------------------------------
        $display("\n[SCENARIO A] Power-on / Reset with Authentic Firmware (SW0=0, SW1=0)...");
        reset_with_image(4'b0000);

        fork : wait_a
            begin
                wait (boot_jump_enable == 1'b1);
                jump_cyc = cycle_cnt;
                wait (test_pass == 1'b1);
                pass_cyc = cycle_cnt;
                repeat (2) @(posedge clk);
                disable wait_a;
            end
            begin
                #200000;
                $display("  [ERROR] Timed out waiting for valid boot!");
                errors++;
                disable wait_a;
            end
        join

        $display("  Boot Timing : reset -> boot_jump_enable = %0d cycles (%.2f us)", jump_cyc, jump_cyc * 0.01);
        $display("  Boot Timing : reset -> test_pass        = %0d cycles (%.2f us)", pass_cyc, pass_cyc * 0.01);
        $display("  Board State : hash_ok=%b, jump_en=%b, refuse=%b, LED=4'b%b, RGB=3'b%b (010=GREEN)",
                 hash_ok, boot_jump_enable, boot_refuse, led, rgb_led);

        if (test_pass !== 1'b1 || led !== 4'b1111 || rgb_led !== 3'b010 || boot_refuse !== 1'b0) begin
            $display("  [ERROR] Scenario A failed!");
            errors++;
        end else begin
            $display("  [PASS] Authentic firmware verified by Ascon-Hash256 and booted cleanly!");
        end

        // ----------------------------------------------------------------------
        // SCENARIO B: Live SW0 Byte-Flip Attack (SW0=1 during boot)
        // ----------------------------------------------------------------------
        $display("\n[SCENARIO B] Flipping SW0=1 (1-bit fault injected into DMA word 0x410)...");
        reset_with_image(4'b0001);

        fork : wait_b
            begin
                wait (boot_refuse == 1'b1);
                repeat (10) @(posedge clk);
                disable wait_b;
            end
            begin
                #200000;
                $display("  [ERROR] Timed out waiting for SW0 refusal!");
                errors++;
                disable wait_b;
            end
        join

        $display("  Board State : hash_ok=%b, jump_en=%b, refuse=%b, test_pass=%b",
                 hash_ok, boot_jump_enable, boot_refuse, test_pass);
        $display("  LED Output  : LED=4'b%b (1010), RGB=3'b%b (001=RED)", led, rgb_led);

        if (boot_refuse !== 1'b1 || boot_jump_enable !== 1'b0 || test_pass !== 1'b0 ||
            led !== 4'b1010 || rgb_led !== 3'b001) begin
            $display("  [ERROR] Scenario B failed to refuse!");
            errors++;
        end else begin
            $display("  [PASS] 1-bit payload corruption detected and locked out with RED / 4'b1010!");
        end

        // ----------------------------------------------------------------------
        // SCENARIO C: Physical SW1 Tamper Sensor Pulse (Sticky Hardware Lockout)
        // ----------------------------------------------------------------------
        $display("\n[SCENARIO C] Valid image boots, SW1 pulses high mid-check, then clears...");
        reset_with_image(4'b0000);
        wait (dma_start == 1'b1);
        @(negedge clk);
        sw         = 4'b0010; // SW1=1 tamper!
        tamper_det = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        sw         = 4'b0000; // Tamper pulse cleared!
        tamper_det = 1'b0;
        repeat (15) @(posedge clk);

        $display("  Post-Pulse  : tamper_latched=%b, jump_en=%b, refuse=%b, fsm_state=%0d (7=REFUSE)",
                 tamper_latched, boot_jump_enable, boot_refuse, boot_fsm_state);
        $display("  LED Output  : LED=4'b%b, RGB=3'b%b (001=RED)", led, rgb_led);

        if (tamper_latched !== 1'b1 || boot_refuse !== 1'b1 || boot_jump_enable !== 1'b0 ||
            test_pass !== 1'b0 || led !== 4'b1010 || rgb_led !== 3'b001) begin
            $display("  [ERROR] Scenario C sticky tamper failed!");
            errors++;
        end else begin
            $display("  [PASS] Sticky tamper lockout held even after tamper pulse returned to 0!");
        end

        $display("\n========================================================================");
        if (errors == 0) begin
            $display("DEMO 04 RESULT: PASS (All 3 Zybo Board Boot Scenarios Verified in Sim!)");
            $display("========================================================================");
            $finish;
        end else begin
            $display("DEMO 04 RESULT: FAIL (%0d errors)", errors);
            $display("========================================================================");
            $fatal(1, "Demo 04 failed");
        end
    end

endmodule

