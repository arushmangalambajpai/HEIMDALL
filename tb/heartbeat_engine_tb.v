`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Project: HEIMDALL
// Module: HMD-003 – Heartbeat Engine Testbench
// File: heartbeat_engine_tb.v
// Standard: Verilog-2001
////////////////////////////////////////////////////////////////////////////////

module heartbeat_engine_tb;

    // Inputs
    reg clk;
    reg rst;
    reg heartbeat;
    reg [31:0] timeout_limit;

    // Output
    wire heartbeat_timeout;

    // Testbench Variables
    integer pass_count;
    integer fail_count;

    // Instantiate Device Under Test (DUT)
    heartbeat_engine dut (
        .clk(clk),
        .rst(rst),
        .heartbeat(heartbeat),
        .timeout_limit(timeout_limit),
        .heartbeat_timeout(heartbeat_timeout)
    );

    // 100 MHz Clock Generation (10 ns Period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Waveform Dump Configuration
    initial begin
        $dumpfile("waves/heartbeat_engine.vcd");
        $dumpvars(0, heartbeat_engine_tb);
    end

    // Task to evaluate test assertions
    task check_result;
        input [320:1] test_name;
        input expected;
        input actual;
        begin
            if (expected === actual) begin
                $display("[PASS] %s | Expected: %b, Got: %b", test_name, expected, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s | Expected: %b, Got: %b", test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Main Verification Procedure
    initial begin
        // Initialize Inputs
        pass_count = 0;
        fail_count = 0;
        rst = 1'b1;
        heartbeat = 1'b0;
        timeout_limit = 32'd10;

        // Synchronous delay
        #20;

        //--------------------------------------------------
        // TEST 1: Reset Verification
        //--------------------------------------------------
        $display("\n--- Test 1: Reset Check ---");
        @(negedge clk);
        check_result("Timeout inactive during reset", 1'b0, heartbeat_timeout);

        rst = 1'b0; // De-assert reset synchronously
        @(negedge clk);
        check_result("Timeout inactive right after reset release", 1'b0, heartbeat_timeout);

        //--------------------------------------------------
        // TEST 2: Counter increments without timeout
        //--------------------------------------------------
        $display("\n--- Test 2: Counter Increments Without Timeout ---");
        repeat (5) @(negedge clk); // Advance 5 cycles (limit is 10)
        check_result("No timeout before limit reached", 1'b0, heartbeat_timeout);

        //--------------------------------------------------
        // TEST 3: Timeout occurs exactly at timeout_limit
        //--------------------------------------------------
        $display("\n--- Test 3: Timeout Assertion at limit ---");
        repeat (4) @(negedge clk); // Total 10 cycles reached since reset
        check_result("Timeout asserts at limit", 1'b1, heartbeat_timeout);

        //--------------------------------------------------
        // TEST 4: Heartbeat resets counter
        //--------------------------------------------------
        $display("\n--- Test 4: Heartbeat Resets Counter ---");
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        timeout_limit = 32'd10;
        
        repeat (7) @(negedge clk); // Advance partially toward limit
        heartbeat = 1'b1;          // Pulse heartbeat
        @(negedge clk);
        heartbeat = 1'b0;

        repeat (7) @(negedge clk); // Total 14 cycles, but counter was reset at cycle 7
        check_result("Heartbeat cleared counter and prevented timeout", 1'b0, heartbeat_timeout);

        //--------------------------------------------------
        // TEST 5: Multiple heartbeat receptions
        //--------------------------------------------------
        $display("\n--- Test 5: Multiple Heartbeat Receptions ---");
        repeat (4) begin
            repeat (4) @(negedge clk);
            heartbeat = 1'b1;
            @(negedge clk);
            heartbeat = 1'b0;
        end
        check_result("Periodic heartbeats maintain normal operation", 1'b0, heartbeat_timeout);

        //--------------------------------------------------
        // TEST 6: Timeout recovery after heartbeat
        //--------------------------------------------------
        $display("\n--- Test 6: Timeout Recovery After Heartbeat ---");
        repeat (10) @(negedge clk); // Allow engine to time out
        check_result("Verify timeout condition is active", 1'b1, heartbeat_timeout);

        heartbeat = 1'b1; // Send heartbeat to recover
        @(negedge clk);
        heartbeat = 1'b0;
        @(negedge clk);
        check_result("Timeout recovers to low after heartbeat pulse", 1'b0, heartbeat_timeout);

        //--------------------------------------------------
        // TEST 7: Edge case (timeout_limit = 1)
        //--------------------------------------------------
        $display("\n--- Test 7: Timeout Limit = 1 ---");
        rst = 1'b1;
        timeout_limit = 32'd1;
        @(negedge clk);
        rst = 1'b0;

        @(negedge clk);
        check_result("Timeout asserts after 1 cycle", 1'b1, heartbeat_timeout);

        heartbeat = 1'b1;
        @(negedge clk);
        heartbeat = 1'b0;
        check_result("Recovery for timeout_limit = 1", 1'b0, heartbeat_timeout);

        //--------------------------------------------------
        // Summary & Testbench Completion
        //--------------------------------------------------
        $display("\n========================================");
        $display("       TESTBENCH EXECUTION SUMMARY       ");
        $display("========================================");
        $display(" PASSED: %0d", pass_count);
        $display(" FAILED: %0d", fail_count);
        if (fail_count == 0) begin
            $display(" OVERALL STATUS: PASS");
        end else begin
            $display(" OVERALL STATUS: FAIL");
        end
        $display("========================================\n");

        $finish;
    end

endmodule