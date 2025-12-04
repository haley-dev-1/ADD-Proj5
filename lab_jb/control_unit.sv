// Michael Stewart and Haley Lind 
module control_unit ( 
  input logic [6:0] opcode, 
  input logic [2:0] funct3, 
  input logic [6:0] funct7, 
  input logic [11:0] csr,
  
  input  logic stall_EX,
  output logic stall_FETCH,
  
  output logic [3:0] aluop, 
  output logic alusrc,
  output logic alusrc_pc,     // Select PC as ALU A input (for AUIPC)
  output logic alusrc_imm20,  // Select imm20 as ALU B input (for AUIPC)
  output logic [1:0] regsel, 
  output logic regwrite,
  output logic memread,
  output logic memwrite,
  output logic gpio_we,
  output logic is_branch,
  output logic is_jal,
  output logic is_jalr
); 
  
  always_comb begin 
    // Default values
    aluop = 4'b0000;
    alusrc = 1'b0;
    alusrc_pc = 1'b0;
    alusrc_imm20 = 1'b0;
    regsel = 2'b10; 
    regwrite = 1'b0;
    memread = 1'b0;
    memwrite = 1'b0;
    gpio_we = 1'b0;
    is_branch = 1'b0;
    is_jal = 1'b0;
    is_jalr = 1'b0;
    stall_FETCH = 1'b0;
    
    if (stall_EX) begin
      // If stalled, turn off all write enables
      regwrite = 1'b0;
      memwrite = 1'b0;
      gpio_we = 1'b0;
    end else begin
      case(opcode) 
        // ***************************** R-Type instructions (opcode 0110011) *******************************************

        7'b0110011 : begin 
          regwrite = 1'b1; 
          regsel = 2'b10;  // ALU result to register
          alusrc = 1'b0;   // Use rs2 (not immediate)
          
          case (funct7) 
            7'b0000000 : begin 
              case(funct3)
                3'b000 : aluop = 4'b0011; // add
                3'b001 : aluop = 4'b1000; // sll
                3'b010 : aluop = 4'b1100; // slt (signed)
                3'b011 : aluop = 4'b1101; // sltu (unsigned)
                3'b100 : aluop = 4'b0010; // xor
                3'b101 : aluop = 4'b1001; // srl
                3'b110 : aluop = 4'b0001; // or
                3'b111 : aluop = 4'b0000; // and
              endcase 
            end
            
            7'b0100000 : begin 
              case(funct3) 
                3'b000 : aluop = 4'b0100; // sub
                3'b101 : aluop = 4'b1010; // sra
              endcase
            end 
            
            7'b0000001 : begin  // M extension
              case(funct3) 
                3'b000 : aluop = 4'b0101; // mul
                3'b001 : aluop = 4'b0110; // mulh
                3'b011 : aluop = 4'b0111; // mulhu
                // Note: div/divu/rem/remu not required by lab
              endcase 
            end
          endcase
        end 
   
        // ******************** I-Type ALU instructions (opcode 0010011) *************************
        7'b0010011 : begin 
          regwrite = 1'b1; 
          alusrc = 1'b1;   // Use immediate
          regsel = 2'b10;  // ALU result to register
          
          case(funct3)
            3'b000 : aluop = 4'b0011;  // addi
            3'b001 : aluop = 4'b1000;  // slli
            3'b010 : aluop = 4'b1100;  // slti (signed)
            3'b011 : aluop = 4'b1101;  // sltiu (unsigned)
            3'b100 : aluop = 4'b0010;  // xori
            3'b101 : begin
              if (funct7 == 7'b0000000) 
                aluop = 4'b1001; // srli
              else
                aluop = 4'b1010; // srai
            end
            3'b110 : aluop = 4'b0001;  // ori
            3'b111 : aluop = 4'b0000;  // andi
          endcase
        end
        

        // I-Type Load instructions (opcode 0000011)
        7'b0000011 : begin // LOAD (lb, lh, lw, lbu, lhu)
          regwrite = 1'b1;
          alusrc = 1'b1;   // Use immediate for address calculation
          aluop = 4'b0011; // ADD: rs1 + imm12
          regsel = 2'b10;  // Memory data to register
          memread = 1'b1;
        end
     	// 
        7'b0100011 : begin // storing 
          alusrc = 1'b1;   // use immediate for address calculation
          aluop = 4'b0011; // TODO, ADD: rs1 + imm12
          memwrite = 1'b1;
          regwrite = 1'b0; // stores don't write to register file
         
        end
        
        // *********************** U-Type: LUI (opcode 0110111) ***************************************************
        7'b0110111 : begin // lui
          regwrite = 1'b1;
          regsel = 2'b01;  // imm20 to register (upper immediate)
        end 
        

        // U-Type: AUIPC (opcode 0010111)

        7'b0010111 : begin // auipc
          regwrite = 1'b1;
          alusrc_pc = 1'b1;      // Use PC as ALU A input (not rs1)
          alusrc_imm20 = 1'b1;   // Use imm20 as ALU B input (not imm12)
          aluop = 4'b0011;       // ADD: PC + imm20
          regsel = 2'b10;        // ALU result to register
        end
   

        // ******************************************CSR instructions (opcode 1110011) *****************************
        7'b1110011 : begin 
          if (funct3 == 3'b001) begin // csrrw
            case(csr)
              12'hf00 : begin // Read from GPIO input (io0)
                regwrite = 1'b1;
                regsel = 2'b00;  // GPIO input to register
              end 
              12'hf02 : begin // Write to GPIO output (io2)
                gpio_we = 1'b1;
                regwrite = 1'b0;
              end
              default: regwrite = 1'b0;
            endcase
          end
        end
       
        // ************************************B-type: Branch instructions (opcode 1100011) ************************
        7'b1100011 : begin
          is_branch = 1'b1;
          alusrc = 1'b0;  // Compare two registers
          
          case(funct3)
            3'b000 : aluop = 4'b0100; // beq: use subtraction (check zero)
            3'b001 : aluop = 4'b0100; // bne: use subtraction (check not zero)
            3'b100 : aluop = 4'b1100; // blt: signed comparison
            3'b101 : aluop = 4'b1100; // bge: signed comparison
            3'b110 : aluop = 4'b1101; // bltu: unsigned comparison
            3'b111 : aluop = 4'b1101; // bgeu: unsigned comparison
          endcase
        end
        
        // ********************************J-type: JAL (opcode 1101111) *******************************************

        7'b1101111 : begin
          is_jal = 1'b1;
          regwrite = 1'b1;
          regsel = 2'b11;  // PC+4 to register (return address)
        end
        
        // ******************** I-type: JALR (opcode 1100111) ****************************************

        7'b1100111 : begin
          is_jalr = 1'b1;
          regwrite = 1'b1;
          alusrc = 1'b1;   // Use immediate
          aluop = 4'b0011; // ADD: rs1 + imm12
          regsel = 2'b11;  // PC+4 to register (return address)
        end
        
        default : begin
          // Unknown opcode - aka no op .. .default?
        end
               
      endcase
    end
  end
endmodule
