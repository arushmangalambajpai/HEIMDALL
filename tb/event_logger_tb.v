// ============================================================================
// PROJECT: HEIMDALL
// MODULE:  HMD-002 – Event Logger Testbench
// FILE:    event_logger_tb.v
// Standard: Verilog-2001
// Description: Testbench for event_logger DUT verifying reset, single push/pop,
//              full/empty states, overflow/underflow rejection, wrap-around,
//              and simultaneous push/pop.
// ============================================================================

`timescale 1ns / 1ps

module event_logger_tb;

    // ------------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg        push;
    reg        pop;
    reg [31:0] event_in;

    wire [31:0] event_out;
    wire        full;
    wire        empty;

    // Tracking and loop variables
    integer error_count;
    integer i;
    reg [31:0] expected_val;

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------------------
    event_logger uut (
        .clk(clk),
        .rst(rst),
        .push(push),
        .pop(pop),
        .event_in(event_in),
        .event_out(event_out),
        .full(full),
        .empty(empty)
    );

    // ------------------------------------------------------------------------
    // Clock Generation: 100 MHz (10 ns period)
    // ------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // VCD Dump Setup
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("waves/event_logger.vcd");
        $dumpvars(0, event_logger_tb);
    end

    // ------------------------------------------------------------------------
    // Main Test Stimulus
    // ------------------------------------------------------------------------
    initial begin
        // Initialize Inputs
        rst         = 1'b0;
        push        = 1'b0;
        pop         = 1'b0;
        event_in    = 32'h0;
        error_count = 0;

        $display("==================================================");
        $display("      STARTING HEIMDALL EVENT LOGGER TESTBENCH    ");
        $display("==================================================");

        // ----------------------------------------------------
        // 1. Verification: Reset
        // ----------------------------------------------------
        $display("[TEST 1] Reset Verification...");
        @(negedge clk);
        rst = 1'b1;
        repeat (5) @(posedge clk); // Hold reset high for 5 clock cycles
        @(negedge clk);
        rst = 1'b0;

        @(negedge clk);
        if (empty !== 1'b1 || full !== 1'b0 || event_out !== 32'h0) begin
            $display("  [FAIL] Reset check failed! empty=%b (exp 1), full=%b (exp 0), event_out=0x%08h (exp 0)",
                     empty, full, event_out);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Reset verified successfully.");
        end

        // ----------------------------------------------------
        // 2. Verification: Single Push
        // ----------------------------------------------------
        $display("[TEST 2] Single Push Verification...");
        push     = 1'b1;
        event_in = 32'hA5A5_1234;
        @(negedge clk);
        push     = 1'b0;
        event_in = 32'h0;

        if (empty !== 1'b0 || full !== 1'b0) begin
            $display("  [FAIL] Single push flag check failed! empty=%b (exp 0), full=%b (exp 0)", empty, full);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Single push verified.");
        end

        // ----------------------------------------------------
        // 3. Verification: Single Pop
        // ----------------------------------------------------
        $display("[TEST 3] Single Pop Verification...");
        pop = 1'b1;
        @(negedge clk);
        pop = 1'b0;

        if (event_out !== 32'hA5A5_1234) begin
            $display("  [FAIL] Single pop data mismatch! event_out=0x%08h (exp 0xA5A51234)", event_out);
            error_count = error_count + 1;
        end else if (empty !== 1'b1) begin
            $display("  [FAIL] Single pop empty flag check failed! empty=%b (exp 1)", empty);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Single pop verified.");
        end

        // ----------------------------------------------------
        // 4. Verification: FIFO Full
        // ----------------------------------------------------
        $display("[TEST 4] FIFO Full Verification (Pushing 16 items)...");
        for (i = 0; i < 16; i = i + 1) begin
            push     = 1'b1;
            event_in = 32'h1000_0000 + i;
            @(negedge clk);
        end
        push     = 1'b0;
        event_in = 32'h0;

        if (full !== 1'b1 || empty !== 1'b0) begin
            $display("  [FAIL] FIFO full check failed! full=%b (exp 1), empty=%b (exp 0)", full, empty);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] FIFO Full verified.");
        end

        // ----------------------------------------------------
        // 6. Verification: Overflow Rejection
        // ----------------------------------------------------
        $display("[TEST 6] Overflow Rejection Verification...");
        push     = 1'b1;
        event_in = 32'hDEAD_DEAD; // Should be rejected
        @(negedge clk);
        push     = 1'b0;
        event_in = 32'h0;

        if (full !== 1'b1 || empty !== 1'b0) begin
            $display("  [FAIL] Overflow check failed! full=%b (exp 1), empty=%b (exp 0)", full, empty);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Overflow rejection verified.");
        end

        // ----------------------------------------------------
        // 5. Verification: FIFO Empty (Pop all 16 items)
        // ----------------------------------------------------
        $display("[TEST 5] FIFO Empty Verification (Popping 16 items)...");
        for (i = 0; i < 16; i = i + 1) begin
            pop = 1'b1;
            @(negedge clk);
            pop = 1'b0;
            expected_val = 32'h1000_0000 + i;
            if (event_out !== expected_val) begin
                $display("  [FAIL] FIFO Data mismatch at index %0d! Got 0x%08h, Exp 0x%08h", i, event_out, expected_val);
                error_count = error_count + 1;
            end
        end

        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("  [FAIL] FIFO empty check failed after drain! empty=%b (exp 1), full=%b (exp 0)", empty, full);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] FIFO Empty verified.");
        end

        // ----------------------------------------------------
        // 7. Verification: Underflow Rejection
        // ----------------------------------------------------
        $display("[TEST 7] Underflow Rejection Verification...");
        pop = 1'b1;
        @(negedge clk);
        pop = 1'b0;

        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("  [FAIL] Underflow check failed! empty=%b (exp 1), full=%b (exp 0)", empty, full);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Underflow rejection verified.");
        end

        // ----------------------------------------------------
        // 8. Verification: Wrap-around
        // ----------------------------------------------------
        $display("[TEST 8] Wrap-around Verification...");
        // Push 12 items (pointers move to 12)
        for (i = 0; i < 12; i = i + 1) begin
            push     = 1'b1;
            event_in = 32'h2000_0000 + i;
            @(negedge clk);
        end
        push = 1'b0;

        // Pop 12 items (read pointer moves to 12)
        for (i = 0; i < 12; i = i + 1) begin
            pop = 1'b1;
            @(negedge clk);
            pop = 1'b0;
        end

        // Push 8 items (pointers wrap past 15 to index 4)
        for (i = 0; i < 8; i = i + 1) begin
            push     = 1'b1;
            event_in = 32'h3000_0000 + i;
            @(negedge clk);
        end
        push = 1'b0;

        // Verify wrap-around popped data integrity
        for (i = 0; i < 8; i = i + 1) begin
            pop = 1'b1;
            @(negedge clk);
            pop = 1'b0;
            pop = 1'b0;
            expected_val = 32'h3000_0000 + i;
            if (event_out !== expected_val) begin
                $display("  [FAIL] Wrap-around data mismatch at index %0d! Got 0x%08h, Exp 0x%08h", i, event_out, expected_val);
                error_count = error_count + 1;
            end
        end

        if (empty !== 1'b1) begin
            $display("  [FAIL] FIFO empty check failed after wrap-around drain!");
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Wrap-around verified.");
        end

        // ----------------------------------------------------
        // 9. Verification: Simultaneous Push + Pop
        // ----------------------------------------------------
        $display("[TEST 9] Simultaneous Push + Pop Verification...");
        // First pre-fill FIFO with 2 items
        for (i = 0; i < 2; i = i + 1) begin
            push     = 1'b1;
            event_in = 32'h4000_0000 + i;
            @(negedge clk);
        end
        push = 1'b0;

        // Perform simultaneous push and pop
        push     = 1'b1;
        pop      = 1'b1;
        event_in = 32'h4000_0002;
        @(negedge clk);
        push     = 1'b0;
        pop      = 1'b0;

        if (event_out !== 32'h4000_0000) begin
            $display("  [FAIL] Simultaneous push+pop read value incorrect! Got 0x%08h (exp 0x40000000)", event_out);
            error_count = error_count + 1;
        end

        // Pop remaining 2 items to ensure the new pushed value exists
        pop = 1'b1;
        @(negedge clk);
        pop = 1'b0;
        if (event_out !== 32'h4000_0001) begin
            $display("  [FAIL] Subsequent pop data mismatch! Got 0x%08h (exp 0x40000001)", event_out);
            error_count = error_count + 1;
        end

        pop = 1'b1;
        @(negedge clk);
        pop = 1'b0;
        if (event_out !== 32'h4000_0002) begin
            $display("  [FAIL] Sim-pushed item data mismatch! Got 0x%08h (exp 0x40000002)", event_out);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] Simultaneous push + pop verified.");
        end

        // ----------------------------------------------------
        // Simulation Summary
        // ----------------------------------------------------
        $display("==================================================");
        if (error_count == 0) begin
            $display("               STATUS: PASS                       ");
            $display("      ALL 9 VERIFICATION CHECKS PASSED!           ");
        end else begin
            $display("               STATUS: FAIL                       ");
            $display("      TOTAL ERRORS ENCOUNTERED: %0d               ", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule