# 16-bit 5-Stage Pipelined RISC Processor (Verilog)

Computer Architecture project, Section 5C, Department of Computer Science, HITEC University, Taxila.
Submitted to: Sir Hussnain Shoaib

**Team:** Muhammad Huzaifa, Muhammad Ibrahim Malik, Matti Ur Rehman, Muhammad Awais

## Overview
A 16-bit RISC processor written in Verilog HDL (IEEE 1364-2005) at RTL level, with a classic 5-stage pipeline:
**IF -> ID -> EX -> MEM -> WB**, separated by pipeline registers.

- **ISA:** ADD, SUB, AND, OR, LW, SW (4-bit opcode)
- **Instruction format:** `[15:12] opcode | [11:8] dest | [7:4] src1 | [3:0] src2 / immediate`
- **Registers:** 16 x 16-bit (R0 hardwired to 0)
- **Memories:** 256 x 16-bit instruction memory and data memory
- **Hazard handling:** software stalling (NOP bubbles), no forwarding hardware

## Repository structure
```
src/processor.v        ALU, RegisterFile, InstructionMemory, DataMemory, PipelinedProcessor
tb/tb_processor.v      Testbench (10 ns clock, console monitor)
docs/                  Report, simulation transcript, waveform
```

## Run the simulation
**ModelSim / Questa**
```
vlog src/processor.v tb/tb_processor.v
vsim tb_processor
run -all
```

**Icarus Verilog**
```
iverilog -o sim src/processor.v tb/tb_processor.v
vvp -n sim
```

## Test program
```
ADD R1, R0, 5
ADD R2, R0, 10
NOP x3
ADD R3, R1, R2   # expect 15
NOP x3
SUB R4, R2, R1   # expect 5
```

## Results
![Simulation transcript](docs/simulation_transcript.png)
![Waveform](docs/waveform.png)
