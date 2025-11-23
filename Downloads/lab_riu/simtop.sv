module simtop;

    logic clk;
    logic [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,HEX6,HEX7;
    logic [3:0] KEY;
    logic [17:0] SW;

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

    // ---------------- Clock generator ----------------
    initial clk = 0;
    always #5 clk = ~clk; // 10 time units per full period

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

/*
corresponding testbench state machine (assuming you've called your GPIO output register gpio_out) would be:

integer outputs [] = {5, 10, 15}; // An array of the expected outputs in order
logic [2:0] state; // Current state
always_ff @(posedge clk, negedge reset) begin
    if (!reset) begin
        state <= 3'b000; // Reset the state on system reset
    end else begin
        case (state) // Check what state we're in
            3'b000: begin // Loop in the initial state until we sync with the pre-branch output of 5
                if (gpio_out == outputs[0]) begin
                    $display("Synced with pre-branch output: %0d", gpio_out);
                    state <= 3'b001; // Once we see it, move to the next state
                end
            end
            3'b001: begin // Next up we have the branch instruction itself, so just wait a cycle here for it to finish
                state <= 3'b010;
            end
            3'b010: begin // Now we should be in the stall cycle right after the branch instruction
                if (gpio_out == outputs[1]) begin // If we see the post-branch output, then either we didn't stall or we didn't take the branch
                    $display("Oh no, we executed the instruction after the branch and got the output: %0d", gpio_out);
                    $finish;
                end else if (gpio_out == outputs[0]) begin // If the output is unchanged, then we successfully stalled
                    $display("Output didn't change during stall, good: %0d", gpio_out);
                    state <= 3'b011; // Only go to the final state if things look good
                end else begin // If we see anything else, that's super weird
                    $display("Unexpected output during stall: %0d", gpio_out);
                    $finish;
                end
            end
            3'b011: begin // The final state: we're done stalling and expect to be at the "done:" label
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
*/