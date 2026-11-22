// ==============================================================================
// Zybo Z7-10 Physical Board Top-Level for Full On-Board NIST KAT Run
// Clock: 125 MHz (K17) -> MMCM -> 100 MHz System Clock
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module top_kat_board #(
    parameter string FIRMWARE_HEX = ""
) (
    input  wire        clk_125mhz,
    input  wire        rst_btn,
    input  wire [3:0]  sw,
    output wire [3:0]  led,
    output wire        led6_r,
    output wire        led6_g,
    output wire        led6_b
);

    wire clk_100mhz;
    wire clk_100mhz_unbuf;
    wire clkfb_out, clkfb_in;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.0),
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (8.0),
        .CLKOUT0_DIVIDE_F   (10.0),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk_125mhz),
        .CLKFBIN  (clkfb_in),
        .CLKOUT0  (clk_100mhz_unbuf),
        .CLKOUT0B (), .CLKOUT1 (), .CLKOUT1B (), .CLKOUT2 (), .CLKOUT2B (),
        .CLKOUT3  (), .CLKOUT3B (), .CLKOUT4 (), .CLKOUT5 (), .CLKOUT6 (),
        .CLKFBOUT (clkfb_out),
        .CLKFBOUTB(),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (rst_btn)
    );

    BUFG u_bufg_clkfb (.I(clkfb_out), .O(clkfb_in));
    BUFG u_bufg_clkout(.I(clk_100mhz_unbuf), .O(clk_100mhz));

    reg [2:0] rst_sync;
    always @(posedge clk_100mhz or posedge rst_btn or negedge mmcm_locked) begin
        if (rst_btn || !mmcm_locked) begin
            rst_sync <= 3'b000;
        end else begin
            rst_sync <= {rst_sync[1:0], 1'b1};
        end
    end
    wire rst_n = rst_sync[2];

    (* DONT_TOUCH = "TRUE" *) wire [2:0] rgb_led;

    top_kat_soc #(
        .FIRMWARE_HEX (FIRMWARE_HEX),
        .RAM_WORDS    (32768),
        .BUFFER_DEPTH (32)
    ) u_soc (
        .clk                   (clk_100mhz),
        .rst_n                 (rst_n),
        .sw                    (sw),
        .led                   (led),
        .rgb_led               (rgb_led),
        .trap                  (),
        .test_pass             (),
        .kat_done_out          (),
        .kat_all_pass_out      (),
        .kat_hash_pass_out     (),
        .kat_aead_enc_pass_out (),
        .kat_aead_dec_pass_out (),
        .kat_fail_cnt_out      (),
        .kat_cycles_out        ()
    );

    assign led6_r = rgb_led[0];
    assign led6_g = rgb_led[1];
    assign led6_b = rgb_led[2];

endmodule

