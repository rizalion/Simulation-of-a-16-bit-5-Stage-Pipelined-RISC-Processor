`timescale 1ns / 1ps

module tb_processor;

    // Inputs
    reg clk;
    reg rst;

    // Instantiate the Unit Under Test (UUT)
    PipelinedProcessor uut (
        .clk(clk),
        .rst(rst)
    );

    // Clock Generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simulation Monitor
    initial begin
        $display("-------------------------------------------------------------");
        $display(" TIME | PC   | INSTRUCTION      | ALU RESULT (Dec) | REGISTER WRITE");
        $display("-------------------------------------------------------------");
        $monitor("%4dns | %h | %b | %d               | Wr: %b",
                 $time, uut.PC, uut.IF_Instr, uut.EX_ALUResult, uut.MEM_WB_RegWrite);
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        rst = 1;
        #10; // Wait 10ns
        rst = 0; // Release Reset

        // Run simulation for enough cycles
        #200;

        $display("-------------------------------------------------------------");
        $display(" SIMULATION FINISHED");
        $display("-------------------------------------------------------------");
        $stop;
    end

endmodule
