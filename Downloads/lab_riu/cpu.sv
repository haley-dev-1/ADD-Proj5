// haley lind & Michael Stewart csce611 oct15 2025
// needs to be named the same as the file 
module cpu(
    input logic clk, 
    input logic res, // reset
    input logic [17:0] gpio_in,
    output logic [31:0] gpio_out
);
    
    /* 
    – Add branch_addr, jal_addr, and jalr_addr as possible next state values for PC_FETCH
    – Add pcsrc_EX to control PC mux -- this will be used to determine whether sequential next instruction, or if we need to send a different thang.
    – Add stall_FETCH as output of control unit
    – Add stall_EX as input to control unit
    – Add PC_EX as 4th input to regdst mux
    */

    /* Branch Resolution (is a branch taken?)
    pcsrc_ex = 2'b01 // same parameter used in mux for fetch next address
    beq sub R_EX == 32'b0
    bne sub R_EX == 32'b0 
    blt slt 32'b1
    bltu sltu 32'b1
    bge slt b0
    bgeu sltu 32'b0 

    // these conditions determine whether pcsrc_EX indicates fetching for a branch addy or next instruction
    */

    // need to declare instruction fields still 
    logic [6:0] opcode; 
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;
    
    //control signals
    logic [1:0] alusrc_EX;
    logic GPIO_we; 
    logic regwrite_EX;
    logic [1:0] regsel_EX;
    logic [3:0] aluop_EX;
    
    //register file signals 
    logic [31:0] readdata1, readdata2; 
    logic [31:0] writedata;
    
    // ALU signals 
    logic [31:0] alu_A, alu_B, alu_result; 
    logic alu_zero;
    
    //GPIO registers
    logic [31:0] gpio_out_reg;
    
    logic [31:0] pc_F;
    logic [31:0] instruction_F;
    logic [31:0] instruction_EX;

    logic [1:0] pcsrc_ctrl_EX; // <== used in ctlr unit (00=pc+4, 01=branch, 10=jal, 11=jalr)

    // immmediates from decoder (sign-extended)
    logic [31:0] imm_I, imm_B, imm_U, imm_J;

    // instruction memory
        // instr_mem imem (
    //     .clk (clk),
    //     .addr(pc_F),
    //     .data(instruction_F)        // valid next cycle
    // );

   

    // ============= lab 4, so we can implement R and J instructions .... new logic required ============
    logic [31:0] pc_EX;         // PC of instruction in EX stage
    logic [31:0] branch_target_EX;
    logic [31:0] jal_target_EX;
    logic [31:0] jalr_target_EX;
    logic [31:0] pc_next_F;

    // PC targets for control flow, computed in EX stage
    assign branch_target_EX = pc_EX + imm_B;  // B-type
    assign jal_target_EX    = pc_EX + imm_J;  // JAL
    assign jalr_target_EX   = (readdata1 + imm_I) & 32'hFFFF_FFFE; // JALR: (rs1 + imm_I) & ~1
    // =============================================================================


    // "initializing instruction memory" from slides
    logic [31:0] instruction_mem [4095:0]; // 4k-word (32 bits) instruction memory array

    //needs to follow naming of compiled rars program 
    initial $readmemh("instmem.dat", instruction_mem);

    // ===================== PC / instruction fetch ==========================
    // beforehand, our cpu only did sequential next instructions ... no jump/branch ...
    always_ff @(posedge clk) begin
        if (res) begin
            pc_F           <= 32'b0;
            pc_EX          <= 32'b0;
            instruction_EX <= 32'b0; // clear EX-stage instruction
        end else begin
            // Fetch instruction at current fetch PC
            instruction_EX <= instruction_mem[pc_F[11:2]];

            // Pipeline PC into EX so EX knows "its" PC
            pc_EX <= pc_F;

            // Update fetch PC for next cycle according to branch/jump logic
            pc_F <= pc_next_F;
        end
    end
    // ========================================================================

    // TODO: pc_next_F and PC mux controlled by ''_EX and ''_ctrl_EX
    // pc_next_F = pc+F + $ for standard (good case) case
    // pc_next_F = branch_target_EX
    // pc_next_F = jal_target+EX, jalr_target_Ex when J/JALR

    // select next pc based on contrl from ctrl unit
    always_comb begin
        case (pcsrc_ctrl_EX)
            2'b00: pc_next_F = pc_F + 32'd4;       // normal
            2'b01: pc_next_F = branch_target_EX;    // B-type
            2'b10: pc_next_F = jal_target_EX;       // JAL
            2'b11: pc_next_F = jalr_target_EX;      // JALR
            default: pc_next_F = pc_F + 32'd4;
        endcase
    end

	riscv_32_instr_decoder decode (

            .full(instruction_EX),
            .opcode(opcode),
            
            .funct3(funct3),
            .funct7(funct7),
            
            .rs1(rs1),
            .rs2(rs2),
            .rd(rd),

            .imm_I  (imm_I),
            .imm_B  (imm_B),
            .imm_U  (imm_U),
            .imm_J  (imm_J) 

            // rip, here lies the ghost of imm20 and imm12 from lab3.
    );


    /* =========== TODO: Control signals ... defaults ? =========== */
    /* ==                                                       /* == 
    /* =========================================================== */


    //We wire the control unit to above wires declared in "Control unit wiring" section
    ctrl_unit ctrl (
            .op(opcode),
            .funct3(funct3),
            .funct7(funct7),
           
            /* outputs */
            .alusrc_EX(alusrc_EX),     
            .GPIO_we(GPIO_we),
            .regwrite_EX(regwrite_EX),
            .regsel_EX(regsel_EX),  // 1 or 2 bit? TODO
            .aluop_EX(aluop_EX),    // isn't that four bits*/
            .pcsrc_ctrl_EX(pcsrc_ctrl_EX)
    );
    
    regfile rf (
    .clk(clk),
    .we(regwrite_EX),
    .readaddr1(rs1),
    .readaddr2(rs2),
    .writeaddr(rd),
    .writedata(writedata),
    .readdata1(readdata1),
    .readdata2(readdata2)
    );
    
    alu alu_inst ( 
    .A(alu_A),
    .B(alu_B),
    .op(aluop_EX),
    .R(alu_result),
    .zero(alu_zero)
    );
    
    assign alu_A = readdata1;
    always_comb begin
        case (alusrc_EX)
            2'b00: alu_B = readdata2;  // R TYPE rs2
            2'b01: alu_B = imm_I;      // I tYPE / already sign-extended
            2'b10: alu_B = imm_U;      // U-type: already shifted
            default: alu_B = 32'b0;
        endcase
    end
 
    // implements the regsel_EX = 2'b11 as PC+4 for the j type in CPU
    always_comb begin 
        case (regsel_EX)
            2'b00: writedata = 32'b0;         // default
            2'b01: writedata = imm_U;        // lui/aiupc
            2'b10: writedata = alu_result;    // ALU result
            2'b11: writedata = pc_EX + 32'd4;   // JAL/JALR return address <--- for jumps!
        endcase
    end

    // TODO!!!!!!!!!!!!!! Override with PC+$ controlled by contorl unit ... 
    // TODO
    // TODO
    
   // GPIO output register f00 
   always_ff @(posedge clk) begin 
   	if (res) begin
   		gpio_out_reg <= 32'b0;
   	end else if (GPIO_we) begin 
   		gpio_out_reg <= readdata1; // write rs1 to GPIO
   	end
   end 
   assign gpio_out = gpio_out_reg; 
    		 
endmodule
