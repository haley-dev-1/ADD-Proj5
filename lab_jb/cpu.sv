// Haley Lind & Michael Stewart - Simplified CPU (No Data Memory)
module cpu ( 
  input logic clk, 
  input logic rst, // active low reset 
  input logic [31:0] gpio_in,
  output logic [31:0] gpio_out
);

  // Fetch stage
  logic [31:0] PC_F, PC_F_next;
  logic [31:0] instr_F;
  
  // Execute stage  
  logic [31:0] instr_E, PC_E;
  logic [6:0] opcode_E;
  logic [2:0] funct3_E;
  logic [6:0] funct7_E;
  logic [11:0] csr_E;
  logic [4:0] rs1_E, rs2_E, rd_E;
  logic [11:0] imm12_E;
  logic [31:0] imm20_E, imm_B_E, imm_J_E;
  
  // Writeback stage
  logic [31:0] alu_result_W, PC_plus4_W, imm20_W;
  logic [31:0] rs1_data_W, rs2_data_W;
  logic [4:0] rd_W;
  logic regwrite_W, gpio_we_W;
  logic [1:0] regsel_W;

  // Control signals (Execute stage)
  logic [3:0] aluop;
  logic alusrc, alusrc_pc, alusrc_imm20;
  logic [1:0] regsel;
  logic regwrite, gpio_we;
  logic is_branch, is_jal, is_jalr;
  logic branch_taken, take_branch;

  // Datapath signals
  logic [31:0] rf_rd1, rf_rd2, rf_wd;
  logic [31:0] alu_a, alu_b, alu_result;
  logic alu_zero;
  logic [31:0] PC_E_byte;
  logic [31:0] branch_target, jal_target, jalr_target;

  // ====================================================================
  // INSTRUCTION MEMORY (Read-only)
  // ====================================================================
  logic [31:0] imem[0:255];
  
  initial begin 
    $readmemh("./instmem.dat", imem);
  end 
  
  assign instr_F = imem[PC_F];

  // ====================================================================
  // DECODER
  // ====================================================================
  decoder decode (
    .instruction(instr_E),
    .opcode(opcode_E), .funct3(funct3_E), .funct7(funct7_E), .csr(csr_E),
    .rs1(rs1_E), .rs2(rs2_E), .rd(rd_E),
    .imm12(imm12_E), .imm_S(), .imm20(imm20_E),
    .imm_B(imm_B_E), .imm_J(imm_J_E)
  );

  // ====================================================================
  // CONTROL UNIT
  // ====================================================================
  control_unit ctrl (
    .opcode(opcode_E), .funct3(funct3_E), .funct7(funct7_E), .csr(csr_E),
    .stall_EX(1'b0), .stall_FETCH(),
    .aluop(aluop), .alusrc(alusrc), .alusrc_pc(alusrc_pc), .alusrc_imm20(alusrc_imm20),
    .regsel(regsel), .regwrite(regwrite),
    .memread(), .memwrite(), .gpio_we(gpio_we),
    .is_branch(is_branch), .is_jal(is_jal), .is_jalr(is_jalr)
  );

  // ====================================================================
  // REGISTER FILE
  // ====================================================================
  logic rf_we;
  assign rf_we = (rd_W != 5'd0) && regwrite_W;
  
  regfile rf (
    .clk(clk), .we(rf_we),
    .readaddr1(rs1_E), .readaddr2(rs2_E),
    .writeaddr(rd_W), .writedata(rf_wd),
    .readdata1(rf_rd1), .readdata2(rf_rd2)
  );

  // ====================================================================
  // ALU DATAPATH
  // ====================================================================
  
  // Immediate sign extension
  logic [31:0] imm_I_sext, shamt;
  assign imm_I_sext = {{20{imm12_E[11]}}, imm12_E};
  assign shamt = {27'b0, imm12_E[4:0]};
  
  // ALU input A: PC or rs1
  assign alu_a = alusrc_pc ? (PC_E << 2) : rf_rd1;
  
  // ALU input B: imm20, immediate, or rs2
  always_comb begin
    if (alusrc_imm20) begin
      alu_b = imm20_E;  // AUIPC
    end else if (alusrc) begin
      if (aluop == 4'b1000 || aluop == 4'b1001 || aluop == 4'b1010)
        alu_b = shamt;  // Shift instructions use 5-bit shift amount
      else
        alu_b = imm_I_sext;  // I-type immediate (ALU ops, JALR)
    end else begin
      alu_b = rf_rd2;  // R-type uses rs2
    end
  end
  
  alu alu_inst (
    .A(alu_a), .B(alu_b), .op(aluop),
    .R(alu_result), .zero(alu_zero)
  );

  // ====================================================================
  // BRANCH & JUMP LOGIC
  // ====================================================================
  
  // Branch condition evaluation
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

  // ====================================================================
  // FETCH STAGE PIPELINE
  // ====================================================================
  
  always_comb begin
    if (take_branch) begin
      if (is_jal)       PC_F_next = jal_target;
      else if (is_jalr) PC_F_next = jalr_target;
      else              PC_F_next = branch_target;
    end else begin
      PC_F_next = PC_F + 1;
    end
  end
  
  always_ff @(posedge clk) begin
    if (!rst) PC_F <= 32'd0;
    else      PC_F <= PC_F_next;
  end

  // ====================================================================
  // EXECUTE STAGE PIPELINE
  // ====================================================================
  
  always_ff @(posedge clk) begin
    if (!rst) begin
      instr_E <= 32'h00000013; // NOP
      PC_E <= 32'd0;
    end else begin
      if (take_branch) begin
        instr_E <= 32'h00000013; // Flush pipeline on branch/jump
      end else begin
        instr_E <= instr_F;
      end
      PC_E <= PC_F;
    end
  end

 
  // WRITEBACK STAGE PIPELINE

  
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
      rs2_data_W <= 32'd0;
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
