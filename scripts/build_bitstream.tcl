# ==============================================================================
# Automated Batch Synthesis and Bitstream Generation for Zybo Z7-10
# Target Part: xc7z010clg400-1 (AMD-Xilinx 7-Series Zynq)
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]

puts "================================================================================"
puts "STARTING VIVADO BATCH BITSTREAM BUILD FOR ZYBO Z7-10"
puts "Root Directory: $ROOT_DIR"
puts "================================================================================"

# 1. Create In-Memory Project
create_project -in_memory -part xc7z010clg400-1

# 2. Add Source Files
read_verilog -sv "$ROOT_DIR/rtl/soc/picorv32.v"
read_verilog -sv "$ROOT_DIR/rtl/soc/top_bringup.sv"
read_verilog -sv "$ROOT_DIR/rtl/soc/top_bringup_board.sv"

# 3. Add Constraints
read_xdc "$ROOT_DIR/board/zybo_z7_10.xdc"

# 4. Synthesize Design
puts "\n--- STEP 1/5: Synthesizing top_bringup_board for xc7z010clg400-1 ---"
synth_design -top top_bringup_board -part xc7z010clg400-1 -flatten_hierarchy rebuilt

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
