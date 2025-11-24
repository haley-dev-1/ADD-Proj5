module cpu(
    input logic clk, 
    input logic res,
    input logic [31:0] gpio_in,
    output logic [31:0] gpio_out
);

    // Decoded instruction fields
    logic [6:0] opcode; 
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;
    logic [11:0] imm12;
    logic [19:0] imm20;
    logic [20:0] imm_j;  // NEW
    logic [12:0] imm_b;  // NEW
    
    // Control signals
    logic [1:0] alusrc_EX;
    logic [0:0] GPIO_we; 
    logic [0:0] regwrite_EX;
    logic [1:0] regsel_EX;
    logic [3:0] aluop_EX;
    logic branch;       // NEW
    logic jump;         // NEW
    
    // Registered control signals
    logic [1:0] alusrc_EX_reg;
    logic [0:0] GPIO_we_reg;
    logic [0:0] regwrite_EX_reg;
    logic [1:0] regsel_EX_reg;
    logic [3:0] aluop_EX_reg;
    logic branch_reg;   // NEW
    logic jump_reg;     // NEW
    logic [2:0] funct3_reg;  // NEW: needed for branch conditions
    
    // Register file signals 
    logic [31:0] readdata1, readdata2; 
    logic [31:0] writedata;
    
    // ALU signals 
    logic [31:0] alu_A, alu_B, alu_result; 
    logic alu_zero;
    
    // GPIO registers
    logic [31:0] gpio_out_reg;
    assign gpio_out = gpio_out_reg; 
    
    // PC and instruction signals
    logic [31:0] pc_F;
    logic [31:0] pc_next;  // NEW
    logic [31:0] instruction_F;
    logic [31:0] instruction_mem [4095:0];
    logic [31:0] instruction_EX;
    
    // Branch/Jump target calculation
    logic [31:0] pc_EX;              
    logic [31:0] branch_target;      
    logic [31:0] jump_target;      
    logic [31:0] imm_b_ext;         
    logic [31:0] imm_j_ext;         
    logic branch_taken;              
    
    initial $readmemh("./instmem.dat", instruction_mem);

    // Fetch stage
    always_ff @(posedge clk) begin
        if (res) begin
            instruction_EX <= 32'b0;
            pc_F <= 32'b0;
            pc_EX <= 32'b0;
        end else begin
            instruction_EX <= instruction_mem[pc_F[11:2]];
            pc_EX <= pc_F;  // Pass PC to EX stage
            pc_F <= pc_next;
        end
    end

    // Instruction decoder
    riscv_32_instr_decoder decode (
        .full(instruction_EX),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm12(imm12),
        .imm20(imm20),
        .imm_j(imm_j),
        .imm_b(imm_b)
    );

    // Control unit
    ctrl_unit ctrl (
        .op(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .imm12(imm12),
        .imm20(imm20), 
        .alusrc_EX(alusrc_EX),     
        .GPIO_we(GPIO_we),
        .regwrite_EX(regwrite_EX),
        .regsel_EX(regsel_EX),
        .aluop_EX(aluop_EX),
        .branch(branch),
        .jump(jump)
    );
    
    // Register control signals
    always_ff @(posedge clk) begin
        if (res) begin
            alusrc_EX_reg <= 2'b00;
            GPIO_we_reg <= 1'b0;
            regwrite_EX_reg <= 1'b0;
            regsel_EX_reg <= 2'b00;
            aluop_EX_reg <= 4'b0000;
            branch_reg <= 1'b0;
            jump_reg <= 1'b0;
            funct3_reg <= 3'b000;
        end else begin
            alusrc_EX_reg <= alusrc_EX;
            GPIO_we_reg <= GPIO_we;
            regwrite_EX_reg <= regwrite_EX;
            regsel_EX_reg <= regsel_EX;
            aluop_EX_reg <= aluop_EX;
            branch_reg <= branch;
            jump_reg <= jump;
            funct3_reg <= funct3;
        end
    end
    
    // Sign-extend immediates
    assign imm_b_ext = {{19{imm_b[12]}}, imm_b};
    assign imm_j_ext = {{11{imm_j[20]}}, imm_j};
    
    // Calculate branch and jump targets
    assign branch_target = pc_EX + imm_b_ext;
    assign jump_target = (opcode == 7'b1100111) ? (alu_result & ~32'b1) : (pc_EX + imm_j_ext);
    
    // Branch condition logic
    always_comb begin
        branch_taken = 1'b0;
        if (branch_reg) begin
            case(funct3_reg)
                3'b000: branch_taken = alu_zero;           // BEQ
                3'b001: branch_taken = ~alu_zero;          // BNE
                3'b100: branch_taken = alu_result[0];      // BLT
                3'b101: branch_taken = ~alu_result[0];     // BGE
                3'b110: branch_taken = alu_result[0];      // BLTU
                3'b111: branch_taken = ~alu_result[0];     // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end
    
    // PC control logic
    always_comb begin
        if (jump_reg) begin
            pc_next = jump_target;
        end else if (branch_taken) begin
            pc_next = branch_target;
        end else begin
            pc_next = pc_F + 32'd4;
        end
    end
    
    // Register file
    regfile rf (
        .clk(clk),
        .we(regwrite_EX_reg),
        .readaddr1(rs1),
        .readaddr2(rs2),
        .writeaddr(rd),
        .writedata(writedata),
        .readdata1(readdata1),
        .readdata2(readdata2)
    );
    
    // ALU
    alu alu_inst ( 
        .A(alu_A),
        .B(alu_B),
        .op(aluop_EX_reg),
        .R(alu_result),
        .zero(alu_zero)
    );
    
    assign alu_A = readdata1;
    
    // ALU input B mux
    always_comb begin
        case(alusrc_EX_reg)
            2'b00: alu_B = readdata2;
            2'b01: alu_B = {{20{imm12[11]}}, imm12};
            2'b10: alu_B = {imm20, 12'b0};
            default: alu_B = 32'b0;
        endcase
    end 
    
    // Writeback mux (need to add PC+4 for JAL/JALR)
    always_comb begin 
        case(regsel_EX_reg)
            2'b00: writedata = 32'b0;
            2'b01: writedata = {imm20, 12'b0};  // LUI
            2'b10: begin
                // Check if this is JAL/JALR (need PC+4) or normal ALU result
                if (jump_reg)
                    writedata = pc_EX + 32'd4;  // Return address for JAL/JALR
                else
                    writedata = alu_result;
            end
            2'b11: writedata = gpio_in;
            default: writedata = 32'b0;
        endcase
    end
    
    // GPIO output register
    always_ff @(posedge clk) begin 
        if (res) begin
            gpio_out_reg <= 32'b0;
        end else if (GPIO_we_reg) begin 
            gpio_out_reg <= readdata1;
        end
    end 
    		 
endmodule
