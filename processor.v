`timescale 1ns / 1ps

// --- OPCODE DEFINITIONS ---
`define ADD  4'b0000
`define SUB  4'b0001
`define AND  4'b0010
`define OR   4'b0011
`define LW   4'b0100
`define SW   4'b0101

// --- ALU MODULE ---
module ALU (
    input [15:0] A, B,
    input [3:0] ALUOp,
    output reg [15:0] Result,
    output Zero
);
    assign Zero = (Result == 0);
    always @(*) begin
        case(ALUOp)
            `ADD: Result = A + B;
            `SUB: Result = A - B;
            `AND: Result = A & B;
            `OR:  Result = A | B;
            default: Result = 0;
        endcase
    end
endmodule

// --- REGISTER FILE ---
module RegisterFile (
    input clk, rst, we,
    input [3:0] raddr1, raddr2, waddr,
    input [15:0] wdata,
    output [15:0] rdata1, rdata2
);
    reg [15:0] regs[0:15];
    integer i;

    assign rdata1 = (raddr1 == 0) ? 0 : regs[raddr1];
    assign rdata2 = (raddr2 == 0) ? 0 : regs[raddr2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i=0; i<16; i=i+1) regs[i] <= 0;
        end else if (we && waddr != 0) begin
            regs[waddr] <= wdata;
        end
    end
endmodule

// --- INSTRUCTION MEMORY (With Hazard Bubbles) ---
module InstructionMemory (
    input [15:0] pc,
    output [15:0] instruction
);
    reg [15:0] memory [0:255];

    initial begin
        // Program:
        // 1. R1 = 5
        // 2. R2 = 10
        // 3. R3 = R1 + R2 (Should be 15)
        // 4. R4 = R2 - R1 (Should be 5)
        memory[0] = 16'b0000_0001_0000_0101; // ADD R1, R0, 5
        memory[1] = 16'b0000_0010_0000_1010; // ADD R2, R0, 10
        memory[2] = 16'b0000_0000_0000_0000; // NOP (Bubble)
        memory[3] = 16'b0000_0000_0000_0000; // NOP (Bubble)
        memory[4] = 16'b0000_0000_0000_0000; // NOP (Bubble)
        memory[5] = 16'b0000_0011_0001_0010; // ADD R3, R1, R2
        memory[6] = 16'b0000_0000_0000_0000; // NOP
        memory[7] = 16'b0000_0000_0000_0000; // NOP
        memory[8] = 16'b0000_0000_0000_0000; // NOP
        memory[9] = 16'b0001_0100_0010_0001; // SUB R4, R2, R1
    end
    assign instruction = memory[pc[7:0]];
endmodule

// --- DATA MEMORY ---
module DataMemory (
    input clk, we,
    input [15:0] addr, wdata,
    output [15:0] rdata
);
    reg [15:0] memory [0:255];
    assign rdata = memory[addr[7:0]];
    always @(posedge clk) begin
        if (we) memory[addr[7:0]] <= wdata;
    end
endmodule

// --- TOP LEVEL PIPELINED PROCESSOR ---
module PipelinedProcessor (
    input clk, rst
);
    // Wires and Pipeline Registers
    reg [15:0] PC;
    wire [15:0] NextPC, IF_Instr;

    // Pipeline Registers
    reg [15:0] IF_ID_PC, IF_ID_Instr;
    reg [15:0] ID_EX_A, ID_EX_B;
    reg [3:0]  ID_EX_Opcode, ID_EX_Dest;
    reg ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite;
    reg [15:0] EX_MEM_Result, EX_MEM_WriteData;
    reg [3:0]  EX_MEM_Dest;
    reg EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite;
    reg [15:0] MEM_WB_Result, MEM_WB_ReadData;
    reg [3:0]  MEM_WB_Dest;
    reg MEM_WB_RegWrite, MEM_WB_MemToReg;

    // Decode Wires
    wire [15:0] ID_RData1, ID_RData2;
    wire [3:0] ID_Opcode = IF_ID_Instr[15:12];
    wire [3:0] ID_Dest = IF_ID_Instr[11:8];
    wire [3:0] ID_Src1 = IF_ID_Instr[7:4];
    wire [3:0] ID_Src2 = IF_ID_Instr[3:0];
    wire ID_RegWrite = (ID_Opcode == `ADD || ID_Opcode == `SUB || ID_Opcode == `AND || ID_Opcode == `OR || ID_Opcode == `LW);

    // Execute Wires
    wire [15:0] EX_ALUResult;
    wire EX_Zero;
    wire [15:0] MEM_ReadData;
    wire [15:0] WB_WriteBackData;

    // Module Instantiation
    InstructionMemory IM (PC, IF_Instr);
    RegisterFile RF (clk, rst, MEM_WB_RegWrite, ID_Src1, ID_Src2, MEM_WB_Dest, WB_WriteBackData, ID_RData1, ID_RData2);
    ALU MainALU (ID_EX_A, ID_EX_B, ID_EX_Opcode, EX_ALUResult, EX_Zero);
    DataMemory DM (clk, EX_MEM_MemWrite, EX_MEM_Result, EX_MEM_WriteData, MEM_ReadData);

    assign WB_WriteBackData = (MEM_WB_MemToReg) ? MEM_WB_ReadData : MEM_WB_Result;
    assign NextPC = PC + 1;

    // PIPELINE LOGIC
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 0; IF_ID_Instr <= 0; ID_EX_RegWrite <= 0; EX_MEM_RegWrite <= 0; MEM_WB_RegWrite <= 0;
        end else begin
            PC <= NextPC;

            // IF -> ID
            IF_ID_Instr <= IF_Instr;

            // ID -> EX
            ID_EX_A <= ID_RData1;
            ID_EX_B <= (ID_Src1 == 0) ? {12'b0, ID_Src2} : ID_RData2; // Immediate handling
            ID_EX_Opcode <= ID_Opcode;
            ID_EX_Dest <= ID_Dest;
            ID_EX_RegWrite <= ID_RegWrite;

            // EX -> MEM
            EX_MEM_Result <= EX_ALUResult;
            EX_MEM_Dest <= ID_EX_Dest;
            EX_MEM_RegWrite <= ID_EX_RegWrite;

            // MEM -> WB
            MEM_WB_Result <= EX_MEM_Result;
            MEM_WB_Dest <= EX_MEM_Dest;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
        end
    end
endmodule
