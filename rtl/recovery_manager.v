// ============================================================================
// PROJECT: HEIMDALL
// MODULE: HMD-006 – Recovery Manager
// FILE: recovery_manager.v
// LANGUAGE: Verilog-2001
// ============================================================================

module recovery_manager #(
    parameter RESET_HOLD_CYCLES    = 5,
    parameter STABILIZATION_CYCLES = 10,
    parameter READY_TIMEOUT_CYCLES = 15
) (
    input  wire clk,
    input  wire rst,
    input  wire recovery_start,
    input  wire system_ready,

    output reg  reset_request,
    output reg  recovery_busy,
    output reg  recovery_done,
    output reg  recovery_failed
);

    // State Encoding (One-Hot / Dense Encoded)
    localparam [3:0] STATE_RESET          = 4'd0;
    localparam [3:0] STATE_IDLE           = 4'd1;
    localparam [3:0] STATE_ASSERT_RESET   = 4'd2;
    localparam [3:0] STATE_HOLD_RESET     = 4'd3;
    localparam [3:0] STATE_RELEASE_RESET  = 4'd4;
    localparam [3:0] STATE_WAIT_STABILIZE = 4'd5;
    localparam [3:0] STATE_VERIFY_READY   = 4'd6;
    localparam [3:0] STATE_COMPLETE       = 4'd7;
    localparam [3:0] STATE_FAILED         = 4'd8;

    // Internal Registers
    reg [3:0]  state;
    reg [31:0] delay_counter;
    reg [31:0] timeout_counter;

    // FSM Sequential Logic
    always @(posedge clk) begin
        if (rst) begin
            state           <= STATE_RESET;
            delay_counter   <= 32'd0;
            timeout_counter <= 32'd0;
        end else begin
            case (state)
                STATE_RESET: begin
                    delay_counter   <= 32'd0;
                    timeout_counter <= 32'd0;
                    state           <= STATE_IDLE;
                end

                STATE_IDLE: begin
                    if (recovery_start) begin
                        state <= STATE_ASSERT_RESET;
                    end
                end

                STATE_ASSERT_RESET: begin
                    delay_counter <= 32'd1;
                    if (RESET_HOLD_CYCLES == 0) begin
                        state <= STATE_RELEASE_RESET;
                    end else begin
                        state <= STATE_HOLD_RESET;
                    end
                end

                STATE_HOLD_RESET: begin
                    delay_counter <= delay_counter + 1'b1;
                    if ((delay_counter + 1'b1) >= RESET_HOLD_CYCLES) begin
                        state <= STATE_RELEASE_RESET;
                    end
                end

                STATE_RELEASE_RESET: begin
                    delay_counter <= 32'd1;
                    if (STABILIZATION_CYCLES == 0) begin
                        state <= STATE_VERIFY_READY;
                    end else begin
                        state <= STATE_WAIT_STABILIZE;
                    end
                end

                STATE_WAIT_STABILIZE: begin
                    delay_counter <= delay_counter + 1'b1;
                    if ((delay_counter + 1'b1) > STABILIZATION_CYCLES) begin
                        timeout_counter <= 32'd0;
                        state           <= STATE_VERIFY_READY;
                    end
                end

                STATE_VERIFY_READY: begin
                    if (system_ready) begin
                        state <= STATE_COMPLETE;
                    end else begin
                        timeout_counter <= timeout_counter + 1'b1;
                        if ((timeout_counter + 1'b1) == READY_TIMEOUT_CYCLES) begin
                            state <= STATE_FAILED;
                        end
                    end
                end

                STATE_COMPLETE: begin
                    delay_counter   <= 32'd0;
                    timeout_counter <= 32'd0;
                    state           <= STATE_IDLE;
                end

                STATE_FAILED: begin
                    delay_counter   <= 32'd0;
                    timeout_counter <= 32'd0;
                    state           <= STATE_IDLE;
                end

                default: begin
                    state           <= STATE_RESET;
                    delay_counter   <= 32'd0;
                    timeout_counter <= 32'd0;
                end
            endcase
        end
    end

    // Combinational Output Logic
    always @(*) begin
        reset_request   = (state == STATE_ASSERT_RESET) || (state == STATE_HOLD_RESET);
        recovery_busy   = (state != STATE_RESET) && (state != STATE_IDLE);
        recovery_done   = (state == STATE_COMPLETE);
        recovery_failed = (state == STATE_FAILED);
    end

endmodule