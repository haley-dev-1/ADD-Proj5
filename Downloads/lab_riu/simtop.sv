module simtop;

    logic clk;
    logic [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,HEX6,HEX7;
    logic [3:0] KEY;
    logic [17:0] SW;

    // internal signals used by the FSM
    logic reset;                // fsm is active-low
    logic [31:0] gpio_out;      // copy of CPU's GPIO output register

    top dut
    (
        // CLOCK
        .CLOCK_50(clk),
        .CLOCK2_50(),
        .CLOCK3_50(),

        // LED
        .LEDG(),
        .LEDR(),

        // KEY and SW
        .KEY(KEY),
        .SW(SW),

        // SEG7
        .HEX1(HEX1),
        .HEX0(HEX0),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7)
    );

    // ---------------- Clock generator ---------------------------
    initial clk = 0;
    always #5 clk = ~clk; // 10 time units per full period
    // ------------------------------------------------------------

    // -------- connect reset and gpio_out (outputs) to fsm -------
    assign reset   = KEY[0];                // FSM uses active-low reset
    assign gpio_out = dut.my_cpu.gpio_out_reg;  // tap the CPU's GPIO output register
    // ------------------------------------------------------------

    // -------------- B / J / Etc Checker -----------------
    // The expected GPIO sequence is:
    //  outputs[0] = 5
    //  outputs[1] = 10 (instruction after branch, if NOT taken)
    //  outputs[2] = 15 (final "done", if branch IS taken)
    // -------------------------------------------------------------
    
    // -------------------------- B /J / Branch ---------------------
    int outputs [3] = '{5,10,15};

    // the current state (for FSM tb.)
        // 000 = waiting for pre-branch marker (5)
        // 001 = cycle of the branch/jump instruction
        // 010 = stall/flush cycle (should NOT see wrong-path output)
        // 011 = final marker (15) after taking the branch/jump
    logic [2:0] state; 

    // ============================== FINITE STATE MACHINE FOR SELF CHECKING TESTBENCH ==============================
    //  BELOW is the fsm logic that verifies branch (b) and jump (j) instructions for lab 4.
    //  It will notify if an unexpected thing happens, giving us an error message and stops simluation.
    //  it runs every clock cycles and vlalidates the cpu is handling jumps and branches correctly. 
    // ==============================================================================================================
    
    always_ff @(posedge clk, negedge reset) 
    begin
        if (!reset) begin
            state <= 3'b000; // reset system on reset, otherwise continue to else!
        end 
        else begin
            case (state)                    // Check what state we're in
                3'b000: begin               // Loop in the initial state until we sync with the pre-branch output of 5
                    if (gpio_out == outputs[0]) begin
                        $display("Synced with pre-branch output: %0d", gpio_out);
                        state <= 3'b001; // Once we see it, move to the next state
                    end
                end
            
                3'b001: begin               // Next up we have the branch instruction itself, so just wait a cycle here for it to finish
                    state <= 3'b010;
                end
            
                3'b010: begin               // Now we should be in the stall cycle right after the branch instruction
                    if (gpio_out == outputs[1]) begin   // If we see the post-branch output, then either we didn't stall or we didn't take the branch
                        $display("Oh no, we executed the instruction after the branch and got the output: %0d", gpio_out);
                        $finish;

                    end else if (gpio_out == outputs[0]) begin  // If the output is unchanged, then we successfully stalled
                        $display("Output didn't change during stall, good: %0d", gpio_out);
                        state <= 3'b011;    // Only go to the final state if things look good

                    end else begin          // If we see anything else, that's super weird
                        $display("Unexpected output during stall: %0d", gpio_out);
                        $finish;
                    end
                end
            
                3'b011: begin               // The final state: we're done stalling and expect to be at the "done:" label
                    if (gpio_out == outputs[2]) begin // Check for the final output from the "done:" csrrw
                        $display("Branch taken successfully, final output: %0d", gpio_out); // Yay, it's good
                        $finish;
                    end else begin // Oh no, it's bad
                        $display("Unexpected final output: %0d", gpio_out);
                        $finish;
                    end
                end
            endcase
        end
    end

    // ========================================= DRIVING THE SIMULATION ============================================
    //  from lab 3 where we implemented r, i, and u, and self-checkign testbench
    //  initializes switch and keys
    //  prints summary of executions at end
    //  summary: tests, drives reset, prints debug info, and manages overall simulation timeline
    // ==============================================================================================================
    
    initial begin
        // Start conditions
        SW = 18'b0;
        // KEY: default not-pressed = 1 (DE2 buttons are active-low typically)
        KEY = 4'b1111;

        $display("======================================");
        $display("Starting CPU test");
        $display("---------------------------------------");

        // Optional: apply a short reset pulse (press KEY0 for a few cycles)
        KEY[0] = 1'b0; // press (active-low)
        #20;
        KEY[0] = 1'b1; // release -> cpu.res = ~KEY0 will be 0 (not in reset)
        #20;

        $display("\n Test 1: Instruction Fetch (show PC and instruction_EX)");
        #100; // let a few cycles run

        $display("PC= %h", dut.my_cpu.pc_F);
        $display("Instruction_EX = %h", dut.my_cpu.instruction_EX);

        // 
        repeat (60) begin
            #10; // wait one clock period (since clk toggles every 5)
            $display("%0t\tPC=%h\tINSTR=0x%08h\tRF[5]=0x%08h GPIO_in=0x%08h GPIO_out=0x%08h GPIO_we=%b",
                     $time,
                     dut.my_cpu.pc_F,
                     dut.my_cpu.instruction_EX,
                     dut.my_cpu.rf.mem[5],
                     dut.my_cpu.gpio_in,
                     dut.my_cpu.gpio_out_reg,
                     dut.my_cpu.GPIO_we);
        end

        // Simple final check print
        $display("\n Final Ouput");
        $display("GPIO Output  = 0x%08h (dec %0d)",
                 dut.my_cpu.gpio_out, dut.my_cpu.gpio_out);

        $finish;
    end

endmodule
