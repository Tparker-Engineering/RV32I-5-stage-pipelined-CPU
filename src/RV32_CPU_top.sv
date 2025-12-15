`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2025 12:27:26 PM
// Design Name: 
// Module Name: RV32_cpu_pipeline
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
module RV32_CPU_top(
    input CLK100,
    output [9:0] LED,
    output [2:0] RGB0,
    output [2:0] RGB1,
    output [3:0] SS_ANODE,
    output [7:0] SS_CATHODE,
    input [11:0] SW,
    input [3:0] PB,
    inout [23:0] GPIO,
    output [3:0] SERVO,
    output PDM_SPEAKER,
    input PDM_MIC_DATA,
    output PDM_MIC_CLK,
    output ESP32_UART1_TXD,
    input ESP32_UART1_RXD,
    output IMU_SCLK,
    output IMU_SDI,
    input IMU_SDO_AG,
    input IMU_SDO_M,
    output IMU_CS_AG,
    output IMU_CS_M,
    input IMU_DRDY_M,
    input IMU_INT1_AG,
    input IMU_INT_M,
    output IMU_DEN_AG
);
    assign RGB0 = 3'b000;
    assign RGB1 = 3'b000;
    assign GPIO[15:0] = 16'bzzzzzzzzzzzzzzzz;
    assign GPIO[23:20] = 4'bzzzz;
    assign GPIO[18] = 1'bz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;

    wire clk = CLK100;
    reg reset, reset_sync_ff1;

    always_ff @(posedge clk) begin
        reset_sync_ff1 <= PB[0];
        reset <= reset_sync_ff1;
    end

    // IF stage
    wire [31:2] memif_addr;
    wire [31:0] pc_if_out, iw_if_out;
    wire halt_pipeline;

    // RAM interface
    reg [31:2] i_addr;
    reg [31:0] i_rdata, d_rdata, d_wdata;
    reg d_we;
    reg [3:0] d_be;
    wire [31:2] d_addr;

    // I/O interface
    wire [31:2] io_addr;
    wire [31:0] io_rdata, io_wdata;
    wire [3:0] io_be;
    wire io_we;

    // Reg interface
    wire [31:0] rs1_data_reg_out, rs2_data_reg_out;
    wire [4:0] reg_rs1_id_out, reg_rs2_id_out;

    wire jump_enable;
    wire [31:0] jump_addr;

    // ID Stage
    wire [31:0] pc_id_out, iw_id_out;
    wire [31:0] rs1_data_id_out, rs2_data_id_out;
    wire [4:0] wb_reg_id_out;
    wire wb_enable_id_out;
    wire [1:0] wb_src_id_out;
    wire we_id_out;

    // EX Stage
    wire [31:0] pc_ex_out, iw_ex_out, alu_ex_out;
    wire [4:0] wb_reg_ex_out;
    wire wb_enable_ex_out, we_ex_out;
    wire [31:0] rs2_data_ex_out;
    wire [1:0] wb_src_ex_out;

    // MEM Stage
    wire [31:0] pc_mem_out, iw_mem_out, alu_mem_out;
    wire [4:0] wb_reg_mem_out;
    wire wb_enable_mem_out;
    wire [1:0] wb_src_mem_out;
    wire [31:0] mem_rdata_mem_out, io_rdata_mem_out;

    // WB Stage
    wire [31:0] wb_reg_data_out;
    wire [4:0] wb_reg_wb_out;
    wire wb_enable_wb_out;

    // Forwarding and hazard
    wire df_ex_enable;
    wire [4:0] df_ex_reg;
    wire [31:0] df_ex_data;

    wire df_mem_enable;
    wire [4:0] df_mem_reg;
    wire [31:0] df_mem_data;

    wire df_wb_enable;
    wire [4:0] df_wb_reg;
    wire [31:0] df_wb_data;

    wire wb_from_mem_id_out;
    wire wb_from_mem_ex_out;
    wire wb_from_mem_mem_out;
    wire wb_from_mem_wb_out;

    RV32_IF_top if_ (
        .clk(clk),
        .reset(reset),
        .jump_enable_in(jump_enable),
        .jump_addr_in(jump_addr),
        .halt_pipeline(halt_pipeline),
        .memif_addr(memif_addr),
        .memif_data(i_rdata),
        .pc_out(pc_if_out),
        .iw_out(iw_if_out)
    );

    dual_port_ram memory (
        .clk(clk),
        .i_addr(memif_addr),
        .i_rdata(i_rdata),
        .d_addr(d_addr),
        .d_rdata(d_rdata),
        .d_we(d_we),
        .d_be(d_be),
        .d_wdata(d_wdata)
    );

    RV32_IO io (
        .clk(clk),
        .reset(reset),
        .io_addr(io_addr),
        .io_wdata(io_wdata),
        .io_we(io_we),
        .io_be(io_be),
        .io_rdata(io_rdata),
        .pushbuttons(PB),
        .leds(LED)
    );

    regs regs (
        .clk(clk),
        .reset(reset),
        .rs1_reg(reg_rs1_id_out),
        .rs2_reg(reg_rs2_id_out),
        .rs1_data(rs1_data_reg_out),
        .rs2_data(rs2_data_reg_out),
        .wb_enable(wb_enable_wb_out),
        .wb_reg(wb_reg_wb_out),
        .wb_data(wb_reg_data_out)
    );

    RV32_ID_top id (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_if_out),
        .iw_in(iw_if_out),
        .regif_rs1_data(rs1_data_reg_out),
        .regif_rs2_data(rs2_data_reg_out),
        .regif_rs1_reg(reg_rs1_id_out),
        .regif_rs2_reg(reg_rs2_id_out),
        .reg_rs1_data_out(rs1_data_id_out),
        .reg_rs2_data_out(rs2_data_id_out),
        .pc_out(pc_id_out),
        .iw_out(iw_id_out),
        .wb_reg_out(wb_reg_id_out),
        .wb_enable_out(wb_enable_id_out),
        .wb_src_out(wb_src_id_out),
        .we_out(we_id_out),
        .halt_pipeline(halt_pipeline),
        .jump_enable_out(jump_enable),
        .jump_addr_out(jump_addr),
        .df_ex_enable(df_ex_enable),
        .df_ex_reg(df_ex_reg),
        .df_ex_data(df_ex_data),
        .df_mem_enable(df_mem_enable),
        .df_mem_reg(df_mem_reg),
        .df_mem_data(df_mem_data),
        .df_wb_enable(df_wb_enable),
        .df_wb_reg(df_wb_reg),
        .df_wb_data(df_wb_data),
        .df_wb_from_mem_ex(wb_from_mem_ex_out),
        .df_wb_from_mem_mem(wb_from_mem_mem_out),
        .wb_from_mem_out(wb_from_mem_id_out)
    );

    RV32_EX_top ex (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_id_out),
        .iw_in(iw_id_out),
        .rs1_data_in(rs1_data_id_out),
        .rs2_data_in(rs2_data_id_out),
        .wb_reg_in(wb_reg_id_out),
        .wb_enable_in(wb_enable_id_out),
        .we_in(we_id_out),
        .wb_src_in(wb_src_id_out),
        .wb_src_out(wb_src_ex_out),
        .we_out(we_ex_out),
        .pc_out(pc_ex_out),
        .iw_out(iw_ex_out),
        .alu_out(alu_ex_out),
        .rs2_data_out(rs2_data_ex_out),
        .wb_reg_out(wb_reg_ex_out),
        .wb_enable_out(wb_enable_ex_out),
        .df_ex_enable(df_ex_enable),
        .wb_from_mem_out(wb_from_mem_ex_out),
        .df_ex_reg(df_ex_reg),
        .df_ex_data(df_ex_data),
        .df_wb_from_mem_wb(wb_from_mem_wb_out),
        .df_wb_reg(df_wb_reg),
        .df_wb_data(df_wb_data)
    );

    RV32_MEM_top mem (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_ex_out),
        .iw_in(iw_ex_out),
        .alu_in(alu_ex_out),
        .rs2_data_in(rs2_data_ex_out),
        .wb_reg_in(wb_reg_ex_out),
        .wb_enable_in(wb_enable_ex_out),
        .we_in(we_ex_out),
        .pc_out(pc_mem_out),
        .iw_out(iw_mem_out),
        .alu_out(alu_mem_out),
        .wb_reg_out(wb_reg_mem_out),
        .wb_enable_out(wb_enable_mem_out),
        .wb_src_in(wb_src_ex_out),
        .wb_src_out(wb_src_mem_out),
        .we_out(we_mem_out),
        .memif_addr(d_addr),
        .memif_rdata(d_rdata),
        .memif_we(d_we),
        .memif_be(d_be),
        .memif_wdata(d_wdata),
        .io_addr(io_addr),
        .io_rdata(io_rdata),
        .io_we(io_we),
        .io_be(io_be),
        .io_wdata(io_wdata),
        .mem_rdata_out(mem_rdata_mem_out),
        .io_rdata_out(io_rdata_mem_out),
        .df_mem_enable(df_mem_enable),
        .df_mem_reg(df_mem_reg),
        .df_mem_data(df_mem_data),
        .wb_from_mem_out(wb_from_mem_mem_out)
    );

    RV32_WB_top wb (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_mem_out),
        .iw_in(iw_mem_out),
        .alu_in(alu_mem_out),
        .mem_rdata_in(mem_rdata_mem_out),
        .io_rdata_in(io_rdata_mem_out),
        .wb_reg_in(wb_reg_mem_out),
        .wb_enable_in(wb_enable_mem_out),
        .wb_src_in(wb_src_mem_out),
        .regif_wb_enable(wb_enable_wb_out),
        .regif_wb_reg(wb_reg_wb_out),
        .regif_wb_data(wb_reg_data_out),
        .df_wb_enable(df_wb_enable),
        .df_wb_reg(df_wb_reg),
        .df_wb_data(df_wb_data),
        .wb_from_mem_out(wb_from_mem_wb_out)
    );

    ila_0 ila(
        .clk(clk),
        .probe0(iw_if_out),
        .probe1(iw_id_out),
        .probe2(iw_ex_out),
        .probe3(iw_mem_out),
        .probe4(pc_if_out),
        .probe5(pc_id_out),
        .probe6(pc_ex_out),
        .probe7(pc_mem_out),
        .probe8(io_addr),
        .probe9(io_rdata),
        .probe10(io_we),
        .probe11(io_be),
        .probe12(wb_reg_data_out),
        .probe13(wb_reg_wb_out),
        .probe14(jump_enable_out),
        .probe15(reset)
    );
endmodule
