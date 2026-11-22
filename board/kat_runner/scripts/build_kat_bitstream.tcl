# ==============================================================================
# Vivado Batch Synth + Implementation + Bitstream Runner for Full KAT Project
# Runs Presentation/vivado_kat/ascon_kat.xpr through write_bitstream and prints
# summary timing, resource (BRAM), and ILA debug core verification checks.
# ==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set KAT_ROOT   [file normalize "$SCRIPT_DIR/.."]
set PRES_ROOT  [file normalize "$KAT_ROOT/.."]
set PROJ_XPR   "$PRES_ROOT/vivado_kat/ascon_kat.xpr"

open_project $PROJ_XPR

catch { reset_run synth_1 }
launch_runs synth_1 -jobs 8
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "=== SYNTH STATUS: $synth_status ==="
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis failed with status: $synth_status"
}

catch { reset_run impl_1 }
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "=== IMPL STATUS: $impl_status ==="
if {![string match "*Complete*" $impl_status]} {
    error "Implementation / bitstream failed with status: $impl_status"
}

open_run impl_1
puts "=== DEBUG CORES ==="
puts [get_debug_cores]
foreach dc [get_debug_cores] {
    puts "  $dc : ports = [llength [get_debug_ports -of_objects [get_debug_cores $dc]]]"
}

puts "=== TIMING SUMMARY ==="
report_timing_summary -delay_type min_max -max_paths 3 -no_header -return_string

puts "=== UTILIZATION SUMMARY ==="
report_utilization -return_string

set bit_path "$PRES_ROOT/vivado_kat/ascon_kat.runs/impl_1/top_kat_board.bit"
set ltx_path "$PRES_ROOT/vivado_kat/ascon_kat.runs/impl_1/top_kat_board.ltx"
puts "=== ARTIFACTS ==="
puts "BIT ($bit_path): exists=[file exists $bit_path]"
puts "LTX ($ltx_path): exists=[file exists $ltx_path]"
exit 0

