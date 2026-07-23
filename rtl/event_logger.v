// ============================================================================
// PROJECT: HEIMDALL
// MODULE:  HMD-002 – Event Logger
// FILE:    event_logger.v
// Standard: Synthesizable Verilog-2001
// Description:
//   Synchronous circular FIFO event logger with 32-bit width and depth of 16.
//   Rejects push when full, rejects pop when empty. Synchronous reset clears
//   memory, pointers, count, and output registers.
// ============================================================================

module event_logger (
    input  wire        clk,
    input  wire        rst,
    input  wire        push,
    input  wire        pop,
    input  wire [31:0] event_in,
    output reg  [31:0] event_out,
    output wire        full,
    output wire        empty
);

    // ------------------------------------------------------------------------
    // Constants and Parameters
    // ------------------------------------------------------------------------
    localparam DEPTH      = 16;
    localparam DATA_WIDTH = 32;
    localparam PTR_WIDTH  = 4; // 2^4 = 16 entries
    localparam CNT_WIDTH  = 5; // 0 to 16 entries

    // ------------------------------------------------------------------------
    // Internal Signals & Registers
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0]  w_ptr;
    reg [PTR_WIDTH-1:0]  r_ptr;
    reg [CNT_WIDTH-1:0]  count;

    integer i;

    // ------------------------------------------------------------------------
    // Status Flags
    // ------------------------------------------------------------------------
    assign empty = (count == 5'd0);
    assign full  = (count == 5'd16);

    // Operation Enable Logic (Reject push if full, reject pop if empty)
    wire do_push = push && !full;
    wire do_pop  = pop  && !empty;

    // ------------------------------------------------------------------------
    // Synchronous FIFO Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            // Clear memory, pointers, counter, and output
            w_ptr     <= {PTR_WIDTH{1'b0}};
            r_ptr     <= {PTR_WIDTH{1'b0}};
            count     <= {CNT_WIDTH{1'b0}};
            event_out <= {DATA_WIDTH{1'b0}};

            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            // Handle Write / Push Operation
            if (do_push) begin
                mem[w_ptr] <= event_in;
                w_ptr      <= w_ptr + 1'b1;
            end

            // Handle Read / Pop Operation
            if (do_pop) begin
                event_out <= mem[r_ptr];
                r_ptr     <= r_ptr + 1'b1;
            end

            // Handle Internal Count Update
            case ({do_push, do_pop})
                2'b10:   count <= count + 1'b1; // Push only
                2'b01:   count <= count - 1'b1; // Pop only
                default: count <= count;        // No-op or simultaneous push & pop
            endcase
        end
    end

endmodule