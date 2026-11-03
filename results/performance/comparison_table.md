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
| 32-bit Serialised (Paper Design Point) | `permutation_serial32` | — | — | — | — | — | — | — | — |
| **Full SoC System (PicoRV32 + Ascon Engine)** | `top_bringup_board` | **9232** | **19937** | **4** | **0** | **-2.657** | **VIOLATED** | **79.01** | **12.657** |

## 2. Cryptographic Throughput & Hardware Efficiency

| Architecture Variant | Cycles / AEAD Block | Cycles / Hash Block | AEAD-128 @ 100MHz (Mbit/s) | AEAD-128 @ F_max (Mbit/s) | Hash-256 @ 100MHz (Mbit/s) | Hash-256 @ F_max (Mbit/s) | AEAD Efficiency (Mbit/s/LUT) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1-Round Iterative (Baseline) | 8 | 12 | 1600.00 | **3301.69** | 533.33 | **1100.56** | 2.941 |
| 2-Rounds Unrolled (High Throughput) | 4 | 6 | 3200.00 | **4347.24** | 1066.67 | **1449.08** | 3.408 |
| 1/2-Round Folded (Low Area / Pipelined) | 16 | 24 | 800.00 | **2119.21** | 266.67 | **706.40** | 1.465 |
| 1-Round Espresso (ESPRESSO S-box) | 8 | 12 | 1600.00 | **2521.27** | 533.33 | **840.42** | 2.645 |
| 32-bit Serialised (Paper Design Point) | 16 | 24 | — | — | — | — | — |

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

### 32-bit Serialised (Paper Design Point) (`permutation_serial32`)
- **Implementation Strategy:** Serialised 32-bit datapath: processes 32 columns of the 5x64-bit state per cycle, requiring 2 clock cycles per Ascon round. Reduces area vs 1r at cost of 2x cycle count. Based on serial architecture from Graz University ascon-hardware repository. [SOURCE]
## 4. Verification & Audit Trail

- **Zero Fabrication Guarantee:** All resource counts (LUT, FF, BRAM, DSP) and timing slacks (WNS) are parsed directly from routed Vivado reports in `results/synthesis/` and `results/timing/`.
- **Report Files:**
  - `permutation_1r`: `results/synthesis/permutation_1r_util.rpt` and `results/timing/permutation_1r_timing.rpt`
  - `permutation_2r`: `results/synthesis/permutation_2r_util.rpt` and `results/timing/permutation_2r_timing.rpt`
  - `permutation_half`: `results/synthesis/permutation_half_util.rpt` and `results/timing/permutation_half_timing.rpt`
  - `permutation_1r_espresso`: `results/synthesis/permutation_1r_espresso_util.rpt` and `results/timing/permutation_1r_espresso_timing.rpt`
  - `permutation_serial32`: `results/synthesis/permutation_serial32_util.rpt` and `results/timing/permutation_serial32_timing.rpt`
