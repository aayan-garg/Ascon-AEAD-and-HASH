# ==============================================================================
# Vivado Full On-Board NIST KAT Project Builder (Vivado 2025.1)
# Target: Digilent Zybo Z7-10 (xc7z010clg400-1)
# Purpose: Creates a standalone GUI/batch Vivado project in Presentation/vivado_kat/
#          referencing the untouched RTL in ../../Ascon-AEAD-and-HASH/rtl/
#          and building the single 128 KB BRAM bitstream for all 2,114 NIST KATs.
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set KAT_ROOT   [file normalize "$SCRIPT_DIR/.."]
set PRES_ROOT  [file normalize "$KAT_ROOT/.."]
set REPO_ROOT  [file normalize "$PRES_ROOT/../Ascon-AEAD-and-HASH"]
set PROJ_DIR   "$PRES_ROOT/vivado_kat"
set PROJ_NAME  "ascon_kat"

puts "================================================================================"
puts "CREATING VIVADO FULL KAT PROJECT (2,114 NIST VECTORS)"
puts "Project Dir  : $PROJ_DIR"
puts "Untouched RTL: $REPO_ROOT/rtl"
puts "KAT Assets   : $KAT_ROOT"
puts "================================================================================"

create_project -force $PROJ_NAME $PROJ_DIR -part xc7z010clg400-1

# Ensure SV sources are compiled cleanly
set_property target_language Verilog [current_project]

# 1. Design Sources (referencing real untouched repo RTL + Presentation/kat_board RTL)
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
    "$KAT_ROOT/rtl/top_kat_soc.sv" \
    "$KAT_ROOT/rtl/top_kat_board.sv" \
]

add_files -fileset sources_1 -norecurse $design_files
add_files -fileset sources_1 -norecurse "$KAT_ROOT/build/kat_board_all2114.hex"

# Synthesis top: Full 2,114-KAT Zybo Z7-10 SoC (128 KB BRAM)
set_property top top_kat_board [get_filesets sources_1]
set_property generic [list "FIRMWARE_HEX=$KAT_ROOT/build/kat_board_all2114.hex"] [get_filesets sources_1]

# 2. Physical, Clock & ILA Debug Constraints (Zybo Z7-10)
add_files -fileset constrs_1 -norecurse "$REPO_ROOT/board/zybo_z7_10.xdc"
add_files -fileset constrs_1 -norecurse "$REPO_ROOT/board/timing_ooc.xdc"
add_files -fileset constrs_1 -norecurse "$KAT_ROOT/constrs/ila_kat.xdc"

# Disable OOC constraint during full-chip board runs (clk_125mhz is defined in zybo_z7_10.xdc)
set_property is_enabled false [get_files "*timing_ooc.xdc"]

# ILA insertion runs during opt_design (implementation), after synth_design preserves hierarchy
set_property used_in_synthesis false [get_files "*ila_kat.xdc"]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

# 3. Simulation Sources
add_files -fileset sim_1 -norecurse [list \
    "$KAT_ROOT/sim/tb_kat_soc.sv" \
    "$KAT_ROOT/build/kat_preflight.hex" \
]
set_property top tb_kat_soc [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {100ms} -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "================================================================================"
puts "VIVADO FULL KAT PROJECT READY: $PROJ_DIR/$PROJ_NAME.xpr"
puts "================================================================================"
exit 0

