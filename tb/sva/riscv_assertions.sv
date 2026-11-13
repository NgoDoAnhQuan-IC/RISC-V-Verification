module riscv_pc_assertions(input logic clock, reset, enabled, input logic [31:0] pc);
  import uvm_pkg::*;
  ap_reset_pc: assert property (@(posedge clock) enabled && reset |-> pc == 0)
    else `uvm_error("SVA_PC_RESET", $sformatf("%m PC=%08h during reset", $sampled(pc)))

  property pc_step;
    logic [31:0] before_edge;
    @(posedge clock) disable iff (reset)
      (enabled, before_edge = pc) |-> @(negedge clock) pc == before_edge + 32'd4;
  endproperty
  ap_pc_step: assert property (pc_step)
    else `uvm_error("SVA_PC_STEP", $sformatf("%m PC=%08h after increment", $sampled(pc)))
endmodule

module riscv_alu_assertions(input logic clock, enabled, zero, input logic [31:0] result);
  import uvm_pkg::*;
  ap_zero_flag: assert property (@(posedge clock) enabled |->
      !$isunknown({zero, result}) && zero == (result == 0))
    else `uvm_error("SVA_ZERO", $sformatf("%m result=%08h zero=%b", $sampled(result), $sampled(zero)))
endmodule

module riscv_decode_assertions(input logic clock, enabled, we,
    input logic [6:0] opcode, funct7, input logic [2:0] funct3, input logic [3:0] alu_op);
  import uvm_pkg::*;
  // Bit 4 marks encodings that may write back. The low nibble is don't-care
  // for unsupported instructions, which must leave architectural state intact.
  function automatic logic [4:0] expected_decode(logic [6:0] opc, f7, logic [2:0] f3);
    if (opc != 7'h33) return 0;
    case ({f7, f3})
      {7'h00, 3'h0}: return 5'h12;
      {7'h20, 3'h0}: return 5'h14;
      {7'h01, 3'h0}: return 5'h16;
      {7'h00, 3'h1}: return 5'h13;
      {7'h00, 3'h2}: return 5'h18;
      {7'h00, 3'h4}: return 5'h17;
      {7'h00, 3'h5}: return 5'h15;
      {7'h00, 3'h6}: return 5'h11;
      {7'h00, 3'h7}: return 5'h10;
      default: return 0;
    endcase
  endfunction
  wire [4:0] expected = expected_decode(opcode, funct7, funct3);
  ap_decode: assert property (@(posedge clock) enabled |->
      !$isunknown({opcode, funct7, funct3}) && we == expected[4] &&
      (!expected[4] || alu_op == expected[3:0]))
    else `uvm_error("SVA_DECODE", $sformatf("%m opcode=%02h funct7=%02h funct3=%h expected=%05b actual=%05b",
      $sampled(opcode), $sampled(funct7), $sampled(funct3), $sampled(expected), $sampled({we,alu_op})))
endmodule

module riscv_rf_assertions(input logic clock, reset, enabled, we,
    input logic [4:0] rd, input logic [31:0] wdata, input wire [31:0] regs[31:0]);
  import uvm_pkg::*;
  // Capture the bus before the active-edge write. Observe stored data half
  // a cycle later, including the last write of a short program.
  property committed_write;
    logic [4:0] dest;
    logic [31:0] value;
    @(posedge clock) disable iff (reset)
      (enabled && we && rd != 0, dest = rd, value = wdata)
        |-> @(negedge clock) regs[dest] == value;
  endproperty
  ap_commit: assert property (committed_write)
    else `uvm_error("SVA_COMMIT", $sformatf("%m register write did not commit"))
  for (genvar r = 0; r < 32; r++) begin : write_disabled
    wire [31:0] value = regs[r];
    property held_across_edge;
      logic [31:0] before_edge;
      @(posedge clock) disable iff (reset)
        (enabled && we === 1'b0, before_edge = value)
        |-> @(negedge clock) !$isunknown(before_edge) && value == before_edge;
    endproperty
    ap_stable: assert property (held_across_edge)
      else `uvm_error("SVA_SPURIOUS_WRITE", $sformatf("%m x%0d changed or unknown with write disabled", r))
  end
  ap_x0: assert property (@(posedge clock) disable iff (reset)
      enabled |-> @(negedge clock) regs[0] == 0)
    else `uvm_error("SVA_X0", $sformatf("%m x0=%08h after clock edge", $sampled(regs[0])))
endmodule
