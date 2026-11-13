`uvm_analysis_imp_decl(_result)

class riscv_coverage extends uvm_subscriber #(riscv_item);
  `uvm_component_utils(riscv_coverage)
  uvm_analysis_imp_result #(riscv_item, riscv_coverage) result_export;
  bit previous_write;
  logic [4:0] previous_rd;
  logic [31:0] previous_pc;

  covergroup instr_cg with function sample(riscv_item item, riscv_op_e op);
    option.per_instance = 1;
    cp_instr: coverpoint op { bins instructions[] = {[ADD:SLT]}; }
    cp_rd:  coverpoint item.rd  { bins regs[] = {[0:31]}; }
    cp_rs1: coverpoint item.rs1 { bins regs[] = {[0:31]}; }
    cp_rs2: coverpoint item.rs2 { bins regs[] = {[0:31]}; }
    op_x_rd: cross cp_instr, cp_rd;
  endgroup

  covergroup result_cg with function sample(riscv_item item, riscv_op_e op);
    option.per_instance = 1;
    cp_op: coverpoint op { bins instructions[] = {[ADD:SLT]}; }
    cp_zero: coverpoint item.actual_zero { bins clear = {0}; bins asserted = {1}; }
    cp_shift: coverpoint item.read_data2 iff (op inside {SLL, SRL}) {
      bins zero = {0}; bins shift_1_15 = {[1:15]}; bins shift_16_31 = {[16:31]};
      bins upper_bits_set = {[32:32'hffff_ffff]};
    }
    cp_in1_range: coverpoint item.read_data1 {
      bins zero = {0}; bins small_positive = {[1:100]};
      bins max_positive = {32'h7fff_ffff}; bins min_negative = {32'h8000_0000};
      bins small_negative = {[32'hffff_ff9c:32'hffff_fffe]}; bins all_ones = {32'hffff_ffff};
    }
    cp_in2_range: coverpoint item.read_data2 {
      bins zero = {0}; bins small_positive = {[1:100]};
      bins max_positive = {32'h7fff_ffff}; bins min_negative = {32'h8000_0000};
      bins small_negative = {[32'hffff_ff9c:32'hffff_fffe]}; bins all_ones = {32'hffff_ffff};
    }
    op_x_zero: cross cp_op, cp_zero;
    cross_corner_operands: cross cp_in1_range, cp_in2_range;
  endgroup

  covergroup hazard_cg with function sample(logic [4:0] producer_rd, bit consumer_reads_rd);
    option.per_instance = 1;
    cp_producer: coverpoint producer_rd {
      bins x0_discarded_write = {0}; bins writable[] = {[1:31]};
    }
    cp_consumer: coverpoint consumer_reads_rd { bins reads_producer_address = {1}; }
    cross_raw_hazard: cross cp_producer, cp_consumer;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    instr_cg = new();
    result_cg = new();
    hazard_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    result_export = new("result_export", this);
  endfunction

  function void write(riscv_item t);
    if (t.get_op() != UNKNOWN) instr_cg.sample(t, t.get_op());
  endfunction

  function void write_result(riscv_item item);
    if (item.actual_regwrite === 1'b1 && item.get_op() != UNKNOWN) begin
      result_cg.sample(item, item.get_op());
      // Each new program starts at PC=0; a producer cannot span a reset.
      if (previous_write && item.pc != 0 && item.pc == previous_pc + 4)
        hazard_cg.sample(previous_rd, previous_rd inside {item.rs1, item.rs2});
      previous_rd = item.actual_write_reg;
      previous_pc = item.pc;
      previous_write = 1;
    end else previous_write = 0;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COVERAGE", $sformatf(
      "instruction=%0.1f%% rd=%0.1f%% rs1=%0.1f%% rs2=%0.1f%% zero=%0.1f%% op_x_rd=%0.1f%% op_x_zero=%0.1f%%",
      instr_cg.cp_instr.get_inst_coverage(), instr_cg.cp_rd.get_inst_coverage(),
      instr_cg.cp_rs1.get_inst_coverage(), instr_cg.cp_rs2.get_inst_coverage(),
      result_cg.cp_zero.get_inst_coverage(), instr_cg.op_x_rd.get_inst_coverage(),
      result_cg.op_x_zero.get_inst_coverage()), UVM_NONE)
  endfunction
endclass
