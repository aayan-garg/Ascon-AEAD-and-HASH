open_hw_manager
connect_hw_server -allow_non_jtag
puts "Connected to hw_server."

set targets [get_hw_targets]
puts "Detected targets: $targets"

foreach target $targets {
    puts "--- Probing target: $target ---"
    current_hw_target $target
    
    # Try different JTAG frequencies
    foreach freq {500000 1000000 5000000 10000000 15000000} {
        puts "Trying JTAG frequency: $freq Hz..."
        catch {
            set_property PARAM.FREQUENCY $freq [current_hw_target]
            open_hw_target
            set devs [get_hw_devices]
            puts ">>> SUCCESS at $freq Hz! Devices: $devs"
            close_hw_target
            break
        } err
        puts "  Failed at $freq Hz: $err"
        catch { close_hw_target }
    }
}

disconnect_hw_server
close_hw_manager
exit 0
