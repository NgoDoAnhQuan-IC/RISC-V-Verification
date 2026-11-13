// Combinational ALU for the supported RV32 register-register operations.
module ALU (
    input [31:0] in1, in2,
    input [3:0] alu_control,
    output reg [31:0] alu_result,
    output zero_flag
);
    always @* begin
        case (alu_control)
            4'h0: alu_result = in1 & in2;                 // AND
            4'h1: alu_result = in1 | in2;                 // OR
            4'h2: alu_result = in1 + in2;                 // ADD
            4'h3: alu_result = in1 << in2[4:0];           // SLL
            4'h4: alu_result = in1 - in2;                 // SUB
            4'h5: alu_result = in1 >> in2[4:0];           // SRL
            4'h6: alu_result = in1 * in2;                 // MUL (low 32 bits)
            4'h7: alu_result = in1 ^ in2;                 // XOR
            4'h8: alu_result = {31'b0, $signed(in1) < $signed(in2)}; // SLT
            default: alu_result = 32'b0;
        endcase
    end

    assign zero_flag = (alu_result == 32'b0);
endmodule
