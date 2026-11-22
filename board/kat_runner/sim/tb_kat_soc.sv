`timescale 1ns / 1ps

module tb_kat_soc;
    reg        clk;
    reg        rst_n;
    reg  [3:0] sw;
    wire [3:0] led;
    wire [2:0] rgb_led;
    wire       trap;
    wire       test_pass;
    wire       kat_done;
    wire       kat_all_pass;
    wire [31:0] hash_pass;
    wire [31:0] aead_enc_pass;
    wire [31:0] aead_dec_pass;
    wire [31:0] fail_cnt;
    wire [31:0] cycles;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    top_kat_soc #(
        .FIRMWARE_HEX (`"C:/Users/Aayan/Desktop/RTL_Project/Presentation/kat_board/build/kat_preflight.hex`"),
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
        .kat_hash_pass_out     (hash_pass),
        .kat_aead_enc_pass_out (aead_enc_pass),
        .kat_aead_dec_pass_out (aead_dec_pass),
        .kat_fail_cnt_out      (fail_cnt),
        .kat_cycles_out        (cycles)
    );

    initial begin
        sw    = 4'b0;
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        wait (kat_done == 1'b1 || trap == 1'b1);
        repeat (10) @(posedge clk);

        $display("============================================================");
        $display("TB_KAT_SOC RESULT: done=%b all_pass=%b trap=%b test_pass=%b",
                 kat_done, kat_all_pass, trap, test_pass);
        $display("  Hash Pass     = %0d", hash_pass);
        $display("  AEAD Enc Pass = %0d", aead_enc_pass);
        $display("  AEAD Dec Pass = %0d", aead_dec_pass);
        $display("  Fail Count    = %0d", fail_cnt);
        $display("  Cycles        = %0d", cycles);
        $display("  LED=%4b RGB=%3b", led, rgb_led);
        $display("============================================================");

        if (!kat_all_pass || fail_cnt != 0 || trap) begin
            $fatal(1, "KAT SoC preflight failed!");
        end
        $display("[PASS] KAT SoC preflight passed!");
        $finish;
    end

    initial begin
        #100000000; // 100 ms sim watchdog
        $fatal(1, "Timeout waiting for kat_done");
    end
endmodule

