// ==============================================================================
// SystemVerilog Assertions (SVA) for Hardware Secure Boot Controller
// File: formal/sva/boot_ctrl_sva.sv
// Target: boot_ctrl.sv
// Proves safety invariants matching CTL properties:
//   1. AG (jump -> hash_ok)
//   2. AG (jump -> verified_before_jump)
//   3. AG (tamper_latched -> !EF jump)
//   4. AG (STATE_DECIDE & !hash_verified -> AX STATE_HALT_REFUSE)
//   5. AG (refuse -> AG refuse)
// ==============================================================================

`timescale 1ns / 1ps

module boot_ctrl_sva (
    input wire clk,
    input wire rst_n,
    input wire [3:0] state,
    input wire hash_verified,
    input wire tamper_latched,
    input wire verified_before_jump,
    input wire tamper_det,
    input wire jump_enable,
    input wire refuse,
    input wire busy
);

    localparam [3:0]
        STATE_RESET       = 4'd0,
        STATE_READ_HEADER = 4'd1,
        STATE_DMA_STREAM  = 4'd2,
        STATE_WAIT_HASH   = 4'd3,
        STATE_CHECK_TAG   = 4'd4,
        STATE_DECIDE      = 4'd5,
        STATE_JUMP        = 4'd6,
        STATE_HALT_REFUSE = 4'd7;

    // -------------------------------------------------------------------------
    // Property 1: Jump Implies Hash Verified (Matches CTLSPEC: AG (jump -> hash_ok))
    // Whenever jump_enable is active or in steady STATE_JUMP (without active tamper),
    // hash_verified must be 1'b1.
    // -------------------------------------------------------------------------
    property p_jump_implies_hash_verified;
        @(posedge clk) disable iff (!rst_n)
        (jump_enable || (state == STATE_JUMP && !tamper_det && !tamper_latched)) |-> hash_verified;
    endproperty
    assert_jump_implies_hash_verified: assert property (p_jump_implies_hash_verified)
        else $error("SVA VIOLATION: In STATE_JUMP without valid hash_verified!");

    // -------------------------------------------------------------------------
    // Property 2: Verified Before Jump Monitor Invariant
    // (Matches CTLSPEC: AG (jump -> verified_before_jump))
    // -------------------------------------------------------------------------
    property p_jump_implies_verified_before_jump;
        @(posedge clk) disable iff (!rst_n)
        (jump_enable || (state == STATE_JUMP && !tamper_det && !tamper_latched)) |-> verified_before_jump;
    endproperty
    assert_jump_implies_vbj: assert property (p_jump_implies_verified_before_jump)
        else $error("SVA VIOLATION: In STATE_JUMP without verified_before_jump!");

    // -------------------------------------------------------------------------
    // Property 3: Tamper is Sticky
    // Once tamper_latched is high, it can NEVER become low until hardware reset.
    // -------------------------------------------------------------------------
    property p_tamper_sticky;
        @(posedge clk) disable iff (!rst_n)
        tamper_latched |=> (!rst_n || tamper_latched);
    endproperty
    assert_tamper_sticky: assert property (p_tamper_sticky)
        else $error("SVA VIOLATION: tamper_latched dropped while active!");

    // -------------------------------------------------------------------------
    // Property 4: Tamper Prevents Jump
    // (Matches CTLSPEC: AG (tamper_latched -> !EF jump))
    // Once tamper_latched is set, on the next cycle and all future cycles,
    // the system MUST be in STATE_HALT_REFUSE and jump_enable must be 0.
    // -------------------------------------------------------------------------
    property p_tamper_prevents_jump;
        @(posedge clk) disable iff (!rst_n)
        tamper_latched |=> (!rst_n || (!jump_enable && (state == STATE_HALT_REFUSE)));
    endproperty
    assert_tamper_prevents_jump: assert property (p_tamper_prevents_jump)
        else $error("SVA VIOLATION: Jump asserted while tamper is latched!");

    // -------------------------------------------------------------------------
    // Property 5: Refusal is Terminal
    // (Matches CTLSPEC: AG (refuse -> AG refuse))
    // Once in STATE_HALT_REFUSE, state remains STATE_HALT_REFUSE indefinitely.
    // -------------------------------------------------------------------------
    property p_refuse_terminal;
        @(posedge clk) disable iff (!rst_n)
        (state == STATE_HALT_REFUSE) |=> (!rst_n || (state == STATE_HALT_REFUSE));
    endproperty
    assert_refuse_terminal: assert property (p_refuse_terminal)
        else $error("SVA VIOLATION: Escaped from STATE_HALT_REFUSE!");

    // -------------------------------------------------------------------------
    // Property 6: Decision Barrier Determinism
    // (Matches CTLSPEC: AG (STATE_DECIDE & !hash_verified -> AX STATE_HALT_REFUSE))
    // In STATE_DECIDE, if hash_verified is 0, next state MUST be STATE_HALT_REFUSE.
    // -------------------------------------------------------------------------
    property p_decide_failure_to_refuse;
        @(posedge clk) disable iff (!rst_n)
        (state == STATE_DECIDE && !hash_verified) |=> (!rst_n || (state == STATE_HALT_REFUSE));
    endproperty
    assert_decide_failure: assert property (p_decide_failure_to_refuse)
        else $error("SVA VIOLATION: Failed hash in DECIDE did not transition to REFUSE!");

    // -------------------------------------------------------------------------
    // Property 7: Reset Clears All Authorization
    // -------------------------------------------------------------------------
    property p_reset_state;
        @(posedge clk)
        (!rst_n) |-> (state == STATE_RESET && !jump_enable && !hash_verified && !tamper_latched);
    endproperty
    assert_reset_state: assert property (p_reset_state)
        else $error("SVA VIOLATION: Reset did not clear security flags!");

endmodule
