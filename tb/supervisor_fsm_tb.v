// ============================================================================
// Module Name:  tb_supervisor_fsm
// Project:      Project HEIMDALL (Module HMD-005)
// Description:  Testbench for Supervisor FSM (Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps

module tb_supervisor_fsm;

    // Clock and Reset Signals
    reg        clk;
    reg        rst;

    // Input Signals
    reg        heartbeat_enable;
    reg        challenge_enable;
    reg [31:0] heartbeat_period;
    reg [31:0] challenge_period;
    reg [31:0] max_failure_count;
    reg        heartbeat_timeout;
    reg        challenge_busy;
    reg        challenge_done;
    reg        challenge_ok;
    reg        recovery_complete;

    // Output Signals
    wire       heartbeat_start;
    wire       challenge_start;
    wire       log_event;
    wire [7:0] log_event_code;
    wire       recovery_start;
    wire       system_fault;

    // Global Test Status
    reg        all_passed;

    // Unit Under Test (UUT)
    supervisor_fsm uut (
        .clk(clk),
        .rst(rst),
        .heartbeat_enable(heartbeat_enable),
        .challenge_enable(challenge_enable),
        .heartbeat_period(heartbeat_period),
        .challenge_period(challenge_period),
        .max_failure_count(max_failure_count),
        .heartbeat_timeout(heartbeat_timeout),
        .challenge_busy(challenge_busy),
        .challenge_done(challenge_done),
        .challenge_ok(challenge_ok),
        .recovery_complete(recovery_complete),
        .heartbeat_start(heartbeat_start),
        .challenge_start(challenge_start),
        .log_event(log_event),
        .log_event_code(log_event_code),
        .recovery_start(recovery_start),
        .system_fault(system_fault)
    );

    // Clock Generation: 10ns period (100MHz)
    always #5 clk = ~clk;
    // Simulation Timeout
    initial begin
        #5000;
        $display("");
        $display("====================================================");
        $display("SIMULATION TIMEOUT");
        $display("====================================================");
        $finish;
    end

    // Check Tasks
    task check_output;
        input [31:0] exp_val;
        input [31:0] act_val;
        input [256*8-1:0] test_name;
        begin
            if (exp_val !== act_val) begin
                $display("[FAIL] %0s", test_name);
                $display("  Expected: 0x%0h (%0d)", exp_val, exp_val);
                $display("  Actual:   0x%0h (%0d)", act_val, act_val);
                $display("  Simulation Time: %0t ns", $time);
                all_passed = 1'b0;
            end else begin
                $display("[PASS] %0s", test_name);
            end
        end
    endtask

    // Main Test Stimulus
    initial begin
        // Initialize Signals
        clk = 1'b0;
        rst = 1'b1;
        heartbeat_enable = 1'b0;
        challenge_enable = 1'b0;
        heartbeat_period = 32'd0;
        challenge_period = 32'd0;
        max_failure_count = 32'd0;
        heartbeat_timeout = 1'b0;
        challenge_busy = 1'b0;
        challenge_done = 1'b0;
        challenge_ok = 1'b0;
        recovery_complete = 1'b0;
        all_passed = 1'b1;
        $dumpfile("waves/supervisor_fsm.vcd");
        $dumpvars(0, tb_supervisor_fsm);

        $display("===================================");

        $display("====================================================");
        $display("  HEIMDALL - HMD-005 Supervisor FSM Unit Tests");
        $display("====================================================");
        $display("");

        // ----------------------------------------------------
        // TEST 1: Reset & Init Transition
        // ----------------------------------------------------
        clk = 0;
        rst = 1;

        repeat (2) @(posedge clk);

        rst = 0;

        repeat (2) @(posedge clk);

        // Reset -> INIT -> IDLE transitions occur over 2 clock ticks
        @(posedge clk); // State becomes INIT
        @(posedge clk); // State becomes IDLE

        // Configure FSM parameters
        max_failure_count = 32'd2;
        heartbeat_period  = 32'd3;
        challenge_period  = 32'd5;
        check_output(1'b0, heartbeat_start, "Test 1.1: heartbeat_start idle");
        check_output(1'b0, challenge_start, "Test 1.2: challenge_start idle");
        check_output(1'b0, log_event, "Test 1.3: log_event idle");
        check_output(1'b0, recovery_start, "Test 1.4: recovery_start idle");
        check_output(1'b0, system_fault, "Test 1.5: system_fault cleared");

        // ----------------------------------------------------
        // TEST 2: Normal Heartbeat Cycle
        // ----------------------------------------------------
        heartbeat_enable = 1'b1;
        challenge_enable = 1'b0;

        // Wait for heartbeat_start observable pulse
        wait (heartbeat_start);
        #1;
        check_output(1'b1, heartbeat_start, "Test 2.2: heartbeat_start asserted");
        check_output(1'b1, log_event, "Test 2.3a: Log event asserted");
        check_output(8'h01, log_event_code, "Test 2.3b: Log event 0x01 (Heartbeat Started)");

        // Transition to WAIT_HEARTBEAT state happens on next clock edge
        @(posedge clk);
        #1;
        // Simulate normal heartbeat response (no timeout)
        heartbeat_timeout = 1'b0;

        @(posedge clk); // Process WAIT_HEARTBEAT -> IDLE
        #1;
        check_output(1'b0, heartbeat_start, "Test 2.4: heartbeat_start cleared");
        check_output(1'b0, log_event, "Test 2.5: log_event cleared");

        // ----------------------------------------------------
        // TEST 3: Normal Challenge Cycle
        // ----------------------------------------------------
        heartbeat_enable = 1'b0;
        challenge_enable = 1'b1;

        // Wait for challenge_start observable pulse
        wait (challenge_start);
        #1;
        check_output(1'b1, challenge_start, "Test 3.2: challenge_start asserted");
        check_output(1'b1, log_event, "Test 3.3a: Log event asserted");
        check_output(8'h03, log_event_code, "Test 3.3b: Log event 0x03 (Challenge Started)");

        // State is now WAIT_CHALLENGE
        // Simulate challenge completion with success
        challenge_done = 1'b1;
        challenge_ok = 1'b1;
        
        @(posedge clk); // Process WAIT_CHALLENGE -> IDLE
        #1;
        check_output(1'b1, log_event, "Test 3.5a: Log event asserted");
        check_output(8'h04, log_event_code, "Test 3.5b: Log event 0x04 (Challenge Success)");
        challenge_done = 1'b0;
        challenge_ok   = 1'b0;
        
        @(posedge clk);
        #1;
        
        check_output(1'b0, challenge_start, "Test 3.6: challenge_start cleared");
        check_output(1'b0, log_event, "Test 3.7: log_event cleared");
        challenge_done = 0;
        challenge_ok   = 0;
        // ----------------------------------------------------
        // TEST 4: Challenge Failure
        // ----------------------------------------------------
        
        // Wait for challenge_start observable pulse
        wait (challenge_start);
        
        // Next cycle transitions to WAIT_CHALLENGE
        @(posedge clk);
        #1;
        // Simulate challenge failure
        challenge_done = 1'b1;
        challenge_ok = 1'b0;

        @(posedge clk); // Process WAIT_CHALLENGE -> FAILURE_CHECK
        #1;
        check_output(1'b1, log_event, "Test 4.1a: Log event asserted");
        check_output(8'h05, log_event_code, "Test 4.1b: Log event 0x05 (Challenge Failure)");

        @(posedge clk); // Process FAILURE_CHECK -> IDLE (1 < max 2)
        #1;

        // ----------------------------------------------------
        // TEST 5: Heartbeat Timeout
        // ----------------------------------------------------
        challenge_done = 1'b0;
        heartbeat_enable = 1'b1;
        challenge_enable = 1'b0;

        // Wait for heartbeat_start observable pulse
        wait (heartbeat_start);
        #1;
        
        // Assert timeout BEFORE the FSM evaluates WAIT_HEARTBEAT
        heartbeat_timeout = 1'b1;
        
        @(posedge clk);
        #1;
        check_output(1'b1, log_event, "Test 5.1a: Log event asserted");
        check_output(8'h02, log_event_code, "Test 5.1b: Log event 0x02 (Heartbeat Timeout)");
        heartbeat_timeout = 1'b0;
        // ----------------------------------------------------
        // TEST 6: Failure Escalation to Recovery
        // ----------------------------------------------------
        @(posedge clk); // Process FAILURE_CHECK -> RECOVERY (2 >= max 2)
        #1;

        // ----------------------------------------------------
        // TEST 7: Recovery Execution
        // ----------------------------------------------------
        wait (recovery_start);
        #1;
        check_output(1'b1, recovery_start, "Test 7.1: recovery_start asserted");
        check_output(1'b1, system_fault, "Test 7.2: system_fault asserted");
        check_output(1'b1, log_event, "Test 7.3a: Log event asserted");
        check_output(8'h06, log_event_code, "Test 7.3b: Log event 0x06 (Recovery Started)");

        // State is now WAIT_RECOVERY
        // Simulate recovery completion
        recovery_complete = 1'b1;

        @(posedge clk); // Process WAIT_RECOVERY -> INIT
        #1;
        check_output(1'b1, log_event, "Test 7.5a: Log event asserted");
        check_output(8'h07, log_event_code, "Test 7.5b: Log event 0x07 (Recovery Completed)");
        check_output(1'b0, system_fault, "Test 7.7: system_fault cleared");
        recovery_complete = 1'b0;
        // ----------------------------------------------------
        // TEST 8: Return to IDLE from INIT
        // ----------------------------------------------------
        @(posedge clk); // Process INIT -> IDLE
        #1;
        check_output(1'b0, heartbeat_start, "Test 8.1: heartbeat_start idle");
        check_output(1'b0, challenge_start, "Test 8.2: challenge_start idle");
        check_output(1'b0, log_event, "Test 8.3: log_event idle");
        check_output(1'b0, recovery_start, "Test 8.4: recovery_start idle");
        check_output(1'b0, system_fault, "Test 8.5: system_fault idle");

        $display("");
        $display("====================================================");
        if (all_passed) begin
            $display("  OVERALL UNIT TEST RESULT: ALL TESTS PASSED");
        end else begin
            $display("  OVERALL UNIT TEST RESULT: TESTS FAILED");
        end
        $display("====================================================");

        $finish;
    end

endmodule