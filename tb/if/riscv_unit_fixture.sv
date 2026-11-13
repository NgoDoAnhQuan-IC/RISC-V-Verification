module riscv_unit_fixture(input logic clock);
  riscv_unit_if bus(clock);
  ALU alu(bus.a, bus.b, bus.alu_op, bus.result, bus.zero);
  CONTROL control_unit(bus.funct7, bus.funct3, bus.opcode, bus.decoded_op, bus.decode_we);
  REG_FILE rf(bus.rs1, bus.rs2, bus.rd, bus.wdata, bus.rdata1, bus.rdata2,
              bus.rf_we, clock, bus.rf_reset);
  IFU ifu(clock, bus.ifu_reset, bus.instruction);
  assign bus.pc = ifu.PC;

  // Decoder coverage includes the unsupported funct3 exercised by TC_CTRL_05.
  // Count only active decoder vectors and only R-type fields.
  covergroup decoder_cg @(posedge clock);
    option.per_instance = 1;
    cp_opcode: coverpoint bus.opcode iff (bus.ctrl_check) { bins r_type = {7'h33}; }
    cp_funct3: coverpoint bus.funct3 iff (bus.ctrl_check && bus.opcode == 7'h33) {
      bins values[] = {[0:7]};
    }
    cp_funct7: coverpoint bus.funct7 iff (bus.ctrl_check && bus.opcode == 7'h33) {
      bins base = {0}; bins subtract = {7'h20}; bins multiply = {1};
    }
  endgroup
  decoder_cg decoder_coverage = new();

  covergroup fetch_cg @(posedge clock);
    option.per_instance = 1;
    cp_pc_seq: coverpoint bus.pc iff (bus.ifu_check && !bus.ifu_reset) {
      bins rom[] = {0, 4, 8, 12, 16, 20, 24, 28};
      bins out_of_bounds = {[32:32'hffff_ffff]};
    }
  endgroup
  fetch_cg fetch_coverage = new();

  riscv_alu_assertions alu_checks(clock, bus.alu_check, bus.zero, bus.result);
  riscv_decode_assertions ctrl_checks(clock, bus.ctrl_check, bus.decode_we,
      bus.opcode, bus.funct7, bus.funct3, bus.decoded_op);
  riscv_rf_assertions rf_checks(clock, bus.rf_reset, bus.rf_check, bus.rf_we,
      bus.rd, bus.wdata, rf.reg_memory);
  riscv_pc_assertions pc_checks(clock, bus.ifu_reset, bus.ifu_check, bus.pc);
endmodule
