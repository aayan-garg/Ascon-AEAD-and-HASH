# ==============================================================================
# Integrated Logic Analyzer (ILA 6.2) Constraints for Full 2,114-KAT Zybo Build
# Implementation ONLY (used_in_synthesis = false), flatten_hierarchy = none
# Flat XDC syntax (no Tcl procs, so 0 Designutils 20-1307 critical warnings)
# ==============================================================================

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]

set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets {clk_100mhz}]

# probe0: rst_n (1)
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 1 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets {rst_n}]

# probe1: u_soc/kat_done (1)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets {u_soc/kat_done}]

# probe2: u_soc/kat_all_pass (1)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets {u_soc/kat_all_pass}]

# probe3: u_soc/kat_hash_pass[11:0] (12) -> expects 1025 (0x401)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 12 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [list [get_nets {u_soc/kat_hash_pass[0]}] [get_nets {u_soc/kat_hash_pass[1]}] [get_nets {u_soc/kat_hash_pass[2]}] [get_nets {u_soc/kat_hash_pass[3]}] [get_nets {u_soc/kat_hash_pass[4]}] [get_nets {u_soc/kat_hash_pass[5]}] [get_nets {u_soc/kat_hash_pass[6]}] [get_nets {u_soc/kat_hash_pass[7]}] [get_nets {u_soc/kat_hash_pass[8]}] [get_nets {u_soc/kat_hash_pass[9]}] [get_nets {u_soc/kat_hash_pass[10]}] [get_nets {u_soc/kat_hash_pass[11]}]]

# probe4: u_soc/kat_aead_enc_pass[11:0] (12) -> expects 1089 (0x441)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 12 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [list [get_nets {u_soc/kat_aead_enc_pass[0]}] [get_nets {u_soc/kat_aead_enc_pass[1]}] [get_nets {u_soc/kat_aead_enc_pass[2]}] [get_nets {u_soc/kat_aead_enc_pass[3]}] [get_nets {u_soc/kat_aead_enc_pass[4]}] [get_nets {u_soc/kat_aead_enc_pass[5]}] [get_nets {u_soc/kat_aead_enc_pass[6]}] [get_nets {u_soc/kat_aead_enc_pass[7]}] [get_nets {u_soc/kat_aead_enc_pass[8]}] [get_nets {u_soc/kat_aead_enc_pass[9]}] [get_nets {u_soc/kat_aead_enc_pass[10]}] [get_nets {u_soc/kat_aead_enc_pass[11]}]]

# probe5: u_soc/kat_aead_dec_pass[11:0] (12) -> expects 1089 (0x441)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 12 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [list [get_nets {u_soc/kat_aead_dec_pass[0]}] [get_nets {u_soc/kat_aead_dec_pass[1]}] [get_nets {u_soc/kat_aead_dec_pass[2]}] [get_nets {u_soc/kat_aead_dec_pass[3]}] [get_nets {u_soc/kat_aead_dec_pass[4]}] [get_nets {u_soc/kat_aead_dec_pass[5]}] [get_nets {u_soc/kat_aead_dec_pass[6]}] [get_nets {u_soc/kat_aead_dec_pass[7]}] [get_nets {u_soc/kat_aead_dec_pass[8]}] [get_nets {u_soc/kat_aead_dec_pass[9]}] [get_nets {u_soc/kat_aead_dec_pass[10]}] [get_nets {u_soc/kat_aead_dec_pass[11]}]]

# probe6: u_soc/kat_fail_cnt[11:0] (12) -> expects 0
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 12 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [list [get_nets {u_soc/kat_fail_cnt[0]}] [get_nets {u_soc/kat_fail_cnt[1]}] [get_nets {u_soc/kat_fail_cnt[2]}] [get_nets {u_soc/kat_fail_cnt[3]}] [get_nets {u_soc/kat_fail_cnt[4]}] [get_nets {u_soc/kat_fail_cnt[5]}] [get_nets {u_soc/kat_fail_cnt[6]}] [get_nets {u_soc/kat_fail_cnt[7]}] [get_nets {u_soc/kat_fail_cnt[8]}] [get_nets {u_soc/kat_fail_cnt[9]}] [get_nets {u_soc/kat_fail_cnt[10]}] [get_nets {u_soc/kat_fail_cnt[11]}]]

# probe7: u_soc/kat_cycles[31:0] (32)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [list [get_nets {u_soc/kat_cycles[0]}] [get_nets {u_soc/kat_cycles[1]}] [get_nets {u_soc/kat_cycles[2]}] [get_nets {u_soc/kat_cycles[3]}] [get_nets {u_soc/kat_cycles[4]}] [get_nets {u_soc/kat_cycles[5]}] [get_nets {u_soc/kat_cycles[6]}] [get_nets {u_soc/kat_cycles[7]}] [get_nets {u_soc/kat_cycles[8]}] [get_nets {u_soc/kat_cycles[9]}] [get_nets {u_soc/kat_cycles[10]}] [get_nets {u_soc/kat_cycles[11]}] [get_nets {u_soc/kat_cycles[12]}] [get_nets {u_soc/kat_cycles[13]}] [get_nets {u_soc/kat_cycles[14]}] [get_nets {u_soc/kat_cycles[15]}] [get_nets {u_soc/kat_cycles[16]}] [get_nets {u_soc/kat_cycles[17]}] [get_nets {u_soc/kat_cycles[18]}] [get_nets {u_soc/kat_cycles[19]}] [get_nets {u_soc/kat_cycles[20]}] [get_nets {u_soc/kat_cycles[21]}] [get_nets {u_soc/kat_cycles[22]}] [get_nets {u_soc/kat_cycles[23]}] [get_nets {u_soc/kat_cycles[24]}] [get_nets {u_soc/kat_cycles[25]}] [get_nets {u_soc/kat_cycles[26]}] [get_nets {u_soc/kat_cycles[27]}] [get_nets {u_soc/kat_cycles[28]}] [get_nets {u_soc/kat_cycles[29]}] [get_nets {u_soc/kat_cycles[30]}] [get_nets {u_soc/kat_cycles[31]}]]

# probe8: u_soc/kat_status[15:0] (16)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 16 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [list [get_nets {u_soc/kat_status[0]}] [get_nets {u_soc/kat_status[1]}] [get_nets {u_soc/kat_status[2]}] [get_nets {u_soc/kat_status[3]}] [get_nets {u_soc/kat_status[4]}] [get_nets {u_soc/kat_status[5]}] [get_nets {u_soc/kat_status[6]}] [get_nets {u_soc/kat_status[7]}] [get_nets {u_soc/kat_status[8]}] [get_nets {u_soc/kat_status[9]}] [get_nets {u_soc/kat_status[10]}] [get_nets {u_soc/kat_status[11]}] [get_nets {u_soc/kat_status[12]}] [get_nets {u_soc/kat_status[13]}] [get_nets {u_soc/kat_status[14]}] [get_nets {u_soc/kat_status[15]}]]

# probe9: u_soc/dma_start (1)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets {u_soc/dma_start}]

# probe10: u_soc/dma_done (1)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets {u_soc/dma_done}]

# probe11: led_OBUF[3:0] (4)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 4 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [list [get_nets {led_OBUF[0]}] [get_nets {led_OBUF[1]}] [get_nets {led_OBUF[2]}] [get_nets {led_OBUF[3]}]]

# probe12: u_soc/rgb_led[2:0] (3)
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 3 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [list [get_nets {u_soc/rgb_led[0]}] [get_nets {u_soc/rgb_led[1]}] [get_nets {u_soc/rgb_led[2]}]]
