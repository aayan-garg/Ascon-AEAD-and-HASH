# ==============================================================================
# Vivado Secure Boot Project Builder (Vivado 2025.1)
# Target: Digilent Zybo Z7-10 (xc7z010clg400-1)
# Top: top_bringup_board (100 MHz SoC with Secure Boot + ILA Probes)
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set REPO_ROOT  [file normalize "$SCRIPT_DIR/.."]
set PROJ_DIR   "$REPO_ROOT/vivado/ascon_boot"
set PROJ_NAME  "ascon_boot"

puts "================================================================================"
puts "CREATING VIVADO SECURE BOOT PROJECT"
puts "Project Dir  : $PROJ_DIR"
puts "Repository   : $REPO_ROOT"
puts "Target Device: xc7z010clg400-1"
puts "================================================================================"

file mkdir $PROJ_DIR
create_project -force $PROJ_NAME $PROJ_DIR -part xc7z010clg400-1

set_property target_language Verilog [current_project]

# 1. RTL Design Sources
set design_files [list \
    "$REPO_ROOT/rtl/ascon/sbox5.sv" \
    "$REPO_ROOT/rtl/ascon/sbox5_espresso.sv" \
    "$REPO_ROOT/rtl/ascon/sbox5_kernel.sv" \
    "$REPO_ROOT/rtl/ascon/sbox5_bdd.sv" \
    "$REPO_ROOT/rtl/ascon/diffusion.sv" \
    "$REPO_ROOT/rtl/ascon/round_core.sv" \
    "$REPO_ROOT/rtl/ascon/permutation_1r.sv" \
    "$REPO_ROOT/rtl/ascon/permutation_1r_espresso.sv" \
    "$REPO_ROOT/rtl/ascon/permutation_2r.sv" \
    "$REPO_ROOT/rtl/ascon/permutation_half.sv" \
    "$REPO_ROOT/rtl/ascon/permutation_serial32.sv" \
    "$REPO_ROOT/rtl/ascon/plaintext_gate.sv" \
    "$REPO_ROOT/rtl/ascon/mode_ctrl.sv" \
    "$REPO_ROOT/rtl/ascon/mode_ctrl_wrappers.sv" \
    "$REPO_ROOT/rtl/ascon/aead_ctrl.sv" \
    "$REPO_ROOT/rtl/ascon/hash_ctrl.sv" \
    "$REPO_ROOT/rtl/bus/axil_regs.sv" \
    "$REPO_ROOT/rtl/dma/dma_master.sv" \
    "$REPO_ROOT/rtl/soc/boot_ctrl.sv" \
    "$REPO_ROOT/rtl/soc/fetch_guard.sv" \
    "$REPO_ROOT/rtl/soc/picorv32.v" \
    "$REPO_ROOT/rtl/soc/top_bringup.sv" \
    "$REPO_ROOT/rtl/soc/top_bringup_board.sv" \
]

add_files -fileset sources_1 -norecurse $design_files
set hex_path [file normalize "$REPO_ROOT/firmware/tests/boot_matrix/bram_case1_valid.hex"]
add_files -fileset sources_1 -norecurse $hex_path

set_property top top_bringup_board [get_filesets sources_1]
set_property generic [list "FIRMWARE_HEX=$hex_path"] [get_filesets sources_1]

# 2. Constraints (Physical Zybo Z7-10 + ILA Probes)
add_files -fileset constrs_1 -norecurse "$REPO_ROOT/board/zybo_z7_10.xdc"
add_files -fileset constrs_1 -norecurse "$REPO_ROOT/board/timing_ooc.xdc"
add_files -fileset constrs_1 -norecurse "$REPO_ROOT/board/ila_boot.xdc"

set_property is_enabled false [get_files "*timing_ooc.xdc"]
set_property used_in_synthesis false [get_files "*ila_boot.xdc"]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

# 3. Simulation Testbenches
set sim_files [list \
    "$REPO_ROOT/tb/demo/tb_demo_01_sbox_and_perm.sv" \
    "$REPO_ROOT/tb/demo/tb_demo_02_hash_digest.sv" \
    "$REPO_ROOT/tb/demo/tb_demo_03_aead_and_gate.sv" \
    "$REPO_ROOT/tb/demo/tb_demo_04_secure_boot.sv" \
    "$REPO_ROOT/tb/demo/tb_demo_05_fetch_guard.sv" \
    "$REPO_ROOT/tb/integration/tb_secure_boot.sv" \
]

add_files -fileset sim_1 -norecurse $sim_files
set_property top tb_demo_04_secure_boot [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "================================================================================"
puts "SUCCESS: Vivado Secure Boot Project Created: $PROJ_DIR/$PROJ_NAME.xpr"
puts "================================================================================"
exit 0
