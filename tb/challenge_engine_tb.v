`timescale 1ns / 1ps

module challenge_engine_tb;

    // DUT Inputs
    reg clk;
    reg rst;
    reg challenge_start;
    reg response_valid;
    reg [31:0] expected_response;
    reg [31:0] received_response;

    // DUT Outputs
    wire challenge_busy;
    wire challenge_done;
    wire challenge_ok;

    // Instantiate Design Under Test
    challenge_engine dut (
        .clk(clk),
        .rst(rst),
        .challenge_start(challenge_start),
        .response_valid(response_valid),
        .expected_response(expected_response),
        .received_response(received_response),
        .challenge_busy(challenge_busy),
        .challenge_done(challenge_done),
        .challenge_ok(challenge_ok)
    );

    // 100 MHz Clock Generation (10 ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Waveform Dump Requirement
    initial begin
        $dumpfile("waves/challenge_engine.vcd");
        $dumpvars(0, challenge_engine_tb);
    end

    // Verification Stimulus and Checks
    initial begin
        // Initialize Inputs
        rst = 1;
        challenge_start = 0;
        response_valid = 0;
        expected_response = 32'h0;
        received_response = 32'h0;

        // ------------------------------------------------------------
        // 1. Verify Reset Behavior
        // ------------------------------------------------------------
        repeat (2) @(posedge clk);
        #1;
        if (challenge_busy !== 1'b0 || challenge_done !== 1'b0 || challenge_ok !== 1'b0) begin
            $display("[FAIL] Check 1: Reset behavior incorrect. Signals active during reset.");
        end else begin
            $display("[PASS] Check 1: Synchronous reset behavior verified.");
        end

        // Deassert Reset synchronously
        @(negedge clk);
        rst = 0;
        @(posedge clk);

        // ------------------------------------------------------------
        // 2 & 3. Verify challenge_start enters WAIT_RESPONSE & holds busy high
        // ------------------------------------------------------------
        @(negedge clk);
        challenge_start = 1;
        
        @(posedge clk);
        #1;
        challenge_start = 0;

        if (challenge_busy !== 1'b1) begin
            $display("[FAIL] Check 2: Failed to enter WAIT_RESPONSE on challenge_start.");
        end else begin
            $display("[PASS] Check 2: challenge_start successfully transitions state.");
        end

        // Verify WAIT_RESPONSE holds busy high across cycles
        repeat (3) @(posedge clk);
        #1;
        if (challenge_busy !== 1'b1) begin
            $display("[FAIL] Check 3: WAIT_RESPONSE failed to hold challenge_busy high.");
        end else begin
            $display("[PASS] Check 3: WAIT_RESPONSE holds busy high.");
        end

        // ------------------------------------------------------------
        // 4 & 6. Verify Matching response sets challenge_ok & done pulse width
        // ------------------------------------------------------------
        @(negedge clk);
        expected_response = 32'hDEADBEEF;
        received_response = 32'hDEADBEEF;
        response_valid = 1;

        @(posedge clk);
        #1;
        response_valid = 0;

        @(posedge clk);
        #1;
	

        if (challenge_done !== 1'b1 || challenge_ok !== 1'b1) begin
            $display("[FAIL] Check 4: Matching response evaluation failed. done=%b, ok=%b", challenge_done, challenge_ok);
        end else begin
            $display("[PASS] Check 4: Matching response sets challenge_ok high.");
        end

        // ------------------------------------------------------------
        // 6 & 7. Check challenge_done pulse duration (1 clock) and return to IDLE
        // ------------------------------------------------------------
        @(posedge clk);
        #1;
        if (challenge_done !== 1'b0) begin
            $display("[FAIL] Check 6: challenge_done remained high for more than 1 clock cycle.");
        end else begin
            $display("[PASS] Check 6: challenge_done pulsed for exactly one clock cycle.");
        end

        if (challenge_busy !== 1'b0) begin
            $display("[FAIL] Check 7: Failed automatic return to IDLE (busy remains high).");
        end else begin
            $display("[PASS] Check 7: Automatic return to IDLE verified.");
        end

        // ------------------------------------------------------------
        // 5. Verify Mismatching response clears challenge_ok
        // ------------------------------------------------------------
        @(negedge clk);
        challenge_start = 1;

        @(posedge clk);
        #1;
        challenge_start = 0;

        @(negedge clk);
        expected_response = 32'h12345678;
        received_response = 32'h87654321; // Intentional Mismatch
        response_valid = 1;

        @(posedge clk);
        #1;
        response_valid = 0;
        @(posedge clk);
        #1;
	
	    

        if (challenge_done !== 1'b1 || challenge_ok !== 1'b0) begin
            $display("[FAIL] Check 5: Mismatching response evaluation failed. done=%b, ok=%b", challenge_done, challenge_ok);
        end else begin
            $display("[PASS] Check 5: Mismatching response correctly cleared challenge_ok.");
        end

        @(posedge clk); // Allow return to IDLE

        // ------------------------------------------------------------
        // 8. Verify Multiple Consecutive Challenge Transactions
        // ------------------------------------------------------------
        // Transaction A: Match
        @(negedge clk);
        challenge_start = 1;
        
        @(posedge clk);
        #1;
        challenge_start = 0;

        @(negedge clk);
        expected_response = 32'hAAAA5555;
        received_response = 32'hAAAA5555;
        response_valid = 1;

        @(posedge clk);
        #1;
        response_valid = 0;

        @(posedge clk);
        #1;
        
        if (challenge_done !== 1'b1 || challenge_ok !== 1'b1) begin
            $display("[FAIL] Check 8: Consecutive Transaction A failed.");
        end

        // Immediately launch Transaction B on the following cycle
        @(negedge clk);
        challenge_start = 1;

        @(posedge clk);
        #1;
        challenge_start = 0;

        @(negedge clk);
        expected_response = 32'hCAFEBABE;
        received_response = 32'hCAFE0000; // Mismatch
        response_valid = 1;

        @(posedge clk);
        #1;
        response_valid = 0;
	
	@(posedge clk);
	#1;

        if (challenge_done !== 1'b1 || challenge_ok !== 1'b0) begin
            $display("[FAIL] Check 8: Consecutive Transaction B failed.");
        end else begin
            $display("[PASS] Check 8: Multiple consecutive challenge transactions verified.");
        end

        @(posedge clk);
        #1;

        $display("--- VERIFICATION SUITE COMPLETE ---");
        $finish;
    end

endmodule