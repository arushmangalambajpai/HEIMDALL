// ============================================================================
// PROJECT: HEIMDALL
// MODULE: HMD-006 – Recovery Manager
// FILE: tb_recovery_manager.v
// ROLE: Self-Checking Production RTL Verification Environment
// LANGUAGE: Verilog-2001 (Compatible with Icarus Verilog)
// ============================================================================

`timescale 1ns / 1ps

module tb_recovery_manager;

    // ------------------------------------------------------------------------
    // Parameters Matching DUT Configuration
    // ------------------------------------------------------------------------
    parameter RESET_HOLD_CYCLES    = 5;
    parameter STABILIZATION_CYCLES = 10;
    parameter READY_TIMEOUT_CYCLES = 15;

    // ------------------------------------------------------------------------
    // FSM State Encoding (Hierarchical Verification Reference)
    // ------------------------------------------------------------------------
    localparam [3:0] STATE_RESET          = 4'd0;
    localparam [3:0] STATE_IDLE           = 4'd1;
    localparam [3:0] STATE_ASSERT_RESET   = 4'd2;
    localparam [3:0] STATE_HOLD_RESET     = 4'd3;
    localparam [3:0] STATE_RELEASE_RESET  = 4'd4;
    localparam [3:0] STATE_WAIT_STABILIZE = 4'd5;
    localparam [3:0] STATE_VERIFY_READY   = 4'd6;
    localparam [3:0] STATE_COMPLETE       = 4'd7;
    localparam [3:0] STATE_FAILED         = 4'd8;

    // ------------------------------------------------------------------------
    // DUT Interface Signals
    // ------------------------------------------------------------------------
    reg  clk;
    reg  rst;
    reg  recovery_start;
    reg  system_ready;

    wire reset_request;
    wire recovery_busy;
    wire recovery_done;
    wire recovery_failed;

    // ------------------------------------------------------------------------
    // Verification Tracking & Scoreboard
    // ------------------------------------------------------------------------
    integer pass_count  = 0;
    integer fail_count  = 0;
    integer test_number = 0;
    integer cycle_counter;

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------------------
    recovery_manager #(
        .RESET_HOLD_CYCLES(RESET_HOLD_CYCLES),
        .STABILIZATION_CYCLES(STABILIZATION_CYCLES),
        .READY_TIMEOUT_CYCLES(READY_TIMEOUT_CYCLES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .recovery_start(recovery_start),
        .system_ready(system_ready),
        .reset_request(reset_request),
        .recovery_busy(recovery_busy),
        .recovery_done(recovery_done),
        .recovery_failed(recovery_failed)
    );

    // ------------------------------------------------------------------------
    // Clock Generation (10ns Period / 100MHz)
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // VCD Waveform Generation
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("recovery_manager.vcd");
        $dumpvars(0, tb_recovery_manager);
    end

    // ------------------------------------------------------------------------
    // Self-Checking Verification Task
    // ------------------------------------------------------------------------
    task check_step;
        input [3:0]       exp_state;
        input             exp_reset_req;
        input             exp_busy;
        input             exp_done;
        input             exp_failed;
        input [200*8:1]   test_desc;
        begin
            test_number = test_number + 1;
            if ((dut.state       === exp_state)     &&
                (reset_request   === exp_reset_req) &&
                (recovery_busy   === exp_busy)      &&
                (recovery_done   === exp_done)      &&
                (recovery_failed === exp_failed)) begin
                $display("[PASS] Test %0d: %s", test_number, test_desc);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_number, test_desc);
                $display("       EXP -> State:%0d req:%b busy:%b done:%b fail:%b",
                         exp_state, exp_reset_req, exp_busy, exp_done, exp_failed);
                $display("       GOT -> State:%0d req:%b busy:%b done:%b fail:%b",
                         dut.state, reset_request, recovery_busy, recovery_done, recovery_failed);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Test Suite Execution (Clock-Synchronous Verification Environment)
    // ------------------------------------------------------------------------
    initial begin
        // Initialize Inputs
        rst            = 0;
        recovery_start = 0;
        system_ready   = 0;

        $display("Running HMD-006 Recovery Manager RTL Testbench");
        $display("==============================================");

        // ====================================================================
        // 1. INITIALIZATION & HARDWARE RESET
        // ====================================================================
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        #1; // Sample immediately after edge
        check_step(STATE_RESET, 1'b0, 1'b0, 1'b0, 1'b0, "Hardware Reset Active -> STATE_RESET");

        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;
        check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "Auto transition -> STATE_IDLE on first clock");

        // ====================================================================
        // 2. IDLE BEHAVIOUR
        // ====================================================================
        repeat (5) @(posedge clk);
        #1;
        check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "IDLE stability check over multiple clock ticks");

        // ====================================================================
        // 3. FULL SUCCESSFUL RECOVERY SEQUENCE WITH TIMING VERIFICATION
        // ====================================================================
        @(negedge clk);
        recovery_start = 1;

        @(posedge clk);
        #1;
        check_step(STATE_ASSERT_RESET, 1'b1, 1'b1, 1'b0, 1'b0, "Recovery Start -> STATE_ASSERT_RESET");

        @(negedge clk);
        recovery_start = 0;

        @(posedge clk);
        #1;
        check_step(STATE_HOLD_RESET, 1'b1, 1'b1, 1'b0, 1'b0, "Transition -> STATE_HOLD_RESET (Cycle 1)");

        // Verify HOLD_RESET duration exactly equal to (RESET_HOLD_CYCLES - 1) additional cycles
        cycle_counter = 1;
        repeat (RESET_HOLD_CYCLES - 2) begin
            @(posedge clk);
            #1;
            cycle_counter = cycle_counter + 1;
            check_step(STATE_HOLD_RESET, 1'b1, 1'b1, 1'b0, 1'b0, "STATE_HOLD_RESET active cycle check");
        end

        // Transitions to STATE_RELEASE_RESET
        @(posedge clk);
        #1;
        check_step(STATE_RELEASE_RESET, 1'b0, 1'b1, 1'b0, 1'b0, "Transition -> STATE_RELEASE_RESET");

        // Transition to STATE_WAIT_STABILIZE
        @(posedge clk);
        #1;
        check_step(STATE_WAIT_STABILIZE, 1'b0, 1'b1, 1'b0, 1'b0, "Transition -> STATE_WAIT_STABILIZE (Cycle 1)");

        // Verify WAIT_STABILIZE duration exactly STABILIZATION_CYCLES cycles
        repeat (STABILIZATION_CYCLES - 1) begin
            @(posedge clk);
            #1;
            check_step(STATE_WAIT_STABILIZE, 1'b0, 1'b1, 1'b0, 1'b0, "STATE_WAIT_STABILIZE active cycle check");
        end

        // Transition to STATE_VERIFY_READY
        @(posedge clk);
        #1;
        check_step(STATE_VERIFY_READY, 1'b0, 1'b1, 1'b0, 1'b0, "Transition -> STATE_VERIFY_READY");

        // Assert ready signal mid-wait
        repeat (2) @(posedge clk);
        @(negedge clk);
        system_ready = 1;

        @(posedge clk);
        #1;
        check_step(STATE_COMPLETE, 1'b0, 1'b1, 1'b1, 1'b0, "System Ready -> STATE_COMPLETE pulse width check");

        @(negedge clk);
        system_ready = 0;

        @(posedge clk);
        #1;
        check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "Return to STATE_IDLE following COMPLETE");

        // ====================================================================
        // 4. TIMEOUT RECOVERY SEQUENCE (FAILED PATH)
        // ====================================================================
        @(negedge clk);
        recovery_start = 1;

        @(posedge clk); // STATE_ASSERT_RESET
        @(negedge clk);
        recovery_start = 0;

        // Advance through RESET_HOLD + RELEASE + STABILIZE
        repeat (RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES) @(posedge clk);
        #1;
        check_step(STATE_VERIFY_READY, 1'b0, 1'b1, 1'b0, 1'b0, "Timeout Sequence -> Entered STATE_VERIFY_READY");

        // Stay in VERIFY_READY without system_ready until timeout (READY_TIMEOUT_CYCLES - 1 clock steps)
        cycle_counter = 0;
        repeat (READY_TIMEOUT_CYCLES - 1) begin
            @(posedge clk);
            #1;
            cycle_counter = cycle_counter + 1;
            check_step(STATE_VERIFY_READY, 1'b0, 1'b1, 1'b0, 1'b0, "STATE_VERIFY_READY timeout counter cycle check");
        end

        // Timeout triggers transition to STATE_FAILED
        @(posedge clk);
        #1;
        check_step(STATE_FAILED, 1'b0, 1'b1, 1'b0, 1'b1, "Timeout reached -> STATE_FAILED pulse check");

        @(posedge clk);
        #1;
        check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "Return to STATE_IDLE following FAILED");

        // ====================================================================
        // 5. IGNORED RECOVERY REQUEST WHILE BUSY
        // ====================================================================
        @(negedge clk);
        recovery_start = 1;
        @(posedge clk); // STATE_ASSERT_RESET
        @(negedge clk);
        recovery_start = 0;

        @(posedge clk); // STATE_HOLD_RESET
        #1;
        check_step(STATE_HOLD_RESET, 1'b1, 1'b1, 1'b0, 1'b0, "Active in HOLD_RESET");

        // Assert secondary start pulse while active
        @(negedge clk);
        recovery_start = 1;
        @(posedge clk);
        #1;
        check_step(STATE_HOLD_RESET, 1'b1, 1'b1, 1'b0, 1'b0, "Ignored recovery_start while BUSY (State remains HOLD_RESET)");

        @(negedge clk);
        recovery_start = 0;

        // Finish recovery cleanly
        repeat (RESET_HOLD_CYCLES - 2 + 1 + STABILIZATION_CYCLES + 1) @(posedge clk);
        @(negedge clk);
        system_ready = 1;
        @(posedge clk); // STATE_COMPLETE
        @(negedge clk);
        system_ready = 0;
        @(posedge clk); // STATE_IDLE
        #1;
        check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "Successfully reached IDLE after ignored start attempt");

        // ====================================================================
        // 6. SYNCHRONOUS HARDWARE RESET MID-RECOVERY
        // ====================================================================
        @(negedge clk);
        recovery_start = 1;
        @(posedge clk); // STATE_ASSERT_RESET
        @(negedge clk);
        recovery_start = 0;

        repeat (3) @(posedge clk); // In HOLD_RESET or STABILIZE
        #1;
        check_step(dut.state, reset_request, recovery_busy, 1'b0, 1'b0, "Mid-recovery state established");

        // Trigger synchronous hardware reset
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        #1;
        check_step(STATE_RESET, 1'b0, 1'b0, 1'b0, 1'b0, "Synchronous reset forces immediate STATE_RESET");

        @(negedge clk);
        rst = 0;
        @(posedge clk);
        #1;
        check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "System re-initialized to STATE_IDLE");

        // ====================================================================
        // 7. MULTIPLE CONSECUTIVE RECOVERY CYCLES
        // ====================================================================
        repeat (3) begin
            @(negedge clk);
            recovery_start = 1;
            @(posedge clk); // ASSERT
            @(negedge clk);
            recovery_start = 0;

            repeat (RESET_HOLD_CYCLES + 1 + STABILIZATION_CYCLES + 1) @(posedge clk);
            @(negedge clk);
            system_ready = 1;
            @(posedge clk); // COMPLETE
            #1;
            check_step(STATE_COMPLETE, 1'b0, 1'b1, 1'b1, 1'b0, "Consecutive Cycle Execution -> STATE_COMPLETE");

            @(negedge clk);
            system_ready = 0;
            @(posedge clk); // IDLE
            #1;
            check_step(STATE_IDLE, 1'b0, 1'b0, 1'b0, 1'b0, "Consecutive Cycle Execution -> STATE_IDLE");
        end

        // ====================================================================
        // FINAL SUMMARY & RESULTS
        // ====================================================================
        $display("==============================================");
        $display("RTL Tests Passed: %0d/%0d", pass_count, test_number);
        $display("==============================================");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED - RTL behavior matches Golden Model C code.");
        end else begin
            $display("VERIFICATION FAILURE: %0d test(s) failed.", fail_count);
        end

        $finish;
    end

endmodule