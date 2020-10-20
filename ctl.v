/*
 * generate control signals
 *
 * (C) Arlet Ottens <arlet@c-scape.nl> 
 */

module ctl(
    input clk,
    output sync,
    input cond,
    input [7:0] DB,
    output reg WE,
    output [7:0] flags,
    output [6:0] alu_op,
    output [5:0] dp_op,
    output [1:0] do_op,
    output reg [11:0] ab_op );

wire [2:0] adder;
wire [1:0] shift;
wire [1:0] ci;
wire [2:0] src;
wire [2:0] dst;

assign flags = control[7:0];
assign alu_op = { ci, shift, adder };
assign dp_op  = control[20:15];

reg [35:0] microcode[511:0];
reg [35:0] control;

assign do_op = control[29:28];
assign sync = (control[22:21] == 2'b00);

initial
    $readmemb( "microcode.hex", microcode, 0 );

reg [8:0] pc;
reg [4:0] finish;   // finishing code

always @(*) 
    casez( control[22:21] )
        2'b00:          pc = {1'b0, DB};            // look up next instruction at 000
        2'b?1:          pc = {1'b1, control[7:0]};  // microcode at @100
        2'b10:          pc = {4'b1100, finish };    // finish code at @180
    endcase

always @(posedge clk)
    WE <= control[27];

always @(posedge clk)
    control <= microcode[pc];

always @(posedge clk)
    if( control[22] )
        finish <= control[14:10];

assign shift = control[14:13];
assign adder = control[12:10];
assign ci    = control[9:8];


always @(*)
    case( control[26:23] )    //              IPHF_AHB_ABL_CI
        4'b0000:                ab_op = 12'bxx10_100_0010_1;     // AB + 1    
        4'b0001:                ab_op = 12'b1110_000_0111_0;     // {00, DB+REG}    
        4'b0010:                ab_op = 12'bxx00_110_1100_0;     // PC         
        4'b0011:                ab_op = 12'b1110_111_1011_0;     // {DB, AHL+REG}, store PC
        4'b0100:                ab_op = 12'b0100_010_0011_0;     // {01, SP}     
        4'b0101:                ab_op = 12'bxx10_100_0010_0;     // AB + 0        
        4'b0110:                ab_op = 12'b0010_111_1011_0;     // {DB, AHL+REG}, keep PC
        4'b0111:                ab_op = 12'b0110_010_0011_1;     // {01, SP+1}
        4'b1000: if( cond )     
                    if( DB[7] ) ab_op = 12'bxx10_101_0110_1;     // {AB-1, AB} + DB + 1
                    else        ab_op = 12'bxx10_100_0110_1;     // {AB+0, AB} + DB + 1
                 else           ab_op = 12'bxx10_100_0010_1;     // AB + 1    
        4'b1001: if( !cond )     
                    if( DB[7] ) ab_op = 12'bxx10_101_0110_1;     // {AB-1, AB} + DB + 1
                    else        ab_op = 12'bxx10_100_0110_1;     // {AB+0, AB} + DB + 1
                 else           ab_op = 12'bxx10_100_0010_1;     // AB + 1    
        4'b1010:                ab_op = 12'b0000_010_0011_0;     // {01, SP}, keep PC
        4'b1011:                ab_op = 12'b1110_010_0011_0;     // {01, SP}, store PC+1
        4'b1100:                ab_op = 12'b0001_000_0011_0;     // {FF, REG}
        4'b1101: if( DB[7] )    ab_op = 12'bxx10_101_0110_1;     // {AB-1, AB} + DB + 1
                 else           ab_op = 12'bxx10_100_0110_1;     // {AB+0, AB} + DB + 1
        default:                ab_op = 12'bxxxx_xxx_xxxx_x;
    endcase

endmodule
