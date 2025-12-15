`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2025 01:14:36 PM
// Design Name: 
// Module Name: RV32_MEM_top
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
module RV32_MEM_top(
    input clk,
    input reset,
    input [31:0] pc_in,
    input logic [31:0] iw_in,
    input [31:0] alu_in,
    input [4:0] wb_reg_in,
    input  we_in,
    input wb_enable_in,
    input [31:0] rs2_data_in,

    // Memory interface
    output logic [31:2] memif_addr,
    input [31:0] memif_rdata,
    output logic memif_we,
    input  [1:0] wb_src_in,
    output reg [1:0] wb_src_out,
    output reg we_out,
    output logic [3:0] memif_be,
    output logic [31:0] memif_wdata,

    // IO interface
    output logic [31:2] io_addr,
    input [31:0] io_rdata,
    output logic io_we,
    output logic [3:0] io_be,
    output logic [31:0] io_wdata,

    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] alu_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,

    // Load results to WB stage
    output logic [31:0] mem_rdata_out,
    output logic [31:0] io_rdata_out,

    // Data forwarding
    output logic df_mem_enable,
    output logic [4:0] df_mem_reg,
    output logic [31:0] df_mem_data,

    //Indicate load-type writeback
    output logic wb_from_mem_out
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out <= 0;
            iw_out <= 0;
            alu_out <= 0;
            we_out <= 0;
            wb_reg_out <= 0;
            wb_enable_out <= 0;
            wb_src_out <= 0;
        end else begin
            pc_out <= pc_in;
            iw_out <= iw_in;
            alu_out <= alu_in;
            we_out <= we_in;
            wb_reg_out <= wb_reg_in;
            wb_enable_out <= wb_enable_in;
            
            if (wb_src_in == 2'b01) begin // load
                if (alu_in[31] == 1'b1)
                    wb_src_out <= 2'b10; // IO load
                else
                    wb_src_out <= 2'b01; // MEM load
            end else begin
                wb_src_out <= wb_src_in;
            end
        end
    end

    assign df_mem_enable = wb_enable_in;
    assign df_mem_reg = wb_reg_in;
    assign df_mem_data = alu_in;

    logic is_store;
    assign is_store = (iw_in[6:0] == 7'b0100011);  // STORE opcode

    // Byte enable logic
    logic [3:0] store_be;
    always_comb begin
        case (iw_in[14:12])
            3'b000: store_be = 4'b0001 << alu_in[1:0];              // SB
            3'b001: store_be = (alu_in[1]) ? 4'b1100 : 4'b0011;     // SH
            3'b010: store_be = 4'b1111;                             // SW
            default: store_be = 4'b0000;
        endcase
    end

    // Shifter
    logic [31:0] shifted_wdata;
    always_comb begin
        case (iw_in[14:12])
            3'b000: shifted_wdata = rs2_data_in[7:0] << (8 * alu_in[1:0]);
            3'b001: shifted_wdata = rs2_data_in[15:0] << (8 * {alu_in[1], 1'b0});
            3'b010: shifted_wdata = rs2_data_in;
            default: shifted_wdata = 32'b0;
        endcase
    end

    always_comb begin
        // Default
        memif_addr = alu_in[31:2];
        io_addr    = alu_in[31:2];

        memif_wdata = shifted_wdata;
        io_wdata    = shifted_wdata;

        memif_we = 0;
        io_we    = 0;

        memif_be = 4'b0000;
        io_be    = 4'b0000;

        if (is_store && we_in) begin
            if (alu_in[31] == 0) begin
                memif_we = 1;
                memif_be = store_be;
            end else begin
                io_we = 1;
                io_be = store_be;
            end
        end
    end

    assign mem_rdata_out = memif_rdata;
    assign io_rdata_out  = io_rdata;

    assign wb_from_mem_out = (wb_src_in == 2'b01 || wb_src_in == 2'b10);

endmodule