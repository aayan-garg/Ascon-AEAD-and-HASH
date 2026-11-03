# ==============================================================================
# Comprehensive Vivado Project Generation Script: ascon_soc.xpr
# Targets: Digilent Zybo Z7-10 (xc7z010clg400-1)
# Includes: All RTL modules, all constraints, all testbenches, and firmware hex
# ==============================================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]
set PROJ_DIR   "$ROOT_DIR/vivado_proj"
set PROJ_NAME  "ascon_soc"

# 1. Close any currently open project
catch {close_project}

# 2. Clean/Create project directory
file mkdir $PROJ_DIR

# 3. Create Vivado Project targeting Zybo Z7-10
create_project -force $PROJ_NAME $PROJ_DIR -part xc7z010clg400-1

# 4. Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

# 5. Add ALL RTL Design Sources
puts "\n--- Adding RTL Design Sources ---"
set rtl_files [list \
    "$ROOT_DIR/rtl/ascon/aead_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/diffusion.sv" \
    "$ROOT_DIR/rtl/ascon/hash_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/mode_ctrl.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_1r.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_1r_espresso.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_2r.sv" \
    "$ROOT_DIR/rtl/ascon/permutation_half.sv" \
    "$ROOT_DIR/rtl/ascon/plaintext_gate.sv" \
    "$ROOT_DIR/rtl/ascon/round_core.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5.sv" \
    "$ROOT_DIR/rtl/ascon/sbox5_espresso.sv" \
    "$ROOT_DIR/rtl/bus/axil_regs.sv" \
    "$ROOT_DIR/rtl/dma/dma_master.sv" \
    "$ROOT_DIR/rtl/soc/boot_ctrl.sv" \
    "$ROOT_DIR/rtl/soc/picorv32.v" \
    "$ROOT_DIR/rtl/soc/top_bringup.sv" \
    "$ROOT_DIR/rtl/soc/top_bringup_board.sv" \
]
add_files -fileset sources_1 $rtl_files

# 6. Add Firmware Memory Files to Sources
set fw_hex_files [glob -nocomplain "$ROOT_DIR/firmware/**/*.hex"]
if {[llength $fw_hex_files] > 0} {
    add_files -fileset sources_1 $fw_hex_files
}

# 7. Set Synthesis Top Module
set_property top top_bringup_board [current_fileset]

# 8. Add Constraints
puts "\n--- Adding Constraints ---"
set constr_files [list \
    "$ROOT_DIR/board/zybo_z7_10.xdc" \
]
add_files -fileset constrs_1 $constr_files

# 9. Add ALL Simulation Testbenches to sim_1
puts "\n--- Adding Simulation Testbenches ---"
set tb_files [list \
    "$ROOT_DIR/tb/unit/tb_sbox5.sv" \
    "$ROOT_DIR/tb/unit/tb_sbox_equiv.sv" \
    "$ROOT_DIR/tb/unit/tb_diffusion.sv" \
    "$ROOT_DIR/tb/unit/tb_round_core.sv" \
    "$ROOT_DIR/tb/unit/tb_permutation_1r.sv" \
    "$ROOT_DIR/tb/unit/tb_permutation_2r.sv" \
    "$ROOT_DIR/tb/unit/tb_permutation_half.sv" \
    "$ROOT_DIR/tb/unit/tb_mode_ctrl.sv" \
    "$ROOT_DIR/tb/unit/tb_security_gate.sv" \
    "$ROOT_DIR/tb/unit/tb_aead.sv" \
    "$ROOT_DIR/tb/unit/tb_hash.sv" \
    "$ROOT_DIR/tb/unit/tb_hello.sv" \
    "$ROOT_DIR/tb/unit/tb_boot_ctrl.sv" \
    "$ROOT_DIR/tb/unit/tb_picorv32_bringup.sv" \
    "$ROOT_DIR/tb/integration/tb_axil_regs.sv" \
    "$ROOT_DIR/tb/integration/tb_dma.sv" \
    "$ROOT_DIR/tb/integration/tb_soc_ascon.sv" \
    "$ROOT_DIR/tb/integration/tb_soc_dma.sv" \
    "$ROOT_DIR/tb/integration/tb_secure_boot.sv" \
]
add_files -fileset sim_1 $tb_files
if {[llength $fw_hex_files] > 0} {
    add_files -fileset sim_1 $fw_hex_files
}

# 10. Set Default Simulation Top to tb_sbox_equiv
set_property top tb_sbox_equiv [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# 11. Configure Simulation Settings
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# 12. Pre-create simulation working directories and sync firmware for relative $readmemh paths
set sim_xsim_dir "$PROJ_DIR/$PROJ_NAME.sim/sim_1/behav/xsim"
file mkdir "$sim_xsim_dir/firmware/tests/boot_matrix"
file mkdir "$sim_xsim_dir/firmware/bootrom"
foreach f [glob -nocomplain "$ROOT_DIR/firmware/tests/boot_matrix/*.hex"] {
    file copy -force $f "$sim_xsim_dir/firmware/tests/boot_matrix/"
}
foreach f [glob -nocomplain "$ROOT_DIR/firmware/bootrom/*.hex"] {
    file copy -force $f "$sim_xsim_dir/firmware/bootrom/"
}
foreach f [glob -nocomplain "$ROOT_DIR/firmware/tests/*.hex"] {
    file copy -force $f "$sim_xsim_dir/"
}

# 13. Update Compile Order for Design and Simulation Trees
puts "\n--- Updating Compile Orders ---"
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "\n================================================================================"
puts "Vivado Project '$PROJ_NAME' created successfully!"
puts "Project File: $PROJ_DIR/$PROJ_NAME.xpr"
puts "Target Part:  xc7z010clg400-1 (Digilent Zybo Z7-10)"
puts "Design Files: [llength $rtl_files] RTL sources added"
puts "Sim Files:    [llength $tb_files] Testbenches added"
puts "================================================================================\n"
