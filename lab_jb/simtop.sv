// csce611 simtop lab4 Michael Stewart & Haley Lind 
module simtop;
  logic clk;
  logic [17:0] SW;
  logic [3:0]  KEY;
  logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
  logic CLOCK2_50, CLOCK3_50;
  
  // Instantiate DUT
  top dut (
    .CLOCK_50(clk),
    .CLOCK2_50(CLOCK2_50),
    .CLOCK3_50(CLOCK3_50),
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
  
  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Helper to decode 7-segment to decimal digit (0-9)
  function automatic logic [3:0] seg7_to_digit(logic [6:0] seg);
    case (seg)
      7'b1000000: seg7_to_digit = 4'd0;
      7'b1111001: seg7_to_digit = 4'd1;
      7'b0100100: seg7_to_digit = 4'd2;
      7'b0110000: seg7_to_digit = 4'd3;
      7'b0011001: seg7_to_digit = 4'd4;
      7'b0010010: seg7_to_digit = 4'd5;
      7'b0000010: seg7_to_digit = 4'd6;
      7'b1111000: seg7_to_digit = 4'd7;
      7'b0000000: seg7_to_digit = 4'd8;
      7'b0010000: seg7_to_digit = 4'd9;
      7'b1111111: seg7_to_digit = 4'd0; // blank/off
      default:    seg7_to_digit = 4'hX;
    endcase
  endfunction
  
  // Read decimal value from HEX displays
  // Assumes format like: HEX7-HEX0 showing decimal digits
  function automatic real read_decimal_from_hex();
    real value;
    int d0, d1, d2, d3, d4, d5, d6, d7;
    begin
      d0 = seg7_to_digit(HEX0); // ones place
      d1 = seg7_to_digit(HEX1); // tens or first decimal
      d2 = seg7_to_digit(HEX2);
      d3 = seg7_to_digit(HEX3);
      d4 = seg7_to_digit(HEX4);
      d5 = seg7_to_digit(HEX5);
      d6 = seg7_to_digit(HEX6);
      d7 = seg7_to_digit(HEX7);
      
      // Assume format: integer.decimal (e.g., "00004.000" for sqrt(16)=4)
      value = d7*1000000.0 + d6*100000.0 + d5*10000.0 + d4*1000.0 + 
              d3*100.0 + d2*10.0 + d1*1.0 + d0*0.1;
      read_decimal_from_hex = value;
    end
  endfunction
  
  // Alternative: Read as BCD-style packed decimal
  function automatic int read_bcd_value();
    int value;
    value = seg7_to_digit(HEX7) * 10000000 +
            seg7_to_digit(HEX6) * 1000000 +
            seg7_to_digit(HEX5) * 100000 +
            seg7_to_digit(HEX4) * 10000 +
            seg7_to_digit(HEX3) * 1000 +
            seg7_to_digit(HEX2) * 100 +
            seg7_to_digit(HEX1) * 10 +
            seg7_to_digit(HEX0);
    read_bcd_value = value;
  endfunction
  
  // Test sequence
  initial begin
    real hex_value;
    int bcd_value;
    real expected_float;
    KEY = 4'b1111;
    $display("=== RISC-V CPU Square Root Test (Decimal Display) ===");
    
    // ---- Test case 1: sqrt(16) = 4.0 ----
    SW = 18'd16;
    expected_float = 4.0;
    KEY = 4'b1110; #20; 
    KEY = 4'b1111;
    $display("\nTest 1: sqrt(16) = expected 4.0");
    repeat (1000) @(posedge clk);
    
    bcd_value = read_bcd_value();
    $display("SW=%0d | expected=%.3f | HEX displays show: %0d %0d %0d %0d %0d %0d %0d %0d", 
             SW, expected_float,
             seg7_to_digit(HEX7), seg7_to_digit(HEX6), seg7_to_digit(HEX5), seg7_to_digit(HEX4),
             seg7_to_digit(HEX3), seg7_to_digit(HEX2), seg7_to_digit(HEX1), seg7_to_digit(HEX0));
    $display("   BCD value: %0d", bcd_value);
    $display("   gpio_out: 0x%08h", dut.mycpu.gpio_out);
    
    // ---- Test case 2: sqrt(17) ≈ 4.123 ----
    SW = 18'd17;
    expected_float = 4.123;
    KEY = 4'b1110; #20; KEY = 4'b1111;
    $display("\nTest 2: sqrt(17) ≈ 4.123");
    repeat (1000) @(posedge clk);
    
    bcd_value = read_bcd_value();
    $display("SW=%0d | expected≈%.3f | HEX displays show: %0d %0d %0d %0d %0d %0d %0d %0d", 
             SW, expected_float,
             seg7_to_digit(HEX7), seg7_to_digit(HEX6), seg7_to_digit(HEX5), seg7_to_digit(HEX4),
             seg7_to_digit(HEX3), seg7_to_digit(HEX2), seg7_to_digit(HEX1), seg7_to_digit(HEX0));
    $display("   BCD value: %0d", bcd_value);
    $display("   gpio_out: 0x%08h", dut.mycpu.gpio_out);
    
    // ---- Test case 3: sqrt(36) = 6.0 ----
    SW = 18'd36;
    expected_float = 6.0;
    KEY = 4'b1110; #20; KEY = 4'b1111;
    $display("\nTest 3: sqrt(36) = 6.0");
    repeat (1000) @(posedge clk);
    
    bcd_value = read_bcd_value();
    $display("SW=%0d | expected=%.3f | HEX displays show: %0d %0d %0d %0d %0d %0d %0d %0d", 
             SW, expected_float,
             seg7_to_digit(HEX7), seg7_to_digit(HEX6), seg7_to_digit(HEX5), seg7_to_digit(HEX4),
             seg7_to_digit(HEX3), seg7_to_digit(HEX2), seg7_to_digit(HEX1), seg7_to_digit(HEX0));
    $display("   BCD value: %0d", bcd_value);
    $display("   gpio_out: 0x%08h", dut.mycpu.gpio_out);
    
    $display("\n=== Test complete ===");
    $display("\nNOTE: Adjust display format interpretation based on your actual output format");
    $display("      (e.g., where decimal point is, leading zeros, etc.)");
    $finish;
  end
endmodule
