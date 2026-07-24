// Project: HEIMDALL
// Module: HMD-003 – Heartbeat Engine
// File: heartbeat_engine.v

module heartbeat_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        heartbeat,
    input  wire [31:0] timeout_limit,
    output reg         heartbeat_timeout
);

    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter           <= 32'd0;
            heartbeat_timeout <= 1'b0;
        end else if (heartbeat) begin
            counter           <= 32'd0;
            heartbeat_timeout <= 1'b0;
        end else begin
            counter <= counter + 32'd1;
            if ((counter + 32'd1) >= timeout_limit) begin
                heartbeat_timeout <= 1'b1;
            end
        end
    end

endmodule