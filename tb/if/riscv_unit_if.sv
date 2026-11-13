// Pin-level stimulus for independent instances of the same Processor/ RTL.
interface riscv_unit_if(input logic clock);
  bit alu_check, ctrl_check, rf_check, ifu_check;
  logic [31:0] a, b, result;
  logic [3:0] alu_op;
  logic zero;

  logic [6:0] opcode, funct7;
  logic [2:0] funct3;
  logic [3:0] decoded_op;
  logic decode_we;

  bit rf_reset, rf_we, ifu_reset;
  logic [4:0] rs1, rs2, rd;
  logic [31:0] wdata, rdata1, rdata2;
  logic [31:0] pc, instruction;
endinterface
