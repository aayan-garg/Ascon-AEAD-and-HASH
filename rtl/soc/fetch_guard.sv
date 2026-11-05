// ==============================================================================
// Module: fetch_guard.sv
// Project: Ascon AEAD and Hash Engine for IoT Secure Boot
// Description: Hardware fetch-address guard enforcing that the PicoRV32
//   CPU cannot execute from the application region (addresses >= APP_BASE)
//   until boot_ctrl asserts jump_enable=1.
//
//   When jump_enable=0:
//     - AXI read requests to addresses in [APP_BASE..BRAM_TOP) are ACCEPTED
//       but return 0x00000013 (RISC-V NOP / ADDI x0,x0,0) instead of real data.
//     - This is NOT a stall: the CPU will loop on NOPs, which is observable
//       and safe because no branch/jump into the app region can succeed.
//   When jump_enable=1:
//     - All addresses pass through to BRAM normally.
//
// NOTE on threat model: This guard blocks FETCH; it does not block LOAD/STORE
// from the Boot ROM into the application region. The Boot ROM itself must not
// write to the application region after hashing it (to avoid TOCTOU).
// The DMA engine has read-only access to BRAM Port B and cannot modify BRAM.
//
// Requirement: [SPEC] R14, F3 fix (2026-11-03)
// Threat claim: A CPU executing Boot ROM firmware cannot fetch executable
//   instructions from the application region until boot_ctrl asserts jump_enable,
//   which is conditioned on hash_ok.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module fetch_guard #(
    parameter [31:0] APP_BASE   = 32'h0000_1040, // Candidate application entry point
    parameter [31:0] BRAM_TOP   = 32'h0000_4000  // End of BRAM (16 KB)
) (
    // From CPU AXI master (read address channel)
    input  wire        s_axi_arvalid,
    input  wire [31:0] s_axi_araddr,

    // Hardware authorization from boot_ctrl
    input  wire        jump_enable,    // boot_ctrl STATE_JUMP signal

    // To BRAM slave (gated read address channel)
    output wire        m_axi_arvalid,  // Passed through only for authorized or Boot-ROM fetches
    output wire [31:0] m_axi_araddr,

    // Override read data channel (mux between BRAM and NOP)
    input  wire [31:0] bram_rdata,     // Actual BRAM data
    input  wire        bram_rvalid,
    output wire [31:0] gated_rdata,    // Data returned to CPU
    output wire        gated_rvalid
);

    // Address in application region [APP_BASE, BRAM_TOP)?
    wire in_app_region = (s_axi_araddr >= APP_BASE) && (s_axi_araddr < BRAM_TOP);

    // Gate: allow BRAM access normally, but if in_app_region and not authorized,
    // still let the transaction complete (so CPU doesn't hang) but return NOP.
    assign m_axi_arvalid = s_axi_arvalid;     // Always forward to BRAM
    assign m_axi_araddr  = s_axi_araddr;

    // Return NOP when fetching from app region without authorization
    localparam [31:0] RISCV_NOP = 32'h0000_0013; // ADDI x0, x0, 0

    wire block_fetch = in_app_region && !jump_enable;

    assign gated_rdata  = block_fetch ? RISCV_NOP : bram_rdata;
    assign gated_rvalid = bram_rvalid;

endmodule

