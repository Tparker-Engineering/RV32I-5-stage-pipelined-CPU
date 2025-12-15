# RV32I-5-stage-pipelined-CPU
RV32 (32-bit RISC-V style) CPU core written in SystemVerilog, organized as a 5-stage pipeline with a dual-port RAM and a tiny memory-mapped I/O block (LEDs + pushbuttons).

What’s in this repo

Top level and pipeline stages:

RV32_CPU_top.sv — top-level integration (pipeline + RAM + I/O + regfile)

RV32_IF_top.sv — instruction fetch (PC + instruction port address)

RV32_ID_top.sv — decode + immediate generation + branch/jump decision + hazard control

RV32_EX_top.sv — execute stage with forwarding + ALU

RV32_MEM_top.sv — store byte-enable generation + RAM vs I/O routing for stores

RV32_WB_top.sv — writeback mux + load byte/half selection + sign/zero extension

Core building blocks:

regs.sv — 32x32 register file (x0 hard-wired to 0)

alu.sv — ALU used by EX stage (module name: ALU)

mem.sv — dual-port RAM (module name: dual_port_ram), initialized from stop_go.mem

RV32_IO.sv — memory-mapped I/O (pushbuttons read, LEDs write)

stop_go.mem — program image loaded into RAM with $readmemh

Pipeline overview

Stages and responsibilities:

IF: generates instruction memory address, outputs PC + instruction word

ID: decodes opcode/funct fields, reads register operands, computes branch/jump targets, controls stalling/flush

EX: computes ALU results (arith/logic/address) with forwarding

MEM: performs store formatting (byte enables + shifted store data) and selects RAM vs I/O for stores

WB: selects writeback source and performs load extraction/sign-extension for LB/LH/LBU/LHU

Control-flow handling:

JAL/JALR/branches are resolved in ID; when a jump/branch is taken, the next fetched instruction is flushed.

Data hazards:

load-use hazards stall the pipeline

forwarding paths are used in EX (and an extra stall is applied for branches that depend on a load still in MEM)

Memory system

The memory is a simple dual-port block:

Instruction port: read-only (i_addr -> i_rdata)

Data port: read/write with byte enables (d_addr/d_wdata/d_be/d_we -> d_rdata)

Addresses are word-indexed using bits [31:2].
Default memory depth is 2^ADDR_WIDTH words; in mem.sv the default is ADDR_WIDTH = 14 (16384 words = 64 KiB).

Program initialization:

mem.sv loads stop_go.mem at time 0 using $readmemh("stop_go.mem", ram)

Memory-mapped I/O

Stores are routed to I/O when the computed address has alu_in[31] = 1 (otherwise they go to RAM). I/O uses word offsets io_addr[3:2]:

0x8000_0000: read pushbuttons (returns {28'b0, PB[3:0]})

0x8000_0004: write LEDs (updates LED[9:0], honoring byte-enables)

Loads can write back from either RAM or I/O (WB selects between mem_rdata_in and io_rdata_in). The ID stage tags a load as “I/O load” based on iw_in[31] (the sign bit of the I-type immediate), so I/O loads are expected to be encoded using a negative I-type offset (bit 11 set) consistent with an address in the 0x8000_0000 region.

Implemented instruction classes (decode-level)

RV32_ID_top.sv enables register writeback for these opcode groups:

R-type ALU ops 

I-type ALU ops 

Loads: LB, LH, LW, LBU, LHU (final extraction/signing happens in WB)

Stores: SB, SH, SW (byte-enables generated in MEM)

Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU (decision in ID)

Jumps: JAL and JALR

LUI

x0 is always zero via the regfile implementation in regs.sv.
