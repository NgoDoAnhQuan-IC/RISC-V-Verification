class riscv_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(riscv_scoreboard)

  uvm_tlm_analysis_fifo #(riscv_item) expected_fifo, actual_fifo;
  uvm_analysis_imp_program #(riscv_item, riscv_scoreboard) program_export;
  int unsigned program_count, expected_count, pass_count, fail_count, rejected_count;
  logic [31:0] planned_words[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo = new("actual_fifo", this);
    program_export = new("program_export", this);
  endfunction

  // Copy the requested image before reset or any DUT fetch. Each request may
  // carry a different program, including images constructed by a sequence.
  function void write_program(riscv_item request);
    program_count++;
    if (request.program_words.size() == 0) begin
      for (int i = 0; i < request.rom_words_to_run; i++)
        planned_words.push_back(RESET_PROGRAM[i]);
      expected_count += request.rom_words_to_run;
    end else begin
      foreach (request.program_words[i]) planned_words.push_back(request.program_words[i]);
      expected_count += request.program_words.size();
    end
  endfunction

  task run_phase(uvm_phase phase);
    riscv_item exp_item, act_item;
    forever begin
      // Leave a lone prediction in the FIFO for check_phase to diagnose.
      expected_fifo.peek(exp_item);
      actual_fifo.get(act_item);
      expected_fifo.get(exp_item);
      compare(exp_item, act_item);
    end
  endtask

  function void compare(riscv_item e, riscv_item a);
    logic [31:0] planned_word;
    bit bus_unknown, bad_payload;
    if (planned_words.size() == 0)
      `uvm_fatal("EXTRA_FETCH", $sformatf("Unexpected instruction at PC=%08h", a.pc))
    planned_word = planned_words.pop_front();
    bus_unknown = $isunknown({a.pc, a.instruction_code, a.read_data1, a.read_data2,
        a.actual_regwrite, a.actual_write_reg, a.actual_write_data, a.actual_zero, a.actual_alu_control});
    bad_payload = e.expected_regwrite && (a.actual_write_data !== e.expected_write_data ||
                                           a.actual_zero !== e.expected_zero);
    if (e.instruction_code !== planned_word || a.pc !== e.pc || a.instruction_code !== e.instruction_code ||
        a.read_data1 !== e.read_data1 || a.read_data2 !== e.read_data2 ||
        bus_unknown || a.actual_regwrite !== e.expected_regwrite ||
        a.actual_write_reg !== e.expected_write_reg || bad_payload) begin
      fail_count++;
      `uvm_error("WRITEBACK", $sformatf(
        "%s expected pc=%08h instr=%08h src=(%08h,%08h) we=%b rd=x%0d data=%08h zero=%b | actual pc=%08h instr=%08h src=(%08h,%08h) we=%b rd=x%0d data=%08h zero=%b alu_control=%04b",
        e.get_instr_name(), e.pc, planned_word, e.read_data1, e.read_data2, e.expected_regwrite, e.expected_write_reg, e.expected_write_data,
        e.expected_zero, a.pc, a.instruction_code, a.read_data1, a.read_data2, a.actual_regwrite, a.actual_write_reg,
        a.actual_write_data, a.actual_zero, a.actual_alu_control))
    end else begin
      pass_count++;
      if (!e.expected_regwrite) rejected_count++;
      `uvm_info("WRITEBACK", $sformatf("PASS PC=%08h %s x%0d=%08h zero=%b",
        a.pc, e.get_instr_name(), a.actual_write_reg, a.actual_write_data, a.actual_zero), UVM_MEDIUM)
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expected_count == 0 || pass_count + fail_count != expected_count ||
        expected_fifo.used() != 0 || actual_fifo.used() != 0)
      `uvm_error("INCOMPLETE", $sformatf("Planned=%0d compared=%0d queued expected=%0d actual=%0d",
        expected_count, pass_count + fail_count, expected_fifo.used(), actual_fifo.used()))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCOREBOARD", $sformatf("Planned=%0d Compared=%0d PASS=%0d FAIL=%0d",
      expected_count, pass_count + fail_count, pass_count, fail_count), UVM_NONE)
  endfunction
endclass
