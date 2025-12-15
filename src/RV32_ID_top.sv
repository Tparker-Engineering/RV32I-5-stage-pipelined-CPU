`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2025 04:27:41 PM
// Design Name: 
// Module Name: RV32_ID_top
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
module RV32_ID_top(
    input clk,
    input reset,
    input [31:0] pc_in,
    input [31:0] iw_in,
    output [4:0] regif_rs1_reg,
    output [4:0] regif_rs2_reg,
    input [31:0] regif_rs1_data,
    input [31:0] regif_rs2_data,

    // Data forwarding
    input        df_ex_enable,
    input [4:0]  df_ex_reg,
    input [31:0] df_ex_data,
    input        df_mem_enable,
    input [4:0]  df_mem_reg,
    input [31:0] df_mem_data,
    input        df_wb_enable,
    input [4:0]  df_wb_reg,
    input [31:0] df_wb_data,

    // Hazard control
    input        df_wb_from_mem_ex,
    input        df_wb_from_mem_mem,

    output logic jump_enable_out,
    output logic [31:0] jump_addr_out,

    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [31:0] reg_rs1_data_out,
    output reg [31:0] reg_rs2_data_out,
    output reg [4:0] wb_reg_out,
    output reg [1:0] wb_src_out,
    output reg we_out,
    output reg wb_enable_out,
    output reg halt_pipeline,

    output logic wb_from_mem_out
);

    //assign regif_rs1_reg = iw_in[19:15];
    //assign regif_rs2_reg = iw_in[24:20];
    
    logic save_valid;
    logic [31:0] saved_pc, saved_iw;
    
    assign regif_rs1_reg = (save_valid) ? saved_iw[19:15] : iw_in[19:15];
    assign regif_rs2_reg = (save_valid) ? saved_iw[24:20] : iw_in[24:20];
    
    wire [6:0] opcode = (save_valid) ? saved_iw[6:0] : iw_in[6:0];
    wire [2:0] funct3 = (save_valid) ? saved_iw[14:12] : iw_in[14:12];
    logic [31:0] imm_jal = (save_valid) ? {{12{saved_iw[31]}}, saved_iw[19:12], saved_iw[20], saved_iw[30:21], 1'b0}
                                        :{{12{iw_in[31]}}, iw_in[19:12], iw_in[20], iw_in[30:21], 1'b0};
    logic [31:0] imm_branch = (save_valid) ? {{20{saved_iw[31]}}, saved_iw[7], saved_iw[30:25], saved_iw[11:8], 1'b0}
                                           : {{20{iw_in[31]}}, iw_in[7], iw_in[30:25], iw_in[11:8], 1'b0};
    logic [31:0] imm_jalr = (save_valid) ? {{20{saved_iw[31]}}, saved_iw[31:20]}
                                         : {{20{iw_in[31]}}, iw_in[31:20]};

    
    logic flush_next;
    logic [31:0] rs1_val, rs2_val;
    logic [1:0] wb_src_next;

    assign wb_from_mem_out = (opcode == 7'b0000011); // LOAD

    wire stall_ex = df_wb_from_mem_ex &&
        ((df_ex_reg == regif_rs1_reg && regif_rs1_reg != 0) ||
         (df_ex_reg == regif_rs2_reg && regif_rs2_reg != 0));

    wire stall_mem = df_wb_from_mem_mem && (opcode == 7'b1100011) &&
        ((df_mem_reg == regif_rs1_reg && regif_rs1_reg != 0) ||
         (df_mem_reg == regif_rs2_reg && regif_rs2_reg != 0));

    assign halt_pipeline = stall_ex || stall_mem;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            flush_next <= 0;
        else
            flush_next <= jump_enable_out;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            save_valid <= 0;
            saved_pc <= 0;
            saved_iw <= 0;
        end else if (stall_ex && !save_valid) begin
            saved_pc <= pc_in;
            saved_iw <= iw_in;
            save_valid <= 1;
        end else if (!stall_ex && !stall_mem && save_valid) begin
            save_valid <= 0;
        end
    end

    always_comb begin
        // Forwarding logic
        if (regif_rs1_reg != 0) begin
            if (df_ex_enable && df_ex_reg == regif_rs1_reg)
                rs1_val = df_ex_data;
            else if (df_mem_enable && df_mem_reg == regif_rs1_reg &&
                     !(df_ex_enable && df_ex_reg == regif_rs1_reg))
                rs1_val = df_mem_data;
            else if (df_wb_enable && df_wb_reg == regif_rs1_reg &&
                     !(df_ex_enable && df_ex_reg == regif_rs1_reg) &&
                     !(df_mem_enable && df_mem_reg == regif_rs1_reg))
                rs1_val = df_wb_data;
            else
                rs1_val = regif_rs1_data;
        end else rs1_val = 0;

        if (regif_rs2_reg != 0) begin
            if (df_ex_enable && df_ex_reg == regif_rs2_reg)
                rs2_val = df_ex_data;
            else if (df_mem_enable && df_mem_reg == regif_rs2_reg &&
                     !(df_ex_enable && df_ex_reg == regif_rs2_reg))
                rs2_val = df_mem_data;
            else if (df_wb_enable && df_wb_reg == regif_rs2_reg &&
                     !(df_ex_enable && df_ex_reg == regif_rs2_reg) &&
                     !(df_mem_enable && df_mem_reg == regif_rs2_reg))
                rs2_val = df_wb_data;
            else
                rs2_val = regif_rs2_data;
        end else rs2_val = 0;

        // Jump detection
        jump_enable_out = 0;
        jump_addr_out = 0;
        if (!flush_next) begin
            case (opcode)
                7'b1101111: begin
                    jump_enable_out = 1;
                    jump_addr_out = pc_in + imm_jal;
                end
                7'b1100111: begin
                    jump_enable_out = 1;
                    jump_addr_out = (rs1_val + imm_jalr) & ~32'b1;
                end
                7'b1100011: begin
                    case (funct3)
                        3'b000: if (rs1_val == rs2_val) jump_enable_out = 1;
                        3'b001: if (rs1_val != rs2_val) jump_enable_out = 1;
                        3'b100: if ($signed(rs1_val) < $signed(rs2_val)) jump_enable_out = 1;
                        3'b101: if ($signed(rs1_val) >= $signed(rs2_val)) jump_enable_out = 1;
                        3'b110: if (rs1_val < rs2_val) jump_enable_out = 1;
                        3'b111: if (rs1_val >= rs2_val) jump_enable_out = 1;
                    endcase
                    if (jump_enable_out)
                        jump_addr_out = pc_in + imm_branch;
                end
            endcase
        end

        // WB source
        wb_src_next = 2'b00;
        if (opcode == 7'b0000011)
            wb_src_next = (iw_in[31]) ? 2'b10 : 2'b01;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out <= 0;
            iw_out <= 0;
            reg_rs1_data_out <= 0;
            reg_rs2_data_out <= 0;
            wb_reg_out <= 0;
            we_out <= 0;
            wb_src_out <= 0;
            wb_enable_out <= 0;
        end else if (stall_ex) begin
            // NOP while EX hazard 
            iw_out <= 32'h00000013;
            pc_out <= 0;
            reg_rs1_data_out <= 0;
            reg_rs2_data_out <= 0;
            wb_reg_out <= 0;
            we_out <= 0;
            wb_enable_out <= 0;
            wb_src_out <= 2'b00;
        end else if (stall_mem) begin
            // Hold outputs
            iw_out <= iw_out;
            pc_out <= pc_out;
            reg_rs1_data_out <= reg_rs1_data_out;
            reg_rs2_data_out <= reg_rs2_data_out;
            wb_reg_out <= wb_reg_out;
            we_out <= we_out;
            wb_enable_out <= wb_enable_out;
            wb_src_out <= wb_src_out;
        end else if (save_valid && !stall_ex && !stall_mem) begin
            // Replay saved iw
            iw_out <= saved_iw;
            pc_out <= saved_pc;
            reg_rs1_data_out <= rs1_val;
            reg_rs2_data_out <= rs2_val;
            wb_reg_out <= saved_iw[11:7];
            we_out <= (saved_iw[6:0] == 7'b0100011);
            wb_src_out <= wb_src_next;
            wb_enable_out <= (saved_iw[6:0] == 7'b0000011 ||
                              saved_iw[6:0] == 7'b0010011 ||
                              saved_iw[6:0] == 7'b0110011 ||
                              saved_iw[6:0] == 7'b0110111 ||
                              saved_iw[6:0] == 7'b1100111 ||
                              saved_iw[6:0] == 7'b1101111);
        end else if (flush_next) begin
            // Flush after jump
            iw_out <= 32'h00000013;
            reg_rs1_data_out <= 0;
            reg_rs2_data_out <= 0;
            wb_reg_out <= 0;
            wb_enable_out <= 0;
            wb_src_out <= 2'b00;
            we_out <= 0;
        end else begin
            // Normal
            iw_out <= iw_in;
            pc_out <= pc_in;
            reg_rs1_data_out <= rs1_val;
            reg_rs2_data_out <= rs2_val;
            wb_reg_out <= iw_in[11:7];
            we_out <= (opcode == 7'b0100011);
            wb_src_out <= wb_src_next;
            wb_enable_out <= (opcode == 7'b0000011 ||
                              opcode == 7'b0010011 ||
                              opcode == 7'b0110011 ||
                              opcode == 7'b0110111 ||
                              opcode == 7'b1100111 ||
                              opcode == 7'b1101111);
        end
    end

endmodule