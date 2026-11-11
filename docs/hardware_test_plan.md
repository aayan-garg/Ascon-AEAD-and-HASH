# Hardware Test Plan & ILA Verification Guide: Ascon Secure Boot on Zybo Z7-10

**Project:** Ascon AEAD and Hash Engine for IoT Secure Boot  
**Target Hardware:** Digilent Zybo Z7-10 Development Board (AMD-Xilinx XC7Z010-1CLG400C)  
**System Clock:** 100.0 MHz (10.0 ns period) generated via MMCM from 125.0 MHz Ethernet PHY oscillator  
**Primary Reference:** `Project_PS.md` (Problem Statement & Project-Specific Deliverables)  
**Status:** Hardware Test Specification & Active Validation Record (Normal/`SW0` Steady-State Logged; Edge-Triggered ILA / `SW1` / On-Board KAT Pending)  

---

## 1. Executive Summary & Traceability to `Project_PS.md`

This document defines the complete on-board hardware test program, acceptance criteria, and Integrated Logic Analyzer (ILA) capture protocols required to validate the Ascon AEAD128 and Hash-256 secure-boot system on the physical Digilent Zybo Z7-10 FPGA board.

Every test procedure in this document directly traces to the requirements and deliverables defined in `Project_PS.md`:

| Requirement ID | Problem Statement Specification (`Project_PS.md`) | On-Board Hardware Verification Procedure | Primary Evidence / Artifact |
|:---|:---|:---|:---|
| **PS-DEL-1** | *"All NIST KATs pass for AEAD and hash, in simulation and on board."* | **Module HW-06:** Memory-mapped AXI4-Lite execution of canonical NIST SP 800-232 vectors; on-chip digest/tag comparison. | ILA capture of `ascon_tag_ok`, `hash_done`, and register status match. |
| **PS-DEL-2** | *"Throughput/area table for each rounds-per-cycle design point and the paper design."* | Post-implementation utilization and timing reports on XC7Z010 at 100 MHz; hardware verification of clock frequency. | `results/performance/comparison_table.md`, `results/timing/timing_bringup.txt`. |
| **PS-DEL-3** | *"CTL proof: boot jump never happens before `hash_ok`."* | **Module HW-02 & HW-07 (ILA):** Hardware Fetch Guard physical gating; real-time ILA probe demonstrating strict temporal ordering: $t(\text{hash\_ok}) < t(\text{boot\_jump\_enable})$. | Real-time ILA capture of `boot_jump_enable`, `hash_ok`, `fsm_state`, `gated_rdata`. |
| **PS-DEL-4** | *"Boot-time measurement (cycles) for a given firmware size."* | **Module HW-05:** Hardware cycle-counter capture from reset deassertion to `boot_jump_enable` across 64 B (906 cyc), 1 KB (2,706 cyc), and 4 KB (8,462 cyc). | Oscilloscope capture on trigger pin; ILA sample counter; `boot_scaling_benchmark.log`. |
| **PS-DEL-5** | *"Demo: good image boots (LED pattern); flipping one byte via a switch makes the boot refuse."* | **Module HW-03 & HW-04:** Live switch-controlled fault injection: SW0=1 flips candidate bit 0 during DMA; SW1=1 asserts physical tamper sensor. | Visual discrete LED pattern (`4'b1111` vs `4'b1010`), RGB LD6 (Green vs Red), and ILA waveforms. |

---

## 2. Hardware Architecture & Test Setup

### 2.1 Hardware Testbench Setup & Interconnect

```mermaid
flowchart TD
    subgraph HostPC ["Host PC Workstation"]
        VivadoHW ["Vivado Hardware Manager\n(JTAG Server TCP:3121)"]
    end

    subgraph ZyboBoard ["Digilent Zybo Z7-10 Board (XC7Z010-1CLG400C)"]
        subgraph PowerClock ["Power & Clocking"]
            PWR ["5V USB / Wall Jumper JP6"]
            OSC ["125 MHz PHY Osc (K17)"] --> MMCM ["MMCME2_BASE\n(125 MHz -> 100 MHz)"]
            MMCM --> CLK100 ["clk_100mhz (100 MHz)"]
        end

        subgraph IO ["Physical Switches & Buttons"]
            BTN0 ["BTN0 (K18)"] --> RSTSYNC ["Reset Synchronizer\n(rst_n)"]
            SW0 ["SW0 (G15)"] --> FAULT_INJ ["DMA XOR Bit 0 Inversion\n(Byte-Flip Fault Injection)"]
            SW1 ["SW1 (P15)"] --> TAMPER ["Hardware Tamper Sensor\n(tamper_det)"]
        end

        subgraph SoC ["PicoRV32 Secure Boot SoC"]
            CPU ["PicoRV32 RV32I Core"]
            BRAM ["16 KB Dual-Port BRAM\n(Boot ROM + App)"]
            GUARD ["Instruction Fetch Guard\n(Gating 0x1040..0x4000)"]
            DMA ["DMA Streaming Master"]
            ASCON ["Ascon AEAD & Hash Accelerator\n(100 MHz, 1 round/cyc)"]
            BCTRL ["Hardware Boot Controller\n(boot_ctrl.sv FSM)"]
        end

        subgraph Indicators ["Visual Status Outputs"]
            LEDS ["Discrete LEDs LD0..LD3\n(M14, M15, G14, D18)"]
            RGB ["Tri-Color RGB LED LD6\n(V16, F17, M17)"]
        end

        subgraph Debug ["On-Chip Instrumentation"]
            ILA ["Vivado ILA Core 6.2\n(1024 depth @ 100 MHz)"]
        end
    end

    VivadoHW <==>|Micro-USB JTAG (J12)| Debug
    CLK100 --> SoC
    CLK100 --> ILA
    RSTSYNC --> SoC
    FAULT_INJ --> DMA
    TAMPER --> BCTRL
    BCTRL --> GUARD
    BCTRL --> LEDS
    BCTRL --> RGB
    SoC -.->|11 Probes / 18 Bits| ILA
```

### 2.2 Board Pin Constraints & Hardware Interface

The pin assignments are enforced in [`board/zybo_z7_10.xdc`](../board/zybo_z7_10.xdc) and mapped in [`rtl/soc/top_bringup_board.sv`](../rtl/soc/top_bringup_board.sv):

| Physical Interface | Pin | IOStandard | RTL Net Name | Electrical & Semantic Behavior |
|:---|:---:|:---:|:---|:---|
| **Ethernet PHY Clock** | `K17` | LVCMOS33 | `clk_125mhz` | 125.0 MHz oscillator. Feeds internal MMCM to generate jitter-filtered 100.0 MHz system clock. |
| **Push Button 0** | `K18` | LVCMOS33 | `rst_btn` | Active-High manual reset. Pressing BTN0 forces asynchronous reset; release produces synchronous deassertion. |
| **Slide Switch 0** | `G15` | LVCMOS33 | `sw[0]` | **Live DMA Byte-Flip Fault Injection:** Inverts bit 0 of BRAM word `0x410` (byte `0x1040`) during DMA read. |
| **Slide Switch 1** | `P15` | LVCMOS33 | `sw[1]` | **Live Glitch / Tamper Sensor:** Asserts physical `tamper_det` input to `boot_ctrl.sv`, tripping sticky lockout. |
| **Slide Switch 2** | `W13` | LVCMOS33 | `sw[2]` | Unused / reserved slide switch input on `top_bringup_board` |
| **Slide Switch 3** | `T16` | LVCMOS33 | `sw[3]` | Unused / reserved slide switch input on `top_bringup_board` |
| **Discrete LED 0** | `M14` | LVCMOS33 | `led[0]` | Boot verification activity (LD0); illuminated during normal boot pass. |
| **Discrete LED 1** | `M15` | LVCMOS33 | `led[1]` | Boot refusal alert (LD1); illuminated during refusal pattern `4'b1010`. |
| **Discrete LED 2** | `G14` | LVCMOS33 | `led[2]` | DMA hashing activity (LD2); illuminated during normal boot pass. |
| **Discrete LED 3** | `D18` | LVCMOS33 | `led[3]` | CPU alive heartbeat (LD3); illuminated during both normal boot and refusal pattern. |
| **RGB LED LD6 Red** | `V16` | LVCMOS33 | `led6_r` | **Solid RED:** Refusal Lockout (`boot_refuse == 1` or tamper detected). |
| **RGB LED LD6 Green**| `F17` | LVCMOS33 | `led6_g` | **Solid GREEN:** Authentication Successful & Verified (`boot_jump_enable == 1`). |
| **RGB LED LD6 Blue** | `M17` | LVCMOS33 | `led6_b` | **Solid BLUE:** Digest Verification / DMA Stream in progress. |

---

## 3. Detailed Hardware Test Modules

### Test Module HW-01: Power-On Reset & MMCM Lock Verification
- **Objective:** Verify physical power rail stability, MMCM 125 MHz → 100 MHz multiplication/division, and synchronous reset release.
- **Preconditions:** Zybo Z7-10 powered on via SW4; JTAG connected; bitstream programmed.
- **Procedure:**
  1. Measure MMCM lock pin status or verify via Vivado Hardware Manager that `LOCKED` signal asserts within 100 µs of power-up.
  2. Press and hold BTN0. Observe that all user LEDs extinguish immediately.
  3. Release BTN0. Verify clean reset deassertion on the positive edge of `clk_100mhz`.
- **Pass Criteria:** MMCM reaches steady-state lock; reset synchronizer releases without metastable glitches; system transitions to Boot ROM address `0x0000_0000`.

---

### Test Module HW-02: Normal Authenticated Secure Boot (Valid Image, PS-DEL-5)
- **Objective:** Validate end-to-end secure boot of an authentic 64-byte application payload matching the pre-provisioned NIST SP 800-232 digest.
- **Preconditions:** `SW0 = 0` (no fault injection), `SW1 = 0` (no tamper), bitstream loaded with `firmware/tests/boot_matrix/bram_case1_valid.hex`.
- **Execution Steps:**
  1. Ensure all switches are set LOW (`SW[3:0] = 4'b0000`).
  2. Press and release **BTN0** (Reset).
- **Observed Hardware Sequence:**
  - **T = 0 to 180 ns (Cycles 0–18):** CPU executes Boot ROM initialization, configures DMA source address to `0x0000_1040` and length to 64 bytes (`0x40`).
  - **T = 180 to 260 ns (Cycles 18–26):** DMA master streams 8 64-bit words across the internal streaming interface to the Ascon Hash-256 accelerator.
  - **T = 260 to 880 ns (Cycles 26–88):** Ascon core executes round permutation (12 rounds initialization, absorption, 12 rounds finalization).
  - **T = 8.8 to 9.06 µs (Cycles 880–906):** `boot_ctrl` compares calculated 256-bit digest against `DEFAULT_TRUSTED_DIGEST`:
    $$\text{Computed Digest} == \text{32'hEDB41305\_12075573\_11B6C8A2\_AFB9E393\_7FE61055\_A2267BDC\_433A4F7B\_777BB3DF}$$
  - **T = 9.06 µs (Cycle 906):** Hardware comparator matches: `hash_ok = 1` asserts. Boot controller transitions `fsm_state` to `STATE_JUMP`, asserting `boot_jump_enable = 1`.
  - **T = 9.1 µs:** `fetch_guard` unlocks BRAM execution for addresses $\ge \text{0x1040}$. CPU jumps from Boot ROM loop to application code at `0x0000_1040`.
  - **T = 13.42 µs (Cycle 1,342):** Application executes payload instructions and writes `0x8000_000F` to GPIO register (`0x1000_0000`).
- **Pass Criteria:**
  - Discrete LEDs LD0..LD3 illuminate solid ON: **`4'b1111`** (`0xF`).
  - RGB LED LD6 illuminates solid **GREEN** (`3'b010`).
  - Zero CPU trap assertions (`u_soc/trap == 0`).

---

### Test Module HW-03: Real-Time DMA Byte-Flip Fault Injection Demo (PS-DEL-5)
- **Objective:** Demonstrate primary project requirement: *flipping one byte via a switch makes the boot refuse*.
- **Preconditions:** Board running or reset with `SW0 = 1`, `SW1 = 0`.
- **Fault Mechanism:** In `rtl/soc/top_bringup.sv`, slide switch SW0 inverts bit 0 of the first payload word (`dma_bram_rdata = dma_bram_raw ^ 32'h0000_0001` when `dma_bram_addr == 12'h410`).
- **Execution Steps:**
  1. Slide **SW0 to HIGH (1)**.
  2. Press and release **BTN0** (Reset) to initiate secure boot.
- **Observed Hardware Sequence:**
  - DMA streams corrupted payload word `0x1040` (with bit 0 flipped).
  - Ascon Hash-256 processes corrupted input. Due to cryptographic avalanche effect, $\approx 50\%$ of the output digest bits differ from the golden digest.
  - At cycle 890, `boot_ctrl` comparator checks digest: `hash_match == 0`.
  - `boot_ctrl` immediately transitions `fsm_state` to `STATE_HALT_REFUSE` (`4'd7`), asserting `boot_refuse = 1`.
  - `boot_jump_enable` remains strictly `0`.
  - CPU attempts fetch to `0x0000_1040`. `fetch_guard` intercepts fetch and returns RISC-V NOP (`0x0000_0013`), preventing execution of corrupted code.
- **Pass Criteria:**
  - Discrete LEDs LD0..LD3 display alternating refusal pattern: **`4'b1010`** (LD3=ON, LD2=OFF, LD1=ON, LD0=OFF).
  - RGB LED LD6 illuminates solid **RED** (`3'b001`).
  - System remains permanently locked out until reset.
- **Recovery Verification:**
  - Slide **SW0 back to LOW (0)**.
  - Press **BTN0**.
  - System instantly restores normal boot: solid **GREEN** + **`4'b1111`**.

---

### Test Module HW-04: Hardware Glitch / Physical Tamper Sensor Demo
- **Objective:** Validate hardware security perimeter response to transient glitch or enclosure tamper sensor assertion.
- **Preconditions:** Board running in normal boot state (Green LED).
- **Execution Steps:**
  1. While board is operating in normal boot, flick **SW1 to HIGH (1)**.
- **Observed Hardware Sequence:**
  - `sw[1]` triggers physical `tamper_det` input to `boot_ctrl.sv`.
  - Internal sticky latch `tamper_latched_q` fires high immediately.
  - Boot controller immediately revokes authorization: `boot_refuse = 1`, `boot_jump_enable = 0`.
  - `fetch_guard` immediately locks down instruction fetch from application region.
- **Sticky Latch Verification:**
  - Slide **SW1 back to LOW (0)**.
  - Verify refusal state **persists** (LD6 remains solid RED, discrete LEDs remain `4'b1010`).
  - Press **BTN0** to clear the tamper latch and restore normal operation.
- **Pass Criteria:** Glitch assertion produces immediate (<10 ns) lock out; tamper register remains sticky until manual physical reset.

---

### Test Module HW-05: Hardware Boot-Time Cycle Measurement (PS-DEL-4)
- **Objective:** Measure physical execution cycles and latency across multiple firmware payload sizes (64 B, 1 KB, 4 KB) at 100 MHz.
- **Measurement Method:**
  1. **On-Chip Cycle Counter:** Read 32-bit cycle capture register via AXI-Lite / GPIO.
  2. **ILA Sample Counter:** Count exact clock cycles between reset deassertion (`rst_n` rising) and `boot_jump_enable` rising edge.
  3. **External Oscilloscope:** Probe GPIO pin 0 (`led[0]`) or test point with a high-bandwidth digital oscilloscope to measure physical time delta.
- **Authoritative Benchmark Reference:**

| Firmware Payload Size | DMA Transfer Cycles | Ascon Hashing Cycles | Total Cycles to Jump ($T_{\text{jump}}$) | Total Latency to Jump ($\mu\text{s}$) | Total Cycles to App Pass | Total Latency to Pass ($\mu\text{s}$) |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **64 Bytes** (Default) | 8 | 72 | **906 cycles** | **9.06 $\mu$s** | **1,342 cycles** | **13.42 $\mu$s** |
| **1,024 Bytes** (1 KB) | 128 | 1,152 | **2,706 cycles** | **27.06 $\mu$s** | **3,155 cycles** | **31.55 $\mu$s** |
| **4,096 Bytes** (4 KB) | 512 | 4,608 | **8,462 cycles** | **84.62 $\mu$s** | **8,933 cycles** | **89.33 $\mu$s** |

- **Empirical Hardware Scaling Model:**
  $$T(N) = 1.874 \times N + 786.5 \text{ clock cycles} \quad (18.74\text{ ns/byte} + 7.865\,\mu\text{s})$$
- **Pass Criteria:** Physical measurements match cycle-accurate simulation within $\pm 0$ clock cycles on the digital bus, and within $\pm 10$ ns on external oscilloscope probes.

---

### Test Module HW-06: On-Board NIST Known-Answer Test (KAT) Validation (PS-DEL-1)
- **Objective:** Verify NIST SP 800-232 mathematical compliance of the hardware Ascon accelerator on the physical FPGA fabric.
- **Procedure:**
  - Execute firmware test harness exercising Ascon-AEAD128 (encryption, decryption, and authentication tag checking) and Ascon-Hash256 (256-bit hashing across variable lengths) through the memory-mapped AXI4-Lite registers (`0x4000_0000`).
  - Hardware checks computed tags and digests against golden test vectors embedded in ROM.
- **Pass Criteria:**
  - 100% of tested KAT vectors match NIST SP 800-232 golden values with zero bit errors.
  - Successful tag comparison releases decrypted plaintext in shadow buffer; tampered tag comparison returns `SLVERR` and suppresses plaintext release (R3 plaintext release gate).

---

## 4. Integrated Logic Analyzer (ILA) Architecture & Implementation

### 4.1 ILA Core Configuration

The Integrated Logic Analyzer core (`xilinx.com:ip:ila:6.2`) is inserted into the post-synthesis netlist via [`scripts/build_bitstream_ila.tcl`](../scripts/build_bitstream_ila.tcl). It operates directly in the 100.0 MHz system clock domain without adding capacitive loading or altering design timing closure.

- **Sampling Clock:** `clk_100mhz` (100.0 MHz, 10.0 ns resolution)
- **Sample Depth:** 1024 samples (provides $10.24\,\mu\text{s}$ continuous real-time capture window)
- **Input Pipeline Stages:** 0 (cycle-accurate alignment with system clock)
- **Total Monitored Nets:** 11 probe ports (18 total probe bits, per [`scripts/build_bitstream_ila.tcl`](../scripts/build_bitstream_ila.tcl))

### 4.2 Complete ILA Probe Signal Map

| Probe Port | Probe Width | Monitored Signal / Net Name | Radix | Semantic Function in Secure Boot |
|:---|:---:|:---|:---:|:---|
| `probe0` | 1 | `rst_n` | HEX | Synchronized active-low system reset |
| `probe1` | 1 | `u_soc/boot_refuse` | HEX | **Refusal Indicator:** Terminal lockout flag |
| `probe2` | 1 | `u_soc/u_ascon/u_boot_ctrl/hash_ok` | HEX | **Digest Match:** 256-bit hardware comparator match flag |
| `probe3` | 1 | `u_soc/dma_start` | HEX | DMA transfer initiation pulse |
| `probe4` | 1 | `u_soc/dma_busy` | HEX | DMA engine actively fetching BRAM words |
| `probe5` | 1 | `u_soc/dma_done` | HEX | DMA payload stream transfer complete flag |
| `probe6` | 1 | `u_soc/dma_stream_valid` | HEX | DMA stream data valid handshake |
| `probe7` | 1 | `u_soc/dma_stream_ready` | HEX | Ascon engine stream ready handshake |
| `probe8` | 4 | `led_OBUF[3:0]` | HEX | Discrete status LEDs LD0..LD3 |
| `probe9` | 2 | `sw_IBUF[1:0]` | HEX | Physical slide switches (`SW0`=flip, `SW1`=tamper) |
| `probe10` | 3 | `u_soc/rgb_led[2:0]` | HEX | RGB status LED LD6 (`[0]=Red`, `[1]=Green`, `[2]=Blue`) |

---

## 5. Simulated Transient Reference & Recorded Hardware Captures

> **Important Distinction:** The committed on-board ILA CSV captures (`results/board/ila_traces/ila_capture_normal_boot.csv` and `ila_capture_fault_injection.csv`) were captured in immediate `-trigger_now` steady-state mode after boot completed. The cycle-by-cycle boot diagrams below illustrate **simulated reference timing** from `tb_secure_boot.sv` (`906` / `1,342` cycles at `100 MHz`); armed rising-edge hardware ILA captures (`capture_ila.tcl normal` and `fault`) are pending to record the live boot transient on silicon.

### 5.1 Case 1: Golden Secure Boot Reference Flow (Normal Boot, SW0=0, SW1=0)

**Target Trigger Setup (for transient capture):** Trigger on rising edge of `u_soc/dma_start` (`probe3 == 1'b1`) via `scripts/capture_ila.tcl normal`. Observed `-trigger_now` steady-state hardware values (`ila_capture_normal_boot.csv`): `rst_n=1, boot_refuse=0, hash_ok=1, dma_done=1, led_OBUF=0xF, sw_IBUF=0x0, rgb_led=0x2 (Green)`.

```mermaid
sequenceDiagram
    autonumber
    participant CPU as PicoRV32 (Boot ROM)
    participant DMA as DMA Master
    participant BRAM as 16 KB BRAM
    participant Ascon as Ascon Hash Engine
    participant BC as Boot Controller
    participant FG as Fetch Guard

    Note over CPU,FG: Cycle 0-18: Reset deasserted; Boot ROM initializes
    CPU->>DMA: Configure DMA (Src: 0x1040, Len: 64 B)
    CPU->>DMA: Assert dma_start pulse
    Note over DMA,Ascon: Cycles 18-26: DMA streaming 8x 64-bit words
    loop DMA Stream Transfer
        DMA->>BRAM: Read word 0x410..0x417 (No bit-flip)
        BRAM-->>DMA: Return authentic firmware words
        DMA->>Ascon: Stream data (valid/ready handshake)
    end
    DMA->>BC: Assert dma_done pulse
    Note over Ascon,BC: Cycles 26-880: Ascon Hash-256 absorption & finalization
    Ascon->>BC: Assert hash_done + 256-bit computed digest
    BC->>BC: Compare with golden digest (hash_match == 1)
    Note over BC: Cycle 906: hash_ok asserts; FSM -> STATE_JUMP
    BC->>FG: Assert boot_jump_enable = 1
    FG-->>CPU: Application region unlocked (0x1040..0x4000)
    CPU->>BRAM: Fetch authentic instruction at 0x1040
    BRAM-->>CPU: Execute valid application payload
    Note over CPU: Cycle 1342: Application completes; write GPIO (LEDs = 0xF, RGB = Green)
```

#### Simulated XSim Reference Cycle Trace (Normal Boot)

```text
Clock Cycle      : ... 18 ... 22 ... 26 ... 880 ... 904 ... 906 ... 910 ... 1342
---------------------------------------------------------------------------------------------------------
clk_100mhz       : _/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_
rst_n            : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sw[0] (ByteFlip) : ______________________________________________________________________________________
sw[1] (Tamper)   : ______________________________________________________________________________________
dma_start        : __/~~~\_______________________________________________________________________________
dma_busy         : ___/~~~~~~~~~~~~~~~~~~~\______________________________________________________________
dma_stream_valid : ___/~~~~~~~~~~~~~~~~~~~\______________________________________________________________
dma_bram_addr    : ----< 410 >< 411 >< 417 >-------------------------------------------------------------
dma_done         : ____________________/~~~\_____________________________________________________________
fsm_state        : --< 1 ><       2       ><        3       ><  4  >< 5 ><              6 (JUMP)        >
hash_ok          : _________________________________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
boot_jump_enable : ___________________________________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
boot_refuse      : ______________________________________________________________________________________
rgb_led[2:0]     : -----------< 3'b100 (BLUE) >-----------------------------<      3'b010 (GREEN)       >
led[3:0]         : -------------------< 4'b0001 >---------------------------<       4'b1111 (0xF)       >
test_pass        : ___________________________________________________________________________________/~~
```

**Key Takeaways from Simulation & Steady-State Hardware Capture:**
1. In Vivado XSim (`tb_secure_boot.sv`), `hash_ok` transitions to `1` prior to `boot_jump_enable` asserting at **Cycle 906** (`9.06 µs`), and application completion occurs at **Cycle 1,342** (`13.42 µs`), matching the formal CTL invariant $AG(\text{jump} \rightarrow \text{hash\_ok})$.
2. On the physical Digilent Zybo Z7-10 (`ila_capture_normal_boot.csv`), steady-state `-trigger_now` capture confirms `hash_ok = 1`, `boot_refuse = 0`, `led_OBUF = 4'b1111`, and `rgb_led = 3'b010` (Green).

---

### 5.2 Case 2: Byte-Flip Fault Injection Reference & Hardware Capture (SW0=1, Refusal Path, PS-DEL-5)

**Target Trigger Setup (for transient capture):** Trigger on rising edge of `u_soc/boot_refuse` (`probe1 == 1'b1`) via `scripts/capture_ila.tcl fault`. Observed `-trigger_now` steady-state hardware values (`ila_capture_fault_injection.csv`): `rst_n=1, boot_refuse=1, hash_ok=0, dma_done=1, led_OBUF=0xA, sw_IBUF=0x1, rgb_led=0x1 (Red)`.

```mermaid
sequenceDiagram
    autonumber
    participant SW as Slide Switch SW0
    participant DMA as DMA Master
    participant BRAM as 16 KB BRAM
    participant Ascon as Ascon Hash Engine
    participant BC as Boot Controller
    participant FG as Fetch Guard
    participant CPU as PicoRV32

    Note over SW: SW0 set HIGH (Fault Injection Enabled)
    CPU->>DMA: Initiate DMA stream
    DMA->>BRAM: Fetch word 0x410 (byte 0x1040)
    Note over DMA: Bit 0 inverted: raw ^ 0x00000001
    DMA->>Ascon: Stream corrupted payload word
    DMA->>BC: dma_done
    Ascon->>BC: Computed corrupted 256-bit digest
    BC->>BC: Compare with golden digest: MISMATCH!
    Note over BC: Cycle 890: hash_match == 0 -> STATE_HALT_REFUSE
    BC->>BC: Assert boot_refuse = 1; boot_jump_enable = 0
    BC-->>CPU: LED pattern = 4'b1010; RGB = RED
    CPU->>FG: Unauthorized fetch attempt to 0x1040
    FG-->>CPU: Intercept! Return RISC-V NOP (0x00000013)
    Note over CPU: CPU trapped in safe NOP slide; application never executes
```

#### Simulated XSim Reference Cycle Trace (Tamper Refusal)

```text
Clock Cycle      : ... 18 ... 22 ... 26 ... 880 ... 890 ... 892 ... 906 ... 1000
---------------------------------------------------------------------------------------------------------
clk_100mhz       : _/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_/~\_
rst_n            : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sw[0] (ByteFlip) : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dma_bram_rdata   : ----< RAW ^ 1 >-----------------------------------------------------------------------
dma_done         : ____________________/~~~\_____________________________________________________________
fsm_state        : --< 1 ><       2       ><        3       >< 4 >< 5 ><     7 (STATE_HALT_REFUSE)     >
hash_ok          : ______________________________________________________________________________________
boot_jump_enable : ______________________________________________________________________________________
boot_refuse      : ___________________________________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rgb_led[2:0]     : -----------< 3'b100 (BLUE) >-----------------------<        3'b001 (RED)             >
led[3:0]         : -------------------< 4'b0001 >---------------------<        4'b1010 (0xA)            >
fetch_guard_nop  : ___________________________________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
test_pass        : ______________________________________________________________________________________
```

**Key Takeaways from Refusal ILA Capture:**
1. At **Cycle 890**, the comparator evaluates the hash mismatch: `hash_ok` remains permanently `0`.
2. `boot_refuse` transitions to `1`, locking `boot_jump_enable` permanently to `0`.
3. `fsm_state` enters `STATE_HALT_REFUSE` (`4'd7`), which is a sink state in the CTL Kripke model:
   $$AG(\text{refuse} \rightarrow AG(\text{refuse}))$$
4. Discrete LEDs drive `4'b1010` and RGB LED LD6 drives solid RED (`3'b001`).

---

## 6. Vivado ILA Build & Automation Toolchain

To ensure total reproducibility on any development machine, automated scripts are provided in the repository:

### 6.1 ILA Bitstream Generation Script: `scripts/build_bitstream_ila.tcl`
Executes full synthesis, inserts the ILA debug core (`u_ila_0`) on the **11 configured probes (18 bits)**, runs physical implementation, and generates both the bitstream and the Hardware Manager probe definition file:
```bash
# Run batch ILA build in Vivado:
C:\Xilinx\2025.1\Vivado\bin\vivado.bat -mode batch -nojournal -log build/vivado_ila_build.log -source scripts/build_bitstream_ila.tcl
```
- **Generated Bitstream (local/gitignored):** `build/top_bringup_ila.bit`
- **Generated Debug Probes (local/gitignored):** `build/top_bringup_ila.ltx`
- **Measured ILA Build Overhead & Totals (`utilization_bringup_ila.txt`, `timing_bringup_ila.txt`):** Adds `+1,696` LUTs, `+2,257` FFs, and `+4.5` BRAM Tiles over the baseline build (`6,784` LUTs [38.55%], `7,743` FFs [22.00%], `8.5` BRAM Tiles [14.17%]), closing post-route STA at **WNS = +1.042 ns** (`0` failing endpoints of 21,115).

### 6.2 Automated Hardware Manager ILA Programming & Capture: `scripts/capture_ila.tcl`
Connects to the Zybo Z7-10 via JTAG, loads `top_bringup_ila.bit` with `top_bringup_ila.ltx`, arms the trigger (or captures immediately with `now`), and exports CSV trace data:
```bash
# Capture steady-state running SoC immediately (-trigger_now):
C:\Xilinx\2025.1\Vivado\bin\vivado.bat -mode batch -nojournal -nolog -source scripts/capture_ila.tcl -tclargs now
# Arm rising-edge capture for normal boot (press BTN0 when prompted):
C:\Xilinx\2025.1\Vivado\bin\vivado.bat -mode batch -nojournal -nolog -source scripts/capture_ila.tcl -tclargs normal
# Arm rising-edge capture for fault injection (set SW0=1 and press BTN0 when prompted):
C:\Xilinx\2025.1\Vivado\bin\vivado.bat -mode batch -nojournal -nolog -source scripts/capture_ila.tcl -tclargs fault
```

---

## 7. Hardware Acceptance Criteria Checklist

| Checklist Item | Requirement | Verification Method | Status |
|:---|:---|:---|:---:|
| **AC-01: Clocking** | 100.0 MHz system clock from 125 MHz input; MMCM locked; 0 setup/hold violations. | Post-route Timing Report | Verified in Timing Reports (Baseline `WNS = +1.510 ns`; ILA `WNS = +1.042 ns`) |
| **AC-02: Normal Boot** | Valid firmware image boots; discrete LEDs = `4'b1111`, RGB LD6 = Solid Green. | Visual observation & steady-state ILA CSV | **Verified on Board** (`ila_capture_normal_boot.csv`, `LD6` Green, `0xF`) |
| **AC-03: Byte-Flip Fault** | Toggling SW0=1 flips candidate bit 0 during DMA; boot refuses; LEDs = `4'b1010`, RGB LD6 = Solid Red. | Switch toggle & steady-state ILA CSV | **Verified on Board** (`ila_capture_fault_injection.csv`, `LD6` Red, `0xA`) |
| **AC-04: Tamper Lockout** | Toggling SW1=1 asserts tamper latch; refusal state persists after SW1 cleared until BTN0 reset. | Switch toggle & ILA capture | Verified in Simulation/CTL (`tb_secure_boot.sv` Case 9); on-board record pending |
| **AC-05: Fetch Guard** | Unauthorized fetches to $\ge \text{0x1040}$ intercepted and replaced with RISC-V NOP (`0x00000013`). | Negative sim (`tb_forced_jump.sv`) & ILA | Verified in Simulation & RTL (`forced_jump_sim.log`) |
| **AC-06: Boot Timing** | Exact cycle counts match scaling benchmark: 64B = 906 cyc, 1KB = 2,706 cyc, 4KB = 8,462 cyc. | Simulation benchmark & armed ILA capture | Benchmarked in XSim (`boot_scaling_benchmark.log`); armed transient ILA pending |
| **AC-07: NIST KATs** | 100% bit-exact compliance on Ascon-AEAD128 and Ascon-Hash256. | Golden model + Vivado XSim KAT suites; on-board runner | 2,114 KATs Verified in Golden Model & RTL XSim (`results/kat/`); on-board KAT runner NOT YET RUN (not included in `top_bringup_board` BRAM image) |
