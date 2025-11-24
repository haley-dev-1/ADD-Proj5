/* 32 x 32 register file implementation */

module regfile (

/**** inputs *****************************************************************/

        input [0:0 ] clk,               /* clock */
        input [0:0 ] we,                /* write enable */
        input [4:0 ] readaddr1,         /* read address 1 */
        input [4:0 ] readaddr2,         /* read address 2 */
        input [4:0 ] writeaddr,         /* write address */
        input [31:0] writedata,         /* write data */

/**** outputs ****************************************************************/

        output logic [31:0] readdata1,        /* read data 1 */
        output logic [31:0] readdata2         /* read data 2 */
);

logic [31:0] mem[31:0];

// Write on clock edge
always_ff @(posedge clk) begin
        if (we) mem[writeaddr] <= writedata;
end

// Read with bypassing - but use PREVIOUS cycle's we
// This breaks the combinational loop
logic we_prev;
logic [4:0] writeaddr_prev;
logic [31:0] writedata_prev;

always_ff @(posedge clk) begin
    we_prev <= we;
    writeaddr_prev <= writeaddr;
    writedata_prev <= writedata;
end

always_comb begin
        // Read port 1 with bypassing
        if (readaddr1 == 5'd0) 
            readdata1 = 32'd0;
        else if (we_prev && readaddr1 == writeaddr_prev) 
            readdata1 = writedata_prev;  // Bypass from previous write
        else 
            readdata1 = mem[readaddr1];

        // Read port 2 with bypassing
        if (readaddr2 == 5'd0) 
            readdata2 = 32'd0;
        else if (we_prev && readaddr2 == writeaddr_prev) 
            readdata2 = writedata_prev;  // Bypass from previous write
        else 
            readdata2 = mem[readaddr2];
end

endmodule
