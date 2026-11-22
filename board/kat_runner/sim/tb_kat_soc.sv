// ==============================================================================
// On-Board NIST KAT Runner Simulation Testbench: tb_kat_soc.sv
// Target: Validates PicoRV32 + Ascon Engine Full NIST SP 800-232 KAT preflight
//
// Matches physical Zybo Z7-10 ILA capture exactly:
//   - Unnecessary signals (clk, trap, test_pass, sw) removed from wave
//   - Identical probes to hardware ILA:
//     kat_done, kat_all_pass, kat_hash_pass[11:0], kat_aead_enc_pass[11:0],
//     kat_aead_dec_pass[11:0], kat_fail_cnt[11:0], kat_cycles[31:0],
//     kat_status[15:0], dma_start, dma_done, led[3:0], rgb_led[2:0]
// ==============================================================================

`timescale 1ns / 1ps

module tb_kat_soc;

    // String banner for intuitive waveform viewing
    logic [8*48-1:0] kat_phase = "RESET / POWER-ON";

    // Board & Status Wires (Matching Zybo Hardware ILA)
    reg         rst_n;
    wire        kat_done;
    wire        kat_all_pass;
    wire [11:0] kat_hash_pass;
    wire [11:0] kat_aead_enc_pass;
    wire [11:0] kat_aead_dec_pass;
    wire [11:0] kat_fail_cnt;
    wire [31:0] kat_cycles;
    wire [15:0] kat_status;
    wire        dma_start;
    wire        dma_done;
    wire [ 3:0] led;
    wire [ 2:0] rgb_led;

    // Internal nets (not exposed in clean waveform)
    reg  [ 3:0] sw = 4'b0000;
    wire        trap;
    wire        test_pass;
    wire [31:0] hash_pass_32;
    wire [31:0] aead_enc_pass_32;
    wire [31:0] aead_dec_pass_32;
    wire [31:0] fail_cnt_32;

    reg clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz clock (10 ns)

    // Instantiate Top KAT SoC
    top_kat_soc #(
        .FIRMWARE_HEX (""),
        .RAM_WORDS    (32768),
        .BUFFER_DEPTH (32)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .sw                    (sw),
        .led                   (led),
        .rgb_led               (rgb_led),
        .trap                  (trap),
        .test_pass             (test_pass),
        .kat_done_out          (kat_done),
        .kat_all_pass_out      (kat_all_pass),
        .kat_hash_pass_out     (hash_pass_32),
        .kat_aead_enc_pass_out (aead_enc_pass_32),
        .kat_aead_dec_pass_out (aead_dec_pass_32),
        .kat_fail_cnt_out      (fail_cnt_32),
        .kat_cycles_out        (kat_cycles)
    );

    // Map 12-bit counters to match hardware ILA widths
    assign kat_hash_pass     = hash_pass_32[11:0];
    assign kat_aead_enc_pass = aead_enc_pass_32[11:0];
    assign kat_aead_dec_pass = aead_dec_pass_32[11:0];
    assign kat_fail_cnt      = fail_cnt_32[11:0];
    assign kat_status        = dut.kat_status[15:0];
    assign dma_start         = dut.dma_start;
    assign dma_done          = dut.dma_done;

    // Plain English status banner for the waveform
    always_comb begin
        if (!rst_n) begin
            kat_phase = "RESET / POWER-ON";
        end else if (kat_done) begin
            kat_phase = kat_all_pass ? "ALL KATS COMPLETE (100% PASS - GREEN)" : "KAT FAILED (RED)";
        end else if (kat_aead_dec_pass > 0) begin
            kat_phase = "ASCON-AEAD128 DECRYPT KATS";
        end else if (kat_aead_enc_pass > 0) begin
            kat_phase = "ASCON-AEAD128 ENCRYPT KATS";
        end else if (kat_hash_pass > 0) begin
            kat_phase = "ASCON-HASH256 KATS";
        end else begin
            kat_phase = "RUNNING NIST PREFLIGHT...";
        end
    end

    // Resolves kat_preflight.hex dynamically
    function automatic string resolve_kat_hex();
        int fd;
        string candidates[7] = '{
            "kat_preflight.hex",
            "board/kat_runner/fw/kat_preflight.hex",
            "../../../../../../board/kat_runner/fw/kat_preflight.hex",
            "../../../../board/kat_runner/fw/kat_preflight.hex",
            "../../board/kat_runner/fw/kat_preflight.hex",
            "kat_board_all2114.hex",
            "board/kat_runner/fw/kat_board_all2114.hex"
        };
        foreach (candidates[idx]) begin
            fd = $fopen(candidates[idx], "r");
            if (fd != 0) begin
                $fclose(fd);
                return candidates[idx];
            end
        end
        $fatal(1, "Could not locate kat_preflight.hex!");
        return "";
    endfunction

    string hex_path;

    initial begin
        hex_path = resolve_kat_hex();
        $display("============================================================");
        $display("DEMO KAT: ON-BOARD NIST KAT RUNNER PREFLIGHT SIMULATION");
        $display("Firmware image: %s", hex_path);
        $display("============================================================");

        $readmemh(hex_path, dut.bram_mem);

        rst_n = 1'b0;
        sw    = 4'b0000;
        repeat (10) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        wait (kat_done == 1'b1 || trap == 1'b1);
        repeat (50) @(posedge clk);

        $display("============================================================");
        $display("TB_KAT_SOC RESULT: done=%b all_pass=%b trap=%b test_pass=%b",
                 kat_done, kat_all_pass, trap, test_pass);
        $display("  Hash Pass     = %0d (0x%03h)", hash_pass_32, kat_hash_pass);
        $display("  AEAD Enc Pass = %0d (0x%03h)", aead_enc_pass_32, kat_aead_enc_pass);
        $display("  AEAD Dec Pass = %0d (0x%03h)", aead_dec_pass_32, kat_aead_dec_pass);
        $display("  Fail Count    = %0d (0x%03h)", fail_cnt_32, kat_fail_cnt);
        $display("  Cycles        = %0d (0x%08h)", kat_cycles, kat_cycles);
        $display("  Status Reg    = 0x%04h", kat_status);
        $display("  LED = 4'b%b (0x%h) RGB = 3'b%b (0x%h - GREEN)", led, led, rgb_led, rgb_led);
        $display("============================================================");

        if (!kat_all_pass || kat_fail_cnt != 0 || trap) begin
            $fatal(1, "KAT SoC preflight failed!");
        end
        $display("[PASS] KAT SoC preflight passed!");
        $finish;
    end

    initial begin
        wait (kat_done == 1'b1);
        disable sim_watchdog;
    end

    initial begin : sim_watchdog
        #50000000; // 50 ms sim watchdog
        $fatal(1, "Timeout waiting for kat_done");
    end

endmodule
