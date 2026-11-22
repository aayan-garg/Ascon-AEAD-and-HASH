// ==============================================================================
// Presentation Demo 05: Hardware Instruction Fetch Guard Security Proof
// Target: Demonstrates why Software Checks Alone Are Not Enough!
//
// Runs malicious firmware (forced_jump.hex) that skips Ascon verification and
// attempts an unauthorized jump straight to app entry point 0x0000_1040:
//   - Left SoC  (ENABLE_FETCH_GUARD = 1): Hardware fetch_guard intercepts reads
//     to [0x1040..0x4000) and substitutes RISC-V NOP (0x00000013), blocking exec!
//   - Right SoC (ENABLE_FETCH_GUARD = 0): Control experiment without guard ->
//     malicious payload executes immediately and raises test_pass = 1!
// ==============================================================================

`timescale 1ns / 1ps

module tb_demo_05_fetch_guard;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    logic rst_n_guarded, rst_n_unguarded;
    wire [3:0] led_guarded, led_unguarded;
    wire [2:0] rgb_guarded, rgb_unguarded;
    wire       trap_guarded, trap_unguarded;
    wire       pass_guarded, pass_unguarded;

    top_bringup #(
        .FIRMWARE_HEX       (""),
        .RAM_WORDS          (4096),
        .BUFFER_DEPTH       (32),
        .ENABLE_FETCH_GUARD (1)
    ) dut_guarded (
        .clk        (clk),
        .rst_n      (rst_n_guarded),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_guarded),
        .rgb_led    (rgb_guarded),
        .trap       (trap_guarded),
        .test_pass  (pass_guarded)
    );

    top_bringup #(
        .FIRMWARE_HEX       (""),
        .RAM_WORDS          (4096),
        .BUFFER_DEPTH       (32),
        .ENABLE_FETCH_GUARD (0)
    ) dut_unguarded (
        .clk        (clk),
        .rst_n      (rst_n_unguarded),
        .tamper_det (1'b0),
        .sw         (4'b0000),
        .led        (led_unguarded),
        .rgb_led    (rgb_unguarded),
        .trap       (trap_unguarded),
        .test_pass  (pass_unguarded)
    );

    // Expose internal guard wires for live Vivado waveform inspection
    wire        guard_jump_en   = dut_guarded.boot_jump_enable;
    wire [31:0] guard_addr      = dut_guarded.bram_araddr_q;
    wire [31:0] guard_raw_bram  = dut_guarded.bram_rdata_raw;
    wire [31:0] guard_cpu_rdata = dut_guarded.bram_rdata;
    wire        guard_blocking  = dut_guarded.u_fetch_guard.block_fetch;

    function automatic string resolve_forced_jump_hex();
        int fd;
        string candidates[8] = '{
            "forced_jump.hex",
            "tb/demo/hex/forced_jump.hex",
            "firmware/tests/forced_jump.hex",
            "../../../../../../firmware/tests/forced_jump.hex",
            "../../../../../../tb/demo/hex/forced_jump.hex",
            "../../../../firmware/tests/forced_jump.hex",
            "C:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/firmware/tests/forced_jump.hex",
            "C:/Users/Aayan/Desktop/RTL_Project/Ascon-AEAD-and-HASH/tb/demo/hex/forced_jump.hex"
        };
        foreach (candidates[idx]) begin
            fd = $fopen(candidates[idx], "r");
            if (fd != 0) begin
                $fclose(fd);
                return candidates[idx];
            end
        end
        $fatal(1, "Could not locate forced_jump.hex!");
        return "";
    endfunction

    string hex_path;
    int    blocked_prints = 0;
    int    errors = 0;

    // Print the first 3 intercepted unauthorized app fetches!
    always @(posedge clk) begin
        if (rst_n_guarded && dut_guarded.bram_rvalid && guard_blocking && blocked_prints < 3) begin
            $display("  [FETCH GUARD BLOCK] Addr=0x%08h | Real BRAM=0x%08h -> Returned NOP=0x%08h",
                     guard_addr, guard_raw_bram, guard_cpu_rdata);
            blocked_prints++;
        end
    end

    initial begin
        hex_path = resolve_forced_jump_hex();
        $display("========================================================================");
        $display("DEMO 05: HARDWARE FETCH GUARD PROOF (FORCED JUMP TO 0x0000_1040)");
        $display("Firmware: %s", hex_path);
        $display("========================================================================");

        rst_n_guarded   = 1'b0;
        rst_n_unguarded = 1'b0;
        $readmemh(hex_path, dut_guarded.bram_mem);
        $readmemh(hex_path, dut_unguarded.bram_mem);
        repeat (5) @(posedge clk);

        // Step 1: Run WITH Hardware Fetch Guard Enabled
        $display("\n[TEST 1] Guard ENABLED (ENABLE_FETCH_GUARD = 1)...");
        @(negedge clk) rst_n_guarded = 1'b1;
        repeat (2000) @(posedge clk);

        $display("  Result: jump_enable=%b, test_pass=%b (0 = payload blocked!)",
                 guard_jump_en, pass_guarded);
        if (pass_guarded !== 1'b0 || guard_jump_en !== 1'b0 || blocked_prints == 0) begin
            $display("  [ERROR] Fetch guard failed to intercept unauthorized jump!");
            errors++;
        end else begin
            $display("  [PASS] Unauthorized jump trapped in NOP slide — payload never executed!");
        end

        // Step 2: Run WITHOUT Hardware Fetch Guard (Control Experiment)
        $display("\n[TEST 2] Guard BYPASSED (ENABLE_FETCH_GUARD = 0)...");
        @(negedge clk) rst_n_unguarded = 1'b1;
        fork : wait_bypass
            begin
                wait (pass_unguarded == 1'b1);
                $display("  Result: test_pass=%b (1 = unguarded payload executed cleanly!)", pass_unguarded);
                $display("  [PASS] Bypass control confirms payload works when guard is absent.");
                disable wait_bypass;
            end
            begin
                #50000;
                $display("  [ERROR] Unguarded control timed out!");
                errors++;
                disable wait_bypass;
            end
        join

        $display("\n========================================================================");
        if (errors == 0) begin
            $display("DEMO 05 RESULT: PASS (Hardware Fetch Guard Stops Forced Jump!)");
            $display("========================================================================");
            $finish;
        end else begin
            $display("DEMO 05 RESULT: FAIL (%0d errors)", errors);
            $display("========================================================================");
            $fatal(1, "Demo 05 failed");
        end
    end

endmodule

