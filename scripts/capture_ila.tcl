# ==============================================================================
# Automated Hardware Manager ILA Programming & Trigger Capture Script
# Target: Digilent Zybo Z7-10 (xc7z010)
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]
set BIT_FILE   "$ROOT_DIR/build/top_bringup_ila.bit"
set PROBE_FILE "$ROOT_DIR/build/top_bringup_ila.ltx"

if {![file exists $BIT_FILE] || ![file exists $PROBE_FILE]} {
    puts "Error: ILA Bitstream or Probes file not found. Run scripts/build_bitstream_ila.tcl first."
    exit 1
}

# Determine trigger mode: "normal" (default) or "fault"
set MODE "normal"
if {$argc > 0} {
    set MODE [lindex $argv 0]
}

puts "================================================================================"
puts "CONNECTING TO ZYBO Z7-10 AND RUNNING ILA CAPTURE (Mode: $MODE)"
puts "Bitstream: $BIT_FILE"
puts "Probes:    $PROBE_FILE"
puts "================================================================================"

open_hw_manager
connect_hw_server -allow_non_jtag
puts "Searching for JTAG targets..."
open_hw_target

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

# Program device with ILA bitstream & probes
set_property PROGRAM.FILE $BIT_FILE $hw_device
set_property PROBES.FILE $PROBE_FILE $hw_device
puts "Programming device $hw_device with ILA bitstream..."
program_hw_devices $hw_device
refresh_hw_device [lindex [get_hw_devices xc7z010*] 0]

# Configure ILA Core
set hw_ila [lindex [get_hw_ilas] 0]
if {$hw_ila eq ""} {
    puts "Error: No ILA core detected on target!"
    close_hw_target
    disconnect_hw_server
    close_hw_manager
    exit 1
}

puts "Configuring ILA Core: $hw_ila"
set_property CONTROL.TRIGGER_POSITION 512 $hw_ila

if {$MODE eq "fault"} {
    puts "Setting trigger: Trigger on boot_refuse == 1 (SW0 byte-flip or tamper refusal)"
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes u_soc/boot_refuse -of_objects $hw_ila]
} else {
    puts "Setting trigger: Trigger on dma_start == 1 (Normal boot authentication)"
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes u_soc/dma_start -of_objects $hw_ila]
}

# Arm ILA trigger
puts "Arming ILA trigger... Waiting for trigger condition..."
arm_hw_ila $hw_ila
wait_on_hw_ila $hw_ila

# Upload and export trace data
puts "Trigger captured! Uploading ILA trace buffer..."
upload_hw_ila_data $hw_ila

file mkdir "$ROOT_DIR/results/board/ila_traces"
set csv_file "$ROOT_DIR/results/board/ila_traces/ila_capture_${MODE}.csv"
write_hw_ila_data -csv_file $csv_file -force [upload_hw_ila_data $hw_ila]
puts "Exported ILA trace to: $csv_file"

close_hw_target
disconnect_hw_server
close_hw_manager
puts "================================================================================"
puts "ILA HARDWARE CAPTURE COMPLETE!"
puts "================================================================================"
exit 0
