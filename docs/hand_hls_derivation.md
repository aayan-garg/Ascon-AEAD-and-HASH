# Hand High-Level Synthesis (HLS) Derivation: Ascon Permutation Round

- **Requirement:** `[SPEC]` Project_PS.md "Permutation round (bit-sliced S-box layer + linear diffusion) from your own hand HLS; design points of half, one and two rounds per cycle."
- **Scope:** Complete architectural derivation, Data Flow Graphs (DFGs), operation scheduling, resource allocation, register binding, and FSMD controller design across all four datapath variants.
- **Target Device:** AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C @ 100 MHz

---

## 1. Algorithmic Specification (NIST SP 800-232 §3)

The 320-bit Ascon permutation state $S$ comprises five 64-bit register words:
$$S = (x_0, x_1, x_2, x_3, x_4)$$

Each permutation round $p$ applies three sequential transformations:
$$p = p_L \circ p_S \circ p_C$$

```
        State S_in [320 bits] = {x0, x1, x2, x3, x4}
                     │
                     ▼
       ┌───────────────────────────┐
       │ Constant Addition (p_C)   │  x2[7:0] ^= c_r
       └─────────────┬─────────────┘
                     │
                     ▼
       ┌───────────────────────────┐
       │ Substitution Layer (p_S)  │  64 parallel 5x5 S-boxes on bit-slices
       └─────────────┬─────────────┘
                     │
                     ▼
       ┌───────────────────────────┐
       │  Linear Diffusion (p_L)   │  5 parallel 64-bit Σ_i word rotations
       └─────────────┬─────────────┘
                     │
                     ▼
        State S_out [320 bits] = {x0', x1', x2', x3', x4'}
```

### 1.1 Constant Addition ($p_C$)
Injects an 8-bit round constant $c_r$ into the least significant byte of word $x_2$:
$$x_2 \leftarrow x_2 \oplus c_r$$

### 1.2 Substitution Layer ($p_S$)
Applies a non-linear 5×5 S-box across 64 vertical bit-slices $i \in [0, 63]$:
$$(x_{0,i}, x_{1,i}, x_{2,i}, x_{3,i}, x_{4,i}) \leftarrow S_{5\times5}(x_{0,i}, x_{1,i}, x_{2,i}, x_{3,i}, x_{4,i})$$

Bit-slice algebraic decomposition:
- **Affine In:** $x_0 \leftarrow x_0 \oplus x_4;\ x_4 \leftarrow x_4 \oplus x_3;\ x_2 \leftarrow x_2 \oplus x_1$
- **Keccak $\chi$ Non-Linear:** $t_i \leftarrow x_i \oplus (\neg x_{i+1} \land x_{i+2}) \pmod 5$
- **Affine Out:** $t_1 \leftarrow t_1 \oplus t_0;\ t_0 \leftarrow t_0 \oplus t_4;\ t_3 \leftarrow t_3 \oplus t_2;\ t_2 \leftarrow \neg t_2$

### 1.3 Linear Diffusion Layer ($p_L$)
Applies five linear feedback functions $\Sigma_0..\Sigma_4$ operating on 64-bit words via right circular shifts ($\ggg$):
$$\Sigma_0(x_0) = x_0 \oplus (x_0 \ggg 19) \oplus (x_0 \ggg 28)$$
$$\Sigma_1(x_1) = x_1 \oplus (x_1 \ggg 61) \oplus (x_1 \ggg 39)$$
$$\Sigma_2(x_2) = x_2 \oplus (x_2 \ggg 1) \oplus (x_2 \ggg 6)$$
$$\Sigma_3(x_3) = x_3 \oplus (x_3 \ggg 10) \oplus (x_3 \ggg 17)$$
$$\Sigma_4(x_4) = x_4 \oplus (x_4 \ggg 7) \oplus (x_4 \ggg 41)$$

---

## 2. Hand HLS Design Point 1: 1 Round per Cycle (Baseline Iterative)

### 2.1 Scheduling & Operator Chaining
In the baseline iterative architecture ([`rtl/ascon/permutation_1r.sv`](../rtl/ascon/permutation_1r.sv)), the entire round transformation ($p_C \rightarrow p_S \rightarrow p_L$) is chained combinationally into a single clock cycle.

- **Schedule Table:**
  | Step | Operation | Inputs | Outputs | Cycle |
  |:---:|---|---|---|:---:|
  | 1 | Constant Add ($p_C$) | `state_q[2]`, `c_r` | `x2_c` | Cycle $r$ |
  | 2 | S-box Layer ($p_S$) | `state_q[0,1,3,4]`, `x2_c` | `s_out[0..4]` | Cycle $r$ |
  | 3 | Linear Diffusion ($p_L$) | `s_out[0..4]` | `round_out[0..4]` | Cycle $r$ |
  | 4 | State Register Writeback | `round_out[0..4]` | `state_q[0..4]` | PosEdge Clk |

- **Resource Allocation:**
  - 64 × 5-bit S-Box instances (`sbox5.sv` / `gen_sbox`)
  - 5 × 64-bit Linear Diffusion blocks (`diffusion.sv`)
  - 1 × 8-bit Round Constant XOR
  - 1 × 320-bit State Register (`state_q`)
  - 1 × 4-bit Round Counter (`round_ctr`)

- **Timing & Critical Path:**
  $$T_{clk} \ge T_{co} + T_{XOR8} + T_{SBOX5} + T_{DIFF64} + T_{su}$$
  - $T_{XOR8} \approx 0.35\text{ ns}$ (1 LUT level)
  - $T_{SBOX5} \approx 1.25\text{ ns}$ (1–2 LUT levels)
  - $T_{DIFF64} \approx 0.70\text{ ns}$ (1 LUT level, 3-input XOR)
  - Achieved Vivado Post-Route $T_{min} = 4.846\text{ ns}$ ($F_{max} = 206.36\text{ MHz}$).

---

## 3. Hand HLS Design Point 2: 2 Rounds per Cycle (Unrolled High-Throughput)

### 3.1 Scheduling & Operator Chaining
In the 2-round unrolled architecture ([`rtl/ascon/permutation_2r.sv`](../rtl/ascon/permutation_2r.sv)), two complete round functions are cascaded back-to-back combinationally within one clock cycle.

- **Schedule Table:**
  | Step | Operation | Inputs | Outputs | Cycle |
  |:---:|---|---|---|:---:|
  | 1 | Round $2r$ Sub-functions ($p_C \rightarrow p_S \rightarrow p_L$) | `state_q`, `c_r0` | `stage1_out` | Cycle $r$ (First half) |
  | 2 | Round $2r+1$ Sub-functions ($p_C \rightarrow p_S \rightarrow p_L$) | `stage1_out`, `c_r1` | `stage2_out` | Cycle $r$ (Second half) |
  | 3 | State Register Writeback | `stage2_out` | `state_q` | PosEdge Clk |

- **Resource Allocation:**
  - 128 × 5-bit S-Box instances ($2 \times 64$)
  - 10 × 64-bit Linear Diffusion blocks ($2 \times 5$)
  - 2 × 8-bit Round Constant XOR gates
  - 1 × 320-bit State Register (`state_q`)
  - Latency: Retires 2 rounds per clock edge. 12 rounds = **6 clock cycles**.

- **Timing & Critical Path:**
  $$T_{clk} \ge T_{co} + 2 \times (T_{XOR8} + T_{SBOX5} + T_{DIFF64}) + T_{su}$$
  - Doubled logic depth limits peak frequency to $F_{max} = 135.85\text{ MHz}$ ($T_{min} = 7.361\text{ ns}$).
  - Delivers maximum throughput: **3,200.00 Mbit/s** at 100 MHz (**4,347.24 Mbit/s** at Fmax).

---

## 4. Hand HLS Design Point 3: Half-Round per Cycle (Pipelined / Folded)

### 4.1 Scheduling & Operator Partitioning
In the half-round folded pipeline ([`rtl/ascon/permutation_half.sv`](../rtl/ascon/permutation_half.sv)), the round function is bisected into two balanced temporal phases separated by a 320-bit pipeline register `s_reg`.

- **Schedule Table (2 Clock Cycles per Round):**
  | Micro-Cycle | Phase | Executed Operations | Intermediate Latches | Output |
  |:---:|---|---|---|---|
  | Cycle $2r$ | Phase 0 (`PHASE_SBOX`) | $p_C$ (Constant Add) + $p_S$ (64 S-boxes) | `s_reg <= sbox_out` | `s_reg` [320 B] |
  | Cycle $2r+1$ | Phase 1 (`PHASE_DIFF`) | $p_L$ (5 Linear Diffusions on `s_reg`) | `state_q <= diff_out` | `state_q` [320 B] |

- **Resource Allocation & Binding:**
  - 64 × 5-bit S-Box instances (evaluated only during Phase 0)
  - 5 × 64-bit Linear Diffusion blocks (evaluated only during Phase 1)
  - 1 × 320-bit State Register (`state_q`)
  - 1 × 320-bit Pipeline Register (`s_reg`)
  - Latency: 2 cycles per round. 12 rounds = **24 clock cycles**.

- **Timing Optimization:**
  $$T_{clk} \ge \max(T_{XOR8} + T_{SBOX5},\ T_{DIFF64}) + T_{co} + T_{su}$$
  - By breaking the combinational chain between non-linear substitution and linear diffusion, logic depth per cycle is halved.
  - Achieved $T_{min} = 3.775\text{ ns}$ ($F_{max} = \mathbf{264.90\text{ MHz}}$) — the highest clock frequency in the project!

---

## 5. Hand HLS Paper Design Point: Serial-32 (Sub-Word Serialized Datapath)

### 5.1 Scheduling & Resource Sharing
The serialized 32-bit architecture ([`rtl/ascon/permutation_serial32.sv`](../rtl/ascon/permutation_serial32.sv), inspired by Groß et al., DSD 2015) shares a single 32-S-box array across two sequential cycles per round (50% reduction in S-box instances).

- **Schedule Table (2 Clock Cycles per Round with Shared Hardware):**
  | Micro-Cycle | Sub-Phase | Active Hardware | Word Slices Processed | Latching / Writeback |
  |:---:|---|---|---|---|
  | Cycle $2r$ | `ST_SBOX_A` | $p_C$ on $x_2[7:0]$ + 32 S-boxes | Low 32 bits: $x_{0..4}[31:0]$ | `half_reg <= sbox32_out` |
  | Cycle $2r+1$ | `ST_SBOX_B` | 32 S-boxes + Full $p_L$ (64-bit $\Sigma$) | High 32 bits: $x_{0..4}[63:32]$ | Recombine `{sbox32_out, half_reg}`, run $p_L$, write `state_q` |

- **Resource Binding:**
  - 32 × 5-bit S-Box instances (`gen_sbox32`)
  - 5 × 64-bit Linear Diffusion blocks
  - 1 × 160-bit Half-Slice Pipeline Register (`half_reg`)
  - 1 × 320-bit State Register (`state_q`)

---

## 6. Comprehensive Architectural Comparison Matrix

All figures below are parsed directly from routed out-of-context Vivado 2025.1 reports targeting XC7Z010 @ 100 MHz:

| Design Point | RTL Top Module | Schedule (Cyc/Round) | S-Box Count | Slice LUTs | Slice FFs | WNS @ 100 MHz | Fmax (MHz) | AEAD-128 @ 100 MHz | Efficiency (Mbps/LUT) |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Half-Round Folded** | `permutation_half` | 2.0 | 64 | 546 | 655 | +6.225 ns | **264.90** | 800.00 Mbps | 1.465 |
| **1-Round Baseline** | `permutation_1r` | 1.0 | 64 | **544** | **335** | +5.154 ns | 206.36 | 1,600.00 Mbps | 2.941 |
| **2-Rounds Unrolled** | `permutation_2r` | **0.5** | 128 | 939 | 335 | +2.639 ns | 135.85 | **3,200.00 Mbps** | **3.408** |
| **Serial-32 Paper** | `permutation_serial32` | 2.0 | **32** | 722 | 497 | +3.506 ns | 153.99 | 800.00 Mbps | 1.108 |

### Architectural Conclusion:
1. **Peak Clock Frequency ($F_{max}$):** The Half-Round pipeline (`permutation_half`) wins at **264.90 MHz** due to temporal partitioning between substitution and diffusion.
2. **Peak Throughput ($Mbps$):** The 2-Round unrolled engine (`permutation_2r`) dominates with **3,200.00 Mbps** at 100 MHz and **4,347.24 Mbps** at Fmax.
3. **Hardware Efficiency ($Mbps/LUT$):** The 2-Round unrolled engine achieves the highest silicon efficiency (**3.408 Mbps/LUT**).
4. **FPGA vs ASIC Sub-Word Trade-off:** Serial-32 reduces S-box count by 50%, which saves area on ASICs. On Xilinx 7-series 6-LUT FPGAs, the multiplexing logic and pipeline registers exceed the S-box savings (722 LUTs vs 544 LUTs), making the 1-Round baseline superior for FPGA targets.

