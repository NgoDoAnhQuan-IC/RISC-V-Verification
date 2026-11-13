module CONTROL(
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,
    output reg [3:0] alu_control,
    output reg regwrite_control
);
    always @* begin
        regwrite_control = 1'b1;
        case ({opcode, funct7, funct3})
            {7'h33, 7'h00, 3'h0}: alu_control = 4'h2; // ADD
            {7'h33, 7'h20, 3'h0}: alu_control = 4'h4; // SUB
            {7'h33, 7'h01, 3'h0}: alu_control = 4'h6; // MUL
            {7'h33, 7'h00, 3'h1}: alu_control = 4'h3; // SLL
            {7'h33, 7'h00, 3'h2}: alu_control = 4'h8; // SLT
            {7'h33, 7'h00, 3'h4}: alu_control = 4'h7; // XOR
            {7'h33, 7'h00, 3'h5}: alu_control = 4'h5; // SRL
            {7'h33, 7'h00, 3'h6}: alu_control = 4'h1; // OR
            {7'h33, 7'h00, 3'h7}: alu_control = 4'h0; // AND
            default: begin
                alu_control = 4'h0;
                regwrite_control = 1'b0;
            end
        endcase
    end
endmodule
