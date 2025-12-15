`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2025 04:18:01 PM
// Design Name: 
// Module Name: RV32_WB_top
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
module RV32_WB_top(
    input clk,
    input reset,
    input [31:0] pc_in,
    input [31:0] iw_in,
    input [31:0] alu_in,
    input [31:0] mem_rdata_in,      
    input [31:0] io_rdata_in,       
    input [4:0] wb_reg_in,
    input wb_enable_in,
    input [1:0] wb_src_in,

    output logic [4:0] regif_wb_reg,
    output logic regif_wb_enable,
    output logic [31:0] regif_wb_data,

    output logic df_wb_enable,
    output logic [4:0] df_wb_reg,
    output logic [31:0] df_wb_data,
    
    output logic wb_from_mem_out
);

    logic [31:0] load_data;
    logic [31:0] rdata;

    always_comb begin
        // Select memory or IO read data
        case (wb_src_in)
            2'b01: rdata = mem_rdata_in;
            2'b10: rdata = io_rdata_in;
            default: rdata = alu_in;  // ALU result (no load)
        endcase

        // Load shifter
        if (iw_in[6:0] == 7'b0000011) begin  // LOAD opcode
            case (iw_in[14:12])
                3'b000: begin  // LB
                    case (alu_in[1:0])
                        2'b00: load_data = {{24{rdata[7]}},  rdata[7:0]};
                        2'b01: load_data = {{24{rdata[15]}}, rdata[15:8]};
                        2'b10: load_data = {{24{rdata[23]}}, rdata[23:16]};
                        2'b11: load_data = {{24{rdata[31]}}, rdata[31:24]};
                    endcase
                end
                3'b001: begin  // LH
                    case (alu_in[1])
                        1'b0: load_data = {{16{rdata[15]}}, rdata[15:0]};
                        1'b1: load_data = {{16{rdata[31]}}, rdata[31:16]};
                    endcase
                end
                3'b010: load_data = rdata; // LW
                3'b100: begin  // LBU
                    case (alu_in[1:0])
                        2'b00: load_data = {24'b0, rdata[7:0]};
                        2'b01: load_data = {24'b0, rdata[15:8]};
                        2'b10: load_data = {24'b0, rdata[23:16]};
                        2'b11: load_data = {24'b0, rdata[31:24]};
                    endcase
                end
                3'b101: begin  // LHU
                    case (alu_in[1])
                        1'b0: load_data = {16'b0, rdata[15:0]};
                        1'b1: load_data = {16'b0, rdata[31:16]};
                    endcase
                end
                default: load_data = 32'b0;
            endcase
        end else begin
            load_data = rdata;  // ALU result
        end
    end

    // Register file write-back
    assign regif_wb_enable = wb_enable_in;
    assign regif_wb_reg    = wb_reg_in;
    assign regif_wb_data   = load_data;

    // Data forwarding
    assign df_wb_enable = wb_enable_in;
    assign df_wb_reg    = wb_reg_in;
    assign df_wb_data   = load_data;

    // Load forwarding signal
    assign wb_from_mem_out = (wb_src_in == 2'b01 || wb_src_in == 2'b10);

endmodule
