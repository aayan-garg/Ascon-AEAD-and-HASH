// ==============================================================================
// Module: mode_ctrl.sv
// Project: Ascon AEAD and Hash Engine (NIST SP 800-232)
// Description: Master Mode Controller & Sponge FSM for Ascon-AEAD128 and Ascon-Hash256.
//
// Features:
//   - Compliant with NIST SP 800-232 (Little-Endian, revised IVs)
//   - Unified sponge datapath shared with permutation_1r (1 round/cycle)
//   - AEAD128 encryption & decryption with 128-bit rate (words S0, S1)
//   - Hash256 message hashing with 64-bit rate (word S0) and 256-bit squeeze
//   - Integrated hardware plaintext release gate (plaintext_gate.sv)
//   - Constant-time 128-bit authentication tag verification
//   - Clean perm_running synchronization preventing stale handshakes
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module mode_ctrl #(
    parameter int BUFFER_DEPTH = 256,
    // [F5 FIX] PERM_VARIANT selects which permutation core is instantiated [SPEC]:
    //   0 = permutation_half  (0.5 round/cycle, 2 cycles/round — lowest area)
    //   1 = permutation_1r   (1 round/cycle — baseline, DEFAULT)
    //   2 = permutation_2r   (2 rounds/cycle — highest throughput)
    //   3 = permutation_serial32 (32-bit datapath, 2 cycles/round — paper design point)
    parameter int PERM_VARIANT = 1,
    parameter string SBOX_TYPE = "BASELINE"  // Passed to permutation_1r only
) (
    input  wire         clk,
    input  wire         rst_n,

    // Command & Configuration
    input  wire         start,
    input  wire         soft_rst,
    input  wire         mode,         // 0 = Ascon-AEAD128, 1 = Ascon-Hash256
    input  wire         decrypt,      // 0 = Encrypt/Hash, 1 = Decrypt
    input  wire [ 31:0] ad_len,       // Associated data length in bytes (AEAD only)
    input  wire [ 31:0] msg_len,      // Message / Plaintext / Ciphertext length in bytes
    input  wire [127:0] key,          // 128-bit key {K1, K0}
    input  wire [127:0] nonce,        // 128-bit nonce {N1, N0}
    input  wire [127:0] expected_tag, // 128-bit expected tag for decryption

    // Data Streaming Input
    input  wire [ 63:0] data_in,
    input  wire         data_in_valid,
    output reg          data_in_ready,

    // Data Streaming Output (Ciphertext)
    output reg  [ 63:0] data_out,
    output reg          data_out_valid,
    input  wire         data_out_ready,

    // Plaintext Gate Read Interface (Decrypted Plaintext)
    input  wire [  7:0] pt_gate_rd_addr,
    output wire [ 63:0] pt_gate_rd_data,
    output wire         pt_gate_rd_valid,

    // Status & Results
    output reg          busy,
    output reg          done,
    output reg          error,
    output reg          tag_ok,
    output wire [127:0] tag_out,      // {T1, T0}
    output wire [255:0] digest_out,   // {H3, H2, H1, H0}
    output wire [  3:0] fsm_state_code
);

    // -------------------------------------------------------------------------
    // NIST SP 800-232 Constants & Initialization Vectors (Little-Endian)
    // -------------------------------------------------------------------------
    localparam [63:0] IV_AEAD128 = 64'h00001000808c0001;
    localparam [63:0] IV_HASH256 = 64'h0000080100cc0002;

    // -------------------------------------------------------------------------
    // Helper function for 64-bit Little-Endian padding
    // -------------------------------------------------------------------------
    function automatic [63:0] pad_word64(input [63:0] raw_data, input [2:0] rem);
        logic [63:0] mask;
        logic [63:0] pad_bit;
        begin
            case (rem)
                3'd0: mask = 64'h00000000_00000000;
                3'd1: mask = 64'h00000000_000000FF;
                3'd2: mask = 64'h00000000_0000FFFF;
                3'd3: mask = 64'h00000000_00FFFFFF;
                3'd4: mask = 64'h00000000_FFFFFFFF;
                3'd5: mask = 64'h000000FF_FFFFFFFF;
                3'd6: mask = 64'h0000FFFF_FFFFFFFF;
                3'd7: mask = 64'h00FFFFFF_FFFFFFFF;
            endcase
            pad_bit = 64'h01 << (rem * 8);
            pad_word64 = (raw_data & mask) | pad_bit;
        end
    endfunction

    function automatic [63:0] mask_word64(input [63:0] raw_data, input [2:0] rem);
        begin
            case (rem)
                3'd0: mask_word64 = 64'h0;
                3'd1: mask_word64 = raw_data & 64'h00000000_000000FF;
                3'd2: mask_word64 = raw_data & 64'h00000000_0000FFFF;
                3'd3: mask_word64 = raw_data & 64'h00000000_00FFFFFF;
                3'd4: mask_word64 = raw_data & 64'h00000000_FFFFFFFF;
                3'd5: mask_word64 = raw_data & 64'h000000FF_FFFFFFFF;
                3'd6: mask_word64 = raw_data & 64'h0000FFFF_FFFFFFFF;
                3'd7: mask_word64 = raw_data & 64'h00FFFFFF_FFFFFFFF;
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // FSM State Encoding
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE          = 4'd0,
        ST_INIT          = 4'd1,
        ST_ABSORB_AD     = 4'd2,
        ST_AD_PAD_BLOCK  = 4'd3,
        ST_DOMAIN_SEP    = 4'd4,
        ST_ABSORB_MSG    = 4'd5,
        ST_MSG_PAD_BLOCK = 4'd6,
        ST_FINALIZE      = 4'd7,
        ST_TAG_CHECK     = 4'd8,
        ST_SQUEEZE       = 4'd9,
        ST_DONE          = 4'd10,
        ST_ERROR         = 4'd11
    } state_t;

    state_t state_reg;

    assign fsm_state_code = (state_reg == ST_IDLE)         ? 4'd0 :
                            (state_reg == ST_INIT)         ? 4'd1 :
                            (state_reg == ST_ABSORB_AD || state_reg == ST_AD_PAD_BLOCK) ? 4'd2 :
                            (state_reg == ST_ABSORB_MSG || state_reg == ST_MSG_PAD_BLOCK || state_reg == ST_SQUEEZE || state_reg == ST_DOMAIN_SEP) ? 4'd3 :
                            (state_reg == ST_FINALIZE)     ? 4'd4 :
                            (state_reg == ST_TAG_CHECK)    ? 4'd5 :
                            (state_reg == ST_DONE)         ? 4'd6 : 4'd7;

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    reg [63:0] s0, s1, s2, s3, s4;
    reg [63:0] r_k0, r_k1;
    reg [63:0] r_n0, r_n1;
    reg [63:0] r_expected_t0, r_expected_t1;
    reg [31:0] r_bytes_left;
    reg [31:0] r_ad_len, r_msg_len;
    reg        r_mode;
    reg        r_decrypt;

    reg [63:0] r_w0_buf;
    reg        r_beat;
    reg [ 2:0] r_squeeze_step;

    reg [127:0] r_tag;
    reg [255:0] r_digest;

    // Plaintext Gate Controls
    reg        gate_wr_clear;
    reg        gate_wr_en;
    reg [ 7:0] gate_wr_addr;
    reg [63:0] gate_wr_data;
    reg        gate_auth_fail;

    // Permutation Datapath Controls & Connections
    reg         perm_start;
    reg         perm_running;
    reg  [ 3:0] perm_rounds;
    wire        perm_ready;
    wire        perm_done;
    reg  [63:0] perm_in_x0, perm_in_x1, perm_in_x2, perm_in_x3, perm_in_x4;
    wire [63:0] perm_out_x0, perm_out_x1, perm_out_x2, perm_out_x3, perm_out_x4;

    // [F5 FIX] Generate-based permutation core selection [SPEC]
    // Default (PERM_VARIANT=1) preserves existing 1r behaviour; no functional change to mode FSM.
    generate
        if (PERM_VARIANT == 0) begin : gen_perm_half
            permutation_half u_perm (
                .clk    (clk),
                .rst_n  (rst_n),
                .start  (perm_start),
                .rounds (perm_rounds),
                .ready  (perm_ready),
                .done   (perm_done),
                .in_x0  (perm_in_x0), .in_x1 (perm_in_x1), .in_x2 (perm_in_x2),
                .in_x3  (perm_in_x3), .in_x4 (perm_in_x4),
                .out_x0 (perm_out_x0), .out_x1 (perm_out_x1), .out_x2 (perm_out_x2),
                .out_x3 (perm_out_x3), .out_x4 (perm_out_x4)
            );
        end else if (PERM_VARIANT == 2) begin : gen_perm_2r
            permutation_2r u_perm (
                .clk    (clk),
                .rst_n  (rst_n),
                .start  (perm_start),
                .rounds (perm_rounds),
                .ready  (perm_ready),
                .done   (perm_done),
                .in_x0  (perm_in_x0), .in_x1 (perm_in_x1), .in_x2 (perm_in_x2),
                .in_x3  (perm_in_x3), .in_x4 (perm_in_x4),
                .out_x0 (perm_out_x0), .out_x1 (perm_out_x1), .out_x2 (perm_out_x2),
                .out_x3 (perm_out_x3), .out_x4 (perm_out_x4)
            );
        end else if (PERM_VARIANT == 3) begin : gen_perm_serial32
            permutation_serial32 u_perm (
                .clk    (clk),
                .rst_n  (rst_n),
                .start  (perm_start),
                .rounds (perm_rounds),
                .ready  (perm_ready),
                .done   (perm_done),
                .in_x0  (perm_in_x0), .in_x1 (perm_in_x1), .in_x2 (perm_in_x2),
                .in_x3  (perm_in_x3), .in_x4 (perm_in_x4),
                .out_x0 (perm_out_x0), .out_x1 (perm_out_x1), .out_x2 (perm_out_x2),
                .out_x3 (perm_out_x3), .out_x4 (perm_out_x4)
            );
        end else begin : gen_perm_1r  // PERM_VARIANT == 1 (default)
            permutation_1r #(.SBOX_TYPE(SBOX_TYPE)) u_perm (
                .clk    (clk),
                .rst_n  (rst_n),
                .start  (perm_start),
                .rounds (perm_rounds),
                .ready  (perm_ready),
                .done   (perm_done),
                .in_x0  (perm_in_x0), .in_x1 (perm_in_x1), .in_x2 (perm_in_x2),
                .in_x3  (perm_in_x3), .in_x4 (perm_in_x4),
                .out_x0 (perm_out_x0), .out_x1 (perm_out_x1), .out_x2 (perm_out_x2),
                .out_x3 (perm_out_x3), .out_x4 (perm_out_x4)
            );
        end
    endgenerate

    plaintext_gate #(.BUFFER_DEPTH(BUFFER_DEPTH)) u_pt_gate (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_clear  (gate_wr_clear),
        .wr_en     (gate_wr_en),
        .wr_addr   (gate_wr_addr),
        .wr_data   (gate_wr_data),
        .tag_ok    (tag_ok),
        .auth_fail (gate_auth_fail),
        .rd_addr   (pt_gate_rd_addr),
        .rd_data   (pt_gate_rd_data),
        .rd_valid  (pt_gate_rd_valid)
    );

    // Outputs
    assign tag_out    = r_tag;
    assign digest_out = r_digest;

    // -------------------------------------------------------------------------
    // Main FSM Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg       <= ST_IDLE;
            busy            <= 1'b0;
            done            <= 1'b0;
            error           <= 1'b0;
            tag_ok          <= 1'b0;
            data_in_ready   <= 1'b0;
            data_out_valid  <= 1'b0;
            data_out        <= 64'h0;
            perm_start      <= 1'b0;
            perm_running    <= 1'b0;
            perm_rounds     <= 4'd12;
            perm_in_x0      <= 64'h0;
            perm_in_x1      <= 64'h0;
            perm_in_x2      <= 64'h0;
            perm_in_x3      <= 64'h0;
            perm_in_x4      <= 64'h0;
            s0              <= 64'h0;
            s1              <= 64'h0;
            s2              <= 64'h0;
            s3              <= 64'h0;
            s4              <= 64'h0;
            r_k0            <= 64'h0;
            r_k1            <= 64'h0;
            r_n0            <= 64'h0;
            r_n1            <= 64'h0;
            r_expected_t0   <= 64'h0;
            r_expected_t1   <= 64'h0;
            r_bytes_left    <= 32'd0;
            r_ad_len        <= 32'd0;
            r_msg_len       <= 32'd0;
            r_mode          <= 1'b0;
            r_decrypt       <= 1'b0;
            r_w0_buf        <= 64'h0;
            r_beat          <= 1'b0;
            r_squeeze_step  <= 2'd0;
            r_tag           <= 128'h0;
            r_digest        <= 256'h0;
            gate_wr_clear   <= 1'b0;
            gate_wr_en      <= 1'b0;
            gate_wr_addr    <= 8'd0;
            gate_wr_data    <= 64'h0;
            gate_auth_fail  <= 1'b0;
        end else if (soft_rst) begin
            state_reg       <= ST_IDLE;
            busy            <= 1'b0;
            done            <= 1'b0;
            error           <= 1'b0;
            tag_ok          <= 1'b0;
            data_in_ready   <= 1'b0;
            data_out_valid  <= 1'b0;
            perm_start      <= 1'b0;
            perm_running    <= 1'b0;
            gate_wr_clear   <= 1'b1;
            gate_wr_en      <= 1'b0;
            gate_auth_fail  <= 1'b1;
        end else begin
            perm_start      <= 1'b0;
            gate_wr_clear   <= 1'b0;
            gate_wr_en      <= 1'b0;
            gate_auth_fail  <= 1'b0;

            if (gate_wr_clear) begin
                gate_wr_addr <= 8'd0;
            end else if (gate_wr_en) begin
                gate_wr_addr <= gate_wr_addr + 1'b1;
            end

            case (state_reg)
                // -------------------------------------------------------------
                // IDLE: Await launch command
                // -------------------------------------------------------------
                ST_IDLE: begin
                    data_in_ready  <= 1'b0;
                    data_out_valid <= 1'b0;
                    perm_running   <= 1'b0;

                    if (start) begin
                        busy            <= 1'b1;
                        done            <= 1'b0;
                        error           <= 1'b0;
                        tag_ok          <= 1'b0;
                        r_mode          <= mode;
                        r_decrypt       <= decrypt;
                        r_ad_len        <= ad_len;
                        r_msg_len       <= msg_len;
                        r_k0            <= key[63:0];
                        r_k1            <= key[127:64];
                        r_n0            <= nonce[63:0];
                        r_n1            <= nonce[127:64];
                        r_expected_t0   <= expected_tag[63:0];
                        r_expected_t1   <= expected_tag[127:64];
                        gate_wr_clear   <= 1'b1;
                        gate_wr_addr    <= 8'd0;
                        r_digest        <= 256'h0;

                        if (mode == 1'b0) begin
                            // Ascon-AEAD128 Initialization
                            perm_in_x0   <= IV_AEAD128;
                            perm_in_x1   <= key[63:0];
                            perm_in_x2   <= key[127:64];
                            perm_in_x3   <= nonce[63:0];
                            perm_in_x4   <= nonce[127:64];
                            perm_rounds  <= 4'd12;
                            perm_start   <= 1'b1;
                            perm_running <= 1'b1;
                            state_reg    <= ST_INIT;
                        end else begin
                            // Ascon-Hash256 Initialization
                            perm_in_x0   <= IV_HASH256;
                            perm_in_x1   <= 64'h0;
                            perm_in_x2   <= 64'h0;
                            perm_in_x3   <= 64'h0;
                            perm_in_x4   <= 64'h0;
                            perm_rounds  <= 4'd12;
                            perm_start   <= 1'b1;
                            perm_running <= 1'b1;
                            state_reg    <= ST_INIT;
                        end
                    end
                end

                // -------------------------------------------------------------
                // INIT: 12-round permutation execution
                // -------------------------------------------------------------
                ST_INIT: begin
                    if (perm_done && perm_running) begin
                        perm_running <= 1'b0;
                        if (r_mode == 1'b0) begin
                            // AEAD Key addition: S3 ^= K0, S4 ^= K1
                            s0 <= perm_out_x0;
                            s1 <= perm_out_x1;
                            s2 <= perm_out_x2;
                            s3 <= perm_out_x3 ^ r_k0;
                            s4 <= perm_out_x4 ^ r_k1;

                            if (r_ad_len > 0) begin
                                r_bytes_left  <= r_ad_len;
                                r_beat        <= 1'b0;
                                data_in_ready <= 1'b1;
                                state_reg     <= ST_ABSORB_AD;
                            end else begin
                                state_reg     <= ST_DOMAIN_SEP;
                            end
                        end else begin
                            // Hash initialization done
                            s0 <= perm_out_x0;
                            s1 <= perm_out_x1;
                            s2 <= perm_out_x2;
                            s3 <= perm_out_x3;
                            s4 <= perm_out_x4;

                            r_bytes_left  <= r_msg_len;
                            if (r_msg_len > 0) begin
                                data_in_ready <= 1'b1;
                                state_reg     <= ST_ABSORB_MSG;
                            end else begin
                                // 0-byte message -> standalone padding block
                                state_reg     <= ST_MSG_PAD_BLOCK;
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // ABSORB_AD: Absorb Associated Data (16-byte rate)
                // -------------------------------------------------------------
                ST_ABSORB_AD: begin
                    if (perm_done && perm_running) begin
                        perm_running <= 1'b0;
                        s0 <= perm_out_x0;
                        s1 <= perm_out_x1;
                        s2 <= perm_out_x2;
                        s3 <= perm_out_x3;
                        s4 <= perm_out_x4;

                        if (r_bytes_left == 0) begin
                            if (r_ad_len[3:0] == 4'd0) begin
                                state_reg <= ST_AD_PAD_BLOCK;
                            end else begin
                                state_reg <= ST_DOMAIN_SEP;
                            end
                        end else begin
                            data_in_ready <= 1'b1;
                        end
                    end else if (data_in_valid && data_in_ready) begin
                        if (r_beat == 1'b0) begin
                            // Beat 0
                            r_w0_buf <= data_in;
                            if (r_bytes_left > 8) begin
                                r_bytes_left <= r_bytes_left - 8;
                                r_beat       <= 1'b1;
                            end else begin
                                data_in_ready <= 1'b0;
                                perm_in_x0    <= s0 ^ pad_word64(data_in, r_bytes_left[2:0]);
                                perm_in_x1    <= s1;
                                perm_in_x2    <= s2;
                                perm_in_x3    <= s3;
                                perm_in_x4    <= s4;
                                perm_rounds   <= 4'd8;
                                perm_start    <= 1'b1;
                                perm_running  <= 1'b1;
                                r_bytes_left  <= 32'd0;
                            end
                        end else begin
                            // Beat 1
                            data_in_ready <= 1'b0;
                            r_beat        <= 1'b0;
                            if (r_bytes_left >= 8) begin
                                perm_in_x0   <= s0 ^ r_w0_buf;
                                perm_in_x1   <= s1 ^ data_in;
                                perm_in_x2   <= s2;
                                perm_in_x3   <= s3;
                                perm_in_x4   <= s4;
                                perm_rounds  <= 4'd8;
                                perm_start   <= 1'b1;
                                perm_running <= 1'b1;
                                r_bytes_left <= r_bytes_left - 8;
                            end else begin
                                perm_in_x0   <= s0 ^ r_w0_buf;
                                perm_in_x1   <= s1 ^ pad_word64(data_in, r_bytes_left[2:0]);
                                perm_in_x2   <= s2;
                                perm_in_x3   <= s3;
                                perm_in_x4   <= s4;
                                perm_rounds  <= 4'd8;
                                perm_start   <= 1'b1;
                                perm_running <= 1'b1;
                                r_bytes_left <= 32'd0;
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // AD_PAD_BLOCK: Standalone padding block when ad_len % 16 == 0
                // -------------------------------------------------------------
                ST_AD_PAD_BLOCK: begin
                    if (perm_done && perm_running) begin
                        perm_running <= 1'b0;
                        s0 <= perm_out_x0;
                        s1 <= perm_out_x1;
                        s2 <= perm_out_x2;
                        s3 <= perm_out_x3;
                        s4 <= perm_out_x4;
                        state_reg <= ST_DOMAIN_SEP;
                    end else if (!perm_running) begin
                        perm_in_x0   <= s0 ^ 64'h00000000_00000001;
                        perm_in_x1   <= s1;
                        perm_in_x2   <= s2;
                        perm_in_x3   <= s3;
                        perm_in_x4   <= s4;
                        perm_rounds  <= 4'd8;
                        perm_start   <= 1'b1;
                        perm_running <= 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // DOMAIN_SEP: 1-bit domain separation into S4[63]
                // -------------------------------------------------------------
                ST_DOMAIN_SEP: begin
                    s4 <= s4 ^ 64'h80000000_00000000;
                    r_bytes_left <= r_msg_len;
                    r_beat       <= 1'b0;

                    if (r_msg_len > 0) begin
                        data_in_ready <= 1'b1;
                        state_reg     <= ST_ABSORB_MSG;
                    end else begin
                        state_reg     <= ST_MSG_PAD_BLOCK;
                    end
                end

                // -------------------------------------------------------------
                // ABSORB_MSG: Message / Plaintext / Ciphertext Absorption
                // -------------------------------------------------------------
                ST_ABSORB_MSG: begin
                    if (data_out_valid && data_out_ready) begin
                        data_out_valid <= 1'b0;
                    end

                    if (perm_done && perm_running) begin
                        perm_running <= 1'b0;
                        s0 <= perm_out_x0;
                        s1 <= perm_out_x1;
                        s2 <= perm_out_x2;
                        s3 <= perm_out_x3;
                        s4 <= perm_out_x4;

                        if (r_mode == 1'b1) begin
                            // Hash Mode
                            if (r_bytes_left == 0) begin
                                if (r_msg_len[2:0] == 3'd0) begin
                                    state_reg <= ST_MSG_PAD_BLOCK;
                                end else begin
                                    r_squeeze_step <= 2'd0;
                                    state_reg      <= ST_SQUEEZE;
                                end
                            end else begin
                                data_in_ready <= 1'b1;
                            end
                        end else begin
                            // AEAD Mode
                            if (r_bytes_left == 0) begin
                                if (r_msg_len[3:0] == 4'd0) begin
                                    state_reg <= ST_MSG_PAD_BLOCK;
                                end else begin
                                    state_reg <= ST_FINALIZE;
                                end
                            end else begin
                                data_in_ready <= 1'b1;
                            end
                        end
                    end else if (data_in_valid && data_in_ready) begin
                        if (r_mode == 1'b1) begin
                            // Hash Mode
                            data_in_ready <= 1'b0;
                            if (r_bytes_left >= 8) begin
                                perm_in_x0   <= s0 ^ data_in;
                                perm_in_x1   <= s1;
                                perm_in_x2   <= s2;
                                perm_in_x3   <= s3;
                                perm_in_x4   <= s4;
                                perm_rounds  <= 4'd12;
                                perm_start   <= 1'b1;
                                perm_running <= 1'b1;
                                r_bytes_left <= r_bytes_left - 8;
                            end else begin
                                perm_in_x0   <= s0 ^ pad_word64(data_in, r_bytes_left[2:0]);
                                perm_in_x1   <= s1;
                                perm_in_x2   <= s2;
                                perm_in_x3   <= s3;
                                perm_in_x4   <= s4;
                                perm_rounds  <= 4'd12;
                                perm_start   <= 1'b1;
                                perm_running <= 1'b1;
                                r_bytes_left <= 32'd0;
                            end
                        end else begin
                            // AEAD Mode
                            if (r_beat == 1'b0) begin
                                if (r_bytes_left > 8) begin
                                    r_bytes_left <= r_bytes_left - 8;
                                    r_beat       <= 1'b1;
                                    if (!r_decrypt) begin
                                        data_out       <= s0 ^ data_in;
                                        data_out_valid <= 1'b1;
                                        r_w0_buf       <= s0 ^ data_in;
                                    end else begin
                                        gate_wr_en    <= 1'b1;
                                        gate_wr_data  <= s0 ^ data_in;
                                        r_w0_buf      <= data_in;
                                    end
                                end else begin
                                    // Final partial beat
                                    data_in_ready <= 1'b0;
                                    if (!r_decrypt) begin
                                        data_out       <= mask_word64(s0 ^ data_in, r_bytes_left[2:0]);
                                        data_out_valid <= 1'b1;
                                        s0             <= s0 ^ pad_word64(data_in, r_bytes_left[2:0]);
                                    end else begin
                                        gate_wr_en    <= 1'b1;
                                        gate_wr_data  <= mask_word64(s0 ^ data_in, r_bytes_left[2:0]);
                                        s0 <= (s0 & ~((64'h01 << (r_bytes_left[2:0] * 8)) - 1)) ^
                                              (mask_word64(data_in, r_bytes_left[2:0])) ^
                                              (64'h01 << (r_bytes_left[2:0] * 8));
                                    end
                                    r_bytes_left <= 32'd0;
                                    state_reg    <= ST_FINALIZE;
                                end
                            end else begin
                                r_beat <= 1'b0;
                                if (r_bytes_left >= 8) begin
                                    data_in_ready <= 1'b0;
                                    if (!r_decrypt) begin
                                        data_out       <= s1 ^ data_in;
                                        data_out_valid <= 1'b1;
                                        perm_in_x0     <= r_w0_buf;
                                        perm_in_x1     <= s1 ^ data_in;
                                    end else begin
                                        gate_wr_en   <= 1'b1;
                                        gate_wr_data <= s1 ^ data_in;
                                        perm_in_x0   <= r_w0_buf;
                                        perm_in_x1   <= data_in;
                                    end
                                    perm_in_x2   <= s2;
                                    perm_in_x3   <= s3;
                                    perm_in_x4   <= s4;
                                    perm_rounds  <= 4'd8;
                                    perm_start   <= 1'b1;
                                    perm_running <= 1'b1;
                                    r_bytes_left <= r_bytes_left - 8;
                                end else begin
                                    data_in_ready <= 1'b0;
                                    s0            <= r_w0_buf;
                                    if (!r_decrypt) begin
                                        data_out       <= mask_word64(s1 ^ data_in, r_bytes_left[2:0]);
                                        data_out_valid <= 1'b1;
                                        s1             <= s1 ^ pad_word64(data_in, r_bytes_left[2:0]);
                                    end else begin
                                        gate_wr_en   <= 1'b1;
                                        gate_wr_data <= mask_word64(s1 ^ data_in, r_bytes_left[2:0]);
                                        s1 <= (s1 & ~((64'h01 << (r_bytes_left[2:0] * 8)) - 1)) ^
                                              (mask_word64(data_in, r_bytes_left[2:0])) ^
                                              (64'h01 << (r_bytes_left[2:0] * 8));
                                    end
                                    r_bytes_left <= 32'd0;
                                    state_reg    <= ST_FINALIZE;
                                end
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // MSG_PAD_BLOCK: Final padding block when msg_len % rate == 0
                // -------------------------------------------------------------
                ST_MSG_PAD_BLOCK: begin
                    if (r_mode == 1'b1) begin
                        if (perm_done && perm_running) begin
                            perm_running   <= 1'b0;
                            s0             <= perm_out_x0;
                            s1             <= perm_out_x1;
                            s2             <= perm_out_x2;
                            s3             <= perm_out_x3;
                            s4             <= perm_out_x4;
                            r_squeeze_step <= 2'd0;
                            state_reg      <= ST_SQUEEZE;
                        end else if (!perm_running) begin
                            perm_in_x0   <= s0 ^ 64'h00000000_00000001;
                            perm_in_x1   <= s1;
                            perm_in_x2   <= s2;
                            perm_in_x3   <= s3;
                            perm_in_x4   <= s4;
                            perm_rounds  <= 4'd12;
                            perm_start   <= 1'b1;
                            perm_running <= 1'b1;
                        end
                    end else begin
                        s0        <= s0 ^ 64'h00000000_00000001;
                        state_reg <= ST_FINALIZE;
                    end
                end

                // -------------------------------------------------------------
                // FINALIZE: AEAD 12-round permutation & tag generation
                // -------------------------------------------------------------
                ST_FINALIZE: begin
                    if (perm_done && perm_running) begin
                        perm_running  <= 1'b0;
                        s0            <= perm_out_x0;
                        s1            <= perm_out_x1;
                        s2            <= perm_out_x2;
                        s3            <= perm_out_x3;
                        s4            <= perm_out_x4;
                        r_tag[63:0]   <= perm_out_x3 ^ r_k0;
                        r_tag[127:64] <= perm_out_x4 ^ r_k1;

                        if (!r_decrypt) begin
                            busy      <= 1'b0;
                            done      <= 1'b1;
                            tag_ok    <= 1'b1;
                            state_reg <= ST_DONE;
                        end else begin
                            state_reg <= ST_TAG_CHECK;
                        end
                    end else if (!perm_running) begin
                        perm_in_x0   <= s0;
                        perm_in_x1   <= s1;
                        perm_in_x2   <= s2 ^ r_k0;
                        perm_in_x3   <= s3 ^ r_k1;
                        perm_in_x4   <= s4;
                        perm_rounds  <= 4'd12;
                        perm_start   <= 1'b1;
                        perm_running <= 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // TAG_CHECK: Constant-time 128-bit comparison
                // -------------------------------------------------------------
                ST_TAG_CHECK: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    if ((r_tag[63:0] == r_expected_t0) && (r_tag[127:64] == r_expected_t1)) begin
                        tag_ok    <= 1'b1;
                        error     <= 1'b0;
                        state_reg <= ST_DONE;
                    end else begin
                        tag_ok         <= 1'b0;
                        error          <= 1'b1;
                        gate_auth_fail <= 1'b1;
                        state_reg      <= ST_ERROR;
                    end
                end

                // -------------------------------------------------------------
                // SQUEEZE: Hash Mode 4-word Extraction (256-bit Digest)
                // -------------------------------------------------------------
                ST_SQUEEZE: begin
                    case (r_squeeze_step)
                        3'd0: begin
                            // Step 0: Extract H0 directly from S0, launch Permutation 1
                            r_digest[63:0] <= s0; // H0
                            perm_in_x0     <= s0;
                            perm_in_x1     <= s1;
                            perm_in_x2     <= s2;
                            perm_in_x3     <= s3;
                            perm_in_x4     <= s4;
                            perm_rounds    <= 4'd12;
                            perm_start     <= 1'b1;
                            perm_running   <= 1'b1;
                            r_squeeze_step <= 3'd1;
                        end

                        3'd1: begin
                            // Step 1: Await Permutation 1 completion -> Extract H1
                            if (perm_done && perm_running) begin
                                perm_running     <= 1'b0;
                                s0               <= perm_out_x0;
                                s1               <= perm_out_x1;
                                s2               <= perm_out_x2;
                                s3               <= perm_out_x3;
                                s4               <= perm_out_x4;
                                r_digest[127:64] <= perm_out_x0; // H1
                                r_squeeze_step   <= 3'd2;
                            end
                        end

                        3'd2: begin
                            // Step 2: Launch Permutation 2
                            perm_in_x0     <= s0;
                            perm_in_x1     <= s1;
                            perm_in_x2     <= s2;
                            perm_in_x3     <= s3;
                            perm_in_x4     <= s4;
                            perm_rounds    <= 4'd12;
                            perm_start     <= 1'b1;
                            perm_running   <= 1'b1;
                            r_squeeze_step <= 3'd3;
                        end

                        3'd3: begin
                            // Step 3: Await Permutation 2 completion -> Extract H2
                            if (perm_done && perm_running) begin
                                perm_running      <= 1'b0;
                                s0                <= perm_out_x0;
                                s1                <= perm_out_x1;
                                s2                <= perm_out_x2;
                                s3                <= perm_out_x3;
                                s4                <= perm_out_x4;
                                r_digest[191:128] <= perm_out_x0; // H2
                                r_squeeze_step    <= 3'd4;
                            end
                        end

                        3'd4: begin
                            // Step 4: Launch Permutation 3
                            perm_in_x0     <= s0;
                            perm_in_x1     <= s1;
                            perm_in_x2     <= s2;
                            perm_in_x3     <= s3;
                            perm_in_x4     <= s4;
                            perm_rounds    <= 4'd12;
                            perm_start     <= 1'b1;
                            perm_running   <= 1'b1;
                            r_squeeze_step <= 3'd5;
                        end

                        3'd5: begin
                            // Step 5: Await Permutation 3 completion -> Extract H3
                            if (perm_done && perm_running) begin
                                perm_running      <= 1'b0;
                                s0                <= perm_out_x0;
                                s1                <= perm_out_x1;
                                s2                <= perm_out_x2;
                                s3                <= perm_out_x3;
                                s4                <= perm_out_x4;
                                r_digest[255:192] <= perm_out_x0; // H3
                                busy              <= 1'b0;
                                done              <= 1'b1;
                                tag_ok            <= 1'b1;
                                state_reg         <= ST_DONE;
                            end
                        end

                        default: r_squeeze_step <= 3'd0;
                    endcase
                end

                // -------------------------------------------------------------
                // DONE: Operation complete
                // -------------------------------------------------------------
                ST_DONE: begin
                    busy           <= 1'b0;
                    data_in_ready  <= 1'b0;
                    data_out_valid <= 1'b0;
                    state_reg      <= ST_IDLE;
                end

                // -------------------------------------------------------------
                // ERROR: Tag mismatch / Security abort
                // -------------------------------------------------------------
                ST_ERROR: begin
                    busy           <= 1'b0;
                    data_in_ready  <= 1'b0;
                    data_out_valid <= 1'b0;
                    state_reg      <= ST_IDLE;
                end

                default: state_reg <= ST_IDLE;
            endcase
        end
    end

endmodule
