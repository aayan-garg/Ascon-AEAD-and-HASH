// ==============================================================================
// Zybo Z7-10 Physical Board Top-Level: top_bringup_board.sv
// Target: AMD-Xilinx XC7Z010-1CLG400C (Zybo Z7-10)
// Clock: 125 MHz Oscillator (K17) -> MMCM -> 100 MHz System Clock
// Reset: BTN0 (K18, Active-High) -> Inverted + Locked Synchronizer
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module top_bringup_board #(
    parameter string FIRMWARE_HEX = "firmware/tests/gpio_toggle_board.hex"
) (
    input  wire        clk_125mhz, // 125 MHz from Ethernet PHY on pin K17
    input  wire        rst_btn,    // BTN0 on pin K18 (Active-high)
    output wire [3:0]  led,        // LD0..LD3 on pins M14, M15, G14, D18
    output wire        led6_r,     // RGB LD6 Red on pin V16
    output wire        led6_g,     // RGB LD6 Green on pin F17
    output wire        led6_b      // RGB LD6 Blue on pin M17
);

    // =========================================================================
    // 1. Clock Generation via Xilinx 7-Series MMCM (125 MHz -> 100 MHz)
    // =========================================================================
    wire clk_100mhz;
    wire clk_100mhz_unbuf;
    wire clkfb_out;
    wire clkfb_in;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.0),       // 125 MHz * 8.0 = 1000 MHz VCO
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (8.0),       // 125 MHz = 8.000 ns
        .CLKOUT0_DIVIDE_F   (10.0),      // 1000 MHz / 10.0 = 100.0 MHz
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk_125mhz),
        .CLKFBIN  (clkfb_in),
        .CLKOUT0  (clk_100mhz_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUT (clkfb_out),
        .CLKFBOUTB(),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (rst_btn)
    );

    // Global Clock Buffers
    BUFG u_bufg_clkfb (.I(clkfb_out), .O(clkfb_in));
    BUFG u_bufg_clkout(.I(clk_100mhz_unbuf), .O(clk_100mhz));

    // =========================================================================
    // 2. Reset Synchronizer
    // =========================================================================
    // Reset is asserted if user presses BTN0 OR MMCM loses lock
    reg [2:0] rst_sync;
    always @(posedge clk_100mhz or posedge rst_btn or negedge mmcm_locked) begin
        if (rst_btn || !mmcm_locked) begin
            rst_sync <= 3'b000;
        end else begin
            rst_sync <= {rst_sync[1:0], 1'b1};
        end
    end
    wire rst_n = rst_sync[2];

    // =========================================================================
    // 3. PicoRV32 SoC Core Instance
    // =========================================================================
    wire [2:0] rgb_led;

    top_bringup #(
        .FIRMWARE_HEX (FIRMWARE_HEX),
        .RAM_WORDS    (4096)
    ) u_soc (
        .clk       (clk_100mhz),
        .rst_n     (rst_n),
        .led       (led),
        .rgb_led   (rgb_led),
        .trap      (),
        .test_pass ()
    );

    assign led6_r = rgb_led[0];
    assign led6_g = rgb_led[1];
    assign led6_b = rgb_led[2];

endmodule
