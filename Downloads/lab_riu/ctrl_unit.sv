/*
 * Haley Lind & Michael Stewart
 * CSCE611 RISCV 3 Stage CPU Design
 * Fall 2025
 */

module ctrl_unit(
    input logic [6:0] op,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic [11:0] imm12,
    input logic [19:0] imm20,
    output logic [1:0] alusrc_EX,
    output logic GPIO_we,
    output logic regwrite_EX,
    output logic [1:0] regsel_EX,
    output logic [3:0] aluop_EX,
    output logic branch,
    output logic jump // new operations that come out of the control unit.
);

    always_comb begin
        regwrite_EX = 1'b0;
        alusrc_EX   = 2'b00;
        GPIO_we     = 1'b0;
        regsel_EX   = 2'b00;
        aluop_EX    = 4'b0000;
        branch = 1'b0;
        jump = 1'b0; // make them 1 bit signals, defaulting to off

        case(op)
            // R TYPE
            7'b0110011: begin
                regwrite_EX = 1'b1;
                alusrc_EX   = 2'b00;
                regsel_EX   = 2'b10;
                GPIO_we     = 1'b0;

                if (funct7 == 7'b0000000) begin
                    if      (funct3 == 3'b000) aluop_EX = 4'b0011; // ADD
                    else if (funct3 == 3'b100) aluop_EX = 4'b0010; // XOR
                    else if (funct3 == 3'b110) aluop_EX = 4'b0001; // OR
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

            // I TYPE
            7'b0010011: begin
                regwrite_EX = 1'b1;
                alusrc_EX   = 2'b01;
                regsel_EX   = 2'b10;
                GPIO_we     = 1'b0;

                if      (funct3 == 3'b000) aluop_EX = 4'b0011; // ADDI
                else if (funct3 == 3'b001) aluop_EX = 4'b1000; // SLLI
                else if (funct3 == 3'b011) aluop_EX = 4'b1101; // SLTIU
                else if (funct3 == 3'b100) aluop_EX = 4'b0010; // XORI
                else if (funct3 == 3'b101) aluop_EX = 4'b1001; // SRLI
                else if (funct3 == 3'b110) aluop_EX = 4'b0001; // ORI
                else if (funct3 == 3'b111) aluop_EX = 4'b0000; // ANDI
            end

            // U TYPE (LUI)
            7'b0110111: begin
                regwrite_EX = 1'b1;
                alusrc_EX   = 2'b10;
                regsel_EX   = 2'b01;
                GPIO_we     = 1'b0;
                aluop_EX    = 4'b0000;
            end

            // CSRRW - CORRECTED FOR 0xF00=INPUT, 0xF02=OUTPUT
            7'b1110011: begin
                regwrite_EX = 1'b0;
                alusrc_EX   = 2'b00;
                regsel_EX   = 2'b00;
                aluop_EX    = 4'b0000;

                if (imm12 == 12'hF00) begin
                    // READ from GPIO input (switches) - 0xF00
                    GPIO_we     = 1'b0;
                    regwrite_EX = 1'b1;
                    regsel_EX   = 2'b11;
                end
                else if (imm12 == 12'hF02) begin
                    // WRITE to GPIO output (HEX displays) - 0xF02
                    GPIO_we     = 1'b1;
                    regwrite_EX = 1'b0;
                    regsel_EX   = 2'b00;
                end
                else begin
                    GPIO_we     = 1'b0;
                    regwrite_EX = 1'b0;
                    regsel_EX   = 2'b00;
                end
            end
            
            // B-Type Instruction
            7'b1100011: begin 
            	regwrite_EX = 1'b0;
            	alusrc_EX = 2'b00;
            	regsel_EX = 2'b00;
            	GPIO_we = 1'b0;
            	branch = 1'b1;
            	
            	if (funct3 == 3'b000) aluop_EX = 4'b0100; // BEQ
            	else if (funct3 == 3'b001) aluop_EX = 4'b0100; // BNE
            	else if (funct3 == 3'b100) aluop_EX = 4'b1100; // BLT
            	else if (funct3 == 3'b101) aluop_EX = 4'b1101; // BGE
             	else if (funct3 == 3'b110) aluop_EX = 4'b1101; // BLTU
            	else if (funct3 == 3'b111) aluop_EX = 4'b0100; // BEGU
            end
            
            // jump and link
            7'b1101111: begin
            	regwrite_EX = 1'b1;
            	regsel_EX = 2'b10;
            	jump = 1'b1;
            	alusrc_EX = 2'b00;
            	GPIO_we = 1'b0;
            end
            
            7'b1100111: begin
            	regwrite_EX = 1'b1;
            	regsel_EX = 2'b10;
            	jump = 1'b1;
            	alusrc_EX = 2'b01;
            	GPIO_we = 1'b0;
            	aluop_EX = 4'b0011;
            end	
            	
            default: begin
                regwrite_EX = 1'b0;
                alusrc_EX   = 2'b00;
                GPIO_we     = 1'b0;
                regsel_EX   = 2'b00;
                aluop_EX    = 4'b0000;
            end
        endcase
    end

endmodule
