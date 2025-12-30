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
  logic [31:0] instr_odd_E, inst_even_E;  // instructions of odd and even; execute stage.
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
  logic [31:0] rf_rd1, rf_rd2, rf_wd;
  logic [31:0] alu_a, alu_b, alu_result;
  logic alu_zero;
  logic [31:0] PC_E_byte;
  logic [31:0] branch_target, jal_target, jalr_target;


  logic [63:0] imem[0:255]; // now imem is 64 bit. we will fetch 2 instructions from imem at a time, addressed by the PC as a bundle. 
  
  assign bundle_F = imem[PC_F]; 
  assign instr_even_F = bundle_F[63:32]; 
  assign instr_odd_F = bundle_F[31:0];

  initial begin 
    $readmemh("./instmem.dat", imem);
  end 
  
  assign instr_F = imem[PC_F];

  //  ------------- DECODERS -- both even and odd instructions (bundle) ------------------ // 
  decoder decode_even (
    .instruction(instr_even_E),
    .opcode(opcode_even_E), .funct3(funct3_even_E), .funct7(funct7_even_E), .csr(csr_even_E),
    .rs1(rs1_even_E), .rs2(rs2_E), .rd(rd_even_E),
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
  
  // ALU input A -- PC or rs1
  assign alu_a = alusrc_pc ? (PC_E << 2) : rf_rd1;
  
  // ALU input B --  imm20, immediate, or rs2
  always_comb begin
    if (alusrc_imm20) begin
      alu_b = imm20_E;  // AUIPC
    end else if (alusrc) begin
      if (aluop == 4'b1000 || aluop == 4'b1001 || aluop == 4'b1010)
        alu_b = shamt;  // shift instructions use a 5-bit shift amount
      else
        alu_b = imm_I_sext;  // i type  immediate (alu ops & jalr)
    end else begin
      alu_b = rf_rd2;  // r type uses rs2
    end
  end
  
  alu alu_inst (
    .A(alu_a), .B(alu_b), .op(aluop),
    .R(alu_result), .zero(alu_zero)
  );


  // branch condition evaluation
  always_comb begin
    branch_taken = 1'b0;
    if (is_branch) begin
      case(funct3_E)
        3'b000 : branch_taken = alu_zero;         // beq
        3'b001 : branch_taken = ~alu_zero;        // bne
        3'b100 : branch_taken = alu_result[0];    // blt
        3'b101 : branch_taken = ~alu_result[0];   // bge
        3'b110 : branch_taken = alu_result[0];    // bltu
        3'b111 : branch_taken = ~alu_result[0];   // bgeu
      endcase
    end
  end
  
  assign PC_E_byte = PC_E << 2;
  assign branch_target = (PC_E_byte + imm_B_E) >> 2;
  assign jal_target = (PC_E_byte + imm_J_E) >> 2;
  assign jalr_target = (alu_result & 32'hfffffffe) >> 2;
  
  assign take_branch = is_jal || is_jalr || (is_branch && branch_taken);

  // the fetch stage pipeline!!!!!!
  always_comb begin
    if (take_branch) begin
      if (is_jal)       PC_F_next = jal_target;
      else if (is_jalr) PC_F_next = jalr_target;
      else              PC_F_next = branch_target;
    end else begin
      PC_F_next = PC_F + 1; // PC_F is an index, and imem at said address returns a 64-bit bundle
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

  assign PC_F_next = PC_F + 1; // we are going to next index. 

  // exec stage pipeline
  always_ff @(posedge clk) begin
    if (!rst) begin
      inst_even_E <= 32'h00000013; // NOP
      PC_E <= 32'd0;
    end else begin
      if (take_branch) begin
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
      alu_result_W <= 32'd0;
      rd_W <= 5'd0;
      regwrite_W <= 1'b0;
      regsel_W <= 2'b00;
      imm20_W <= 32'd0;
      PC_plus4_W <= 32'd0;
      gpio_we_W <= 1'b0;
      rs1_data_W <= 32'd0;
      rs2_data_W <= 32'd0; //?
    end else begin
      alu_result_W <= alu_result;
      rd_W <= rd_E;
      regwrite_W <= regwrite;
      regsel_W <= regsel;
      imm20_W <= imm20_E;
      PC_plus4_W <= (PC_E << 2) + 4;
      gpio_we_W <= gpio_we;
      rs1_data_W <= rf_rd1;
      rs2_data_W <= rf_rd2;
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
