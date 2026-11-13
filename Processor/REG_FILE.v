module REG_FILE(
    input [4:0] read_reg_num1,
    input [4:0] read_reg_num2,
    input [4:0] write_reg,
    input [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    input regwrite,
    input clock,
    input reset
);
    reg [31:0] reg_memory [31:0];
    integer i;

    assign read_data1 = reg_memory[read_reg_num1];
    assign read_data2 = reg_memory[read_reg_num2];

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            // Project reset image: x9=0x09, x10=0x10, ..., x31=0x31.
            for (i = 0; i < 32; i = i + 1)
                reg_memory[i] <= ((i / 10) * 16) + (i % 10);
        end else if (regwrite && write_reg != 0) begin
            reg_memory[write_reg] <= write_data;
        end
    end
endmodule
