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

# Allow hw_server to enumerate Digilent USB-JTAG cable
catch { refresh_hw_server }
after 1000
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    puts "Retrying target scan..."
    after 2000
    catch { refresh_hw_server }
    set targets [get_hw_targets -quiet]
}

if {[llength $targets] == 0} {
    puts "Error: No JTAG targets found! Ensure Zybo Z7-10 is powered ON (SW4) and connected via USB."
    close_hw_manager
    exit 1
}

set target [lindex $targets 0]
puts "Selecting JTAG target: $target"
current_hw_target $target
open_hw_target $target

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

if {$MODE eq "now"} {
    puts "Trigger mode: IMMEDIATE (capturing currently running hardware state)..."
    run_hw_ila $hw_ila -trigger_now
    wait_on_hw_ila -timeout 10 $hw_ila
} elseif {$MODE eq "fault"} {
    puts "Setting trigger: Trigger on boot_refuse == 1 (SW0 byte-flip or tamper refusal)"
    set probe [get_hw_probes *boot_refuse* -of_objects $hw_ila]
    puts "Trigger Probe: $probe"
    set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe

    puts "\n================================================================================"
    puts ">>> ILA TRIGGER ARMED FOR FAULT INJECTION! <<<"
    puts "ACTION REQUIRED: Set SW0=1 (Slide Switch 0 ON), then press and release BTN0"
    puts "================================================================================\n"

    arm_hw_ila $hw_ila
    wait_on_hw_ila -timeout 60 $hw_ila
} else {
    puts "Setting trigger: Trigger on dma_start == 1 (Normal boot authentication)"
    set probe [get_hw_probes *dma_start* -of_objects $hw_ila]
    puts "Trigger Probe: $probe"
    set_property TRIGGER_COMPARE_VALUE eq1'b1 $probe

    puts "\n================================================================================"
    puts ">>> ILA TRIGGER ARMED FOR NORMAL BOOT! <<<"
    puts "ACTION REQUIRED: Ensure SW0=0 (all switches OFF), then press and release BTN0"
    puts "================================================================================\n"

    arm_hw_ila $hw_ila
    wait_on_hw_ila -timeout 60 $hw_ila
}

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

