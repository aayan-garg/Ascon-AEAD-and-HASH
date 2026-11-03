# ==============================================================================
# Ascon SoC Interactive Simulation Procedures for Vivado GUI
# Usage in Vivado Tcl Console:
#   source sim_procedures.tcl
# Then run any command:
#   sim_sbox_equiv
#   sim_round_core
#   sim_permutation_1r
#   sim_permutation_2r
#   sim_permutation_half
#   sim_aead
#   sim_hash
#   sim_security_gate
#   sim_axil_regs
#   sim_dma
#   sim_secure_boot
#   sim_soc_ascon
#   sim_soc_dma
# ==============================================================================

proc help_sim {} {
    puts "=============================================================================="
    puts " Ascon Verification Simulation Commands"
    puts "=============================================================================="
    puts " Milestone 1: Datapath & S-Box"
    puts "   sim_sbox_equiv       - Exhaustive 32-vector S-Box Equivalence (Base vs ESPRESSO)"
    puts "   sim_round_core       - Single Combinational Round Datapath"
    puts "   sim_permutation_1r   - Baseline 1-Round/Cycle Permutation (12 rounds = 12 cycles)"
    puts "   sim_permutation_2r   - Unrolled 2-Rounds/Cycle Permutation (12 rounds = 6 cycles)"
    puts "   sim_permutation_half - Pipelined 1/2-Round/Cycle Permutation (12 rounds = 24 cycles)"
    puts ""
    puts " Milestone 2: Modes & Security Invariants"
    puts "   sim_aead             - Ascon-AEAD128 Encrypt & Decrypt Official NIST KATs"
    puts "   sim_hash             - Ascon-Hash256 Official NIST KATs"
    puts "   sim_security_gate    - Plaintext Shadow Buffer Isolation & Zeroization"
    puts ""
    puts " Milestone 3: SoC Bus & DMA Data Plane"
    puts "   sim_axil_regs        - AXI4-Lite Register File BFM (Write-only keys, SLVERR)"
    puts "   sim_dma              - 64-bit Streaming DMA Engine Boundary Tests (40/40 assertions)"
    puts "   sim_soc_ascon        - PicoRV32 Core + AXI4-Lite Firmware Hash Test"
    puts "   sim_soc_dma          - Full SoC PicoRV32 + DMA Bulk Streaming Hash Test"
    puts ""
    puts " Milestone 4: Secure Boot Engine (The Crown Jewel)"
    puts "   sim_secure_boot      - Complete 9-Case Secure Boot Matrix (Valid vs 1-bit Tamper)"
    puts "=============================================================================="
}

proc sim_run_tb {tb_name {radix_signals ""} {radix_type "hex"}} {
    puts "\n>>> SIM: Switching simulation top to: $tb_name..."
    catch {close_sim -force}
    
    # Sync firmware directory to xsim simulation directory if present
    set proj_dir [get_property directory [current_project]]
    set sim_dir  [file normalize "$proj_dir/[current_project].sim/sim_1/behav/xsim"]
    set fw_src   [file normalize "$proj_dir/../firmware"]
    if {[file exists $fw_src] && [file exists $sim_dir]} {
        catch {file copy -force "$fw_src" "$sim_dir/firmware"}
        catch {file copy -force "$fw_src/tests/gpio_toggle.hex" "$sim_dir/gpio_toggle.hex"}
    }
    
    set_property top $tb_name [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]
    update_compile_order -fileset sim_1
    
    puts ">>> SIM: Launching simulation for $tb_name..."
    launch_simulation
    
    # Add top-level signals if not automatically present
    catch {add_wave /$tb_name/*}
    
    # Set radix if specified
    if {$radix_signals ne ""} {
        foreach sig $radix_signals {
            catch {set_property radix $radix_type [get_waves $sig]}
        }
    }
    
    puts ">>> SIM: Running simulation to completion..."
    run all
    
    # Zoom fit
    catch {zoom_fit}
    catch {xsim::zoom_to_fit}
    puts ">>> SIM: $tb_name simulation finished successfully! Waveform ready on screen.\n"
}

# --- Milestone 1 ---
proc sim_sbox_equiv {} {
    sim_run_tb "tb_sbox_equiv" {/tb_sbox_equiv/in_x /tb_sbox_equiv/out_base /tb_sbox_equiv/out_espresso} "hex"
}

proc sim_round_core {} {
    sim_run_tb "tb_round_core" {/tb_round_core/in_x* /tb_round_core/out_x* /tb_round_core/round_const} "hex"
}

proc sim_permutation_1r {} {
    sim_run_tb "tb_permutation_1r" {/tb_permutation_1r/in_x* /tb_permutation_1r/out_x* /tb_permutation_1r/rounds} "hex"
}

proc sim_permutation_2r {} {
    sim_run_tb "tb_permutation_2r" {/tb_permutation_2r/in_x* /tb_permutation_2r/out_x* /tb_permutation_2r/rounds} "hex"
}

proc sim_permutation_half {} {
    sim_run_tb "tb_permutation_half" {/tb_permutation_half/in_x* /tb_permutation_half/out_x* /tb_permutation_half/rounds} "hex"
}

# --- Milestone 2 ---
proc sim_aead {} {
    sim_run_tb "tb_aead" {/tb_aead/tag_out /tb_aead/expected_tag /tb_aead/pt_rd_data /tb_aead/data_out} "hex"
}

proc sim_hash {} {
    sim_run_tb "tb_hash" {/tb_hash/digest_out /tb_hash/data_in /tb_hash/msg_len} "hex"
}

proc sim_security_gate {} {
    sim_run_tb "tb_security_gate" {/tb_security_gate/rd_data /tb_security_gate/wr_data} "hex"
}

# --- Milestone 3 ---
proc sim_axil_regs {} {
    sim_run_tb "tb_axil_regs" {/tb_axil_regs/s_axi_awaddr /tb_axil_regs/s_axi_wdata /tb_axil_regs/s_axi_rdata} "hex"
}

proc sim_dma {} {
    sim_run_tb "tb_dma" {/tb_dma/bram_rdata /tb_dma/dma_data /tb_dma/bram_addr} "hex"
}

proc sim_soc_ascon {} {
    sim_run_tb "tb_soc_ascon" {/tb_soc_ascon/leds /tb_soc_ascon/test_pass} "hex"
}

proc sim_soc_dma {} {
    sim_run_tb "tb_soc_dma" {/tb_soc_dma/leds /tb_soc_dma/test_pass} "hex"
}

# --- Milestone 4 ---
proc sim_secure_boot {} {
    sim_run_tb "tb_secure_boot" {/tb_secure_boot/led_status /tb_secure_boot/ascon_digest /tb_secure_boot/fsm_state} "hex"
}

puts "\n=============================================================================="
puts " Ascon simulation commands loaded successfully!"
puts " Type 'help_sim' to see the list of available simulation procedures."
puts " Example: Type 'sim_sbox_equiv' and press Enter to run Step 1."
puts "==============================================================================\n"
