# ==============================================================================
# Script: synth_engine_variants.tcl
# Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
# Purpose: Out-of-Context (OOC) Batch Synthesis & Timing of Complete Engines (mode_ctrl)
# Target Part: xc7z010clg400-1 (AMD-Xilinx 7-Series Zynq) @ 100 MHz
# Fulfills Task T7: Engine-Level Area and Timing Characterization
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]

puts "================================================================================"
puts "STARTING ASCON ENGINE-LEVEL (mode_ctrl) BATCH SYNTHESIS & TIMING SUITE"
puts "Target Part : xc7z010clg400-1"
puts "Target Clock: 100.0 MHz (10.000 ns)"
puts "Root Dir    : $ROOT_DIR"
puts "================================================================================"

file mkdir "$ROOT_DIR/results/synthesis"
file mkdir "$ROOT_DIR/results/timing"

set ENGINE_VARIANTS {
    "mode_ctrl_1r_wrap"
    "mode_ctrl_1r_espresso_wrap"
    "mode_ctrl_1r_kernel_wrap"
    "mode_ctrl_1r_bdd_wrap"
    "mode_ctrl_2r_wrap"
    "mode_ctrl_half_wrap"
    "mode_ctrl_serial32_wrap"
}

if { $argc > 0 } {
    set RUN_VARIANTS [list [lindex $argv 0]]
    puts "Running targeted engine variant: $RUN_VARIANTS"
} else {
    set RUN_VARIANTS $ENGINE_VARIANTS
    puts "Running all engine variants: $RUN_VARIANTS"
}

set rtl_files [list \
    "$ROOT_DIR/rtl/ascon/sbox5.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5_espresso.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5_kernel.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5_bdd.sv" \
    "$ROOT_DIR/rtl/ascon/diffusion.sv" \
    "$ROOT_DIR/rtl/ascon/round_core.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_1r.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_1r_espresso.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_2r.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_half.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_serial32.sv" \
    "$ROOT_DIR/rtl/ascon/plaintext_gate.sv" \
    "$ROOT_DIR/rtl/ascon/mode_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/mode_ctrl_wrappers.sv" \
]

foreach var $RUN_VARIANTS {
    puts "\n================================================================================"
    puts "SYNTHESIZING & IMPLEMENTING ENGINE VARIANT: $var"
    puts "================================================================================"

    create_project -in_memory -part xc7z010clg400-1

    read_verilog -sv $rtl_files
    read_xdc "$ROOT_DIR/board/timing_ooc.xdc"

    # Step 1: Out-of-Context Synthesis
    puts "\n>>> Step 1/4: Running synth_design for $var (mode: out_of_context)..."
    if {[catch {synth_design -top $var -part xc7z010clg400-1 -mode out_of_context -flatten_hierarchy rebuilt} err]} {
        puts "ERROR: Synthesis failed for $var: $err"
        close_project
        continue
    }

    # Step 2: Logic Optimization
    puts "\n>>> Step 2/4: Running opt_design for $var..."
    opt_design

    # Step 3: Placement
    puts "\n>>> Step 3/4: Running place_design for $var..."
    place_design

    # Step 4: Routing
    puts "\n>>> Step 4/4: Running route_design for $var..."
    route_design

    # Step 5: Report Utilization and Timing
    set util_rpt   "$ROOT_DIR/results/synthesis/${var}_util.rpt"
    set timing_rpt "$ROOT_DIR/results/timing/${var}_timing.rpt"

    report_utilization -file $util_rpt
    report_timing_summary -file $timing_rpt -max_paths 10

    puts "Completed $var:"
    puts "  Utilization: $util_rpt"
    puts "  Timing:      $timing_rpt"

    close_project
}

puts "\n================================================================================"
puts "ENGINE-LEVEL BATCH SYNTHESIS COMPLETED!"
puts "================================================================================"
exit 0

