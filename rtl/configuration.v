// ============================================================================
// Project HEIMDALL
// Module: HMD-001 Configuration Manager (configuration.v)
// Standard: Verilog-2001 (Synthesizable)
// ============================================================================

module configuration (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_enable,
    input  wire [7:0]  address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data
);

    // ========================================================================
    // Localparams & Register Addresses
    // ========================================================================
    localparam ADDR_CONTROL         = 8'h00;
    localparam ADDR_HEARTBEAT_CFG   = 8'h04;
    localparam ADDR_CHALLENGE_CFG   = 8'h08;
    localparam ADDR_PROTOCOL_ENABLE = 8'h0C;
    localparam ADDR_RECOVERY_CFG    = 8'h10;
    localparam ADDR_STATUS          = 8'h14;

    // Default reset values
    localparam DEFAULT_HEARTBEAT_TIMEOUT = 32'd100;
    localparam STATUS_INITIALIZED_BIT    = 32'h0000_0001;

    // Bit Masks for Writable Fields
    // CONTROL: Only CONTROL_HEIMDALL_ENABLE (bit 0)
    localparam MASK_CONTROL         = 32'h0000_0001;
    
    // HEARTBEAT_CFG: Only HEARTBEAT_TIMEOUT (bits [31:0])
    localparam MASK_HEARTBEAT_CFG   = 32'h0000_FFFF;
    
    // CHALLENGE_CFG: Retry Count (bits [7:0]) & Timeout (bits [31:8])
    localparam MASK_CHALLENGE_CFG   = 32'h0000_FFFF;
    
    // PROTOCOL_ENABLE: SPI (bit 0), UART (bit 1), I2C (bit 2), GPIO (bit 3)
    localparam MASK_PROTOCOL_ENABLE = 32'h0000_000F;
    
    // RECOVERY_CFG: AUTO_RECOVERY (bit 0), SAFE_MODE (bit 1)
    localparam MASK_RECOVERY_CFG    = 32'h0000_0003;

    // ========================================================================
    // Internal Registers
    // ========================================================================
    reg [31:0] reg_control;
    reg [31:0] reg_heartbeat_cfg;
    reg [31:0] reg_challenge_cfg;
    reg [31:0] reg_protocol_enable;
    reg [31:0] reg_recovery_cfg;
    reg [31:0] reg_status;

    // ========================================================================
    // Sequential Always Block (Write Logic & Reset)
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            reg_control         <= 32'h0000_0000;
            reg_heartbeat_cfg   <= DEFAULT_HEARTBEAT_TIMEOUT;
            reg_challenge_cfg   <= 32'h0000_0000;
            reg_protocol_enable <= 32'h0000_0000;
            reg_recovery_cfg    <= 32'h0000_0000;
            reg_status          <= STATUS_INITIALIZED_BIT;
        end else if (write_enable) begin
            case (address)
                ADDR_CONTROL: begin
                    reg_control <= (reg_control & ~MASK_CONTROL) | (write_data & MASK_CONTROL);
                end
                ADDR_HEARTBEAT_CFG: begin
                    reg_heartbeat_cfg <= (reg_heartbeat_cfg & ~MASK_HEARTBEAT_CFG) | (write_data & MASK_HEARTBEAT_CFG);
                end
                ADDR_CHALLENGE_CFG: begin
                    reg_challenge_cfg <= (reg_challenge_cfg & ~MASK_CHALLENGE_CFG) | (write_data & MASK_CHALLENGE_CFG);
                end
                ADDR_PROTOCOL_ENABLE: begin
                    reg_protocol_enable <= (reg_protocol_enable & ~MASK_PROTOCOL_ENABLE) | (write_data & MASK_PROTOCOL_ENABLE);
                end
                ADDR_RECOVERY_CFG: begin
                    reg_recovery_cfg <= (reg_recovery_cfg & ~MASK_RECOVERY_CFG) | (write_data & MASK_RECOVERY_CFG);
                end
                ADDR_STATUS: begin
                    // Read-only register: writes are ignored
                end
                default: begin
                    // Invalid addresses: ignore writes
                end
            endcase
        end
    end

    // ========================================================================
    // Combinational Always Block (Continuous Read Logic)
    // ========================================================================
    always @(*) begin
        case (address)
            ADDR_CONTROL:         read_data = reg_control;
            ADDR_HEARTBEAT_CFG:   read_data = reg_heartbeat_cfg;
            ADDR_CHALLENGE_CFG:   read_data = reg_challenge_cfg;
            ADDR_PROTOCOL_ENABLE: read_data = reg_protocol_enable;
            ADDR_RECOVERY_CFG:    read_data = reg_recovery_cfg;
            ADDR_STATUS:          read_data = reg_status;
            default:              read_data = 32'h0000_0000;
        endcase
    end

endmodule