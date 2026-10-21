# ==============================================================================
# Automated Batch JTAG Programming Script for Zybo Z7-10
# Hardware: Digilent Zybo Z7-10 via Micro-USB (JTAG)
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]
set BIT_FILE   "$ROOT_DIR/build/top_bringup.bit"

if {![file exists $BIT_FILE]} {
    puts "Error: Bitstream $BIT_FILE does not exist. Run scripts/build_bitstream.tcl first."
    exit 1
}

puts "================================================================================"
puts "CONNECTING TO HARDWARE TARGET AND PROGRAMMING ZYBO Z7-10"
puts "Target Bitstream: $BIT_FILE"
puts "================================================================================"

open_hw_manager
connect_hw_server -allow_non_jtag
puts "Searching for JTAG targets..."
open_hw_target

# Select the FPGA device (xc7z010)
set hw_device [lindex [get_hw_devices xc7z010*] 0]
if {$hw_device eq ""} {
    puts "Error: No xc7z010 device found! Ensure Zybo Z7-10 is powered ON (SW4) and connected via USB."
    close_hw_target
    disconnect_hw_server
    close_hw_manager
    exit 1
}

current_hw_device $hw_device
refresh_hw_device -update_hw_probes false $hw_device

puts "Programming device $hw_device with $BIT_FILE..."
set_property PROGRAM.FILE $BIT_FILE $hw_device
program_hw_devices $hw_device

puts "\n================================================================================"
puts "PROGRAMMING COMPLETE! PicoRV32 IS RUNNING ON THE ZYBO Z7-10."
puts "Check LD0..LD3 for walking 1s and LD6 (RGB) for GREEN."
puts "================================================================================"

close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
