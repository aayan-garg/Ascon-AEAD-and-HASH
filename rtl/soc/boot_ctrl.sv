// ==============================================================================
// Hardware Secure Boot Controller FSM: boot_ctrl.sv
// Target: Phase 8 Secure Boot & Boot ROM Verification
// Standard: NIST SP 800-232, Initial Research §12, §13
// Target Formal Property: AG (jump -> hash_ok)
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module boot_ctrl #(
    parameter [31:0] DEFAULT_TRUSTED_LEN = 32'd64,
    // Default trusted 256-bit digest matching provisioned 64-byte payload
    parameter [255:0] DEFAULT_TRUSTED_DIGEST = {
        32'hEDB41305, // DIGEST_7
        32'h12075573, // DIGEST_6
        32'h11B6C8A2, // DIGEST_5
        32'hAFB9E393, // DIGEST_4
        32'h7FE61055, // DIGEST_3
        32'hA2267BDC, // DIGEST_2
        32'h433A4F7B, // DIGEST_1
        32'h777BB3DF  // DIGEST_0
    }
) (
    input  wire        clk,
    input  wire        rst_n,

    // Environmental & Datapath Inputs
    input  wire        start,           // Host / CPU initiates boot verification
    input  wire        dma_done,        // DMA transfer completed
    input  wire        hash_done,       // Ascon Hash-256 calculation completed
    input  wire [255:0] ascon_digest,   // 256-bit computed digest from Ascon coprocessor
    input  wire        tamper_det,      // Physical sensor / glitch tamper pulse
    input  wire        req_jump,        // CPU requests jump authorization

    // Configuration / Override Inputs (from register interface)
    input  wire [31:0]  cfg_trusted_len,
    input  wire [255:0] cfg_trusted_digest,
    input  wire         cfg_use_custom_ref,

    // Observable Control & Safety Outputs
    output wire        jump_enable,     // Hardware permission gate for CPU jump
    output wire        refuse,          // Permanent refusal / lockout status
    output wire        busy,            // Verification actively in progress
    output wire        hash_ok,         // Hardware authenticated digest match flag
    output wire        tamper_latched,  // Sticky tamper register status
    output wire [3:0]  fsm_state,       // Diagnostic 4-bit state encoding
    output wire [3:0]  led_status       // Discrete LED pattern (4'b1111: OK, 4'b1010: REFUSE)
);

    // =========================================================================
    // 1. FSM State Definitions (matching formal/ctl/boot_safety.smv)
    // =========================================================================
    localparam [3:0]
        STATE_RESET       = 4'd0,
        STATE_READ_HEADER = 4'd1,
        STATE_DMA_STREAM  = 4'd2,
        STATE_WAIT_HASH   = 4'd3,
        STATE_CHECK_TAG   = 4'd4,
        STATE_DECIDE      = 4'd5,
        STATE_JUMP        = 4'd6,
        STATE_HALT_REFUSE = 4'd7;

    reg [3:0] state_q, state_d;
    reg       hash_verified_q, hash_verified_d;
    reg       tamper_latched_q;
    reg       verified_before_jump_q;

    // Reference digest selection
    wire [255:0] active_ref_digest = cfg_use_custom_ref ? cfg_trusted_digest : DEFAULT_TRUSTED_DIGEST;

    // =========================================================================
    // 2. Hardware 256-Bit Comparator
    // =========================================================================
    wire hash_match = (ascon_digest == active_ref_digest);

    // =========================================================================
    // 3. Sticky Tamper Register (Hardware Latch)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tamper_latched_q <= 1'b0;
        end else begin
            if (tamper_det) begin
                tamper_latched_q <= 1'b1;
            end
        end
    end

    // Monitor flag: latches high when hash_ok is valid, immediately cleared on tamper detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            verified_before_jump_q <= 1'b0;
        end else if (tamper_latched_q || tamper_det) begin
            verified_before_jump_q <= 1'b0;
        end else if (hash_verified_q) begin
            verified_before_jump_q <= 1'b1;
        end
    end

    // =========================================================================
    // 4. Next-State and Output Combinational Logic
    // =========================================================================
    always @(*) begin
        state_d         = state_q;
        hash_verified_d = hash_verified_q;

        // Sticky tamper immediately forces lockout from any state
        if (tamper_latched_q || tamper_det) begin
            state_d         = STATE_HALT_REFUSE;
            hash_verified_d = 1'b0;
        end else begin
            case (state_q)
                STATE_RESET: begin
                    hash_verified_d = 1'b0;
                    if (start) begin
                        state_d = STATE_READ_HEADER;
                    end
                end

                STATE_READ_HEADER: begin
                    // Advances to DMA streaming upon header acceptance
                    state_d = STATE_DMA_STREAM;
                end

                STATE_DMA_STREAM: begin
                    if (dma_done) begin
                        state_d = STATE_WAIT_HASH;
                    end
                end

                STATE_WAIT_HASH: begin
                    if (hash_done) begin
                        state_d = STATE_CHECK_TAG;
                    end
                end

                STATE_CHECK_TAG: begin
                    // Sample hardware comparator
                    hash_verified_d = hash_match && !(tamper_latched_q || tamper_det);
                    state_d         = STATE_DECIDE;
                end

                STATE_DECIDE: begin
                    if (hash_verified_q && !(tamper_latched_q || tamper_det)) begin
                        state_d = STATE_JUMP;
                    end else begin
                        state_d = STATE_HALT_REFUSE;
                    end
                end

                STATE_JUMP: begin
                    // Steady authorized state
                    state_d = STATE_JUMP;
                end

                STATE_HALT_REFUSE: begin
                    // Permanent sink state: cannot escape without hardware reset
                    state_d = STATE_HALT_REFUSE;
                end

                default: begin
                    state_d = STATE_HALT_REFUSE;
                end
            endcase
        end
    end

    // =========================================================================
    // 5. State Register Sequential Update
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q         <= STATE_RESET;
            hash_verified_q <= 1'b0;
        end else begin
            state_q         <= state_d;
            hash_verified_q <= hash_verified_d;
        end
    end

    // =========================================================================
    // 6. Output Assignments
    // =========================================================================
    // Jump enable is asserted IF AND ONLY IF in STATE_JUMP
    assign jump_enable    = (state_q == STATE_JUMP);
    assign refuse         = (state_q == STATE_HALT_REFUSE);
    assign busy           = (state_q != STATE_RESET) && 
                            (state_q != STATE_JUMP)  && 
                            (state_q != STATE_HALT_REFUSE);
    assign hash_ok        = hash_verified_q;
    assign tamper_latched = tamper_latched_q;
    assign fsm_state      = state_q;

    // LED Pattern:
    //   STATE_JUMP:        4'b1111 (all green / solid on)
    //   STATE_HALT_REFUSE: 4'b1010 (refusal / alternation)
    //   BUSY:              4'b0001 (in progress)
    //   RESET / IDLE:      4'b0000
    assign led_status = (state_q == STATE_JUMP)        ? 4'b1111 :
                        (state_q == STATE_HALT_REFUSE) ? 4'b1010 :
                        busy                           ? 4'b0001 : 4'b0000;

endmodule
