module simtop;
    logic clk;
    logic [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,HEX6,HEX7;
    logic [3:0] KEY;
    logic [17:0] SW;
    
    top dut (
        .CLOCK_50(clk),
        .CLOCK2_50(),
        .CLOCK3_50(),
        .LEDG(),
        .LEDR(),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7)
    );
    
    // Clock generator
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        // Initialize switches
        SW = 18'b00_0000_0000_0000_1111;  // Set to 15; change this for other tests
        
        // Initialize KEY and apply reset
        KEY = 4'b1110;  // Assert reset (KEY[0] = 0)
        
        $display("======================================");
        $display("Starting CPU test - Applying Reset");
        $display("======================================");
        
        // Hold reset for a few cycles
        #20;
        
        // Release reset
        KEY = 4'b1111;  // Deassert reset (KEY[0] = 1)
        
        $display("Reset released, CPU running...");
        
        // Wait for CPU to execute
        #100;
        
        $display("\n=== After 100ns ===");
        $display("PC= %h", dut.my_cpu.pc_F);
        $display("Instruction_EX = %h", dut.my_cpu.instruction_EX);
        
        // Monitor execution
        repeat (60) begin
            #10;
            $display("%0t\tPC=%h\tINSTR=0x%08h\tRF[5]=0x%08h RF[30]=0x%08h GPIO_in=0x%08h GPIO_out=0x%08h GPIO_we=%b",
                     $time,
                     dut.my_cpu.pc_F,
                     dut.my_cpu.instruction_EX,
                     dut.my_cpu.rf.mem[5],
                     dut.my_cpu.rf.mem[30],
                     dut.my_cpu.gpio_in,
                     dut.my_cpu.gpio_out_reg,
                     dut.my_cpu.GPIO_we_reg);  // Use registered version!
        end
        
        $display("\n=== Final Output ===");
        $display("GPIO Output = 0x%08h (dec %0d)",
                 dut.my_cpu.gpio_out, dut.my_cpu.gpio_out);
        
        $display("\n=== Register Dump ===");
        $display("t0 (x5)  = 0x%08h", dut.my_cpu.rf.mem[5]);
        $display("t5 (x30) = 0x%08h", dut.my_cpu.rf.mem[30]);
        
        $finish;
    end

    // --------- CSR/HEX Read/Write Tracing ---------
    always @(posedge clk) begin
        // Print on every CSR instruction (read or write)
        if (dut.my_cpu.opcode == 7'b1110011) begin
            $display("CSR INSTR: PC=%h imm12=0x%03h regwrite=%b GPIO_we=%b regsel=%b rs1=%d rd=%d readdata1=0x%08h writedata=0x%08h GPIO_in=0x%08h GPIO_out=0x%08h",
                dut.my_cpu.pc_F,
                dut.my_cpu.imm12,
                dut.my_cpu.regwrite_EX,
                dut.my_cpu.GPIO_we,
                dut.my_cpu.regsel_EX,
                dut.my_cpu.rs1,
                dut.my_cpu.rd,
                dut.my_cpu.readdata1,
                dut.my_cpu.writedata,
                dut.my_cpu.gpio_in,
                dut.my_cpu.gpio_out_reg
            );
        end

        // Detect actual HEX display update event
        if (dut.my_cpu.GPIO_we) begin
            $display("*** HEX WRITE: PC=%h  HEX value=0x%08h  (readdata1)", 
                dut.my_cpu.pc_F,
                dut.my_cpu.readdata1
            );
        end

        // Detect switch read event
        if (dut.my_cpu.regwrite_EX && dut.my_cpu.imm12 == 12'hF00) begin
            $display("*** SWITCH READ: PC=%h  SW read into reg=%d, value=0x%08h", 
                dut.my_cpu.pc_F,
                dut.my_cpu.rd,
                dut.my_cpu.gpio_in
            );
        end
    end
endmodule

