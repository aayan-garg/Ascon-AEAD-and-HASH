---
name: rtl-design
description: SystemVerilog RTL design patterns for FPGA-based cryptographic accelerators targeting Xilinx 7-series (Zybo Z7-10). Use when writing or reviewing RTL for this Ascon AEAD/Hash project.
---

# RTL Design Skill — Ascon AEAD/Hash on Zybo Z7-10

## When to Use
- Writing any SystemVerilog RTL module (`rtl/` directory)
- Reviewing RTL for correctness, synthesis issues, or coding style
- Implementing cryptographic datapaths (S-box, permutation, state registers)
- Designing FSMs (mode controller, boot controller, DMA controller)
- Integrating AXI4-Lite bus interfaces

## Coding Standards

### Module Structure
```systemverilog
// File: module_name.sv
// Purpose: <one-line description>
// Author: <name>
// Date: <date>
// Dependencies: <list of modules this instantiates>
//
// [SPEC] or [REC] tag for the requirement this implements

module module_name #(
    parameter int PARAM_NAME = DEFAULT_VALUE
) (
    input  logic        clk,
    input  logic        rst,
    // Grouped by function with comments
    input  logic [N:0]  input_signal,
    output logic [M:0]  output_signal
);

    // Local parameters
    localparam int LOCAL_PARAM = VALUE;

    // Signal declarations
    logic [K:0] internal_signal;

    // Combinational logic
    always_comb begin
        // ...
    end

    // Sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            // Synchronous reset
        end else begin
            // Normal operation
        end
    end

endmodule
```

### Key Rules
1. **One module per file.** Filename = module name.
2. **`always_comb`** for combinational. **`always_ff @(posedge clk)`** for sequential.
3. **No latches** unless explicitly justified with a comment and documented in `docs/decisions/`.
4. **Synchronous active-high reset** (`rst`) by default.
5. **`snake_case`** for signals. **`UPPER_SNAKE_CASE`** for parameters.
6. **Explicit widths** on all signals — no implicit 1-bit wires.
7. **No blocking assignments** in `always_ff` blocks.
8. **No non-blocking assignments** in `always_comb` blocks.

### Cryptographic Datapath Patterns

#### S-box (5-bit, combinational)
```systemverilog
// 5 inputs → 5 outputs, pure combinational
// Verify against SP 800-232 truth table exhaustively
module sbox5 (
    input  logic [4:0] x,
    output logic [4:0] y
);
    // Boolean equations from the standard
    // MUST match the exhaustive 32-row truth table
endmodule
```

#### State Register (320-bit, 5×64-bit words)
```systemverilog
module state_reg (
    input  logic        clk, rst,
    input  logic        load_en,
    input  logic [319:0] state_in,
    output logic [319:0] state_out
);
    // Access as 5 × 64-bit words: state_out[319:256], ..., state_out[63:0]
endmodule
```

#### Permutation Round (combinational)
```systemverilog
module round_core #(
    parameter logic [7:0] ROUND_CONSTANT = 8'h00
) (
    input  logic [319:0] state_in,
    output logic [319:0] state_out
);
    // 1. Constant addition (to word 2)
    // 2. S-box layer (bit-sliced across all 64 bit positions)
    // 3. Linear diffusion (per-word rotation and XOR)
endmodule
```

### FSM Patterns
```systemverilog
typedef enum logic [2:0] {
    IDLE,
    INIT,
    ABSORB_AD,
    ABSORB_PT_CT,
    FINALIZE,
    TAG_CHECK,
    DONE,
    ERROR
} state_t;

state_t state, next_state;

always_ff @(posedge clk) begin
    if (rst) state <= IDLE;
    else     state <= next_state;
end

always_comb begin
    next_state = state; // Default: hold
    case (state)
        IDLE: if (start) next_state = INIT;
        // ...
    endcase
end
```

### AXI4-Lite Slave Pattern
- Separate read and write address/data channels
- Single-beat transactions only (no bursts)
- `AWREADY`/`WREADY` can be tied high or registered
- Illegal writes while `busy=1` → ignored + sticky error bit
- `start` is edge-triggered (self-clearing)

## Synthesis Awareness (XC7Z010)
- Target: XC7Z010-1CLG400C (35,200 logic cells, 270 KB BRAM, 80 DSP)
- Clock: 100 MHz (derived from 125 MHz via MMCM)
- Critical path awareness: 2-round chained permutation doubles combinational depth
- Use `(* keep = "true" *)` or `(* dont_touch = "true" *)` sparingly and only when pipeline register placement is critical

## Verification Checklist
Before declaring any RTL module "done":
- [ ] Module compiles with `iverilog` or `verilator --lint-only` with zero warnings
- [ ] Testbench exists in `tb/unit/tb_<module_name>.sv`
- [ ] Testbench prints `PASS` or `FAIL` and returns nonzero on failure
- [ ] If cryptographic: differential test against golden model passes
- [ ] If S-box: exhaustive truth-table test passes (all 32 inputs)
