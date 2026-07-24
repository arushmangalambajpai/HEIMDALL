// ============================================================================
// PROJECT: HEIMDALL
// MODULE:  HMD-007 – Top-Level Integration
// FILE:    heimdall_top.v
// Standard: Synthesizable Verilog-2001
//
// Description:
//   Top-level RTL integration module for Project HEIMDALL.
//   Instantiates and interconnects all six core sub-modules:
//     - HMD-001 Configuration Manager (configuration)
//     - HMD-002 Event Logger (event_logger)
//     - HMD-003 Heartbeat Engine (heartbeat_engine)
//     - HMD-004 Challenge Engine (challenge_engine)
//     - HMD-005 Supervisor FSM (supervisor_fsm)
//     - HMD-006 Recovery Manager (recovery_manager)
// ============================================================================

`timescale 1ns / 1ps

module heimdall_top (
    // Global Clock and Reset
    input  wire        clk,
    input  wire        rst,

    // Configuration Manager Bus Interface
    input  wire        cfg_write_enable,
    input  wire [7:0]  cfg_address,
    input  wire [31:0] cfg_write_data,
    output wire [31:0] cfg_read_data,

    // Event Logger External Interface
    input  wire        log_pop,
    output wire [31:0] log_event_out,
    output wire        log_full,
    output wire        log_empty,

    // Heartbeat Interface
    input  wire        heartbeat_in,

    // Challenge Engine Response Interface
    input  wire        response_valid,
    input  wire [31:0] expected_response,
    input  wire [31:0] received_response,

    // Supervisor Settings / Fixed Inputs
    input  wire [31:0] heartbeat_period,
    input  wire [31:0] challenge_period,
    input  wire [31:0] max_failure_count,

    // Recovery Manager System Interface
    input  wire        system_ready,
    output wire        reset_request,
    output wire        recovery_busy,
    output wire        recovery_done,
    output wire        recovery_failed,

    // Top-Level Status Outputs
    output wire        system_fault
);

    // ------------------------------------------------------------------------
    // Internal Wires & Connections
    // ------------------------------------------------------------------------

    // Configuration Outputs (Unused by other modules due to frozen port definitions)
    // Note: The configuration registers exist internal to HMD-001 but do not export
    // discrete control outputs in its frozen module header.
    
    // Heartbeat Engine Signals
    wire        heartbeat_timeout_sig;

    // Challenge Engine Signals
    wire        challenge_start_sig;
    wire        challenge_busy_sig;
    wire        challenge_done_sig;
    wire        challenge_ok_sig;

    // Supervisor FSM Signals
    wire        heartbeat_start_sig; // Unused port on Heartbeat Engine (HMD-003 lacks this port)
    wire        log_event_sig;
    wire [7:0]  log_event_code_sig;
    wire        recovery_start_sig;

    // Event Logger Bus Construction
    // Zero-extended event code formatted to 32-bit width for FIFO logger
    wire [31:0] event_data_sig;
    assign event_data_sig = {24'b0, log_event_code_sig};

    // ------------------------------------------------------------------------
    // Module Instantiations
    // ------------------------------------------------------------------------

    // HMD-001 Configuration Manager
    configuration u_configuration (
        .clk          (clk),
        .rst          (rst),
        .write_enable (cfg_write_enable),
        .address      (cfg_address),
        .write_data   (cfg_write_data),
        .read_data    (cfg_read_data)
    );

    // HMD-002 Event Logger
    event_logger u_event_logger (
        .clk       (clk),
        .rst       (rst),
        .push      (log_event_sig),
        .pop       (log_pop),
        .event_in  (event_data_sig),
        .event_out (log_event_out),
        .full      (log_full),
        .empty     (log_empty)
    );

    // HMD-003 Heartbeat Engine
    // Note: timeout_limit tied to standard 100-cycle threshold or user-defined value
    heartbeat_engine u_heartbeat_engine (
        .clk               (clk),
        .rst               (rst),
        .heartbeat         (heartbeat_in),
        .timeout_limit(heartbeat_period),
        .heartbeat_timeout (heartbeat_timeout_sig)
    );

    // HMD-004 Challenge Engine
    challenge_engine u_challenge_engine (
        .clk               (clk),
        .rst               (rst),
        .challenge_start   (challenge_start_sig),
        .response_valid    (response_valid),
        .expected_response (expected_response),
        .received_response (received_response),
        .challenge_busy    (challenge_busy_sig),
        .challenge_done    (challenge_done_sig),
        .challenge_ok      (challenge_ok_sig)
    );

    // HMD-005 Supervisor FSM
    // Note: Enables tied high; heartbeat_start output left unconnected as HMD-003 is continuously monitoring
    supervisor_fsm u_supervisor_fsm (
        .clk               (clk),
        .rst               (rst),
        .heartbeat_enable  (1'b1),
        .challenge_enable  (1'b1),
        .heartbeat_period  (heartbeat_period),
        .challenge_period  (challenge_period),
        .max_failure_count (max_failure_count),
        .heartbeat_timeout (heartbeat_timeout_sig),
        .challenge_busy    (challenge_busy_sig),
        .challenge_done    (challenge_done_sig),
        .challenge_ok      (challenge_ok_sig),
        .recovery_complete (recovery_done),
        .heartbeat_start   (heartbeat_start_sig),
        .challenge_start   (challenge_start_sig),
        .log_event         (log_event_sig),
        .log_event_code    (log_event_code_sig),
        .recovery_start    (recovery_start_sig),
        .system_fault      (system_fault)
    );

    // HMD-006 Recovery Manager
    recovery_manager u_recovery_manager (
        .clk            (clk),
        .rst            (rst),
        .recovery_start (recovery_start_sig),
        .system_ready   (system_ready),
        .reset_request  (reset_request),
        .recovery_busy  (recovery_busy),
        .recovery_done  (recovery_done),
        .recovery_failed(recovery_failed)
    );

endmodule