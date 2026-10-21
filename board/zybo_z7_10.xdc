## ==============================================================================
## Zybo Z7-10 Board Constraints File (XDC)
## Target: Digilent Zybo Z7-10 (AMD-Xilinx XC7Z010-1CLG400C)
## Project: Ascon AEAD and Hash Engine for IoT Secure Boot
## Source: Digilent Zybo-Z7-Master.xdc & Zybo Z7 Reference Manual
## ==============================================================================

## -----------------------------------------------------------------------------
## 1. Primary Clock (125 MHz PL oscillator from Ethernet PHY)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk_125mhz }]; # IO_L12P_T1_MRCC_35 Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4.000} [get_ports { clk_125mhz }];

## -----------------------------------------------------------------------------
## 2. Reset Button (Active-High Reset)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { rst_btn }]; # btn[0], IO_L12N_T1_MRCC_35 Sch=btn[0]

## -----------------------------------------------------------------------------
## 3. User Push Buttons (BTN1..BTN3)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; # IO_L24N_T3_34 Sch=btn[1]
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]; # IO_L10P_T1_AD11P_35 Sch=btn[2]
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; # IO_L7P_T1_34 Sch=btn[3]

## -----------------------------------------------------------------------------
## 4. User Slide Switches (SW0..SW3) - Used for tamper injection / mode select
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; # IO_L19N_T3_VREF_35 Sch=sw[0]
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; # IO_L24P_T3_34 Sch=sw[1]
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]; # IO_L4N_T0_34 Sch=sw[2]
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]; # IO_L9P_T1_DQS_34 Sch=sw[3]

## -----------------------------------------------------------------------------
## 5. User Discrete LEDs (LD0..LD3) - Boot status and validation indicator
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; # IO_L23P_T3_35 Sch=led[0] - Boot OK
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; # IO_L23N_T3_35 Sch=led[1] - Boot Refused / Error
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; # IO_0_35 Sch=led[2] - Crypto Core Busy
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; # IO_L3N_T0_DQS_AD1N_35 Sch=led[3] - Heartbeat / CPU Alive

## -----------------------------------------------------------------------------
## 6. Tri-Color (RGB) LED 6 (LD6) - Available on BOTH Zybo Z7-10 and Z7-20
## Note: LD5 is connected to Bank 13 which exists ONLY on Zybo Z7-20.
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { led6_r }]; # IO_L18P_T2_34 Sch=led6_r
set_property -dict { PACKAGE_PIN F17   IOSTANDARD LVCMOS33 } [get_ports { led6_g }]; # IO_L6N_T0_VREF_35 Sch=led6_g
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { led6_b }]; # IO_L8P_T1_AD10P_35 Sch=led6_b

## -----------------------------------------------------------------------------
## 7. UART Interface via Pmod JB (Optional for Soft-Core UART Console)
## -----------------------------------------------------------------------------
# set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]; # JB[1] (Pin 1)
# set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports { uart_rx }]; # JB[2] (Pin 2)
