// ============================================================================
// Project HEIMDALL
// Testbench: HMD-001 Configuration Manager Testbench (tb_configuration.v)
// Standard: Verilog-2001
// Simulator Compatibility: Icarus Verilog + GTKWave
// ============================================================================

`timescale 1ns / 1ps

module tb_configuration;

    // ========================================================================
    // Clock and Timing Parameters
    // ========================================================================
    localparam CLK_PERIOD = 10; // 100 MHz clock

    // ========================================================================
    // Register Address Localparams
    // ========================================================================
    localparam ADDR_CONTROL         = 8'h00;
    localparam ADDR_HEARTBEAT_CFG   = 8'h04;
    localparam ADDR_CHALLENGE_CFG   = 8'h08;
    localparam ADDR_PROTOCOL_ENABLE = 8'h0C;
    localparam ADDR_RECOVERY_CFG    = 8'h10;
    localparam ADDR_STATUS          = 8'h14;

    // ========================================================================
    // Testbench Signal Declarations
    // ========================================================================
    reg         clk;
    reg         rst;
    reg         write_enable;
    reg  [7:0]  address;
    reg  [31:0] write_data;
    wire [31:0] read_data;

    // Test Tracking Variables
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    // ========================================================================
    // Device Under Test (DUT) Instantiation
    // ========================================================================
    configuration dut (
        .clk          (clk),
        .rst          (rst),
        .write_enable (write_enable),
        .address      (address),
        .write_data   (write_data),
        .read_data    (read_data)
    );

    // ========================================================================
    // Free-Running Clock Generator
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ========================================================================
    // Reusable Testbench Tasks
    // ========================================================================

    // Task: Write Register (Synchronized to rising clock edge)
    task write_reg;
        input [7:0]  target_addr;
        input [31:0] data;
        begin
            @(posedge clk);
            address      <= target_addr;
            write_data   <= data;
            write_enable <= 1'b1;
            @(posedge clk);
            write_enable <= 1'b0;
            address      <= 8'h00;
            write_data   <= 32'h00000000;
        end
    endtask

    // Task: Read Register (Synchronized to setup address and sample output)
    task read_reg;
        input  [7:0]  target_addr;
        output [31:0] sampled_data;
        begin
            @(posedge clk);
            address <= target_addr;
            #1; // Brief delay to allow combinational read_data to settle
            sampled_data = read_data;
        end
    endtask

    // Task: Check and Log Test Results
    task check_result;
        input [8*60-1:0] test_name;
        input [31:0]     actual;
        input [31:0]     expected;
        begin
            total_tests = total_tests + 1;
            if (actual === expected) begin
                $display("[PASS] Test %0d: %s | Value: 0x%08X", total_tests, test_name, actual);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] Test %0d: %s | Expected: 0x%08X, Got: 0x%08X", total_tests, test_name, expected, actual);
                failed_tests = failed_tests + 1;
            end
        end
    endtask

    // ========================================================================
    // Test Sequence Execution
    // ========================================================================
    reg [31:0] rdata;

    initial begin
        // Dump waves for GTKWave analysis
        $dumpfile("waves/tb_configuration.vcd");
        $dumpvars(0, tb_configuration);

        // Initialize signals
        rst          = 1'b0;
        write_enable = 1'b0;
        address      = 8'h00;
        write_data   = 32'h00000000;

        // Apply Reset (Held for multiple cycles, released synchronously)
        @(posedge clk);
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        $display("========================================");
        $display("   Project HEIMDALL: HMD-001 Verification");
        $display("========================================");

        // --------------------------------------------------------------------
        // TEST 1: Reset Verification
        // --------------------------------------------------------------------
        read_reg(ADDR_CONTROL, rdata);
        check_result("Reset CONTROL", rdata, 32'h00000000);

        read_reg(ADDR_HEARTBEAT_CFG, rdata);
        check_result("Reset HEARTBEAT_CFG", rdata, 32'd100);

        read_reg(ADDR_CHALLENGE_CFG, rdata);
        check_result("Reset CHALLENGE_CFG", rdata, 32'h00000000);

        read_reg(ADDR_PROTOCOL_ENABLE, rdata);
        check_result("Reset PROTOCOL_ENABLE", rdata, 32'h00000000);

        read_reg(ADDR_RECOVERY_CFG, rdata);
        check_result("Reset RECOVERY_CFG", rdata, 32'h00000000);

        read_reg(ADDR_STATUS, rdata);
        check_result("Reset STATUS", rdata, 32'h00000001);

        // --------------------------------------------------------------------
        // TEST 2: CONTROL Register Masking
        // --------------------------------------------------------------------
        write_reg(ADDR_CONTROL, 32'hFFFFFFFF);
        read_reg(ADDR_CONTROL, rdata);
        check_result("CONTROL Write Mask (Bit 0 only)", rdata, 32'h00000001);

        // --------------------------------------------------------------------
        // TEST 3: HEARTBEAT_CFG Write & Upper Bit Masking
        // --------------------------------------------------------------------
        write_reg(ADDR_HEARTBEAT_CFG, 32'h0001FFFF);
        read_reg(ADDR_HEARTBEAT_CFG, rdata);
        check_result("HEARTBEAT_CFG Masking", rdata, 32'h0000FFFF);

        // --------------------------------------------------------------------
        // TEST 4: CHALLENGE_CFG Write & Masking
        // --------------------------------------------------------------------
        write_reg(ADDR_CHALLENGE_CFG, 32'hFFFFFFFF);
        read_reg(ADDR_CHALLENGE_CFG, rdata);
        check_result("CHALLENGE_CFG Masking", rdata, 32'h0000FFFF);

        // --------------------------------------------------------------------
        // TEST 5: PROTOCOL_ENABLE Write & Masking
        // --------------------------------------------------------------------
        write_reg(ADDR_PROTOCOL_ENABLE, 32'hFFFFFFFF);
        read_reg(ADDR_PROTOCOL_ENABLE, rdata);
        check_result("PROTOCOL_ENABLE Masking (Bits [3:0])", rdata, 32'h0000000F);

        // --------------------------------------------------------------------
        // TEST 6: RECOVERY_CFG Write & Masking
        // --------------------------------------------------------------------
        write_reg(ADDR_RECOVERY_CFG, 32'hFFFFFFFF);
        read_reg(ADDR_RECOVERY_CFG, rdata);
        check_result("RECOVERY_CFG Masking (Bits [1:0])", rdata, 32'h00000003);

        // --------------------------------------------------------------------
        // TEST 7: STATUS Register Protection (Read-Only)
        // --------------------------------------------------------------------
        write_reg(ADDR_STATUS, 32'hFFFFFFFF);
        read_reg(ADDR_STATUS, rdata);
        check_result("STATUS Read-Only Protection", rdata, 32'h00000001);

        // --------------------------------------------------------------------
        // TEST 8: Invalid Address Access (0x20)
        // --------------------------------------------------------------------
        write_reg(8'h20, 32'h12345678);
        read_reg(8'h20, rdata);
        check_result("Invalid Address Read (0x20 Returns 0)", rdata, 32'h00000000);

        // --------------------------------------------------------------------
        // TEST 9: Unaligned Address Access (0x05)
        // --------------------------------------------------------------------
        write_reg(8'h05, 32'h87654321);
        read_reg(8'h05, rdata);
        check_result("Unaligned Address Read (0x05 Returns 0)", rdata, 32'h00000000);

        // --------------------------------------------------------------------
        // TEST 10: Sequential Writes and Reads
        // --------------------------------------------------------------------
        write_reg(ADDR_CONTROL,         32'h00000001);
        write_reg(ADDR_HEARTBEAT_CFG,   32'h00001234);
        write_reg(ADDR_CHALLENGE_CFG,   32'h00005678);
        write_reg(ADDR_PROTOCOL_ENABLE, 32'h0000000A);
        write_reg(ADDR_RECOVERY_CFG,    32'h00000002);

        read_reg(ADDR_CONTROL, rdata);
        check_result("Sequential Read CONTROL", rdata, 32'h00000001);

        read_reg(ADDR_HEARTBEAT_CFG, rdata);
        check_result("Sequential Read HEARTBEAT_CFG", rdata, 32'h00001234);

        read_reg(ADDR_CHALLENGE_CFG, rdata);
        check_result("Sequential Read CHALLENGE_CFG", rdata, 32'h00005678);

        read_reg(ADDR_PROTOCOL_ENABLE, rdata);
        check_result("Sequential Read PROTOCOL_ENABLE", rdata, 32'h0000000A);

        read_reg(ADDR_RECOVERY_CFG, rdata);
        check_result("Sequential Read RECOVERY_CFG", rdata, 32'h00000002);

        // --------------------------------------------------------------------
        // TEST 11: Overwrite Verification
        // --------------------------------------------------------------------
        write_reg(ADDR_HEARTBEAT_CFG, 32'h00001111);
        write_reg(ADDR_HEARTBEAT_CFG, 32'h00002222);
        read_reg(ADDR_HEARTBEAT_CFG, rdata);
        check_result("Overwrite Verification HEARTBEAT_CFG", rdata, 32'h00002222);

        // --------------------------------------------------------------------
        // TEST 12: Reset Recovery
        // --------------------------------------------------------------------
        // Modify every register
        write_reg(ADDR_CONTROL,         32'h00000001);
        write_reg(ADDR_HEARTBEAT_CFG,   32'h0000ABCD);
        write_reg(ADDR_CHALLENGE_CFG,   32'h0000EFF0);
        write_reg(ADDR_PROTOCOL_ENABLE, 32'h00000005);
        write_reg(ADDR_RECOVERY_CFG,    32'h00000001);

        // Trigger Reset
        @(posedge clk);
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // Verify restoration of default values
        read_reg(ADDR_CONTROL, rdata);
        check_result("Reset Recovery CONTROL", rdata, 32'h00000000);

        read_reg(ADDR_HEARTBEAT_CFG, rdata);
        check_result("Reset Recovery HEARTBEAT_CFG", rdata, 32'd100);

        read_reg(ADDR_CHALLENGE_CFG, rdata);
        check_result("Reset Recovery CHALLENGE_CFG", rdata, 32'h00000000);

        read_reg(ADDR_PROTOCOL_ENABLE, rdata);
        check_result("Reset Recovery PROTOCOL_ENABLE", rdata, 32'h00000000);

        read_reg(ADDR_RECOVERY_CFG, rdata);
        check_result("Reset Recovery RECOVERY_CFG", rdata, 32'h00000000);

        read_reg(ADDR_STATUS, rdata);
        check_result("Reset Recovery STATUS", rdata, 32'h00000001);

        // --------------------------------------------------------------------
        // Final Results Summary
        // --------------------------------------------------------------------
        $display("========================================");
        $display("TOTAL TESTS : %0d", total_tests);
        $display("PASSED      : %0d", passed_tests);
        $display("FAILED      : %0d", failed_tests);
        $display("========================================");

        if (failed_tests == 0) begin
            $display("FINAL RESULT : PASS");
        end else begin
            $display("FINAL RESULT : FAIL");
        end

        $finish;
    end

endmodule