# Ascon Hardware Architectural Variants Performance Comparison

**Target Device:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Digilent Zybo Z7-10)  
**Synthesis Mode:** Out-of-Context (OOC) Placement & Routing  
**Target Clock Period:** 10.000 ns (100.00 MHz)  
**Toolchain:** Vivado v2025.1 (win64)  

## 1. Resource Utilization & Maximum Timing Frequency (Permutation Cores OOC)

| Architecture Variant | Top Module | Slice LUTs | Slice FFs | BRAM Tile | DSP | WNS @ 100MHz (ns) | 100MHz Timing | F_max (MHz) | T_min (ns) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1-Round Iterative (Baseline) | `permutation_1r` | 544 | 335 | 0 | 0 | +5.154 | **MET** | **206.36** | 4.846 |
| 2-Rounds Unrolled (High Throughput) | `permutation_2r` | 939 | 335 | 0 | 0 | +2.639 | **MET** | **135.85** | 7.361 |
| 1/2-Round Folded (Low Area / Pipelined) | `permutation_half` | 546 | 655 | 0 | 0 | +6.225 | **MET** | **264.90** | 3.775 |
| 1-Round Espresso (Paper Variant) | `permutation_1r_espresso` | 605 | 335 | 0 | 0 | +3.654 | **MET** | **157.58** | 6.346 |
| **Full SoC System (PicoRV32 + Ascon Engine)** | `top_bringup_board` | **1001** | **569** | **4** | **0** | **+3.098** | **MET** | **144.89** | **6.902** |

## 2. Cryptographic Throughput & Hardware Efficiency

| Architecture Variant | Cycles / AEAD Block | Cycles / Hash Block | AEAD-128 @ 100MHz (Mbit/s) | AEAD-128 @ F_max (Mbit/s) | Hash-256 @ 100MHz (Mbit/s) | Hash-256 @ F_max (Mbit/s) | AEAD Efficiency (Mbit/s/LUT) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1-Round Iterative (Baseline) | 6 | 12 | 1066.67 | **2201.13** | 533.33 | **1100.56** | 1.961 |
| 2-Rounds Unrolled (High Throughput) | 3 | 6 | 2133.33 | **2898.16** | 1066.67 | **1449.08** | 2.272 |
| 1/2-Round Folded (Low Area / Pipelined) | 12 | 24 | 533.33 | **1412.80** | 266.67 | **706.40** | 0.977 |
| 1-Round Espresso (Paper Variant) | 6 | 12 | 1066.67 | **1680.85** | 533.33 | **840.42** | 1.763 |

## 3. Architectural Analysis & Trade-offs

### 1-Round Iterative (Baseline) (`permutation_1r`)
- **Implementation Strategy:** Baseline 1-round/cycle datapath with NIST SP 800-232 bit-sliced S-box.
- **Resource Footprint:** Consumes 544 LUTs and 335 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +5.154 ns at 100 MHz, achieving maximum frequency $F_{max} = 206.36$ MHz.
- **Throughput Characteristics:** Delivers 1066.67 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 2201.13 Mbit/s at peak frequency.

### 2-Rounds Unrolled (High Throughput) (`permutation_2r`)
- **Implementation Strategy:** Chained dual combinational round cores retiring 2 rounds per clock edge.
- **Resource Footprint:** Consumes 939 LUTs and 335 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +2.639 ns at 100 MHz, achieving maximum frequency $F_{max} = 135.85$ MHz.
- **Throughput Characteristics:** Delivers 2133.33 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 2898.16 Mbit/s at peak frequency.

### 1/2-Round Folded (Low Area / Pipelined) (`permutation_half`)
- **Implementation Strategy:** 2-phase folded micro-step datapath (p_C + p_S in cycle 0, p_L in cycle 1).
- **Resource Footprint:** Consumes 546 LUTs and 655 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +6.225 ns at 100 MHz, achieving maximum frequency $F_{max} = 264.90$ MHz.
- **Throughput Characteristics:** Delivers 533.33 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 1412.80 Mbit/s at peak frequency.

### 1-Round Espresso (Paper Variant) (`permutation_1r_espresso`)
- **Implementation Strategy:** Paper-derived variant using 2-level SOP logic minimization for S-box layer.
- **Resource Footprint:** Consumes 605 LUTs and 335 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +3.654 ns at 100 MHz, achieving maximum frequency $F_{max} = 157.58$ MHz.
- **Throughput Characteristics:** Delivers 1066.67 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 1680.85 Mbit/s at peak frequency.

## 4. Verification & Audit Trail

- **Zero Fabrication Guarantee:** All resource counts (LUT, FF, BRAM, DSP) and timing slacks (WNS) are parsed directly from routed Vivado reports in `results/synthesis/` and `results/timing/`.
- **Report Files:**
  - `permutation_1r`: `results/synthesis/permutation_1r_util.rpt` and `results/timing/permutation_1r_timing.rpt`
  - `permutation_2r`: `results/synthesis/permutation_2r_util.rpt` and `results/timing/permutation_2r_timing.rpt`
  - `permutation_half`: `results/synthesis/permutation_half_util.rpt` and `results/timing/permutation_half_timing.rpt`
  - `permutation_1r_espresso`: `results/synthesis/permutation_1r_espresso_util.rpt` and `results/timing/permutation_1r_espresso_timing.rpt`
