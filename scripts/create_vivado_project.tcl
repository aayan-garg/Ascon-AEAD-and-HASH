# ==============================================================================
# Script to create and launch Vivado GUI Project for Ascon SoC Bringup
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set ROOT_DIR   [file normalize "$SCRIPT_DIR/.."]
set PROJ_DIR   "$ROOT_DIR/vivado_proj"
set PROJ_NAME  "ascon_soc"

# Close any currently open project
catch {close_project}

# Create project directory
file mkdir $PROJ_DIR

# Create Vivado Project targeting Zybo Z7-10 (xc7z010clg400-1)
create_project -force $PROJ_NAME $PROJ_DIR -part xc7z010clg400-1

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Add RTL Design Sources
add_files -fileset sources_1 [list \
    "$ROOT_DIR/rtl/soc/top_bringup_board.sv" \
    "$ROOT_DIR/rtl/soc/top_bringup.sv" \
    "$ROOT_DIR/rtl/soc/picorv32.v" \
    "$ROOT_DIR/firmware/tests/gpio_toggle_board.hex" \
]

# Set top module
set_property top top_bringup_board [current_fileset]

# Add Constraints
add_files -fileset constrs_1 [list \
    "$ROOT_DIR/board/zybo_z7_10.xdc" \
]

# Add Simulation Sources
add_files -fileset sim_1 [list \
    "$ROOT_DIR/tb/unit/tb_picorv32_bringup.sv" \
    "$ROOT_DIR/firmware/tests/gpio_toggle.hex" \
]
set_property top tb_picorv32_bringup [get_filesets sim_1]

puts "================================================================================"
puts "Vivado Project created successfully at $PROJ_DIR/$PROJ_NAME.xpr"
puts "================================================================================"
