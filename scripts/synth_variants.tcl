# ==============================================================================
# Script: synth_variants.tcl
# Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
# Purpose: Out-of-Context (OOC) Batch Synthesis & Implementation on Zybo Z7-10
# Target Part: xc7z010clg400-1 (AMD-Xilinx 7-Series Zynq)
# Target Clock: 100 MHz (Period: 10.000 ns)
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]

puts "================================================================================"
puts "STARTING ASCON ARCHITECTURAL VARIANTS SYNTHESIS & TIMING SUITE"
puts "Target Part : xc7z010clg400-1"
puts "Target Clock: 100.0 MHz (10.000 ns)"
puts "Root Dir    : $ROOT_DIR"
puts "================================================================================"

file mkdir "$ROOT_DIR/results/synthesis"
file mkdir "$ROOT_DIR/results/timing"

set ALL_VARIANTS {
    "permutation_1r"
    "permutation_2r"
    "permutation_half"
    "permutation_1r_espresso"
}

# Determine if specific variant was requested via argv
if { $argc > 0 } {
    set RUN_VARIANTS [list [lindex $argv 0]]
    puts "Running targeted variant: $RUN_VARIANTS"
} else {
    set RUN_VARIANTS $ALL_VARIANTS
    puts "Running all variants: $RUN_VARIANTS"
}

set SUMMARY_LOG [open "$ROOT_DIR/results/synthesis/synth_summary.txt" "w"]
puts $SUMMARY_LOG "================================================================================"
puts $SUMMARY_LOG "Vivado Batch Synthesis Summary (Target: xc7z010clg400-1 @ 100 MHz)"
puts $SUMMARY_LOG "Date: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $SUMMARY_LOG "================================================================================"

foreach var $RUN_VARIANTS {
    puts "\n================================================================================"
    puts "SYNTHESIZING & IMPLEMENTING VARIANT: $var"
    puts "================================================================================"

    create_project -in_memory -part xc7z010clg400-1

    # Read all relevant RTL sources
    read_verilog -sv "$ROOT_DIR/rtl/ascon/sbox5.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/sbox5_espresso.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/diffusion.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/round_core.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/permutation_1r.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/permutation_2r.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/permutation_half.sv"
    read_verilog -sv "$ROOT_DIR/rtl/ascon/permutation_1r_espresso.sv"

    # Read OOC timing constraint
    read_xdc "$ROOT_DIR/board/timing_ooc.xdc"

    # Step 1: Out-of-Context Synthesis
    puts "\n>>> Step 1/4: Running synth_design for $var (mode: out_of_context)..."
    if {[catch {synth_design -top $var -part xc7z010clg400-1 -mode out_of_context -flatten_hierarchy rebuilt} err]} {
        puts "ERROR: Synthesis failed for $var: $err"
        puts $SUMMARY_LOG "$var : SYNTHESIS FAILED"
        close_project
        continue
    }

    # Step 2: Logic Optimization
    puts "\n>>> Step 2/4: Running opt_design for $var..."
    if {[catch {opt_design} err]} {
        puts "ERROR: opt_design failed for $var: $err"
        puts $SUMMARY_LOG "$var : OPT_DESIGN FAILED"
        close_project
        continue
    }

    # Step 3: Placement
    puts "\n>>> Step 3/4: Running place_design for $var..."
    if {[catch {place_design} err]} {
        puts "ERROR: place_design failed for $var: $err"
        puts $SUMMARY_LOG "$var : PLACE_DESIGN FAILED"
        close_project
        continue
    }

    # Step 4: Routing
    puts "\n>>> Step 4/4: Running route_design for $var..."
    if {[catch {route_design} err]} {
        puts "ERROR: route_design failed for $var: $err"
        puts $SUMMARY_LOG "$var : ROUTE_DESIGN FAILED"
        close_project
        continue
    }

    # Step 5: Report Generation
    puts "\n>>> Step 5/5: Generating Utilization and Timing Reports..."
    set util_rpt   "$ROOT_DIR/results/synthesis/${var}_util.rpt"
    set timing_rpt "$ROOT_DIR/results/timing/${var}_timing.rpt"

    report_utilization -file $util_rpt
    report_timing_summary -file $timing_rpt -max_paths 10

    puts "Generated: $util_rpt"
    puts "Generated: $timing_rpt"
    puts $SUMMARY_LOG "$var : IMPLEMENTED SUCCESSFULLY"

    close_project
}

close $SUMMARY_LOG
puts "\n================================================================================"
puts "ALL SYNTHESIS & TIMING RUNS COMPLETED!"
puts "Summary written to: $ROOT_DIR/results/synthesis/synth_summary.txt"
puts "================================================================================"
exit 0
