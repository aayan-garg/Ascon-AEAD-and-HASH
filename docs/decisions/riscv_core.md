# Decision Record: RISC-V Core Selection for SoC Integration

- **Status:** `ACCEPTED`
- **Date:** 2026-10-21
- **Deciders:** Antigravity Agent, System Architect
- **Requirement Reference:** `[SPEC]` Project_PS.md §Objective ("RV32 RISC-V processor"); `[SOURCE]` Initial Research §9; `docs/research_plan.md` R-3

---

## 1. Context and Problem Statement

`Project_PS.md` mandates that an RV32 RISC-V processor on the Digilent Zybo Z7-10 acts as the host SoC controller, orchestrating the Ascon cryptographic engine via an AXI4-Lite bus and verifying authentic firmware before execution.

The core must:
1. Run at **100 MHz** in the Zynq-7000 PL fabric (XC7Z010-1CLG400C).
2. Interface cleanly to an **AXI4-Lite** control plane without introducing protocol compliance risks.
3. Fit comfortably within the tight 17,600 LUT6 budget of the XC7Z010 alongside the Ascon engine, DMA master, and interconnect.
4. Minimize toolchain and integration friction for a time-boxed engineering implementation.

---

## 2. Candidate Comparison

We evaluated the three leading open-source RV32 cores:

| Criterion | **PicoRV32** (YosysHQ) | **VexRiscv** (SpinalHDL) | **Ibex** (lowRISC) |
|---|---|---|---|
| **ISA** | RV32I / RV32IMC | RV32I[M][C], configurable | RV32IMC (+ optional B) |
| **Native Bus Interface** | Simple valid/ready memory bus | Plugin-based memory interface | Open Bus Interface (OBI) |
| **AXI4-Lite Master** | **Native Built-in:** `picorv32_axi` and `picorv32_axi_adapter` directly in core repo | Requires full AXI4 master plugin or narrowing wrapper; not AXI4-Lite native | No built-in AXI4-Lite adapter; requires custom OBI-to-AXI bridge |
| **Source Language** | **Pure Verilog-2001** (single file `picorv32.v`) | SpinalHDL (Scala) $\rightarrow$ generated Verilog | Modern SystemVerilog (`.sv`) |
| **Toolchain Dependencies** | Standard `riscv32-unknown-elf-gcc` cross-compiler | Requires JVM, sbt, and SpinalHDL to regenerate | Requires FuseSoC and Python tooling |
| **FPGA Footprint (7-series)** | **$\approx 1,000 - 1,500$ LUTs** | $\approx 900 - 2,000$ LUTs | $\approx 1,800 - 3,500$ LUTs |
| **Verification & Precedent** | Heavily verified in hardware security literature (e.g. `rtlv` formal verification with SymbiYosys) | Widely used in LiteX / Linux-on-Litex SoCs | UVM-verified, OpenTitan silicon tape-outs |
| **Integration Complexity** | **Lowest** — Drop-in single file, native AXI4-Lite | Medium — Scala dependency or vendored generated Verilog | High — Complex bus adapter and package hierarchy |

---

## 3. Decision

1. **Primary Selection: PicoRV32 (`picorv32_axi` with `picorv32_axi_adapter`)**
   - **Rationale:** PicoRV32 is the only candidate offering a battle-tested, first-party AXI4-Lite master interface directly in its repository. Its single-file Verilog implementation eliminates external language dependencies (Scala/JVM), drastically reduces integration surface area, and consumes $< 10\%$ of the Z7-10 LUT capacity.
2. **Fallback Selection: VexRiscv (`GenSmallest` configuration)**
   - **Trigger:** If firmware bring-up requires an interactive GDB/JTAG debug bridge that proves too cumbersome to implement on PicoRV32, a pre-generated VexRiscv core with its debug plugin will be vendored as the fallback.

---

## 4. Phase 2 Bring-Up Acceptance Gate

Before any cryptographic coprocessor logic is wired to the bus in Phase 6, the chosen PicoRV32 core must pass the mandatory Phase 2 exit gate:
1. **BRAM Execution:** Execute a bare-metal RISC-V C program compiled with `riscv32-unknown-elf-gcc` from on-chip BRAM.
2. **Memory Verification:** Perform consecutive load/store operations to a scratch data memory region without stalls or corruptions.
3. **Hardware GPIO Observable:** Drive the discrete LEDs (`led[0..3]`) and RGB LED (`led6`) on the Zybo Z7-10 under firmware control.
