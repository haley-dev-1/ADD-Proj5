// csce611 Michael Stewart & Haley Lind

module decoder (
  input logic [31:0] instruction, 
  
  output logic [6:0] opcode,
  output logic [2:0] funct3, 
  output logic [6:0] funct7, 
  output logic [11:0] csr,
  output logic [4:0] rs1, rs2, rd,
  output logic [11:0] imm12,     // i type
  output logic [11:0] imm_S,     // s type
  output logic [31:0] imm20,     // u type
  output logic [31:0] imm_B,     // b type
  output logic [31:0] imm_J      // j type
);

  // basics
  assign opcode = instruction[6:0];
  assign rd     = instruction[11:7];
  assign funct3 = instruction[14:12];
  assign rs1    = instruction[19:15];
  assign rs2    = instruction[24:20];
  assign funct7 = instruction[31:25];
  assign csr    = instruction[31:20];
  
  // i type sign-extended 12-bit immediate
  assign imm12 = instruction[31:20];
   
  // u type upper 20 bits, already shifted
  assign imm20 = {instruction[31:12], 12'b0};
  
  // b type instructions reconstruct 13-bit offset (sign-extended to 32-bit)
  assign imm_B = {{20{instruction[31]}}, instruction[31], instruction[7],
                  instruction[30:25], instruction[11:8], 1'b0};
  
  // j type reconstruct 21-bit offset (sign-extended to 32-bit)
  // instruction bits:[31]=imm[20], [19:12]= imm[19:12], [20]=imm[11], [30:21]=imm[10:1]
  assign imm_J = {{12{instruction[31]}}, instruction[31], instruction[19:12],
                  instruction[20], instruction[30:21], 1'b0};

endmodule
