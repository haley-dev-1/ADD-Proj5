/*
 * Haley Lind & Michael Stewart
 * CSCE611 RISCV 3 Stage CPU Design
 * Fall 2025
*/

module riscv_32_instr_decoder(
        input logic [31:0] full,

        output logic [6:0] opcode,      // all 
        output logic [2:0] funct3, // 
        output logic [6:0] funct7, // 
        output logic [4:0] rs1,    // 
        output logic [4:0] rs2,    // 
        output logic [4:0] rd,     // dest ... all 
        output logic [11:0] imm12,  // csrrw 
        output logic [19:0] imm20,  // u type
        output logic [20:0] imm_j, //jumping
        output logic [12:0] imm_b // branching 

        //output logic [2:0] // if i was using lut but i decided not to in my design

);

assign opcode = full[6:0]; // grabs those bits, which tell opcode
assign funct3 = full[14:12];
assign funct7 = full[31:25]; 
assign rs1 = full[19:15];
assign rs2 = full[24:20];
assign rd = full[11:7];

/* I Type immediate for CSRRW, etc. */
assign imm12 = full[31:20]; //giving syntax error without full & semicolon

/* U type immediate */
assign imm20 = full[31:12];

// jump and brach assignments
assign imm_j = {full[31], full[19:12], full[20], full[30:21], 1'b0};
assign imm_b = {full[31], full[7], full[30:25], full[11:8], 1'b0};

/* ----- WE AREN'T USING THIS .... But I'm keeping it!
// instantiate lut from lut.sv
// get value from lut (it returns a 0, 1, or 2 in binary)
lut lut_for_instruction_type(
                .op(opcode),
                .instr_type(type_of_instruction)
                                );
// above lut gives back 000, 001, or 010 based on op code (3 bits -- can be extended)
*/
endmodule
