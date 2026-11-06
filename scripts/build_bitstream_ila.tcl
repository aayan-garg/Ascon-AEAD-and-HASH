# ==============================================================================
# Automated Batch Synthesis and ILA-Instrumented Bitstream Generation
# Target Part: xc7z010clg400-1 (AMD-Xilinx 7-Series Zynq)
# Board: Digilent Zybo Z7-10
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]
cd $ROOT_DIR

puts "================================================================================"
puts "STARTING VIVADO BATCH ILA BITSTREAM BUILD FOR ZYBO Z7-10"
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

# 4. Synthesize Design (flatten_hierarchy none preserves net hierarchy for ILA probing)
puts "\n--- STEP 1/6: Synthesizing top_bringup_board for xc7z010clg400-1 ---"
synth_design -top top_bringup_board -part xc7z010clg400-1 -flatten_hierarchy none -generic [list FIRMWARE_HEX="$ROOT_DIR/firmware/tests/boot_matrix/bram_case1_valid.hex"]

# 5. Insert Integrated Logic Analyzer (ILA 6.2) Debug Core
puts "\n--- STEP 2/6: Inserting Integrated Logic Analyzer (ILA 6.2) Core ---"
set ila [create_debug_core u_ila_0 ila]
set_property C_DATA_DEPTH 1024 $ila
set_property C_INPUT_PIPE_STAGES 0 $ila
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets clk_100mhz]

# Define debug probe connections
# Probe 0: rst_n
set_property port_width 1 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets rst_n]

# Probe 1: boot_refuse
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets u_soc/boot_refuse]

# Probe 2: hash_ok
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets u_soc/u_ascon/u_boot_ctrl/hash_ok]

# Probe 3: dma_start
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets u_soc/dma_start]

# Probe 4: dma_busy
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets u_soc/dma_busy]

# Probe 5: dma_done
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets u_soc/dma_done]

# Probe 6: dma_stream_valid
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets u_soc/dma_stream_valid]

# Probe 7: dma_stream_ready
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets u_soc/dma_stream_ready]

# Probe 8: discrete LEDs (led_OBUF)
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets {led_OBUF[0] led_OBUF[1] led_OBUF[2] led_OBUF[3]}]

# Probe 9: slide switches (sw_IBUF)
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets {sw_IBUF[0] sw_IBUF[1]}]

# Probe 10: RGB LED LD6 (rgb_led)
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets {u_soc/rgb_led[0] u_soc/rgb_led[1] u_soc/rgb_led[2]}]

# 6. Logic Optimization
puts "\n--- STEP 3/6: Running logic optimization (opt_design) ---"
opt_design

# 7. Placement
puts "\n--- STEP 4/6: Running placement (place_design) ---"
place_design

# 8. Routing
puts "\n--- STEP 5/6: Running routing (route_design) ---"
route_design

# 9. Reports
puts "\n--- STEP 6/6: Generating reports & bitstream ---"
file mkdir "$ROOT_DIR/results/synthesis"
file mkdir "$ROOT_DIR/results/timing"
file mkdir "$ROOT_DIR/build"

report_utilization -file "$ROOT_DIR/results/synthesis/utilization_bringup_ila.txt"
report_timing_summary -file "$ROOT_DIR/results/timing/timing_bringup_ila.txt" -max_paths 10

# 10. Write Bitstream & Debug Probe File
puts "\nWriting ILA bitstream to $ROOT_DIR/build/top_bringup_ila.bit..."
write_bitstream -force "$ROOT_DIR/build/top_bringup_ila.bit"

puts "Writing debug probes to $ROOT_DIR/build/top_bringup_ila.ltx..."
write_debug_probes -force "$ROOT_DIR/build/top_bringup_ila.ltx"

puts "\n================================================================================"
puts "ILA BITSTREAM BUILD COMPLETED SUCCESSFULLY!"
puts "Bitstream: $ROOT_DIR/build/top_bringup_ila.bit"
puts "Probes:    $ROOT_DIR/build/top_bringup_ila.ltx"
puts "================================================================================"
exit 0

