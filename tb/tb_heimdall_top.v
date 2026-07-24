// ============================================================================
// PROJECT: HEIMDALL
// MODULE:  tb_heimdall_top
// FILE:    tb_heimdall_top.v
// ROLE:    System-Level Verification Environment
// STANDARD: Verilog-2001
// ============================================================================

`timescale 1ns / 1ps

module tb_heimdall_top;

    // ------------------------------------------------------------------------
    // 1. DUT Signals
    // ------------------------------------------------------------------------
    reg         clk;
    reg         rst;

    reg         cfg_write_enable;
    reg  [7:0]  cfg_address;
    reg  [31:0] cfg_write_data;
    wire [31:0] cfg_read_data;

    reg         log_pop;
    wire [31:0] log_event_out;
    wire        log_full;
    wire        log_empty;

    reg         heartbeat_in;

    reg         response_valid;
    reg  [31:0] expected_response;
    reg  [31:0] received_response;

    reg  [31:0] heartbeat_period;
    reg  [31:0] challenge_period;
    reg  [31:0] max_failure_count;

    reg         system_ready;
    wire        reset_request;
    wire        recovery_busy;
    wire        recovery_done;
    wire        recovery_failed;

    wire        system_fault;

    // Global Test Counters
    integer pass_count = 0;
    integer fail_count = 0;

    // ------------------------------------------------------------------------
    // 2. DUT Instantiation
    // ------------------------------------------------------------------------
    heimdall_top u_dut (
        .clk               (clk),
        .rst               (rst),
        .cfg_write_enable  (cfg_write_enable),
        .cfg_address       (cfg_address),
        .cfg_write_data    (cfg_write_data),
        .cfg_read_data     (cfg_read_data),
        .log_pop           (log_pop),
        .log_event_out     (log_event_out),
        .log_full          (log_full),
        .log_empty         (log_empty),
        .heartbeat_in      (heartbeat_in),
        .response_valid    (response_valid),
        .expected_response (expected_response),
        .received_response (received_response),
        .heartbeat_period  (heartbeat_period),
        .challenge_period  (challenge_period),
        .max_failure_count (max_failure_count),
        .system_ready      (system_ready),
        .reset_request     (reset_request),
        .recovery_busy     (recovery_busy),
        .recovery_done     (recovery_done),
        .recovery_failed   (recovery_failed),
        .system_fault      (system_fault)
    );

    // Dynamic block memory instantiation for Standalone Event Logger Verification
    reg         standalone_push;
    reg         standalone_pop;
    reg  [31:0] standalone_event_in;
    wire [31:0] standalone_event_out;
    wire        standalone_full;
    wire        standalone_empty;

    event_logger u_standalone_logger (
        .clk       (clk),
        .rst       (rst),
        .push      (standalone_push),
        .pop       (standalone_pop),
        .event_in  (standalone_event_in),
        .event_out (standalone_event_out),
        .full      (standalone_full),
        .empty     (standalone_empty)
    );

    // ------------------------------------------------------------------------
    // 3. Clock Generator & VCD Dump
    // ------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100MHz simulation clock
    end

    initial begin
        $dumpfile("waves/dump.vcd");
        $dumpvars(0, tb_heimdall_top);
    end

    // ------------------------------------------------------------------------
    // 4. Reset & Helper Tasks
    // ------------------------------------------------------------------------
    task reset_system;
        begin
            rst               = 1'b1;
            cfg_write_enable  = 1'b0;
            cfg_address       = 8'h00;
            cfg_write_data    = 32'h0;
            log_pop           = 1'b0;
            heartbeat_in      = 1'b0;
            response_valid    = 1'b0;
            expected_response = 32'h0;
            received_response = 32'h0;
            heartbeat_period  = 32'd100;
            challenge_period  = 32'd200;
            max_failure_count = 32'd1;
            system_ready      = 1'b1;

            standalone_push   = 1'b0;
            standalone_pop    = 1'b0;
            standalone_event_in = 32'h0;

            repeat (5) @(posedge clk);
            rst = 1'b0;
            @(posedge clk);
        end
    endtask

    task check_condition;
        input [1024:0] test_name;
        input condition;
        begin
            if (condition) begin
                $display("[PASS] %0s", test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s", test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task write_cfg;
        input [7:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cfg_write_enable = 1'b1;
            cfg_address      = addr;
            cfg_write_data   = data;
            @(posedge clk);
            cfg_write_enable = 1'b0;
            cfg_address      = 8'h00;
            cfg_write_data   = 32'h0;
        end
    endtask

    // ------------------------------------------------------------------------
    // 5. Main Test Execution Routine
    // ------------------------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("   STARTING PROJECT HEIMDALL SYSTEM VERIFICATION  ");
        $display("==================================================");

        // --------------------------------------------------------------------
        // TEST 1: System Reset
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 1 : Reset");
        $display("----------------------------------------");
        reset_system();
        check_condition("Reset: system_fault initialized to 0", system_fault == 1'b0);
        check_condition("Reset: recovery_busy initialized to 0", recovery_busy == 1'b0);
        check_condition("Reset: reset_request initialized to 0", reset_request == 1'b0);
        check_condition("Reset: event logger starts empty", log_empty == 1'b1);

        // --------------------------------------------------------------------
        // TEST 2: Configuration Register Access
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 2 : Configuration Register Access");
        $display("----------------------------------------");
        
        // Write & Read Control Register (Addr 0x00, Mask 0x00000001)
        write_cfg(8'h00, 32'hFFFF_FFFF);
        #1;
        cfg_address = 8'h00;
        #1;
        check_condition("Config Reg 0x00 Read (Mask 0x1)", cfg_read_data == 32'h0000_0001);

        // Write & Read Heartbeat Cfg (Addr 0x04, Mask 0x0000FFFF)
        write_cfg(8'h04, 32'h1234_5678);
        #1;
        cfg_address = 8'h04;
        #1;
        check_condition("Config Reg 0x04 Read (Mask 0xFFFF)", cfg_read_data == 32'h0000_5678);

        // Write Read-Only Status Reg (Addr 0x14)
        write_cfg(8'h14, 32'hDEAD_BEEF);
        #1;
        cfg_address = 8'h14;
        #1;
        check_condition("Config Reg 0x14 Status Read-Only Test", cfg_read_data == 32'h0000_0001);

        // --------------------------------------------------------------------
        // TEST 3: Normal Heartbeat Operation
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 3 : Normal Heartbeat Operation");
        $display("----------------------------------------");
        reset_system();
        
        // Pulse heartbeat every 10 cycles for 150 cycles (Timeout limit is set high via period)
        heartbeat_period = 32'd1000;
        challenge_period = 32'd2000;

        repeat (15) begin
            repeat (10) @(posedge clk);
            heartbeat_in = 1'b1;
            @(posedge clk);
            heartbeat_in = 1'b0;
        end

        check_condition("Normal HB: system_fault remains low", system_fault == 1'b0);
        check_condition("Normal HB: recovery_busy remains low", recovery_busy == 1'b0);

        // --------------------------------------------------------------------
        // TEST 4: Heartbeat Timeout
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 4 : Heartbeat Timeout");
        $display("----------------------------------------");
        reset_system();
        heartbeat_period  = 32'd20; // FSM check period
        challenge_period  = 32'd5000;
        max_failure_count = 32'd1;

        // Cease heartbeats and wait for timeout & supervisor failure detection
        wait(system_fault == 1'b1);

        check_condition("HB Timeout: system_fault asserted",
                        system_fault == 1'b1);
        wait(recovery_busy == 1'b1 || reset_request == 1'b1);
        check_condition("HB Timeout: recovery_busy active",
                        recovery_busy == 1'b1 || reset_request == 1'b1);
        // --------------------------------------------------------------------
        // TEST 5: Successful Challenge
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 5 : Successful Challenge");
        $display("----------------------------------------");
        reset_system();
        heartbeat_period  = 32'd5000;
        challenge_period  = 32'd20;
        max_failure_count = 32'd1;

        // Monitor for challenge start signal, then supply correct response
        expected_response = 32'hCAFE_BABE;
        received_response = 32'hCAFE_BABE;

        repeat (25) @(posedge clk);
        response_valid = 1'b1;
        @(posedge clk);
        response_valid = 1'b0;

        repeat (10) @(posedge clk);
        check_condition("Successful Challenge: No system_fault triggered", system_fault == 1'b0);

        // --------------------------------------------------------------------
        // TEST 6: Failed Challenge
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 6 : Failed Challenge");
        $display("----------------------------------------");
        reset_system();
        heartbeat_period  = 32'd5000;
        challenge_period  = 32'd20;
        max_failure_count = 32'd1;

        expected_response = 32'hCAFE_BABE;
        received_response = 32'hBAD_0000; // Mismatched response

        repeat (25) @(posedge clk);
        response_valid = 1'b1;
        @(posedge clk);
        response_valid = 1'b0;

        repeat (10) @(posedge clk);
        check_condition("Failed Challenge: System Fault asserted", system_fault == 1'b1);

        // --------------------------------------------------------------------
        // TEST 7: Recovery Manager
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 7 : Recovery Manager");
        $display("----------------------------------------");
        reset_system();
        
        // Trigger recovery via Heartbeat Fault
        heartbeat_period  = 32'd10;
        challenge_period  = 32'd5000;
        max_failure_count = 32'd1;
        system_ready      = 1'b1;

        // Wait for reset_request assertion
        wait(reset_request == 1'b1);
        check_condition("Recovery: reset_request asserted", reset_request == 1'b1);
        check_condition("Recovery: recovery_busy active", recovery_busy == 1'b1);

        // Wait for recovery completion
        // Wait for recovery completion
        wait(recovery_done == 1'b1);
        check_condition("Recovery: recovery_done pulsed", recovery_done == 1'b1);

        // Wait until Supervisor FSM actually clears the fault
        wait(system_fault == 1'b0);

        check_condition(
            "Recovery: system_fault cleared after complete",
            system_fault == 1'b0
        );
        // --------------------------------------------------------------------
        // TEST 8: Event Logger
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 8 : Event Logger");
        $display("----------------------------------------");
        reset_system();

        // 8.1 Push 16 entries into standalone logger
        begin : logger_test
            integer idx;
        
            for (idx = 1; idx <= 16; idx = idx + 1) begin
                standalone_event_in = idx;
                standalone_push = 1'b1;
        
                @(posedge clk);
        
                standalone_push = 1'b0;
        
                @(posedge clk);
            end
        end

        #1;
        check_condition("Event Logger: FIFO is Full at 16 entries", standalone_full == 1'b1);

        // 8.2 Attempt push on FULL FIFO (Rejection verification)
        @(posedge clk);
        standalone_push     = 1'b1;
        standalone_event_in = 32'h99;
        @(posedge clk);
        standalone_push     = 1'b0;

        // 8.3 Pop all 16 items and verify FIFO order
        begin : logger_pop_test
            integer idx;
            reg fifo_ok;

            fifo_ok = 1'b1;

            for (idx = 1; idx <= 16; idx = idx + 1) begin
                @(posedge clk);
                standalone_pop = 1'b1;

                @(posedge clk);
                standalone_pop = 1'b0;

                // Wait one extra clock for synchronous FIFO output
                @(posedge clk);
                
                $display("Expected=%0d Actual=%0d", idx, standalone_event_out);

                if (standalone_event_out != idx)
                    fifo_ok = 1'b0;
            end

            check_condition(
                "Event Logger: FIFO Ordering (1..16) Verified",
                fifo_ok == 1'b1
            );
        end

        check_condition("Event Logger: FIFO is Empty after full read", standalone_empty == 1'b1);

        // --------------------------------------------------------------------
        // TEST 9: Complete System Flow
        // --------------------------------------------------------------------
        $display("\n----------------------------------------");
        $display("TEST 9 : Complete System Flow");
        $display("----------------------------------------");
        
        // 1. Reset
        reset_system();
        check_condition("Flow Step 1: System Reset Success", system_fault == 1'b0);

        // 2. Configuration
        write_cfg(8'h04, 32'h0000_0064); // HB Cfg
        check_condition("Flow Step 2: Configuration Success", cfg_read_data == 32'h0000_0064);

        // 3. Heartbeat Active & Challenge Success
        heartbeat_period  = 32'd20;
        challenge_period  = 32'd30;
        max_failure_count = 32'd1;

        // Keep feeding heartbeat
        heartbeat_in = 1'b1;
        repeat (10) @(posedge clk);
        heartbeat_in = 1'b0;

        // Respond correctly to challenge
        expected_response = 32'h1234_5678;
        received_response = 32'h1234_5678;
        repeat (35) @(posedge clk);
        response_valid = 1'b1;
        @(posedge clk);
        response_valid = 1'b0;

        check_condition("Flow Step 3: Monitoring healthy without fault", system_fault == 1'b0);

        // 4. Force Heartbeat Failure -> Trigger Fault -> Recovery -> Resume
        repeat (100) @(posedge clk); // Stop heartbeats entirely
        
        wait(reset_request == 1'b1);
        check_condition("Flow Step 4: Heartbeat Failure detected & Fault raised", system_fault == 1'b1);

        wait(recovery_done == 1'b1);
        wait(system_fault == 1'b0);
        check_condition("Flow Step 5: System Recovery Complete & Flow Resumed", system_fault == 1'b0);

        // --------------------------------------------------------------------
        // SUMMARY
        // --------------------------------------------------------------------
        $display("\n========================================");
        $display("HEIMDALL SYSTEM TEST SUMMARY");
        $display("========================================");
        $display("Tests Passed : %0d", pass_count);
        $display("Tests Failed : %0d", fail_count);

        if (fail_count == 0) begin
            $display("\nHEIMDALL SYSTEM VERIFICATION PASSED\n");
        end else begin
            $display("\nHEIMDALL SYSTEM VERIFICATION FAILED\n");
        end

        $finish;
    end

endmodule