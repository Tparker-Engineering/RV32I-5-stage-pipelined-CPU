`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2025 01:36:11 PM
// Design Name: 
// Module Name: RV32_IF_top
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
module regs(
    input clk,              
    input reset,           
    
    // Register read 
    input [4:0] rs1_reg,    
    input [4:0] rs2_reg,    
    
    // Writeback 
    input wb_enable,        
    input [4:0] wb_reg,     
    input [31:0] wb_data,   
    
    // Outputs for read data
    output [31:0] rs1_data, 
    output [31:0] rs2_data  
);

    // 32 registers, 32 bits wide
    logic [31:0] registers [31:0];

    // Synchronous reset
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end
        // Writeback on positive edge 
        else if (wb_enable && wb_reg != 5'b00000) begin
            registers[wb_reg] <= wb_data;  // Write only if not x0
        end
    end

    //Asynchronous read
    assign rs1_data = (rs1_reg == 5'b00000) ? 32'b0 : registers[rs1_reg];
    assign rs2_data = (rs2_reg == 5'b00000) ? 32'b0 : registers[rs2_reg];

endmodule