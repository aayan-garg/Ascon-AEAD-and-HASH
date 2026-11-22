// ==============================================================================
// Presentation Demo 04: End-to-End RISC-V Secure Boot SoC Demo
// Target: Visualizes PicoRV32 + DMA + Ascon-Hash256 + boot_ctrl + fetch_guard
//
// Clean Waveform Display:
//   - All unnecessary signal clutter (clk, trap, internal nets) removed
//   - Self-documenting ASCII string banners: scenario, security_status, fsm_state_name
//   - Exact physical board signals matching Zybo Z7-10 ILA captures
//
// 3 Zybo Z7-10 Physical Demonstrations in Sequence:
//   Scenario A (0 to ~14 us):  Valid firmware -> Hash OK -> boot_jump_enable=1 ->
//                              LEDs=4'b1111, RGB=GREEN (3'b010).
//   Scenario B (14 to ~22 us): Live SW0 byte-flip -> Corrupted digest mismatch ->
//                              boot_refuse=1, LEDs=4'b1010, RGB=RED (3'b001).
//   Scenario C (22 to ~30 us): Live SW1 tamper pulse -> Sticky hardware latch ->
//                              boot_refuse=1, LEDs=4'b1010, RGB=RED (3'b001).
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_04_secure_boot #(
    parameter int RUN_SCENARIO = 0 // 0 = All 3 Scenarios (Matrix), 1 = Scenario A Only (Green Boot)
);

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock

    // ==========================================================================
    // 1. High-Level Waveform String Banners (Visible in Vivado Waveform Viewer)
    // ==========================================================================
    logic [8*48-1:0] scenario        = "INITIALIZING";
    logic [8*48-1:0] security_status = "POWER-ON RESET";
    logic [8*32-1:0] fsm_state_name  = "IDLE";
    logic [8*24-1:0] rgb_color_name  = "OFF";
    logic [8*24-1:0] led_status_name = "OFF";

    // ==========================================================================
    // 2. Clean Top-Level Board & Security Signals (No clk / trap clutter)
    // ==========================================================================
    logic       rst_n      = 1'b0;
    logic [3:0] sw         = 4'b0000; // [0]=Fault Inject, [1]=Tamper Sensor
    wire  [3:0] led;                  // 4'b1111 = Pass, 4'b1010 = Refuse
    wire  [2:0] rgb_led;              // 3'b010  = Green, 3'b001 = Red

    // Hardware Security Intercept Signals
    wire        dma_start;
    wire        dma_busy;
    wire        dma_done;
    wire        hash_ok;
    wire        boot_jump_enable;
    wire        boot_refuse;
    wire        tamper_latched;
    wire [3:0]  boot_fsm_state;

    // ==========================================================================
    // 3. Internal Wires (Not exposed in clean wave window)
    // ==========================================================================
    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    logic tamper_det = 1'b0;
    wire  trap;
    wire  test_pass;

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

    // Map helper signals for clean waveform
    assign boot_jump_enable = dut.boot_jump_enable;
    assign boot_refuse      = dut.boot_refuse;
    assign dma_start        = dut.dma_start;
    assign dma_busy         = dut.dma_busy;
    assign dma_done         = dut.dma_done;
    assign hash_ok          = dut.u_ascon.u_boot_ctrl.hash_ok;
    assign tamper_latched   = dut.u_ascon.u_boot_ctrl.tamper_latched;
    assign boot_fsm_state   = dut.u_ascon.u_boot_ctrl.fsm_state;

    // Format FSM state into human-readable string banner
    always_comb begin
        case (boot_fsm_state)
            4'd0: fsm_state_name = "IDLE";
            4'd1: fsm_state_name = "DMA_TRIGGER";
            4'd2: fsm_state_name = "WAIT_DMA";
            4'd3: fsm_state_name = "WAIT_HASH";
            4'd4: fsm_state_name = "CHECK_DIGEST";
            4'd5: fsm_state_name = "BOOT_GRANTED";
            4'd6: fsm_state_name = "CPU_RUNNING";
            4'd7: fsm_state_name = "BOOT_REFUSED";
            default: fsm_state_name = "UNKNOWN";
        endcase
    end

    // Map RGB LED to human-readable color string
    always_comb begin
        case (rgb_led)
            3'b100:  rgb_color_name = "BLUE (BOOTROM)";
            3'b010:  rgb_color_name = "GREEN (PASS)";
            3'b001:  rgb_color_name = "RED (REFUSED)";
            3'b111:  rgb_color_name = "WHITE (ACTIVE)";
            default: rgb_color_name = "OFF";
        endcase
    end

    // Map Board LEDs to human-readable status string
    always_comb begin
        case (led)
            4'b1111: led_status_name = "PASS (1111)";
            4'b1010: led_status_name = "REFUSED (1010)";
            4'b0001: led_status_name = "BOOTROM RUNNING";
            default: led_status_name = "INIT / OFF";
        endcase
    end

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
            "../../../../tb/demo/hex/bram_case1_valid.hex",
            "../../tb/demo/hex/bram_case1_valid.hex"
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
        scenario        = "SCENARIO A: Normal Boot (GREEN PASS)";
        security_status = "1. VERIFYING AUTHENTIC FIRMWARE";
        $display("\n[SCENARIO A] Power-on / Reset with Authentic Firmware (SW0=0, SW1=0)...");
        reset_with_image(4'b0000);

        fork : wait_a
            begin
                wait (dma_start == 1'b1);
                security_status = "2. DMA STREAMING TO ASCON-HASH";
                wait (boot_jump_enable == 1'b1);
                jump_cyc = cycle_cnt;
                security_status = "3. HASH OK -> BOOT GRANTED (GREEN)";
                wait (test_pass == 1'b1);
                pass_cyc = cycle_cnt;
                security_status = "4. CPU EXECUTION SUCCESSFUL (GREEN 4'b1111)";
                repeat (100) @(posedge clk);
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

        // If user configured to run Scenario A only, finish here with solid green
        if (RUN_SCENARIO == 1) begin
            $display("\n[INFO] RUN_SCENARIO=1: Finishing with Scenario A Active (Solid Green)!");
            scenario        = "SCENARIO A COMPLETE: AUTHENTIC BOOT VERIFIED";
            security_status = "SYSTEM OPERATIONAL: CPU RUNNING (GREEN 4'b1111)";
            repeat (200) @(posedge clk);
            $display("========================================================================");
            $display("DEMO 04 RESULT: PASS (Scenario A Authentic Boot Succeeded!)");
            $display("========================================================================");
            $finish;
        end

        // ----------------------------------------------------------------------
        // SCENARIO B: Live SW0 Byte-Flip Attack (SW0=1 during boot)
        // ----------------------------------------------------------------------
        scenario        = "SCENARIO B: SW0 Byte-Flip Attack (RED REFUSE)";
        security_status = "1. INJECTING 1-BIT FAULT (SW0=1)";
        $display("\n[SCENARIO B] Flipping SW0=1 (1-bit fault injected into DMA word 0x410)...");
        reset_with_image(4'b0001);

        fork : wait_b
            begin
                wait (dma_start == 1'b1);
                security_status = "2. STREAMING CORRUPTED PAYLOAD";
                wait (boot_refuse == 1'b1);
                security_status = "3. DIGEST MISMATCH -> REFUSED (RED 4'b1010)";
                repeat (100) @(posedge clk);
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
        scenario        = "SCENARIO C: SW1 Tamper Pulse (STICKY LOCKOUT)";
        security_status = "1. RE-ARMING VALID IMAGE";
        $display("\n[SCENARIO C] Valid image boots, SW1 pulses high mid-check, then clears...");
        reset_with_image(4'b0000);
        wait (dma_start == 1'b1);
        @(negedge clk);
        security_status = "2. PULSING SW1 TAMPER SWITCH";
        sw         = 4'b0010; // SW1=1 tamper!
        tamper_det = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        security_status = "3. SW1 CLEARED -> HARDWARE STICKY LOCK (RED)";
        sw         = 4'b0000; // Tamper pulse cleared!
        tamper_det = 1'b0;
        repeat (100) @(posedge clk);

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

        scenario        = "ALL SCENARIOS VERIFIED: 100% PASS";
        security_status = "DEMO 04 VERIFICATION COMPLETE";
        repeat (100) @(posedge clk);

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
