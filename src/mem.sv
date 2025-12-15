`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2025 11:00:27 PM
// Design Name: 
// Module Name: mem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module dual_port_ram(
    input clk,
    // Instruction port
    input [31:2] i_addr,
    output reg [31:0] i_rdata,
    // Data port
    input [31:2] d_addr,
    output reg [31:0] d_rdata,
    input d_we,
    input [3:0] d_be,
    input [31:0] d_wdata
);
    
    parameter ADDR_WIDTH = 14;
    // Memory array: 32K x 32b
    reg [31:0] ram [2**ADDR_WIDTH-1:0];

    // Load memory init file
    initial begin
        $readmemh("stop_go.mem", ram);
    end

    // Instruction port(read)
    always_ff @(posedge clk) begin
        i_rdata <= ram[i_addr];
    end

    // Data port(write & read)
    always_ff @(posedge clk) begin
        if (d_we) begin
            if (d_be[0]) ram[d_addr][7:0] <= d_wdata[7:0];
            if (d_be[1]) ram[d_addr][15:8] <= d_wdata[15:8];
            if (d_be[2]) ram[d_addr][23:16] <= d_wdata[23:16];
            if (d_be[3]) ram[d_addr][31:24] <= d_wdata[31:24];
        end else begin
        d_rdata <= ram[d_addr];
        end
    end
endmodule
