# Integrated Logic Analyzer (ILA) Hardware Verification Report

- **Project:** Ascon AEAD and Hash Engine for IoT Secure Boot
- **Target Hardware:** Digilent Zybo Z7-10 (AMD-Xilinx Zynq-7000 `xc7z010clg400-1`)
- **System Clock:** 100.0 MHz ($T_{\text{clk}} = 10.0\text{ ns}$ via MMCM from 125.0 MHz PHY oscillator)
- **Debug Tool:** AMD-Xilinx Vivado Integrated Logic Analyzer (`xilinx.com:ip:ila:6.2`)
- **Build & Capture Scripts:** [`scripts/build_bitstream_ila.tcl`](../../scripts/build_bitstream_ila.tcl), [`scripts/capture_ila.tcl`](../../scripts/capture_ila.tcl)
- **ILA Bitstream / Probes (gitignored local outputs):** `build/top_bringup_ila.bit` (SHA256 `73509960B279B6F45E7196DB4C7BC266A47025391670194D819D1D3BD9843224`), `build/top_bringup_ila.ltx`
- **Reference Document:** [`docs/hardware_test_plan.md`](../../docs/hardware_test_plan.md)

---

## 1. ILA Core Topology & Actual Probe Mapping

The ILA core (`u_ila_0`) is inserted post-synthesis in [`scripts/build_bitstream_ila.tcl`](../../scripts/build_bitstream_ila.tcl) and sampled in the `clk_100mhz` domain.

### 1.1 Core Configuration Parameters
- **IP Core:** `xilinx.com:ip:ila:6.2`
- **Sampling Clock:** `clk_100mhz` (`100.0 MHz`, `10.0 ns` sample period)
- **Sample Buffer Depth (`C_DATA_DEPTH`):** `1,024` samples ($10.24\,\mu\text{s}$ continuous window)
- **Input Pipeline Stages (`C_INPUT_PIPE_STAGES`):** `0`
- **Trigger Position (`CONTROL.TRIGGER_POSITION`):** `512` (midpoint in `capture_ila.tcl`)
- **Configured Probes:** **11 probe ports (18 total probe bits)**

### 1.2 Probed Signal Dictionary (Matches `scripts/build_bitstream_ila.tcl`)

| Probe Port | Signal / Hierarchical Net | Width | Radix | Semantic Role |
|:---|:---|:---:|:---:|:---|
| `probe0` | `rst_n` | 1 | HEX | Synchronized active-low system reset |
| `probe1` | `u_soc/boot_refuse` | 1 | HEX | Hardware refusal lockout output from `boot_ctrl` |
| `probe2` | `u_soc/u_ascon/u_boot_ctrl/hash_ok` | 1 | HEX | Hardware 256-bit digest comparator match flag |
| `probe3` | `u_soc/dma_start` | 1 | HEX | DMA payload stream start pulse |
| `probe4` | `u_soc/dma_busy` | 1 | HEX | DMA streaming active flag |
| `probe5` | `u_soc/dma_done` | 1 | HEX | DMA payload stream complete flag |
| `probe6` | `u_soc/dma_stream_valid` | 1 | HEX | DMA-to-Ascon AXI-Stream `tvalid` |
| `probe7` | `u_soc/dma_stream_ready` | 1 | HEX | Ascon-to-DMA AXI-Stream `tready` |
| `probe8` | `led_OBUF[3:0]` | 4 | HEX | Discrete user LEDs `LD0..LD3` |
| `probe9` | `sw_IBUF[1:0]` | 2 | HEX | Slide switches (`sw[0]` DMA flip, `sw[1]` tamper) |
| `probe10` | `u_soc/rgb_led[2:0]` | 3 | HEX | RGB LED `LD6` (`[0]=Red`, `[1]=Green`, `[2]=Blue`) |

---

## 2. Committed On-Board ILA Captures (`-trigger_now` Steady-State Snapshots)

On November 6, 2026, two 1,024-sample ILA captures were exported from the physical Digilent Zybo Z7-10 using `scripts/capture_ila.tcl` in immediate trigger mode (`run_hw_ila $hw_ila -trigger_now`, trigger marker at sample `512`). Because `-trigger_now` fires after programming/boot completes, both CSV logs capture **steady-state post-boot hardware probe values** across all 1,024 samples (`0..1023`), confirming physical LED/switch and internal status nets on silicon:

| Capture Artifact | Board Stimulus | Visual Observation | `rst_n` | `boot_refuse` | `hash_ok` | `dma_done` | `led_OBUF[3:0]` | `sw_IBUF[1:0]` | `u_soc/rgb_led[2:0]` |
|---|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| [`ila_capture_normal_boot.csv`](ila_traces/ila_capture_normal_boot.csv) | `SW0=0`, `SW1=0` (valid `bram_case1_valid.hex`) | `LD0..3` all ON, `LD6` Solid **Green** | `1` | `0` | `1` | `1` | `0xF` (`4'b1111`) | `0x0` | `0x2` (Green) |
| [`ila_capture_fault_injection.csv`](ila_traces/ila_capture_fault_injection.csv) | `SW0=1`, `SW1=0` (DMA bit-0 flip at word `0x410`) | `LD0..3` `4'b1010`, `LD6` Solid **Red** | `1` | `1` | `0` | `1` | `0xA` (`4'b1010`) | `0x1` | `0x1` (Red) |

In both steady-state captures, `dma_start = 0`, `dma_busy = 0`, `dma_stream_valid = 0`, and `dma_stream_ready = 0` (`TRIGGER = 1` at sample `512`, `0` elsewhere).

---

## 3. Simulated Transient Timing vs. Pending Hardware Captures

Cycle-by-cycle transient transitions during boot are verified in **Vivado XSim simulation** rather than captured yet with an armed rising-edge trigger on silicon:

- **Simulated Reference (`tb_secure_boot.sv` / `boot_timing_sim.log` / `boot_scaling_benchmark.log`):**
  - **Valid Boot (Case 1, 64 B):** `reset_to_jump = 906 cycles (9.06 us)`, `reset_to_test_pass = 1,342 cycles (13.42 us)` at `100 MHz`.
  - **Refusal Paths (Cases 2–9):** `boot_refuse` locks at `1`, `boot_jump_enable` remains `0`, discrete LEDs drive `4'b1010`, and `fetch_guard` intercepts application fetches with RISC-V NOP (`0x0000_0013`).
- **Pending On-Board Edge-Triggered / Bench Items (`STATUS: PENDING`):**
  1. **Armed Rising-Edge Normal Boot ILA Capture:** Run `capture_ila.tcl` in `normal` mode (trigger on `u_soc/dma_start == 1`, press `BTN0` while armed) to record the transient `0 -> dma_start -> hash_ok -> GREEN` transition on silicon.
  2. **Armed Rising-Edge Fault ILA Capture:** Run `capture_ila.tcl` in `fault` mode (trigger on `u_soc/boot_refuse == 1` with `SW0 = 1`, press `BTN0`) to record the transient refusal transition on silicon.
  3. **Physical `SW1` Tamper Bench Log:** Verify `SW1 = 1` lockout and post-`SW1 -> 0` sticky persistence until `BTN0` reset on the physical board (verified in RTL simulation Case 9 and NuSMV CTL proof).

---

## 4. Formal CTL Correlation

In Phase 9, NuSMV 2.6.0 proved all five CTL safety properties on [`formal/ctl/boot_safety_corrected.smv`](../../formal/ctl/boot_safety_corrected.smv) ([`results/formal/nuxmv/proof_corrected_nusmv.log`](../formal/nuxmv/proof_corrected_nusmv.log)):
- `AG(jump -> hash_ok)`
- `AG(jump -> verified_before_jump)`
- `AG(tamper_latched -> !EF jump)`
- `AG(DECIDE & !hash_ok -> AX REFUSE)`
- `AG(refuse -> AG refuse)`

On silicon, the committed `-trigger_now` captures corroborate the reachable terminal invariants (`hash_ok = 1, boot_refuse = 0, rgb_led = GREEN` for untampered boot vs. `hash_ok = 0, boot_refuse = 1, rgb_led = RED` under `SW0 = 1` fault injection). Rising-edge cycle ordering on the live FPGA fabric will be confirmed once the armed `normal` / `fault` ILA captures are run.

---

## 5. ILA Bitstream Utilization & Static Timing Summary

All numbers below are taken directly from [`results/synthesis/utilization_bringup.txt`](../synthesis/utilization_bringup.txt), [`results/timing/timing_bringup.txt`](../timing/timing_bringup.txt), [`results/synthesis/utilization_bringup_ila.txt`](../synthesis/utilization_bringup_ila.txt), and [`results/timing/timing_bringup_ila.txt`](../timing/timing_bringup_ila.txt):

| Metric | Baseline SoC (`top_bringup_board`) | ILA Instrumented Build (`top_bringup_board` + `u_ila_0`) | ILA Overhead | Available (`XC7Z010`) | ILA Utilization (%) |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Slice LUTs** | 5,088 | **6,784** | +1,696 | 17,600 | **38.55%** |
| **Slice Registers (FFs)** | 5,486 | **7,743** | +2,257 | 35,200 | **22.00%** |
| **Block RAM Tiles** | 4 (`4 RAMB36E1`) | **8.5** (`8 RAMB36E1 + 1 RAMB18E1`) | +4.5 | 60 | **14.17%** |
| **Clock Buffers (`BUFGCTRL`)** | 2 | **3** | +1 | 32 | **9.38%** |
| **MMCM (`MMCME2_ADV`)** | 1 | **1** | 0 | 2 | **50.00%** |
| **Post-Route Setup Slack (WNS @ 100 MHz)** | +1.510 ns | **+1.042 ns** | -0.468 ns | $\ge 0.000\text{ ns}$ | **MET (0 / 21,115 failing)** |
| **Post-Route Hold Slack (WHS)** | +0.027 ns | **+0.023 ns** | -0.004 ns | $\ge 0.000\text{ ns}$ | **MET (0 / 21,099 failing)** |

*(Note: During intermediate `route_design`, Vivado logged an estimated WNS of `+1.007 ns` in `build/vivado_ila_build.log`; final post-route `report_timing_summary` closed at `+1.042 ns` WNS, `+0.023 ns` WHS, and `0.000 ns` TNS/THS.)*
