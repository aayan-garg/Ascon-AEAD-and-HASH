# ==============================================================================
# Automated Batch Synthesis and Bitstream Generation for Zybo Z7-10
# Target Part: xc7z010clg400-1 (AMD-Xilinx 7-Series Zynq)
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $ROOT_DIR

puts "================================================================================"
puts "STARTING VIVADO BATCH BITSTREAM BUILD FOR ZYBO Z7-10"
puts "Root Directory: $ROOT_DIR"
puts "Working Directory: [pwd]"
puts "================================================================================"

# 1. Create In-Memory Project
create_project -in_memory -part xc7z010clg400-1

# 2. Add ALL RTL Source Files (Complete SoC: PicoRV32 + Ascon Engine + DMA + Boot Ctrl)
set rtl_files [list \
    "$ROOT_DIR/rtl/ascon/aead_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/diffusion.sv" \
    "$ROOT_DIR/rtl/ascon/hash_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/mode_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_1r.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_1r_espresso.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_2r.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_half.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_serial32.sv" \
    "$ROOT_DIR/rtl/ascon/plaintext_gate.sv" \
    "$ROOT_DIR/rtl/ascon/round_core.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5_espresso.sv" \
    "$ROOT_DIR/rtl/bus/axil_regs.sv" \
    "$ROOT_DIR/rtl/dma/dma_master.sv" \
    "$ROOT_DIR/rtl/soc/boot_ctrl.sv" \
    "$ROOT_DIR/rtl/soc/fetch_guard.sv" \
    "$ROOT_DIR/rtl/soc/picorv32.v" \
    "$ROOT_DIR/rtl/soc/top_bringup.sv" \
    "$ROOT_DIR/rtl/soc/top_bringup_board.sv" \
]
read_verilog -sv $rtl_files

# 3. Add Constraints
read_xdc "$ROOT_DIR/board/zybo_z7_10.xdc"

# 4. Synthesize Design
puts "\n--- STEP 1/5: Synthesizing top_bringup_board for xc7z010clg400-1 ---"
synth_design -top top_bringup_board -part xc7z010clg400-1 -flatten_hierarchy rebuilt -generic [list FIRMWARE_HEX="$ROOT_DIR/firmware/tests/boot_matrix/bram_case1_valid.hex"]

# 5. Logic Optimization
puts "\n--- STEP 2/5: Running logic optimization (opt_design) ---"
opt_design

# 6. Placement
puts "\n--- STEP 3/5: Running placement (place_design) ---"
place_design

# 7. Routing
puts "\n--- STEP 4/5: Running routing (route_design) ---"
route_design

# 8. Reports
puts "\n--- STEP 5/5: Generating utilization, timing, and power reports ---"
file mkdir "$ROOT_DIR/results/synthesis"
file mkdir "$ROOT_DIR/results/timing"
file mkdir "$ROOT_DIR/build"

report_utilization -file "$ROOT_DIR/results/synthesis/utilization_bringup.txt"
report_timing_summary -file "$ROOT_DIR/results/timing/timing_bringup.txt" -max_paths 10

# 9. Generate Bitstream
puts "\nWriting bitstream to $ROOT_DIR/build/top_bringup.bit..."
write_bitstream -force "$ROOT_DIR/build/top_bringup.bit"

puts "\n================================================================================"
puts "BITSTREAM BUILD COMPLETED SUCCESSFULLY!"
puts "Bitstream: $ROOT_DIR/build/top_bringup.bit"
puts "================================================================================"
exit 0
