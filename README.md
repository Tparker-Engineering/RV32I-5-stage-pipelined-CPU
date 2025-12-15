# RV32I-5-stage-pipelined-CPU
# RV32 Pipelined CPU (SystemVerilog)

32-bit RV32 (RISC-V–style) CPU core written in SystemVerilog. The design is organized as a 5-stage pipeline and includes a dual-port RAM plus a small memory-mapped I/O block (LEDs + pushbuttons).

## Repository contents

### Top-level and pipeline stages
- `RV32_CPU_top.sv` — top-level integration (pipeline + RAM + I/O + regfile)
- `RV32_IF_top.sv` — Instruction Fetch (PC + instruction address)
- `RV32_ID_top.sv` — Instruction Decode + immediate gen + branch/jump decision + hazard control
- `RV32_EX_top.sv` — Execute stage (forwarding + ALU)
- `RV32_MEM_top.sv` — Memory stage (store byte-enables + RAM vs I/O routing for stores)
- `RV32_WB_top.sv` — Writeback stage (WB mux + load extract + sign/zero extension)

### Core building blocks
- `regs.sv` — 32×32 register file (x0 hardwired to 0)
- `alu.sv` — ALU used in EX (module name: `ALU`)
- `mem.sv` — dual-port RAM (module name: `dual_port_ram`), initializes from `stop_go.mem`
- `RV32_IO.sv` — memory-mapped I/O (pushbuttons read, LEDs write)
- `stop_go.mem` — program image loaded into RAM via `$readmemh`

## Pipeline overview

### Stages
- **IF**: generates instruction memory address, outputs PC + instruction word
- **ID**: decodes instruction, reads register operands, computes branch/jump targets, controls stall/flush
- **EX**: computes ALU results (arith/logic/address) with forwarding
- **MEM**: formats stores (byte enables + shifted store data) and routes stores to RAM vs I/O
- **WB**: selects writeback source and extracts/sign-extends load data (LB/LH/LBU/LHU)

### Control flow
- Branches/JAL/JALR are resolved in **ID**.
- Taken control transfers assert a **flush** so the next fetched instruction is discarded.

### Hazards / forwarding
- Load-use hazards stall the pipeline.
- Forwarding is used in EX (and an extra stall is applied for branches that depend on a load still in flight).

## Memory system

The memory is a dual-port block:
- **Instruction port**: read-only (`i_addr` → `i_rdata`)
- **Data port**: read/write with byte enables (`d_addr`, `d_wdata`, `d_be`, `d_we` → `d_rdata`)

Addressing is word-based internally using bits `[31:2]`.

Default depth is `2^ADDR_WIDTH` words. In `mem.sv` the default is:
- `ADDR_WIDTH = 14` → 16384 words → 64 KiB

Program initialization:
- `mem.sv` loads `stop_go.mem` at time 0 using `$readmemh("stop_go.mem", ram)`.

## Memory-mapped I/O

### Store routing
Stores are routed to I/O when the computed address has `alu_in[31] = 1` (otherwise stores go to RAM). I/O uses word offsets `io_addr[3:2]`.

### Map
- `0x8000_0000`: read pushbuttons (returns `{28'b0, PB[3:0]}`)
- `0x8000_0004`: write LEDs (updates `LED[9:0]`, honoring byte-enables)

### Loads from I/O
WB can select load data from either RAM or I/O (`mem_rdata_in` vs `io_rdata_in`). In this design, the decode stage tags an “I/O load” using the sign bit of the I-type immediate (`iw_in[31]`), so I/O loads are expected to be encoded using a negative I-type offset (bit 11 set), consistent with the `0x8000_0000` region.

## Instruction classes (decode-level)

`RV32_ID_top.sv` enables writeback / control for these opcode groups:
- **R-type ALU** (`0110011`)
- **I-type ALU** (`0010011`)
- **Loads** (`0000011`): LB, LH, LW, LBU, LHU (final extract/signing happens in WB)
- **Stores** (`0100011`): SB, SH, SW (byte-enables generated in MEM)
- **Branches** (`1100011`): BEQ, BNE, BLT, BGE, BLTU, BGEU (decision in ID)
- **Jumps**: JAL (`1101111`), JALR (`1100111`)
- **LUI** (`0110111`)

Register file notes:
- x0 is always zero (implemented in `regs.sv`).
