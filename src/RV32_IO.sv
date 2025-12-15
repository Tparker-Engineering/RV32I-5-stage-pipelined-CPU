`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/10/2025 08:53:54 PM
// Design Name: 
// Module Name: RV32_IO
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
module RV32_IO(
    input clk,
    input reset,

    input [31:2] io_addr,
    input [31:0] io_wdata,
    input io_we,
    input [3:0] io_be,
    output logic [31:0] io_rdata,

    input [3:0] pushbuttons,
    output reg [9:0] leds
);
    // IO-mapped addresses
    localparam ADDR_LED  = 2'b01;  // 0x80000004
    localparam ADDR_PB   = 2'b00;  // 0x80000000

    always_ff @(posedge clk) begin
        if (reset) begin
            leds <= 10'b0;
            io_rdata <= 32'b0;
        end else begin
            // Handle writes
            if (io_we) begin
                case (io_addr[3:2])
                    ADDR_LED: begin
                        if (io_be[0]) leds[7:0]   <= io_wdata[7:0];
                        if (io_be[1]) leds[9:8]   <= io_wdata[9:8];
                    end
                endcase
            end

            // Handle reads (registered output)
            case (io_addr[3:2])
                ADDR_PB: io_rdata <= {28'b0, pushbuttons};
                default: io_rdata <= 32'b0;
            endcase
        end
    end
    
endmodule

