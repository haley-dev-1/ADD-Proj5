/*
 * Haley Lind & Michael Stewart
 * CSCE611 RISCV 3 Stage CPU Design
 * Fall 2025
 *
 * This is the brain of the CPU. It looks at opcode, funct3, funct7,
 * and imm12 fields from an instruction and decides what control signals
 * to send to other parts of the CPU.
 */

module ctrl_unit(
    input logic [6:0] op,       // opcode from instruction decoder
    input logic [2:0] funct3,   // funct3 field
    input logic [6:0] funct7,   // funct7 field
    input logic [11:0] imm12,   // immediate for CSR/GPIO instructions
    input logic [19:0] imm20,   // legacy
    
    // info comes back from  the EX stage to decide branch/jalr
    input logic alu_zero_EX, // beq, bne
    input logic lt_signed_EX, // result of SLT (signed <)
    input logic lt_unsigned_EX, // result of SLTU (unsigned <)

    output logic [1:0] alusrc_EX,
    output logic        GPIO_we,
    output logic        regwrite_EX,
    output logic [2:0] regsel_EX,
    output logic [3:0] aluop_EX,
    output logic [1:0] pcsrc_ctrl_EX // 2 bits!  seq (00), 01 for branch, jal (10), jalr (11) 

    // for stalls
    output logic stall_FETCH,
    output logic stall_EX

);

    always_comb begin
        // -------------------- Setting defaults --------------------
        regwrite_EX = 1'b0;
        alusrc_EX   = 2'b00;
        GPIO_we     = 1'b0;
        regsel_EX   = 3'b000;
        aluop_EX    = 4'b0000;
        pcsrc_ctrl_EX  = 2'b00; // defautl to sequential; 00 == seq

        stall_FETCH = 1'b0; // probably a smart idea to keep fall at "no" (0) on default 
        stall_EX = 1'b0 // ''

        case(op)
            // -------------------- R TYPE --------------------
            7'b0110011: begin
                regwrite_EX = 1'b1;
                alusrc_EX   = 2'b00;
                regsel_EX   = 3'b010;
                GPIO_we     = 1'b0; // no write

                if (funct7 == 7'b0000000) begin
                    if      (funct3 == 3'b000) aluop_EX = 4'b0011; // ADD
                    else if (funct3 == 3'b100) aluop_EX = 4'b0010; // XOR
                    else if (funct3 == 3'b110) aluop_EX = 4'b0000; // OR
                    else if (funct3 == 3'b111) aluop_EX = 4'b0000; // AND
                    else if (funct3 == 3'b001) aluop_EX = 4'b1000; // SLL
                    else if (funct3 == 3'b101) aluop_EX = 4'b1001; // SRL
                    else if (funct3 == 3'b010) aluop_EX = 4'b1100; // SLT
                    else if (funct3 == 3'b011) aluop_EX = 4'b1101; // SLTU
                end
                else if (funct7 == 7'b0100000) begin
                    if (funct3 == 3'b000) aluop_EX = 4'b0100; // SUB
                    else if (funct3 == 3'b101) aluop_EX = 4'b1010; // SRA
                end
                else if (funct7 == 7'b0000001) begin
                    if      (funct3 == 3'b000) aluop_EX = 4'b0101; // MUL
                    else if (funct3 == 3'b001) aluop_EX = 4'b0110; // MULH
                    else if (funct3 == 3'b010) aluop_EX = 4'b0111; // MULHSU
                    else if (funct3 == 3'b011) aluop_EX = 4'b0111; // MULHU
                    else if (funct3 == 3'b100) aluop_EX = 4'b1110; // DIV
                    else if (funct3 == 3'b101) aluop_EX = 4'b1110; // DIVU
                    else if (funct3 == 3'b110) aluop_EX = 4'b1111; // REM
                    else if (funct3 == 3'b111) aluop_EX = 4'b1111; // REMU
                end
            end

            // -------------------- I TYPE --------------------
            7'b0010011: begin
                regwrite_EX = 1'b1;
                alusrc_EX   = 2'b01;
                regsel_EX   = 3'b010;
                GPIO_we     = 1'b0;

                if      (funct3 == 3'b000) aluop_EX = 4'b0011; // ADDI
                else if (funct3 == 3'b001) aluop_EX = 4'b1000; // SLLI
                else if (funct3 == 3'b011) aluop_EX = 4'b1101; // SLTIU
                else if (funct3 == 3'b100) aluop_EX = 4'b0010; // XORI
                else if (funct3 == 3'b101) aluop_EX = 4'b1001; // SRLI
                else if (funct3 == 3'b110) aluop_EX = 4'b0001; // ORI
                else if (funct3 == 3'b111) aluop_EX = 4'b0000; // ANDI
            end

            // --------------------- JALR (I type) ----------------------- // 
            7'b1100111: begin
                regwrite_EX = 1'b1;     // pc+$
                
                GPIO_we = 1'b0;
                regsel_EX = 3'b010;
                
                alusrc_EX = 2'b10;
                aluop_EX = 4'b0011;     // TODO double check, now its add.
                
                pcsrc_ctrl_EX = 2'b11;                

                stall_FETCH = 1'b1; // turn on
                stall_EX = 1'b1;
            end
            // ----------------------------------------------------------- //

            // ============================================== J ================================================ // 
            // -------------------- JAL (J TYPE) ------------------------------------------------------------------ //
            7'b1101111: begin           // jal rd, offset: R[rd] = PC+4; PC <- PC + sext(offset) 
                
                regwrite_EX = 1'b1;     // We are indeed writing. address goes into rd.

                GPIO_we = 1'b0;
                regsel_EX = 3'b100;      // pertains to pc_4 for jal/jalr

                // ---- KEY IDEA: WE DON'T USE THE ALU FOR JUMP INSTRUCTIONS... THEY DON'T OPERATE ON NOTHIN'! ---- //
                alusrc_EX = 2'b00; //   // leave at 0 cuz we don't use the alu operand for jal instruction 
                aluop_EX = 4'b0011;           // we don't use this for jal; we set to ADD.  
                // ------------------------------------------------------------------------------------------------ //

                pcsrc_ctrl_EX = 2'b10;  // decoding is somewhere above. it tells us pcsrc_ctrl_EX settings are set  to 10 for JAL (J) type logic. 

                // change to yes, insert for next cucle so instruction can't commit
                stall_FETCH   = 1'b1;
                stall_EX = 1'b1;
            end
            // ================================================================================================= // 

            // =========================================== B ==================================== //
            // B Type Instructions - "tHESE PREVENT THE cpu FROM EXECUTING THE NEXT INSTRUCTION IN THE PROGRAM, AND INSTEAD BEGIN A SEQ. OF INSTRUCTIONS IN ANOTHER MEMORY LOCAITON
            7'b1100011: begin

                // defaults
                regwrite_EX = 1'b0;
                GPIO_we = 1'b0;
                regsel_EX = 3'b000;
                alusrc_EX = 2'b00; // compare rs1, rs2

                logic branch_taken;
                branch_taken = 1'b0;

                if  (funct3 == 3'b000) // b
                    aluop_EX = 4'b1000;
                else if  (funct3 == 3'b101) // bge
                    aluop_EX = 4'b1000;
                else if  (funct3 == 3'b111) // bgeu
                    aluop_EX = 4'b1000;     // ??? original said 10000 its 4 bits but thats 5 bits? fix this
                else if  (funct3 == 3'b100) // blt
                    aluop_EX = 4'b1000;
                else if  (funct3 == 3'b110) // bltu
                    aluop_EX = 4'b????~;

            end


            // -------------------- U TYPE (LUI) --------------------
            7'b0110111: begin
                regwrite_EX = 1'b1;
                alusrc_EX   = 2'b10;
                regsel_EX   = 3'b001;
                GPIO_we     = 1'b0;
                aluop_EX    = 4'b0000;
            end

            // -------------------- CSRRW --------------------
            7'b1110011: begin
                regwrite_EX = 1'b0;
                alusrc_EX   = 2'b00;
                regsel_EX   = 3'b000;
                aluop_EX   = 4'b0000;
                GPIO_we = 1'b0;

                if (imm12 == 12'hF00) begin
                    GPIO_we     = 1'b0;
                    regwrite_EX = 1'b1;
                    regsel_EX = 3'b011;
                end
                else if (imm12 == 12'hF02) begin
                    GPIO_we     = 1'b1;
                    regwrite_EX = 1'b1;
                    regsel_EX   = 3'b011;
                end
                else begin
                    GPIO_we = 1'b0;
                    regwrite_EX = 1'b0;
                    regsel_EX = 3'b000;
                end
            end

            // -------------------- DEFAULT --------------------
            default: begin
                regwrite_EX = 1'b0;
                alusrc_EX   = 2'b00;
                GPIO_we     = 1'b0;
                regsel_EX   = 3'b000;
                aluop_EX    = 4'b0000;
            end
        endcase
    end

endmodule

