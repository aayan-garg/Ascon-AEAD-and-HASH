# Hardware Runbook — Ascon Secure Boot on Digilent Zybo Z7-10

> **Notice:** No on-board result has been recorded yet. This runbook defines the exact operational procedure, hardware pin mapping, and expected behaviors for physical testing on the Digilent Zybo Z7-10. Complete test module specifications and ILA waveform analyses are documented in [`docs/hardware_test_plan.md`](../../docs/hardware_test_plan.md) and [`results/board/ila_verification_report.md`](ila_verification_report.md).

- **Target Board:** Digilent Zybo Z7-10 (AMD-Xilinx Zynq-7000 XC7Z010-1CLG400C)
- **Top-Level Module:** `rtl/soc/top_bringup_board.sv`
- **Constraints File:** `board/zybo_z7_10.xdc`
- **Bitstream Target:** `build/top_bringup.bit` (or ILA debug bitstream: `build/top_bringup_ila.bit`)
- **Synthesized Default Firmware:** `firmware/tests/boot_matrix/bram_case1_valid.hex`
- **Clock:** 125 MHz on-board oscillator (pin K17) → MMCM → 100 MHz system clock
- **Primary Reset:** BTN0 (pin K18, Active-High) → Inverted and synchronized to 100 MHz clock domain
- **Hardware Test Plan:** [`docs/hardware_test_plan.md`](../../docs/hardware_test_plan.md)
- **ILA Verification Report:** [`results/board/ila_verification_report.md`](ila_verification_report.md)

---

## 1. Hardware Pin & Switch Mapping Reference

Derived directly from `rtl/soc/top_bringup_board.sv`, `rtl/soc/top_bringup.sv`, and `board/zybo_z7_10.xdc`:

| Interface Element | Pin | Direction | Signal in RTL | Hardware Function / Semantic |
|---|:---:|:---:|---|---|
| **Ethernet PHY Clock** | `K17` | Input | `clk_125mhz` | 125.0 MHz primary oscillator input to MMCM |
| **Push Button 0** | `K18` | Input | `rst_btn` | Active-High manual reset (BTN0 pressed = reset asserted) |
| **Slide Switch 0** | `G15` | Input | `sw[0]` | **Live DMA Byte-Flip Fault Injection:** When `SW0 = 1`, inverts bit 0 of word `0x410` during DMA payload read |
| **Slide Switch 1** | `P15` | Input | `sw[1]` | **Live Hardware Tamper Sensor:** When `SW1 = 1`, asserts physical `tamper_det` input to `boot_ctrl.sv` |
| **Slide Switch 2** | `W13` | Input | `sw[2]` | User input (read by soft-core via AXI-Lite GPIO) |
| **Slide Switch 3** | `T16` | Input | `sw[3]` | User input (read by soft-core via AXI-Lite GPIO) |
| **Discrete LED 0** | `M14` | Output | `led[0]` | Boot status (LD0): ON during verification; ON when boot passes |
| **Discrete LED 1** | `M15` | Output | `led[1]` | Error indicator (LD1): ON during refusal (`4'b1010`) |
| **Discrete LED 2** | `G14` | Output | `led[2]` | Busy indicator (LD2): ON when boot passes (`4'b1111`) |
| **Discrete LED 3** | `D18` | Output | `led[3]` | CPU alive indicator (LD3): ON during refusal and boot pass |
| **RGB LED LD6 Red** | `V16` | Output | `led6_r` / `rgb_led[0]` | **Solid RED:** Refusal Lockout (`boot_refuse == 1`) |
| **RGB LED LD6 Green**| `F17` | Output | `led6_g` / `rgb_led[1]` | **Solid GREEN:** Boot Successful & Verified (`boot_jump_enable == 1`) |
| **RGB LED LD6 Blue** | `M17` | Output | `led6_b` / `rgb_led[2]` | **Solid BLUE:** Verification / DMA Hash in Progress |

---

## 2. Step-by-Step Hardware Execution Procedure

Follow these steps in exact order when performing on-board testing:

### Step 1: Build the Physical Bitstream
Generate the complete FPGA bitstream from clean source files:
```bash
# In Vivado TCL console or terminal:
vivado.exe -mode batch -nojournal -log build/vivado_bringup.log -source scripts/build_bitstream.tcl
```
- **Top wrapper:** `top_bringup_board`
- **Synthesized firmware:** `firmware/tests/boot_matrix/bram_case1_valid.hex` (valid untampered image)
- **Clock frequency:** 100.0 MHz ($WNS \ge 0$, routed $WNS = +1.510$ ns)

### Step 2: Record Bitstream SHA256 Checksum
Verify bitstream cryptographic integrity before flashing:
```powershell
Get-FileHash -Algorithm SHA256 build/top_bringup.bit
# Expected SHA256: 79cef83aa8ec05081a92359999da7ca5b3f13d77ae5bee70073c39f3b8862c86
```

### Step 3: Connect and Program the Zybo Z7-10 Board
1. Connect Micro-USB cable from host PC to Zybo Z7-10 PROG/UART port (J12).
2. Set power select jumper **JP6** to `USB` (or `WALL` if using 5V external power).
3. Set programming mode jumper **JP5** to `JTAG`.
4. Slide power switch **SW4** to `ON` (red power LED lights up).
5. Program the bitstream via batch script or Vivado GUI:
   - **Command-line:** Run `scripts\program_board.bat` or:
     ```bash
     vivado.exe -mode batch -nojournal -nolog -source scripts/program_board.tcl
     ```
   - **Vivado Hardware Manager GUI:** Flow → Open Hardware Manager → Auto Connect → Program Device (`build/top_bringup.bit`).

### Step 4: Normal Boot Validation (Valid Untampered Image)
1. Ensure all switches are set LOW: `SW0 = 0`, `SW1 = 0`, `SW2 = 0`, `SW3 = 0`.
2. Press and release **BTN0** (Reset).
3. **Observed Behavior:**
   - **Transient phase (<10 µs):** RGB LED LD6 flashes solid **BLUE** (`3'b100`) while the Boot ROM initiates DMA and the Ascon-Hash256 core computes the image digest.
   - **Steady-state phase:** RGB LED LD6 illuminates solid **GREEN** (`3'b010`), and all four discrete LEDs LD0..LD3 illuminate solid ON (**`4'b1111`**, `0xF`).
   - **Verdict:** **BOOT OK**. Hardware verified the NIST SP 800-232 digest and granted CPU execution into application code.

### Step 5: Live Fault Injection — DMA Byte-Flip Demo (SW0 = HIGH)
Demonstrate primary project requirement (`Project_PS.md` deliverable: "Demo: good image boots; flipping one byte via a switch makes the boot refuse"):
1. Slide **SW0 to HIGH (1)** (turns on hardware-level XOR bit-inversion during DMA payload reads).
2. Press and release **BTN0** (Reset) to initiate boot with corrupted stream.
3. **Observed Behavior:**
   - RGB LED LD6 illuminates solid **RED** (`3'b001`).
   - Discrete LEDs LD0..LD3 display alternating refusal pattern: **`4'b1010`** (LD3 ON, LD2 OFF, LD1 ON, LD0 OFF).
   - Application execution is suppressed; `fetch_guard` intercepts instruction fetches.
   - **Verdict:** **BOOT REFUSED (Tampered Payload Detected)**.
4. **Recovery Check:**
   - Slide **SW0 back to LOW (0)**.
   - Press **BTN0**.
   - System immediately recovers to solid **GREEN** + **`4'b1111`**.

### Step 6: Live Fault Injection — Hardware Tamper Sensor Demo (SW1 = HIGH)
Demonstrate hardware security sensor trip:
1. Slide **SW1 to HIGH (1)** while system is running, or before reset.
2. **Observed Behavior:**
   - RGB LED LD6 immediately switches to solid **RED** (`3'b001`).
   - Discrete LEDs LD0..LD3 display **`4'b1010`**.
3. **Sticky Latch Verification:**
   - Slide **SW1 back to LOW (0)**.
   - Observe that refusal state persists (RED + `4'b1010` remains locked).
   - Press **BTN0** (Reset) to clear sticky tamper register and restore normal boot.

### Step 7: What to Record During Board Testing
For physical evidence submission, record:
1. **Photographs / Video:**
   - Setup photograph showing Zybo Z7-10 with power and JTAG cables connected.
   - Video demonstrating the 3-state transition: Normal Boot (Green + 0xF) → SW0 flipped (Red + 0xA) → Reset back to Normal (Green + 0xF).
2. **Boot Latency Measurement:**
   - Connect an oscilloscope or logic analyzer probe to test point / PMOD pin if routed, or capture a high-framerate phone video (e.g. 240 fps) of the reset release to Green LED transition.
   - Compare measured physical latency against exact simulation benchmarks below.
3. **UART Output:**
   - UART console output via micro-USB COM port (115200 baud, 8-N-1): `[TO BE CONFIRMED ON BOARD]` (Soft-UART output depends on optional firmware print routines).

---

## 3. Simulated Reference Latencies for Hardware Comparison

Exact cycle-accurate simulation figures obtained from `results/board/boot_matrix/boot_scaling_benchmark.log` and `results/board/boot_matrix/boot_timing_sim.log` (100.0 MHz, 10.0 ns/cycle):

| Metric | 64-Byte Payload (Default Image) | 1,024-Byte (1 KB) Payload | 4,096-Byte (4 KB) Payload |
|---|:---:|:---:|:---:|
| **Reset Release $\rightarrow$ `jump_enable`** | **906 cycles (9.06 µs)** | 2,706 cycles (27.06 µs) | 8,462 cycles (84.62 µs) |
| **Reset Release $\rightarrow$ `test_pass`** | **1,342 cycles (13.42 µs)** | 3,155 cycles (31.55 µs) | 8,933 cycles (89.33 µs) |
| **Hardware Refusal Latency (SW0/SW1)** | **< 1,000 cycles (< 10.0 µs)** | < 3,000 cycles (< 30.0 µs) | < 9,000 cycles (< 90.0 µs) |

---

## 4. Complete 9-Case Boot Matrix Evaluation & On-Board Testability

Every boot scenario from `tb_secure_boot.sv` is mapped below, indicating whether it can be evaluated dynamically on the physical board with switches, or requires synthesizing a different firmware hex image:

| Case | Scenario Tested | Stimulus / Fault Mechanism | Hardware LED (`led[3:0]`) | RGB LED (`LD6`) | Expected Outcome | On-Board Test Method |
|:---:|:---|:---|:---:|:---:|:---:|:---|
| **1** | Valid Untampered Firmware | Authentic image + matching digest | `4'b1111` | **GREEN** | **BOOT OK** | Tested directly with default bitstream (`SW[3:0]=0`). |
| **2** | Byte-Flipped Payload | 1-bit corrupted in payload | `4'b1010` | **RED** | **BOOT REFUSED** | **Testable via switch:** Slide `SW0 = 1`. Alternatively, re-synthesize with `bram_case2_flipped.hex`. |
| **3** | Wrong Reference Digest | Header altered with invalid expected digest | `4'b1010` | **RED** | **BOOT REFUSED** | Re-synthesis required: build bitstream with `bram_case3_wrong_digest.hex`. |
| **4** | Invalid Declared Length | Header declares 0-byte payload length | `4'b1010` | **RED** | **BOOT REFUSED** | Re-synthesis required: build bitstream with `bram_case4_invalid_len.hex`. |
| **5** | Malformed Header Magic | Header magic corrupted (`0xDEADBEEF`) | `4'b1010` | **RED** | **BOOT REFUSED** | Re-synthesis required: build bitstream with `bram_case5_bad_magic.hex`. |
| **6** | Injected DMA Stream Error | DMA stream bus fault injected | `4'b1010` | **RED** | **BOOT REFUSED** | Simulation harness injection (`tb_secure_boot.sv`). |
| **7** | Injected Accelerator Error | Accelerator error signal asserted mid-hash | `4'b1010` | **RED** | **BOOT REFUSED** | Simulation harness injection (`tb_secure_boot.sv`). |
| **8** | Reset Mid-Verification | BTN0 asserted while Blue LED is active | `4'b0000` | **OFF** | **SAFE RESTART** | **Testable via button:** Press BTN0 mid-boot; verify system re-initializes cleanly without hang. |
| **9** | Tamper Sensor Lockout | External tamper line triggered | `4'b1010` | **RED** | **STICKY REFUSAL** | **Testable via switch:** Slide `SW1 = 1`, return to `0`, confirm lockout remains until BTN0 reset. |
