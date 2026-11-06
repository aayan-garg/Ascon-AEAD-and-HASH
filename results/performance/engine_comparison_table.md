# Ascon Engine-Level (mode_ctrl) Out-of-Context Implementation Comparison

- **Target FPGA:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C (Zybo Z7-10)
- **Synthesis Tool:** AMD-Xilinx Vivado v2025.1 (win64)
- **Design Hierarchy:** Full Engine (`mode_ctrl` + `aead_ctrl` + `hash_ctrl` + `plaintext_gate` [BUFFER_DEPTH=32] + Permutation Core)
- **Target Constraint:** 100.0 MHz (10.000 ns period, OOC)
- **Evaluation Date:** November 6, 2026

## 1. Engine Synthesis and STA Timing Results

| Architecture Variant | Top Wrapper | S-Box Type | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | Timing Status |
|---|---|---|---|---|---|---|---|
| **1R Baseline** | `mode_ctrl_1r_wrap` | Standard (Bit-sliced) | 3,191 | 4,015 | +1.925 ns | 123.84 MHz | `[MET]` |
| **1R ESPRESSO** | `mode_ctrl_1r_espresso_wrap` | ESPRESSO SOP (Exact 30-cube) | 3,258 | 4,015 | +1.621 ns | 119.35 MHz | `[MET]` |
| **1R Kernel** | `mode_ctrl_1r_kernel_wrap` | Brayton-McMullen Kernel Factored | 3,192 | 4,015 | +2.226 ns | 128.63 MHz | `[MET]` |
| **1R BDD** | `mode_ctrl_1r_bdd_wrap` | Optimal ROBDD Mux Network | 3,225 | 4,015 | +1.856 ns | 122.79 MHz | `[MET]` |
| **2R Unrolled** | `mode_ctrl_2r_wrap` | Standard (Bit-sliced) | 3,604 | 4,015 | +1.332 ns | 115.37 MHz | `[MET]` |
| **Half-Round (0.5R)** | `mode_ctrl_half_wrap` | Standard (Bit-sliced) | 2,995 | 4,328 | +1.776 ns | 121.60 MHz | `[MET]` |
| **Serial-32** | `mode_ctrl_serial32_wrap` | 32-bit Shared | 3,353 | 4,180 | +1.598 ns | 119.02 MHz | `[MET]` |

## 2. Cryptographic Throughput and Area Efficiency

- **NIST SP 800-232 Parameters:** Ascon-AEAD128 rate = 128 bits ($b=8$ rounds); Ascon-Hash256 rate = 64 bits ($a=12$ rounds).
- **Throughput Formula:** $\text{Throughput (Mbps)} = \frac{\text{Block Rate (bits)} \times F}{\text{Cycles per Block}}$
- **Area Efficiency ($TP/A$):** $\frac{\text{AEAD Throughput (kbps)}}{\text{Slice LUTs}}$

| Architecture Variant | AEAD Cyc/Blk | Hash Cyc/Blk | AEAD @ 100 MHz | AEAD @ Fmax | Hash @ 100 MHz | Hash @ Fmax | AEAD Eff @ 100 MHz (kbps/LUT) |
|---|:---:|:---:|---|---|---|---|:---:|
| **1R Baseline** | 8 | 12 | 1600.00 Mbps | 1981.42 Mbps | 533.33 Mbps | 660.47 Mbps | 501.41 |
| **1R ESPRESSO** | 8 | 12 | 1600.00 Mbps | 1909.54 Mbps | 533.33 Mbps | 636.51 Mbps | 491.10 |
| **1R Kernel** | 8 | 12 | 1600.00 Mbps | 2058.14 Mbps | 533.33 Mbps | 686.05 Mbps | 501.25 |
| **1R BDD** | 8 | 12 | 1600.00 Mbps | 1964.64 Mbps | 533.33 Mbps | 654.88 Mbps | 496.12 |
| **2R Unrolled** | 4 | 6 | 3200.00 Mbps | 3691.74 Mbps | 1066.67 Mbps | 1230.58 Mbps | 887.90 |
| **Half-Round (0.5R)** | 16 | 24 | 800.00 Mbps | 972.76 Mbps | 266.67 Mbps | 324.25 Mbps | 267.11 |
| **Serial-32** | 16 | 24 | 800.00 Mbps | 952.15 Mbps | 266.67 Mbps | 317.38 Mbps | 238.59 |

## 3. Key Observations

1. **2-Round Unrolled** achieves the highest raw throughput at 3,200.00 Mbps @ 100 MHz and 3,719.16 Mbps @ Fmax, with 887.90 kbps/LUT and 3,604 LUTs (+12.9% area vs. 1R baseline).
2. **Half-Round (0.5R)** minimizes engine area (2,995 LUTs, -6.1% vs. 1R baseline) by folding round operations over 2 clock cycles, delivering 800.00 Mbps @ 100 MHz (267.11 kbps/LUT).
3. **Serial-32 Datapath** on Xilinx 7-series FPGA consumes more LUTs than 1R baseline (3,353 vs 3,191 LUTs, +5.1%) and requires 2x cycles per block (16 cycles AEAD, 24 cycles Hash), resulting in lower efficiency (238.59 kbps/LUT vs 501.41 kbps/LUT for 1R baseline). The 6-input LUT architecture makes 1R bit-sliced S-boxes compact, so the multiplexing and state partitioning overhead exceeds the logic sharing savings.
4. **S-Box Variant Comparison Across Identical Engine Wrappers:**
   - **1R Baseline (Canonical Bit-Sliced):** 3,191 LUTs, 4,015 FFs, WNS +1.925 ns (123.84 MHz).
   - **1R Kernel (Brayton-McMullen Factored):** 3,192 LUTs, 4,015 FFs, WNS +2.226 ns (128.64 MHz).
   - **1R BDD (Optimal ROBDD Mux Network):** 3,225 LUTs, 4,015 FFs, WNS +1.856 ns (122.79 MHz).
   - **1R ESPRESSO (Exact 30-Cube SOP):** 3,258 LUTs, 4,015 FFs, WNS +1.621 ns (119.35 MHz).
   - **Hardware Impact Analysis:** A 5-bit Ascon S-box maps to only a few 6-input LUTs (LUT6) on Xilinx 7-series architectures. Because Vivado synthesis re-maps and flattens small Boolean networks into LUT6 primitives during physical technology mapping, differences within ~2% (3,191 to 3,258 LUTs) across identical engine wrappers represent synthesis mapping noise rather than a fundamental architecture benefit, demonstrating that all three optimization paradigms achieve equivalent high-quality hardware realization.
