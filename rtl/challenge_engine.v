// ============================================================================
// PROJECT: HEIMDALL
// MODULE:  HMD-004 – Challenge Engine
// FILE:    challenge_engine.v
// ROLE:    Senior RTL Design Engineer
//
// Description:
//   Synthesizable finite state machine (FSM) implementing the Challenge Engine.
//   Monitors challenge execution, waits for external response validation,
//   compares expected vs. received response payloads, updates status flags,
//   and generates a single-cycle done pulse before returning to idle.
//
// Language Standard: Verilog-2001
// ============================================================================

`timescale 1ns / 1ps

module challenge_engine (
    input wire        clk,
    input wire        rst,
    input wire        challenge_start,
    input wire        response_valid,
    input wire [31:0] expected_response,
    input wire [31:0] received_response,

    output reg        challenge_busy,
    output reg        challenge_done,
    output reg        challenge_ok
);

    // ------------------------------------------------------------------------
    // FSM State Encoding (Explicit Localparam)
    // ------------------------------------------------------------------------
    localparam [1:0] CHALLENGE_IDLE          = 2'b00;
    localparam [1:0] CHALLENGE_WAIT_RESPONSE = 2'b01;
    localparam [1:0] CHALLENGE_COMPARE       = 2'b10;
    localparam [1:0] CHALLENGE_DONE          = 2'b11;

    // FSM State Register
    reg [1:0] state;

    // ------------------------------------------------------------------------
    // Synchronous State Machine & Register Control Logic (Single Always Block)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state          <= CHALLENGE_IDLE;
            challenge_busy <= 1'b0;
            challenge_done <= 1'b0;
            challenge_ok   <= 1'b0;
        end else begin
            case (state)
                // IDLE: Wait for challenge_start assertion
                CHALLENGE_IDLE: begin
                    challenge_done <= 1'b0;
                    if (challenge_start) begin
                        state          <= CHALLENGE_WAIT_RESPONSE;
                        challenge_busy <= 1'b1;
                        challenge_ok   <= 1'b0;
                    end else begin
                        challenge_busy <= 1'b0;
                    end
                end

                // WAIT_RESPONSE: Hold busy status until response_valid is asserted
                CHALLENGE_WAIT_RESPONSE: begin
                    challenge_busy <= 1'b1;
                    challenge_done <= 1'b0;
                
                    if (response_valid) begin
                        if (expected_response == received_response)
                            challenge_ok <= 1'b1;
                        else
                            challenge_ok <= 1'b0;
                
                        state <= CHALLENGE_DONE;
                    end
                end

                // COMPARE: Validate expected vs. received response payloads
                CHALLENGE_COMPARE: begin
                    // Reserved for future expansion.
                    // Version 1 performs comparison in WAIT_RESPONSE.
                    state <= CHALLENGE_DONE;
                end

                // DONE: Assert completion flag for 1 cycle, drop busy flag
                CHALLENGE_DONE: begin
                    challenge_busy <= 1'b0;
                    challenge_done <= 1'b1;
                    state          <= CHALLENGE_IDLE;
                end

                // Default recovery state for safe FSM behavior
                default: begin
                    state          <= CHALLENGE_IDLE;
                    challenge_busy <= 1'b0;
                    challenge_done <= 1'b0;
                    challenge_ok   <= 1'b0;
                end
            endcase
        end
    end

endmodule