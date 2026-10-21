# ==============================================================================
# Out-of-Context (OOC) Timing Constraints for Ascon Permutation Cores
# Target Part: xc7z010clg400-1 (AMD-Xilinx 7-Series Zynq)
# Target Clock: 100 MHz (Period: 10.000 ns, 50% Duty Cycle)
# ==============================================================================

create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
