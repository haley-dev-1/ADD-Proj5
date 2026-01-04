// csce611 project 5 Haley Lind 

module cpu ( 
  input logic clk, 
  input logic rst, // active low reset 
  input logic [31:0] gpio_in,
  output logic [31:0] gpio_out
);

  // Fetch stage -- use 64; split into 2, and even/odd must be executed separately and have their own control paths, and their own register file.

  logic [63:0] bundle_F;        // PC indexes bundles, stepping by 1 per cycle (move by 2 instr. per) // pc only sees 1 pc ... its just an address that points toward next bundle to fetch. "3 PC because we have 3 stages on the instruction we already fetch
  logic [31:0] PC_F;
  logic [31:0] PC_F_next;
  logic [31:0] instr_even_F;
  logic [31:0] instr_odd_F;
  logic [31:0] PC_even_F_next;
  logic [31:0] PC_odd_F_next;              
    
  logic [31:0] instr_even_E, instr_odd_E;
  logic [31:0] PC_E;
  
  // Execute stage  
  logic [6:0] opcode_odd_E, opcode_even_E;
  logic [2:0] funct3_odd_E, funct3_even_E;
  logic [6:0] funct7_odd_E, funct7_even_E;
  logic [11:0] csr_odd_E, csr_even_E;
  logic [4:0] rs1_odd_E, rs2_odd_E, rd_odd_E, rs1_even_E, rs2_even_E, rd_even_E;
  logic [11:0] imm12_even_E, imm12_odd_E;
  logic [31:0] imm20_even_E, imm_even_B_E, imm_even_J_E;
  logic [31:0] imm20_odd_E, imm_odd_B_E, imm_odd_J_E;
  
  // Writeback stage
  logic [31:0] alu_odd_result_W, PC_odd_plus4_W, imm20_odd_W, 
               dalu_even_result_W, PC_even_plus4_W, imm20_even_W;
  logic [31:0] rs1_odd_data_W, rs2_odd_data_W,      // "if you still need rs
               rs1_even_data_W, rs2_even_data_W;    //  in pipe. mirror them"
  logic [4:0] rd_odd_W, rd_even_W;
  logic       regwrite_odd_W, regwrite_even_W; 
  logic       gpio_odd_we_W, gpio_even_we_W;
  logic [1:0] regsel_even_W, regsel_odd_W;  // paths for writeback mux select per lane

  // control signals execute stage: EVEN lane
  logic [3:0] aluop_even_E;
  logic       alusrc_even_E, alusrc_pc_even_E, alusrc_imm20_even_E;
  logic [1:0] regsel_even_E;
  logic       regwrite_even_E, gpio_we_even_E;
  logic       is_branch_even_E, is_jal_even_E, is_jalr_even_E;

  // control signals execute stage: ODD lane
  logic [3:0] aluop_odd_E;
  logic       alusrc_odd_E, alusrc_pc_odd_E, alusrc_imm20_odd_E;
  logic [1:0] regsel_odd_E;
  logic       regwrite_odd_E, gpio_we_odd_E;
  logic       is_branch_odd_E, is_jal_odd_E, is_jalr_odd_E;   // will get forced 0 or trapped (odd can't branch/jump)

  // branch decision / PC control (from EVEN lane only bcuz of jump/branch in ONLY EVEN!)
  logic       branch_taken_even_E;
  logic       take_branch_even_E;

  // Datapath signals
  logic [31:0] PC_E_byte;
  logic [31:0] branch_target_even;
  logic [31:0] jal_target_even;
  logic [31:0] jalr_target_even;

  // instruction memory
  logic [63:0] imem[0:255];   // now imem is 64 bit. we will fetch 2 instructions from imem at a time, addressed by the PC as a bundle. 

  assign bundle_F = imem[PC_F]; 
  assign instr_even_F = bundle_F[63:32]; 
  assign instr_odd_F = bundle_F[31:0];

  initial begin 
    $readmemh("./instmem.dat", imem); // initializes an array. read file into array. repository of intial values.
  end 

  //  ------------- DECODERS -- both even and odd instructions (bundle) ------------------ // 
  decoder decode_even (
    .instruction(instr_even_E),
    .opcode(opcode_even_E), .funct3(funct3_even_E), .funct7(funct7_even_E), .csr(csr_even_E),
    .rs1(rs1_even_E), .rs2(rs2_even_E), .rd(rd_even_E),
    .imm12(imm12_even_E), .imm20(imm20_even_E),
    .imm_B(imm_even_B_E), .imm_J(imm_even_J_E)
  );

  decoder decode_odd (
    .instruction(inst_odd_E),
    .opcode(opcode_odd_E), .funct3(funct3_odd_E), .funct7(funct7_odd_E), .csr(csr_odd_E),
    .rs1(rs1_odd_E), .rs2(rs2_odd_E), .rd(rd_odd_E),
    .imm12(imm12_odd_E), .imm20(imm20_odd_E),
    .imm_B(imm_B_odd_E), .imm_J(imm_J_odd_E)
  );
  //  ----------------------------------------------------------------------------------- //

  //  ------------------------ CONTROL UNITS: Even and Odd ------------------------------ //
  control_unit ctrl_even (
    .opcode(opcode_even_E), .funct3(funct3_even_E), .funct7(funct7_even_E), .csr(csr_even_E),
    .stall_EX(1'b0), .stall_FETCH(),
    .aluop(aluop_even_E), .alusrc(alusrc_even_E), .alusrc_pc(alusrc_pc_even_E), .alusrc_imm20(alusrc_imm20_even_E),
    .regsel(regsel_even_E), .regwrite(regwrite_even_E),
    .memread(), .memwrite(), .gpio_we(gpio_we_even_E),
    .is_branch(is_branch_even_E), .is_jal(is_jal_even_E), .is_jalr(is_jalr_even_E)
  );
  control_unit ctrl_odd (
    .opcode(opcode_odd_E), .funct3(funct3_odd_E), .funct7(funct7_odd_E), .csr(csr_odd_E),
    .stall_EX(1'b0), .stall_FETCH(),
    .aluop(aluop_odd_E), .alusrc(alusrc_odd_E), .alusrc_pc(alusrc_pc_odd_E), .alusrc_imm20(alusrc_imm20_odd_E),
    .regsel(regsel_odd_E), .regwrite(regwrite_odd_E),
    .memread(), .memwrite(), .gpio_we(gpio_we_odd_E),
    .is_branch(is_branch_odd_E), .is_jal(is_jal_odd_E), .is_jalr(is_jalr_odd_E)
  );
  //  ----------------------------------------------------------------------------------- //


  // Register file
  logic rf_we;
  assign rf_we = (rd_W != 5'd0) && regwrite_W;
  
  regfile rf (
    .clk(clk), .we(rf_we),
    .readaddr1(rs1_E), .readaddr2(rs2_E),
    .writeaddr(rd_W), .writedata(rf_wd),
    .readdata1(rf_rd1), .readdata2(rf_rd2)
  );

  // immediate sign extension
  logic [31:0] imm_I_sext, shamt;
  assign imm_I_sext = {{20{imm12_E[11]}}, imm12_E};
  assign shamt = {27'b0, imm12_E[4:0]};
  
// ------ start of ALU logic stuff ---------------------------------------------

// EVEN lane ALU
logic [31:0] alu_even_a, alu_even_b, alu_even_result;
logic        alu_even_zero;

// ODD lane ALU
logic [31:0] alu_odd_a,  alu_odd_b,  alu_odd_result;
logic        alu_odd_zero;

// EVEN lane ALU input A
always_comb begin
  if (alusrc_pc_even_E)
    alu_even_a = PC_E << 2;
  else
    alu_even_a = rs1_even_data_E; // or rf output mapped to even
end

// EVEN lane ALU input B
always_comb begin
  if (alusrc_imm20_even_E) begin
    alu_even_b = imm20_even_E;
  end else if (alusrc_even_E) begin
    if (aluop_even_E == 4'b1000 ||
        aluop_even_E == 4'b1001 ||
        aluop_even_E == 4'b1010)
      alu_even_b = {27'b0, imm12_even_E[4:0]};
    else
      alu_even_b = {{20{imm12_even_E[11]}}, imm12_even_E};
  end else begin
    alu_even_b = rs2_even_data_E;
  end
end

// ODD lane ALU input A
always_comb begin
  if (alusrc_pc_odd_E)
    alu_odd_a = PC_E << 2;
  else
    alu_odd_a = rs1_odd_data_E;
end

// ODD lane ALU input B
always_comb begin
  if (alusrc_imm20_odd_E) begin
    alu_odd_b = imm20_odd_E;
  end else if (alusrc_odd_E) begin
    if (aluop_odd_E == 4'b1000 ||
        aluop_odd_E == 4'b1001 ||
        aluop_odd_E == 4'b1010)
      alu_odd_b = {27'b0, imm12_odd_E[4:0]};
    else
      alu_odd_b = {{20{imm12_odd_E[11]}}, imm12_odd_E};
  end else begin
    alu_odd_b = rs2_odd_data_E;
  end
end
  
alu alu_even (
  .A(alu_even_a),
  .B(alu_even_b),
  .op(aluop_even_E),
  .R(alu_even_result),
  .zero(alu_even_zero)
);

alu alu_odd (
  .A(alu_odd_a),
  .B(alu_odd_b),
  .op(aluop_odd_E),
  .R(alu_odd_result),
  .zero(alu_odd_zero)
);


  // ------ end of ALU logic stuff ---------------------------------------------

  // ---- branch decisions -----------------------------------------------------

  logic [31:0] PC_even_E_byte;
  logic [31:0] branch_target_even;

  // branch condition evaluation
  always_comb begin
    branch_taken_even_E = 1'b0;

    if (is_branch_even_E) begin
      unique case (funct3_even_E)

        3'b000: branch_taken_even_E = alu_even_zero;        // beq
        3'b001: branch_taken_even_E = ~alu_even_zero;       // bne
        3'b100: branch_taken_even_E = alu_even_result[0];   // blt
        3'b101: branch_taken_even_E = ~alu_even_result[0];  // bge
        3'b110: branch_taken_even_E = alu_even_result[0];   // bltu
        3'b111: branch_taken_even_E = ~alu_even_result[0];  // bgeu
        
        default: branch_taken_even_E = 1'b0;

      endcase
    end
  end

  /*
    always_comb begin
    branch_taken_even_E = 1'b0;

    if (is_branch_even_E) begin
      unique case (funct3_even_E)
        3'b000: branch_taken_even_E = alu_even_zero;        // beq  (rs1 - rs2 == 0)
        3'b001: branch_taken_even_E = ~alu_even_zero;       // bne
        3'b100: branch_taken_even_E = alu_even_result[0];   // blt  (depends how you implemented compare)
        3'b101: branch_taken_even_E = ~alu_even_result[0];  // bge
        3'b110: branch_taken_even_E = alu_even_result[0];   // bltu
        3'b111: branch_taken_even_E = ~alu_even_result[0];  // bgeu
        default: branch_taken_even_E = 1'b0;
      endcase
    end
  end
  */
  
  assign instr_F = imem[PC_F];

  // targets
  assign PC_even_E_byte     = PC_E << 2; // PC_E is bundle index; convert to byte addr
  assign branch_target_even = (PC_even_E_byte + imm_even_B_E) >> 2;
  assign jal_target_even    = (PC_even_E_byte + imm_even_J_E) >> 2;

  // jalr uses EVEN lane ALU result (rs1 + imm), then clear bit0
  assign jalr_target_even   = (alu_even_result & 32'hfffffffe) >> 2;

  // even lane decides control flow
  assign take_cf_even_E =
       is_jal_even_E
    || is_jalr_even_E
    || (is_branch_even_E && branch_taken_even_E); // both must be true for branch conditions... its a CONDITIONAL~

  // next pc selection driven by even lane (because even controls jumps/branches)
  always_comb begin
    if (take_cf_even_E) begin
      if (is_jal_even_E)       PC_F_next = jal_target_even;
      else if (is_jalr_even_E) PC_F_next = jalr_target_even;
      else                     PC_F_next = branch_target_even;
    end else begin
      PC_F_next = PC_F + 1; // next bundle
    end
  end
  
  //pipeline registers get us into execute, and we load PC with next. This is clocked. We need those registers inbetween stages to store! 
  always_ff @(posedge clk) begin
    if (!rst) begin
      PC_F <= 32'd0;
      PC_E <= 32'd0;
      instr_even_E <= 32'h00000013; // NOP
      instr_odd_E  <= 32'h00000013; // NOP
    end else begin
      PC_F <= PC_F_next;
      PC_E <= PC_F;                   // on clock edge, latch what we fetched into the execute stage
      instr_even_E <= instr_even_F;   //
      instr_odd_E  <= instr_odd_F;    // 
    end
  end

  // exec stage pipeline
  always_ff @(posedge clk) begin
    if (!rst) begin
      inst_even_E <= 32'h00000013; // NOP
      PC_E <= 32'd0;
    end else begin
      if (take_cf_even_E) begin
        inst_even_E <= 32'h00000013; // Flush pipeline on branch/jump
      end else begin
        inst_even_E <= instr_even_F;
      end
      PC_E <= PC_F;
    end
  end

 
  //writeback stage
  
  always_ff @(posedge clk) begin
    if (!rst) begin
      alu_even_result_W <= 32'd0;
      alu_odd_result_W  <= 32'd0;
      rd_even_W <= 5'd0;
      rd_odd_W  <= 5'd0;
      regwrite_even_W <= 1'b0;
      regwrite_odd_W  <= 1'b0;
      regsel_even_W <= 2'b00;
      regsel_odd_W  <= 2'b00;
      imm20_even_W <= 32'd0;
      imm20_odd_W  <= 32'd0;
      PC_even_plus4_W <= 32'd0;
      PC_odd_plus4_W  <= 32'd0;
      gpio_even_we_W <= 1'b0;
      gpio_odd_we_W  <= 1'b0;
      rs1_even_data_W <= 32'd0;
      rs1_odd_data_W  <= 32'd0;
    end else begin
    
    end else begin
      alu_even_result_W <= alu_even_result; // used to be just one because single lane
      alu_odd_result_W  <= alu_odd_result;  // but now its 2 b/c even/odd instructions (VLIW)
      rd_even_W <= rd_even_E;             // destination registers
      rd_odd_W  <= rd_odd_E;              // destination
      regwrite_even_W <= regwrite_even_E; // control 
      regwrite_odd_W  <= regwrite_odd_E;  // control
       regsel_even_W <= regsel_even_E;    // control 
      regsel_odd_W  <= regsel_odd_E;      // control
      imm20_even_W <= imm20_even_E;       // immediates 
      imm20_odd_W  <= imm20_odd_E;        // immedates
      PC_even_plus4_W <= (PC_E << 2) + 32'd4; // return address (PC+4 in bytes)
      PC_odd_plus4_W  <= (PC_E << 2) + 32'd4;
      gpio_even_we_W <= gpio_we_even_E;   // gpio write enables (still allowed as an instruction effect; you can restrict to even if your ISA says so)
      gpio_odd_we_W  <= gpio_we_odd_E;
      rs1_even_data_W <= rf_even_rd1;     // rs1 values for gpio-out path
      rs1_odd_data_W  <= rf_odd_rd1;
    end
  end
  
  // reg write mux
  
  always_comb begin
    case(regsel_W)
      2'b00 : rf_wd = gpio_in;           // CSR read (io0)
      2'b01 : rf_wd = imm20_W;           // LUI
      2'b10 : rf_wd = alu_result_W;      // ALU result
      2'b11 : rf_wd = PC_plus4_W;        // JAL/JALR return address
      default : rf_wd = 32'd0;
    endcase
  end

  // gpio out 
  
  always_ff @(posedge clk) begin
    if (!rst) begin
      gpio_out <= 32'd0; // active low 
    end else if (gpio_we_W) begin 
      gpio_out <= rs1_data_W;  // csrrw x0 io2 rs1 outputs rs1
    end
  end

endmodule
