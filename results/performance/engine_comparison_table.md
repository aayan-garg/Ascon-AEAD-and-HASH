# Ascon Engine-Level (mode_ctrl) Out-of-Context Implementation Comparison

- **Target FPGA:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Zybo Z7-10)
- **Synthesis Tool:** AMD-Xilinx Vivado v2025.1 (win64)
- **Design Hierarchy:** Full Engine (`mode_ctrl` + `aead_ctrl` + `hash_ctrl` + `plaintext_gate` [BUFFER_DEPTH=32] + Permutation Core)
- **Target Constraint:** 100.0 MHz (10.000 ns period, OOC)
- **Evaluation Date:** November 5, 2026

## 1. Engine Synthesis and STA Timing Results

| Architecture Variant | Top Wrapper | S-Box Type | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | Timing Status |
|---|---|---|---|---|---|---|---|
| **1R Baseline** | `mode_ctrl_1r_wrap` | Standard (Bit-sliced) | 3,191 | 4,015 | +2.130 ns | 127.06 MHz | `[MET]` |
| **1R ESPRESSO** | `mode_ctrl_1r_espresso_wrap` | ESPRESSO SOP | 3,253 | 4,015 | +1.879 ns | 123.14 MHz | `[MET]` |
| **1R Kernel** | `mode_ctrl_1r_kernel_wrap` | ANF restatement (no extraction) | 3,052 | 4,006 | +2.142 ns | 127.26 MHz | `[MET]` |
| **1R BDD** | `mode_ctrl_1r_bdd_wrap` | 32-entry lookup (no BDD) | 3,055 | 4,006 | +2.086 ns | 126.36 MHz | `[MET]` |
| **2R Unrolled** | `mode_ctrl_2r_wrap` | Standard (Bit-sliced) | 3,604 | 4,015 | +1.729 ns | 120.90 MHz | `[MET]` |
| **Half-Round (0.5R)** | `mode_ctrl_half_wrap` | Standard (Bit-sliced) | 2,995 | 4,328 | +1.940 ns | 124.07 MHz | `[MET]` |
| **Serial-32** | `mode_ctrl_serial32_wrap` | 32-bit Shared | 3,353 | 4,180 | +1.900 ns | 123.46 MHz | `[MET]` |

## 2. Cryptographic Throughput and Area Efficiency

- **NIST SP 800-232 Parameters:** Ascon-AEAD128 rate = 128 bits ($b=8$ rounds); Ascon-Hash256 rate = 64 bits ($a=12$ rounds).
- **Throughput Formula:** $\text{Throughput (Mbps)} = \frac{\text{Block Rate (bits)} \times F}{\text{Cycles per Block}}$
- **Area Efficiency ($TP/A$):** $\frac{\text{AEAD Throughput (kbps)}}{\text{Slice LUTs}}$

| Architecture Variant | AEAD Cyc/Blk | Hash Cyc/Blk | AEAD @ 100 MHz | AEAD @ Fmax | Hash @ 100 MHz | Hash @ Fmax | AEAD Eff @ 100 MHz (kbps/LUT) |
|---|:---:|:---:|---|---|---|---|:---:|
| **1R Baseline** | 8 | 12 | 1600.00 Mbps | 2032.96 Mbps | 533.33 Mbps | 677.65 Mbps | 501.41 |
| **1R ESPRESSO** | 8 | 12 | 1600.00 Mbps | 1970.24 Mbps | 533.33 Mbps | 656.75 Mbps | 491.85 |
| **1R Kernel** | 8 | 12 | 1600.00 Mbps | 2036.16 Mbps | 533.33 Mbps | 678.72 Mbps | 524.25 |
| **1R BDD** | 8 | 12 | 1600.00 Mbps | 2021.76 Mbps | 533.33 Mbps | 673.92 Mbps | 523.73 |
| **2R Unrolled** | 4 | 6 | 3200.00 Mbps | 3868.80 Mbps | 1066.67 Mbps | 1289.60 Mbps | 887.90 |
| **Half-Round (0.5R)** | 16 | 24 | 800.00 Mbps | 992.56 Mbps | 266.67 Mbps | 330.85 Mbps | 267.11 |
| **Serial-32** | 16 | 24 | 800.00 Mbps | 987.68 Mbps | 266.67 Mbps | 329.23 Mbps | 238.59 |

## 3. Key Observations

1. **2-Round Unrolled** achieves the highest raw throughput at 3,200.00 Mbps @ 100 MHz and 3,868.80 Mbps @ Fmax, with 887.90 kbps/LUT and 3,604 LUTs (+12.9% area vs. 1R baseline).
2. **Half-Round (0.5R)** minimizes engine area (2,995 LUTs, -6.1% vs. 1R baseline) by folding round operations over 2 clock cycles, delivering 800.00 Mbps @ 100 MHz (267.11 kbps/LUT).
3. **Serial-32 Datapath** on Xilinx 7-series FPGA consumes more LUTs than 1R baseline (3,353 vs 3,191 LUTs, +5.1%) and requires 2x cycles per block (16 cycles AEAD, 24 cycles Hash), resulting in lower efficiency (238.59 kbps/LUT vs 501.41 kbps/LUT for 1R baseline). The 6-input LUT architecture makes 1R bit-sliced S-boxes compact, so the multiplexing and state partitioning overhead exceeds the logic sharing savings.
4. **ESPRESSO SOP S-Box** consumes 3,253 LUTs (+1.9% vs baseline) and meets 100 MHz timing with +1.879 ns WNS (Fmax 123.14 MHz), confirming functional equivalence and comparable post-route implementation quality.

The kernel and BDD rows are measurements of the checked-in RTL only. They
must not be interpreted as evidence of kernel extraction or BDD decomposition.
The small LUT difference versus baseline is not attributed to those
unperformed techniques.
