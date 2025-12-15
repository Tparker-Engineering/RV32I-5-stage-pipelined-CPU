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
module RV32_IF_top(
    input clk,
    input reset,
    input halt_pipeline,
    input jump_enable_in,
    input [31:0] jump_addr_in,
    output [31:2] memif_addr,
    input [31:0] memif_data,
    output reg [31:0] pc_out,
    output [31:0] iw_out
);
    reg [31:0] pc;
    parameter PC_RESET = 32'h00000000;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            pc     <= PC_RESET;
            pc_out <= PC_RESET;
        end
        else if (!halt_pipeline) begin
            // Output current PC of fetched instruction
            pc_out <= pc;
            
            // Update PC for the next cycle
            if (jump_enable_in) begin
                pc <= jump_addr_in;  // Jump target becomes next PC
            end
            else begin
                pc <= pc + 4;        // Sequentially increment PC
            end
        end
    end
    
    assign memif_addr = pc[31:2];
    assign iw_out = memif_data;

endmodule