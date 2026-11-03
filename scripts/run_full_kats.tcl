# run_full_kats.tcl — Run tb_aead_full and tb_hash_full via Vivado XSim batch mode
# Usage: vivado -mode batch -source scripts/run_full_kats.tcl
# Outputs results to results/kat/rtl_aead_full_pass.log and rtl_hash_full_pass.log

set PROJ_DIR [file dirname [file dirname [info script]]]
set XSIM_DIR "$PROJ_DIR/xsim_work"

file mkdir $XSIM_DIR
file mkdir "$PROJ_DIR/results/kat"

# Common RTL sources
set ASCON_RTL [list \
    "$PROJ_DIR/rtl/ascon/sbox5.sv" \
    "$PROJ_DIR/rtl/ascon/diffusion.sv" \
    "$PROJ_DIR/rtl/ascon/round_core.sv" \
    "$PROJ_DIR/rtl/ascon/permutation_1r.sv" \
    "$PROJ_DIR/rtl/ascon/permutation_2r.sv" \
    "$PROJ_DIR/rtl/ascon/permutation_half.sv" \
    "$PROJ_DIR/rtl/ascon/permutation_serial32.sv" \
    "$PROJ_DIR/rtl/ascon/plaintext_gate.sv" \
    "$PROJ_DIR/rtl/ascon/mode_ctrl.sv" \
    "$PROJ_DIR/rtl/ascon/aead_ctrl.sv" \
    "$PROJ_DIR/rtl/ascon/hash_ctrl.sv" \
]

proc run_sim {name tb_file rtl_files work_dir} {
    puts "\n========== Compiling $name =========="
    set compile_opts "-sv -work xsim_work --nolog"
    
    # Compile RTL
    foreach f $rtl_files {
        set rc [catch {exec xvlog {*}$compile_opts $f} msg]
        if {$rc && ![string match "*INFO*" $msg]} { puts "  WARN: $msg" }
    }
    # Compile TB
    set rc [catch {exec xvlog {*}$compile_opts $tb_file} msg]
    if {$rc && ![string match "*INFO*" $msg]} { puts "  TB WARN: $msg" }
    
    # Elaborate
    puts "---------- Elaborating $name ----------"
    set rc [catch {exec xelab -debug off $name -s $name\_snap --nolog} msg]
    if {$rc} { puts "  ELAB: $msg" }
    
    # Simulate
    puts "---------- Simulating $name ----------"
    set rc [catch {exec xsim ${name}_snap -runall --nolog} msg]
    puts $msg
    puts "========== $name DONE =========="
}

run_sim "tb_aead_full" "$PROJ_DIR/tb/unit/tb_aead_full.sv" $ASCON_RTL $XSIM_DIR
run_sim "tb_hash_full" "$PROJ_DIR/tb/unit/tb_hash_full.sv" $ASCON_RTL $XSIM_DIR

puts "\n[run_full_kats.tcl] DONE"

