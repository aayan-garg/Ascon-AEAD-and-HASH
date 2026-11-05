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
| 1-Round Espresso (ESPRESSO S-box) | `permutation_1r_espresso` | 605 | 335 | 0 | 0 | +3.654 | **MET** | **157.58** | 6.346 |
| 32-bit Serialised (Exploratory Design Point) | `permutation_serial32` | 722 | 497 | 0 | 0 | +3.506 | **MET** | **153.99** | 6.494 |

Kernel, BDD, baseline, and ESPRESSO S-box variants are compared at engine
level only in [`engine_comparison_table.md`](engine_comparison_table.md).
They were not separately synthesized as permutation-level wrappers in the
same measurement session. S-box variants were evaluated with the 1-round
permutation only.
| **Full SoC System (PicoRV32 + Ascon Engine)** | `top_bringup_board` | **5088** | **5486** | **4** | **0** | **+1.510** | **MET** | **117.79** | **8.490** |

## 2. Cryptographic Throughput & Hardware Efficiency

| Architecture Variant | Cycles / AEAD Block | Cycles / Hash Block | AEAD-128 @ 100MHz (Mbit/s) | AEAD-128 @ F_max (Mbit/s) | Hash-256 @ 100MHz (Mbit/s) | Hash-256 @ F_max (Mbit/s) | AEAD Efficiency (Mbit/s/LUT) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1-Round Iterative (Baseline) | 8 | 12 | 1600.00 | **3301.69** | 533.33 | **1100.56** | 2.941 |
| 2-Rounds Unrolled (High Throughput) | 4 | 6 | 3200.00 | **4347.24** | 1066.67 | **1449.08** | 3.408 |
| 1/2-Round Folded (Low Area / Pipelined) | 16 | 24 | 800.00 | **2119.21** | 266.67 | **706.40** | 1.465 |
| 1-Round Espresso (ESPRESSO S-box) | 8 | 12 | 1600.00 | **2521.27** | 533.33 | **840.42** | 2.645 |
| 32-bit Serialised (Exploratory Design Point) | 16 | 24 | 800.00 | **1231.91** | 266.67 | **410.64** | 1.108 |

## 3. Architectural Analysis & Trade-offs

### 1-Round Iterative (Baseline) (`permutation_1r`)
- **Implementation Strategy:** Baseline 1-round/cycle datapath with NIST SP 800-232 bit-sliced S-box.
- **Resource Footprint:** Consumes 544 LUTs and 335 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +5.154 ns at 100 MHz, achieving maximum frequency $F_{max} = 206.36$ MHz.
- **Throughput Characteristics:** Delivers 1600.00 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 3301.69 Mbit/s at peak frequency.

### 2-Rounds Unrolled (High Throughput) (`permutation_2r`)
- **Implementation Strategy:** Chained dual combinational round cores retiring 2 rounds per clock edge.
- **Resource Footprint:** Consumes 939 LUTs and 335 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +2.639 ns at 100 MHz, achieving maximum frequency $F_{max} = 135.85$ MHz.
- **Throughput Characteristics:** Delivers 3200.00 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 4347.24 Mbit/s at peak frequency.

### 1/2-Round Folded (Low Area / Pipelined) (`permutation_half`)
- **Implementation Strategy:** 2-phase folded micro-step datapath (p_C + p_S in cycle 0, p_L in cycle 1).
- **Resource Footprint:** Consumes 546 LUTs and 655 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +6.225 ns at 100 MHz, achieving maximum frequency $F_{max} = 264.90$ MHz.
- **Throughput Characteristics:** Delivers 800.00 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 2119.21 Mbit/s at peak frequency.

### 1-Round Espresso (ESPRESSO S-box) (`permutation_1r_espresso`)
- **Implementation Strategy:** ESPRESSO SOP-minimized S-box layer; same round count as 1r baseline.
- **Resource Footprint:** Consumes 605 LUTs and 335 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +3.654 ns at 100 MHz, achieving maximum frequency $F_{max} = 157.58$ MHz.
- **Throughput Characteristics:** Delivers 1600.00 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 2521.27 Mbit/s at peak frequency.

### 32-bit Serialised (Exploratory Design Point) (`permutation_serial32`)
- **Implementation Strategy:** Our own 32-bit-slice serialisation of the permutation, motivated by the serialised design space surveyed in Groß et al. (DSD 2015). Processes 32 columns of the 5x64-bit state per cycle (2 clock cycles per Ascon round). On Xilinx 7-series FPGAs (XC7Z010), it consumes more LUTs than 1r (722 vs 544 LUTs core; 3,353 vs 3,191 engine) due to LUT6 slice structure and multiplexing overhead, yielding 0.51x throughput/LUT efficiency.
- **Resource Footprint:** Consumes 722 LUTs and 497 Flip-Flops on XC7Z010.
- **Timing Margin:** Worst Negative Slack is +3.506 ns at 100 MHz, achieving maximum frequency $F_{max} = 153.99$ MHz.
- **Throughput Characteristics:** Delivers 800.00 Mbit/s AEAD-128 throughput at 100 MHz, scaling to 1231.91 Mbit/s at peak frequency.

## 4. Verification & Audit Trail

- **Zero Fabrication Guarantee:** All resource counts (LUT, FF, BRAM, DSP) and timing slacks (WNS) are parsed directly from routed Vivado reports in `results/synthesis/` and `results/timing/`.
- **Report Files:**
  - `permutation_1r`: `results/synthesis/permutation_1r_util.rpt` and `results/timing/permutation_1r_timing.rpt`
  - `permutation_2r`: `results/synthesis/permutation_2r_util.rpt` and `results/timing/permutation_2r_timing.rpt`
  - `permutation_half`: `results/synthesis/permutation_half_util.rpt` and `results/timing/permutation_half_timing.rpt`
  - `permutation_1r_espresso`: `results/synthesis/permutation_1r_espresso_util.rpt` and `results/timing/permutation_1r_espresso_timing.rpt`
  - `permutation_serial32`: `results/synthesis/permutation_serial32_util.rpt` and `results/timing/permutation_serial32_timing.rpt`
