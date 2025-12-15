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
module ALU(
    input logic [31:0] iw_in,        // Instruction word input (32 bits)
    input logic [31:0] pc_in,        // Program counter input (32 bits)
    input logic [31:0] rs1_data_in,  // Register 1 input (32 bits)
    input logic [31:0] rs2_data_in,  // Register 2 input (32 bits)
    output logic [31:0] alu_out      // ALU result output (32 bits)
);

    // Declare the instruction components
    logic [6:0] opcode;     // opcode (7 bits)
    logic [2:0] funct3;     // funct3 (3 bits)
    logic [6:0] funct7;     // funct7 (7 bits)
    logic [31:0] imm;       // Immediate value (32 bits)
    logic [4:0] shamt;      // Shift amount (5 bits)
    logic [31:0] imm_s;     // Immediate for S-type instructions (12 bits, signed extended)
    logic [31:0] imm_j;     // Immediate for J-type instructions (20 bits, signed extended)

    // Extract opcode, funct3, funct7, and immediate from instruction word
    always_comb begin
        opcode = iw_in[6:0];
        funct3 = iw_in[14:12];
        funct7 = iw_in[31:25];
        imm = iw_in[31:20];  // I-type and other immediate instructions
        shamt = iw_in[24:20];  // For shift operations (shamt field)
        
        // Handle I-type immediate (sign-extended 20 bits)
        imm = {{20{iw_in[31]}}, iw_in[31:20]};
        
        // Handle J-type immediate (sign-extended 20 bits)
        imm_j = {{11{iw_in[31]}}, iw_in[19:12], iw_in[20], iw_in[30:21]};

        // Handle S-type immediate (sign-extended 12 bits)
        imm_s = {{20{iw_in[31]}}, iw_in[31:25], iw_in[11:7]};
    end

    // ALU Operations Logic based on opcode, funct3, funct7, and immediate
    always_comb begin
        case (opcode)
            7'b0110011: begin  // R-type (ADD, SUB, etc.)    
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin  // ADD
                            alu_out = rs1_data_in + rs2_data_in;
                        end else if (funct7 == 7'b0100000) begin  // SUB
                            alu_out = rs1_data_in - rs2_data_in;
                        end
                    end
                    3'b001: begin  // SLL (Shift left logical)
                        alu_out = rs1_data_in << rs2_data_in[4:0];
                    end
                    3'b010: begin  // SLT (Set less than)
                        alu_out = $signed(rs1_data_in) < $signed(rs2_data_in) ? 1 : 0;
                    end
                    3'b011: begin  // SLTU (Set less than unsigned)
                        alu_out = $unsigned(rs1_data_in) < $unsigned(rs2_data_in) ? 1 : 0;
                    end
                    3'b100: begin  // XOR (Exclusive OR)
                        alu_out = rs1_data_in ^ rs2_data_in;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin  // SRL (Shift right logical)
                            alu_out = rs1_data_in >> rs2_data_in[4:0];
                        end else if (funct7 == 7'b0100000) begin  // SRA (Shift right arithmetic)
                            alu_out = $signed(rs1_data_in) >>> rs2_data_in[4:0];
                        end
                    end
                    3'b110: begin  // OR (Logical OR)
                        alu_out = rs1_data_in | rs2_data_in;
                    end
                    3'b111: begin  // AND (Logical AND)
                        alu_out = rs1_data_in & rs2_data_in;
                    end
                endcase
            end
            7'b0010011: begin  // I-type (ADDI, ANDI, etc.)
                case (funct3)
                    3'b000: begin  // ADDI (Add immediate)
                        alu_out = rs1_data_in + $signed(imm);
                    end
                    3'b001: begin  // SLLI (Shift left immediate)
                        alu_out = rs1_data_in << shamt;
                    end
                    3'b010: begin  // SLTI (Set less than immediate)
                        alu_out = $signed(rs1_data_in) < $signed(imm) ? 1 : 0;
                    end
                    3'b011: begin  // SLTIU (Set less than unsigned immediate)
                        alu_out = $unsigned(rs1_data_in) < $unsigned(imm) ? 1 : 0;
                    end
                    3'b100: begin  // XORI (XOR immediate)
                        alu_out = rs1_data_in ^ $signed(imm);
                    end
                    3'b110: begin  // ORI (OR immediate)
                        alu_out = rs1_data_in | $signed(imm);
                    end
                    3'b111: begin  // ANDI (AND immediate)
                        alu_out = rs1_data_in & $signed(imm);
                    end
                endcase
            end
            7'b0000011: begin  // Load instructions (LB, LH, LW, LBU, LHU)
                case (funct3)
                    3'b000: begin  // LB (Load Byte)
                        alu_out = $signed(rs1_data_in + $signed(imm));  // sign-extend byte
                    end
                    3'b001: begin  // LH (Load Half-Word)
                        alu_out = $signed(rs1_data_in + $signed(imm));  // sign-extend half-word
                    end
                    3'b010: begin  // LW (Load Word)
                        alu_out = rs1_data_in + $signed(imm);  // no sign extension needed, load word
                    end
                    3'b100: begin  // LBU (Load Byte Unsigned)
                        alu_out = {24'b0, rs1_data_in + $unsigned(imm)};  // zero-extend byte
                    end
                    3'b101: begin  // LHU (Load Half-Word Unsigned)
                        alu_out = {16'b0, rs1_data_in + $unsigned(imm)};  // zero-extend half-word
                    end
                endcase
            end
            // Add store instructions (SB, SH, SW)
            7'b0100011: begin  // S-type (SB, SH, SW)
                case (funct3)
                    3'b000: begin  // SB (Store Byte)
                        alu_out = rs1_data_in + $signed(imm_s);  // Calculate address
                        // Store byte logic (write to memory, not implemented here)
                    end
                    3'b001: begin  // SH (Store Half-Word)
                        alu_out = rs1_data_in + $signed(imm_s);  // Calculate address
                        // Store half-word logic (write to memory, not implemented here)
                    end
                    3'b010: begin  // SW (Store Word)
                        alu_out = rs1_data_in + $signed(imm_s);  // Calculate address
                        // Store word logic (write to memory, not implemented here)
                    end
                endcase
            end
            7'b1101111: begin  // JAL (Jump and Link)
                // JAL only computes the jump target address
                alu_out = pc_in + 2 * $signed(imm_j);  // Target address calculation
            end

            7'b1100111: begin  // JALR (Jump and Link Register)
                // JALR only computes the jump target address
                alu_out = rs1_data_in + $signed({{20{imm[11]}}, imm});  // Target address calculation
                alu_out[0] = 1'b0;
            end

            7'b0110111: begin  // LUI (Load Upper Immediate)
                alu_out = {iw_in[31:12], 12'b0};  // Place the immediate in the upper 20 bits
            end

            7'b0010111: begin  // AUIPC (Add Upper Immediate to PC)
                alu_out = pc_in + (imm << 12);  // Add the upper immediate to the program counter
            end

            default: begin
                alu_out = 32'b0;  // Default to zero (NOP or invalid)
            end
        endcase
    end    
endmodule