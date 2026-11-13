class riscv_core_matrix_test extends riscv_base_test;
  `uvm_component_utils(riscv_core_matrix_test)
  riscv_core_seq core_seq;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function riscv_base_seq make_sequence();
    core_seq = riscv_core_seq::type_id::create("core_seq");
    if (!$value$plusargs("CASE=%s", core_seq.case_id))
      `uvm_fatal("CASE_ID", "Select a core testcase with +CASE=TC_...")
    return core_seq;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (core_seq.case_id == "TC_CORE_05" && env.scoreboard.expected_count != core_seq.instruction_count)
      `uvm_error("STRESS_COUNT", $sformatf("Requested %0d instructions, driver submitted %0d",
        core_seq.instruction_count, env.scoreboard.expected_count))
  endfunction
endclass

class riscv_invalid_decode_test extends riscv_base_test;
  `uvm_component_utils(riscv_invalid_decode_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db #(bit)::set(this, "env.ref_model", "allow_unsupported", 1);
    super.build_phase(phase);
  endfunction

  virtual function riscv_base_seq make_sequence();
    return riscv_invalid_decode_seq::type_id::create("invalid_decode_seq");
  endfunction

  function void check_phase(uvm_phase phase);
    int expected = 2 * riscv_invalid_decode_seq::INVALID_KINDS * ROM_WORDS;
    super.check_phase(phase);
    if (env.scoreboard.expected_count != expected || env.scoreboard.rejected_count != expected / 2)
      `uvm_error("REJECT_COUNT", "Incorrect number of supported or rejected instruction checks")
    `uvm_info("REJECT_COUNT", $sformatf("Verified %0d rejected instructions out of %0d",
      env.scoreboard.rejected_count, env.scoreboard.expected_count), UVM_NONE)
  endfunction
endclass

class riscv_coverage_closure_test extends riscv_base_test;
  `uvm_component_utils(riscv_coverage_closure_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function riscv_base_seq make_sequence();
    return riscv_closure_seq::type_id::create("closure_seq");
  endfunction
endclass

class riscv_unit_matrix_test extends uvm_test;
  `uvm_component_utils(riscv_unit_matrix_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    riscv_unit_seq seq = riscv_unit_seq::type_id::create("unit_seq");
    phase.raise_objection(this);
    if (!uvm_config_db #(virtual riscv_unit_if)::get(this, "", "unit_vif", seq.vif))
      `uvm_fatal("NO_VIF", "Missing unit-level interface")
    if (!$value$plusargs("CASE=%s", seq.case_id))
      `uvm_fatal("CASE_ID", "Select a unit testcase with +CASE=TC_...")
    seq.start(null);
    if (seq.checks == 0) `uvm_fatal("NO_CHECKS", seq.case_id)
    `uvm_info("UNIT_CHECKS", $sformatf("%s checked %0d expectations", seq.case_id, seq.checks), UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
