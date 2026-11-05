# Decision Record: Toolchain Audit and Pinned Environment Specification

- **Status:** `ACCEPTED`
- **Date:** 2026-10-21
- **Deciders:** Antigravity Agent, System Architect
- **Requirement Reference:** `[SPEC]` R6, R7, R8, R17; `docs/requirements_traceability.md` R17; `Initial Research.md` §5.6, §13, §18-F

---

## 1. Overview and Environment Audit

Every tool used for synthesis, simulation, cross-compilation, and formal verification has been audited on the host system and pinned to an exact version.

| Category | Tool | Pinned Version | Execution Environment & Path | Purpose |
|---|---|---|---|---|
| **FPGA Synthesis & P&R** | AMD-Xilinx Vivado | **v2025.1** (Build 6140274) | Windows: `C:\Xilinx\2025.1\Vivado\bin\vivado.bat` | Out-of-Context synthesis, implementation, timing STA, bitstream generation |
| **HDL Simulation** | Vivado Simulator (XSim) | **v2025.1.0** (`xvlog` / `xsim`) | Windows: `C:\Xilinx\2025.1\Vivado\bin\xvlog.bat` | IEEE-1800 SystemVerilog unit, integration, and SoC testbenches |
| **RISC-V Toolchain** | GNU RISC-V GCC | **v13.2.0** (`riscv64-unknown-elf-gcc`) | WSL2 Ubuntu: `/usr/bin/riscv64-unknown-elf-gcc` | Bare-metal RV32I compilation (`-march=rv32i -mabi=ilp32`) for PicoRV32 |
| **Formal Model Checker** | nuXmv | **v2.1.0** (Linux 64-bit) | WSL2 Ubuntu / Native | CTL model checking proving `AG(jump -> hash_ok)` |
| **Host C Compiler** | GCC (MSYS2 UCRT64) | **v15.2.0** | Windows: `C:\msys64\ucrt64\bin\gcc.exe` | Compiling official NIST KAT test harnesses and reference models |
| **Scripting & Models** | Python | **v3.14.0** | Windows: `C:\Python314\python.exe` | Golden model oracle, PLA generator, regression automation |
| **Version Control** | Git | **v2.50.0** | Windows: `C:\Program Files\Git\cmd\git.exe` | Source code and artifact configuration management |

---

## 2. Formal Verification Tooling Strategy (R-7 & R17)

### 2.1 The Mandatory Tool Distinction: nuXmv vs. SymbiYosys
`[SOURCE]` CERN REDS 2024 (*Open Source Formal Verification with SymbiYosys*) & nuXmv 2.2.0 User Manual:
- **SymbiYosys (Sby):** A bounded model checking (BMC) and k-induction framework for SystemVerilog Assertions (SVA). SVA evaluates linear-time temporal logic (LTL) safety properties along individual traces. **SymbiYosys cannot prove branching-time Computation Tree Logic (CTL) properties.**
- **nuXmv / NuSMV:** A symbolic model checker supporting binary decision diagrams (BDD) and SAT-based algorithms with native support for CTL specifications via `CTLSPEC`.
- **Decision:** **nuXmv 2.1.0** is the official toolchain for proving the mandatory safety property `AG(jump -> hash_ok)`. SymbiYosys is retained only for auxiliary internal bus interface assertions.

### 2.2 FSM Abstraction Boundary for the CTL Proof
Proving properties on an entire 320-bit cryptographic datapath in a model checker leads to state-space explosion:
- The 320-bit permutation datapath is already exhaustively proven mathematically via KATs and truth-table equivalence.
- The formal CTL proof targets the **Secure Boot Controller FSM (`boot_ctrl.sv`)**:
  - State space: Finite states (`RESET`, `READ_LEN`, `DMA_STREAM`, `WAIT_HASH`, `VERIFY_TAG`, `DECIDE`, `JUMP`, `HALT_REFUSE`).
  - Inputs: `hash_ok` (boolean indicator from Ascon comparator), `tamper_det`, `dma_done`.
  - Safety Property:
    $$\text{CTLSPEC } AG(\text{jump} \rightarrow \text{hash\_ok})$$
  - Liveness Property:
    $$\text{CTLSPEC } AG(\text{start} \rightarrow AF(\text{jump} \lor \text{refuse}))$$

---

## 3. Tool Invocation Standards

1. **Vivado Batch Mode (Synthesis & STA):**
   ```powershell
   & "C:\Xilinx\2025.1\Vivado\bin\vivado.bat" -mode batch -source scripts/synth_ascon.tcl
   ```
2. **XSim Batch Mode (Simulation):**
   ```powershell
   & "C:\Xilinx\2025.1\Vivado\bin\xvlog.bat" -sv tb/unit/tb_sbox5.sv rtl/ascon/sbox5.sv
   & "C:\Xilinx\2025.1\Vivado\bin\xelab.bat" tb_sbox5 -s tb_sbox5_sim
   & "C:\Xilinx\2025.1\Vivado\bin\xsim.bat" tb_sbox5_sim -R
   ```
3. **RISC-V Bare-Metal C Compilation:**
   ```powershell
   wsl riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -nostdlib -T firmware/linker/bootrom.ld firmware/startup/crt0.S firmware/bootrom/secure_boot.c -o firmware/bootrom/bootrom.elf
   ```
4. **nuXmv CTL Verification:**
   ```powershell
   wsl /usr/local/bin/nuXmv formal/ctl/boot_safety.smv
   ```
