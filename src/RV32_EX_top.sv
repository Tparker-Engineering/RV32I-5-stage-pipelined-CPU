`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2025 12:49:55 PM
// Design Name: 
// Module Name: RV32_EX_top
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
module RV32_EX_top(
    input logic clk,
    input logic reset,
    
    // From ID stage
    input logic [31:0] pc_in,
    input logic [31:0] iw_in,
    input logic [31:0] rs1_data_in,
    input logic [31:0] rs2_data_in,
    input logic [4:0] wb_reg_in,
    input logic wb_enable_in,
    input logic we_in,
    input [1:0] wb_src_in,

    // Forwarding from WB
    input logic df_wb_from_mem_wb,
    input logic [4:0] df_wb_reg,
    input logic [31:0] df_wb_data,

    // To MEM stage
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] alu_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,
    output reg we_out,
    output reg [1:0] wb_src_out,
    
    output logic [31:0] rs2_data_out,
    
    output logic wb_from_mem_out,
    
    // Forwarding outputs to ID
    output logic df_ex_enable,
    output logic [4:0] df_ex_reg,
    output logic [31:0] df_ex_data
);

    logic [31:0] rs1_val, rs2_val;

    always_comb begin
        rs1_val = rs1_data_in;
        rs2_val = rs2_data_in;

        if (df_wb_from_mem_wb && df_wb_reg != 0) begin
            if (df_wb_reg == iw_in[19:15])  // rs1
                rs1_val = df_wb_data;
            if (df_wb_reg == iw_in[24:20])  // rs2
                rs2_val = df_wb_data;
        end
    end

    // ALU instantiation
    logic[31:0] alu_result;
    ALU alu(
        .iw_in(iw_in),
        .pc_in(pc_in),
        .rs1_data_in(rs1_val),
        .rs2_data_in(rs2_val),
        .alu_out(alu_result)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 32'b0;
            iw_out <= 32'b0;
            alu_out <= 32'b0;
            we_out <= 1'b0;
            rs2_data_out <= 32'b0;
            wb_reg_out <= 5'b0;
            wb_enable_out <= 1'b0;
            wb_src_out <= 2'b00;
        end else begin  
            pc_out <= pc_in;
            iw_out <= iw_in;
            we_out <= we_in;
            alu_out <= alu_result;
            rs2_data_out <= rs2_val;
            wb_reg_out <= wb_reg_in;
            wb_enable_out <= wb_enable_in;
            wb_src_out <= wb_src_in;
        end
    end

    // Forwarding to ID
    assign df_ex_enable = wb_enable_in;
    assign df_ex_reg = wb_reg_in;
    assign df_ex_data = alu_result;
    
    assign wb_from_mem_out = (wb_src_in == 2'b01 || wb_src_in == 2'b10);

endmodule

