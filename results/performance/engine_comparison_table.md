# Ascon Engine-Level (mode_ctrl) Out-of-Context Implementation Comparison

- **Target FPGA:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Zybo Z7-10)
- **Synthesis Tool:** AMD-Xilinx Vivado v2025.1 (win64)
- **Design Hierarchy:** Full Engine (`mode_ctrl` + `aead_ctrl` + `hash_ctrl` + `plaintext_gate` [BUFFER_DEPTH=32] + Permutation Core)
- **Target Constraint:** 100.0 MHz (10.000 ns period, OOC)
- **Evaluation Date:** November 5, 2026

## 1. Engine Synthesis and STA Timing Results

| Architecture Variant | Permutation Core | S-Box Type | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | Timing Status |
|---|---|---|---|---|---|---|---|
| **1R Baseline** | `1-Round` | Standard (Bit-sliced) | 3,191 | 4,015 | +1.925 ns | 123.84 MHz | `[MET]` |
| **1R ESPRESSO** | `1-Round` | ESPRESSO SOP | 3,253 | 4,015 | +1.498 ns | 117.62 MHz | `[MET]` |
| **2R Unrolled** | `2-Round` | Standard (Bit-sliced) | 3,604 | 4,015 | +1.332 ns | 115.37 MHz | `[MET]` |
| **Half-Round (0.5R)** | `0.5-Round` | Standard (Bit-sliced) | 2,995 | 4,328 | +1.776 ns | 121.60 MHz | `[MET]` |
| **Serial-32** | `Serial-32` | 32-LUT Shared | 3,353 | 4,180 | +1.598 ns | 119.02 MHz | `[MET]` |

## 2. AEAD Throughput and Area Efficiency

- **AEAD Block Size:** 128 bits (16 bytes per block, $r=128$)
- **Throughput Formula:** $\text{Throughput (Mbps)} = \frac{128 \text{ bits} \times F}{\text{Cycles per Block}}$
- **Area Efficiency ($TP/A$):** $\frac{\text{Throughput (Mbps)}}{\text{Slice LUTs}}$

| Architecture Variant | Cycles / Block | TP @ 100 MHz (Mbps) | TP @ Fmax (Mbps) | TP/A @ 100 MHz (kbps/LUT) | TP/A @ Fmax (kbps/LUT) |
|---|---|---|---|---|---|
| **1R Baseline** | 7 | 1828.57 Mbps | 2264.50 Mbps | 573.04 | 709.65 |
| **1R ESPRESSO** | 7 | 1828.57 Mbps | 2150.77 Mbps | 562.12 | 661.16 |
| **2R Unrolled** | 4 | 3200.00 Mbps | 3691.84 Mbps | 887.90 | 1024.37 |
| **Half-Round (0.5R)** | 13 | 984.62 Mbps | 1197.29 Mbps | 328.75 | 399.76 |
| **Serial-32** | 13 | 984.62 Mbps | 1171.89 Mbps | 293.65 | 349.50 |

## 3. Key Observations

1. **2-Round Unrolled** achieves the highest raw throughput (3,200.00 Mbps @ 100 MHz, 3,691.84 Mbps @ Fmax), delivering **887.90 kbps/LUT** efficiency despite consuming 3,604 LUTs (+12.9% area vs. 1R).
2. **Half-Round (0.5R)** minimizes engine area (2,995 LUTs, -6.1% vs. 1R baseline), making it optimal for extremely resource-constrained embedded targets.
3. **Serial-32 Datapath** completes 12 rounds in 24 cycles (6 rounds in 12 cycles) using a 32-bit shared S-box architecture, achieving 984.62 Mbps @ 100 MHz with full timing closure (WNS +1.598 ns, Fmax 119.02 MHz).
4. **ESPRESSO SOP S-Box** achieves 3,253 LUTs and +1.498 ns WNS, proving exact functional and timing equivalence to the bit-sliced baseline.
