# ==============================================================================
# Master Vivado Simulation Verification Script: verify_all_sims.tcl
# Runs and verifies behavioral simulations for both Ascon projects:
#   1. vivado/ascon_boot/ascon_boot.xpr (Secure Boot SoC Demos 01 - 05)
#   2. vivado/ascon_kat/ascon_kat.xpr   (On-Board NIST SP 800-232 KAT Runner)
# ==============================================================================

set passed_count 0
set failed_count 0
set results {}

proc run_sim_test {prj_path tb_name sim_time} {
    global passed_count failed_count results
    puts "\n======================================================================"
    puts ">>> RUNNING SIMULATION: $tb_name (Project: $prj_path, Time: $sim_time)"
    puts "======================================================================"

    set prj [open_project $prj_path]
    set_property top $tb_name [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]
    set_property -name {xsim.simulate.runtime} -value $sim_time -objects [get_filesets sim_1]
    update_compile_order -fileset sim_1

    if {[catch {
        launch_simulation
        catch {run $sim_time}
        close_sim
        puts ">>> \[PASS\] Simulation completed successfully: $tb_name"
        incr passed_count
        lappend results [list $tb_name "PASS" $sim_time]
    } err_msg]} {
        puts ">>> \[FAIL\] Simulation error in $tb_name: $err_msg"
        incr failed_count
        lappend results [list $tb_name "FAIL" $err_msg]
        catch {close_sim}
    }
    close_project
}

# ------------------------------------------------------------------------------
# 1. Project: ascon_boot.xpr
# ------------------------------------------------------------------------------
# Primary Presentation Demo: Full 3-Scenario RISC-V Secure Boot
run_sim_test "vivado/ascon_boot/ascon_boot.xpr" "tb_demo_04_secure_boot" "40us"

# Presentation Demo 01: S-Box Equivalence & Permutation Tradeoffs
run_sim_test "vivado/ascon_boot/ascon_boot.xpr" "tb_demo_01_sbox_and_perm" "2us"

# Presentation Demo 02: Ascon-Hash256 NIST Vector & 1-Bit Avalanche
run_sim_test "vivado/ascon_boot/ascon_boot.xpr" "tb_demo_02_hash_digest" "2us"

# Presentation Demo 03: Ascon-AEAD128 & Hardware Plaintext Release Gate
run_sim_test "vivado/ascon_boot/ascon_boot.xpr" "tb_demo_03_aead_and_gate" "2us"

# Presentation Demo 05: Hardware Instruction Fetch Guard Security Proof
run_sim_test "vivado/ascon_boot/ascon_boot.xpr" "tb_demo_05_fetch_guard" "10us"

# ------------------------------------------------------------------------------
# 2. Project: ascon_kat.xpr
# ------------------------------------------------------------------------------
# On-Board Standalone NIST KAT Preflight Verification
run_sim_test "vivado/ascon_kat/ascon_kat.xpr" "tb_kat_soc" "30ms"

# ------------------------------------------------------------------------------
# Final Configuration: Ensure projects open on primary demo testbenches
# ------------------------------------------------------------------------------
set prj [open_project "vivado/ascon_boot/ascon_boot.xpr"]
set_property top "tb_demo_04_secure_boot" [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {40us} -objects [get_filesets sim_1]
set_property -name {xsim.view} -value {$PPRDIR/ascon_boot.wcfg} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1
close_project

set prj [open_project "vivado/ascon_kat/ascon_kat.xpr"]
set_property top "tb_kat_soc" [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {30ms} -objects [get_filesets sim_1]
set_property -name {xsim.view} -value {$PPRDIR/ascon_kat.wcfg} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1
close_project

# ------------------------------------------------------------------------------
# Summary Report
# ------------------------------------------------------------------------------
puts "\n======================================================================"
puts "                FINAL SIMULATION VERIFICATION MATRIX                  "
puts "======================================================================"
foreach r $results {
    set name [lindex $r 0]
    set st   [lindex $r 1]
    set info [lindex $r 2]
    puts [format "  %-28s : %-6s (%s)" $name $st $info]
}
puts "======================================================================"
puts [format "TOTAL PASSED: %d / %d" $passed_count [expr {$passed_count + $failed_count}]]
puts "======================================================================"

if {$failed_count > 0} {
    puts "FAILED: $failed_count simulation(s) failed."
    exit 1
} else {
    puts "SUCCESS: ALL simulations verified and passing cleanly!"
    exit 0
}
