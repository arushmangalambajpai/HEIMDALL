// ============================================================================
// Module Name:  supervisor_fsm
// Project:      Project HEIMDALL (Module HMD-005)
// Description:  Synthesizable Verilog-2001 implementation of Supervisor FSM.
// ============================================================================

module supervisor_fsm (
    input  wire        clk,
    input  wire        rst,

    input  wire        heartbeat_enable,
    input  wire        challenge_enable,

    input  wire [31:0] heartbeat_period,
    input  wire [31:0] challenge_period,
    input  wire [31:0] max_failure_count,

    input  wire        heartbeat_timeout,

    input  wire        challenge_busy,
    input  wire        challenge_done,
    input  wire        challenge_ok,

    input  wire        recovery_complete,

    output reg         heartbeat_start,
    output reg         challenge_start,
    output reg         log_event,
    output reg  [7:0]  log_event_code,
    output reg         recovery_start,
    output reg         system_fault
);

    // FSM State Encoding
    localparam STATE_RESET           = 4'd0;
    localparam STATE_INIT            = 4'd1;
    localparam STATE_IDLE            = 4'd2;
    localparam STATE_HEARTBEAT_START = 4'd3;
    localparam STATE_WAIT_HEARTBEAT  = 4'd4;
    localparam STATE_FAILURE_CHECK   = 4'd5;
    localparam STATE_CHALLENGE_START = 4'd6;
    localparam STATE_WAIT_CHALLENGE  = 4'd7;
    localparam STATE_RECOVERY         = 4'd8;
    localparam STATE_WAIT_RECOVERY    = 4'd9;

    // FSM State Register
    reg [3:0] state;

    // Internal Registers
    reg [31:0] heartbeat_timer;
    reg [31:0] challenge_timer;
    reg [31:0] failure_counter;

    // Sequential FSM Block
    always @(posedge clk) begin
        if (rst) begin
            state           <= STATE_RESET;
            heartbeat_timer <= 32'd0;
            challenge_timer <= 32'd0;
            failure_counter <= 32'd0;
            heartbeat_start <= 1'b0;
            challenge_start <= 1'b0;
            log_event       <= 1'b0;
            log_event_code  <= 8'h00;
            recovery_start  <= 1'b0;
            system_fault    <= 1'b0;
        end else begin
            // Default pulse signals (single clock cycle duration)
            heartbeat_start <= 1'b0;
            challenge_start <= 1'b0;
            log_event       <= 1'b0;
            recovery_start  <= 1'b0;

            case (state)
                STATE_RESET: begin
                    heartbeat_timer <= 32'd0;
                    challenge_timer <= 32'd0;
                    failure_counter <= 32'd0;
                    heartbeat_start <= 1'b0;
                    challenge_start <= 1'b0;
                    log_event       <= 1'b0;
                    log_event_code  <= 8'h00;
                    recovery_start  <= 1'b0;
                    system_fault    <= 1'b0;
                    state           <= STATE_INIT;
                end

                STATE_INIT: begin
                    heartbeat_timer <= 32'd0;
                    challenge_timer <= 32'd0;
                    failure_counter <= 32'd0;
                    system_fault    <= 1'b0;
                    log_event_code  <= 8'h00;
                    state           <= STATE_IDLE;
                end

                STATE_IDLE: begin
                    heartbeat_timer <= heartbeat_timer + 32'd1;
                    challenge_timer <= challenge_timer + 32'd1;

                    if (heartbeat_enable && ((heartbeat_timer + 32'd1) >= heartbeat_period)) begin
                        state <= STATE_HEARTBEAT_START;
                    end else if (challenge_enable && ((challenge_timer + 32'd1) >= challenge_period)) begin
                        state <= STATE_CHALLENGE_START;
                    end
                end

                STATE_HEARTBEAT_START: begin
                    heartbeat_start <= 1'b1;
                    log_event       <= 1'b1;
                    log_event_code  <= 8'h01; // Heartbeat Started
                    state           <= STATE_WAIT_HEARTBEAT;
                end

                STATE_WAIT_HEARTBEAT: begin
                    if (heartbeat_timeout == 1'b0) begin
                        heartbeat_timer <= 32'd0;
                        state           <= STATE_IDLE;
                    end else begin
                        log_event       <= 1'b1;
                        log_event_code  <= 8'h02; // Heartbeat Timeout
                        failure_counter <= failure_counter + 32'd1;
                        state           <= STATE_FAILURE_CHECK;
                    end
                end

                STATE_CHALLENGE_START: begin
                    challenge_start <= 1'b1;
                                        log_event       <= 1'b1;
                    log_event_code  <= 8'h03; // Challenge Started
                    state           <= STATE_WAIT_CHALLENGE;
                end

                STATE_WAIT_CHALLENGE: begin
                    if (!challenge_busy && challenge_done) begin
                        if (challenge_ok) begin
                            log_event       <= 1'b1;
                            log_event_code  <= 8'h04; // Challenge Success
                            challenge_timer <= 32'd0;
                            state           <= STATE_IDLE;
                        end else begin
                            log_event       <= 1'b1;
                            log_event_code  <= 8'h05; // Challenge Failure
                            failure_counter <= failure_counter + 32'd1;
                            state           <= STATE_FAILURE_CHECK;
                        end
                    end
                end

                STATE_FAILURE_CHECK: begin
                    if ((max_failure_count == 32'd0) || (failure_counter >= max_failure_count)) begin
                        state <= STATE_RECOVERY;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end

                STATE_RECOVERY: begin
                    recovery_start <= 1'b1;
                    system_fault   <= 1'b1;
                    log_event      <= 1'b1;
                    log_event_code <= 8'h06; // Recovery Started
                    state          <= STATE_WAIT_RECOVERY;
                end

                STATE_WAIT_RECOVERY: begin
                    if (recovery_complete) begin
                        log_event       <= 1'b1;
                        log_event_code  <= 8'h07; // Recovery Completed
                        failure_counter <= 32'd0;
                        system_fault    <= 1'b0;
                        state           <= STATE_INIT;
                    end
                end

                default: begin
                    heartbeat_start <= 1'b0;
                    challenge_start <= 1'b0;
                    log_event       <= 1'b0;
                    log_event_code  <= 8'h00;
                    recovery_start  <= 1'b0;
                    system_fault    <= 1'b0;

                    heartbeat_timer <= 32'd0;
                    challenge_timer <= 32'd0;
                    failure_counter <= 32'd0;

                    state <= STATE_RESET;
                end
            endcase
        end
    end

endmodule