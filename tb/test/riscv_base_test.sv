class riscv_base_test extends uvm_test;
  `uvm_component_utils(riscv_base_test)

  riscv_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = riscv_env::type_id::create("env", this);
  endfunction

  virtual function riscv_base_seq make_sequence();
    return riscv_base_seq::type_id::create("seq");
  endfunction

  task run_phase(uvm_phase phase);
    riscv_base_seq seq;
    phase.raise_objection(this);
    seq = make_sequence();
    seq.start(env.in_agent.sequencer);
    if (env.scoreboard.program_count != seq.num_runs)
      `uvm_error("RUN_COUNT", $sformatf("Requested %0d runs, observed %0d",
        seq.num_runs, env.scoreboard.program_count))
    // item_done is issued on the falling edge after the last checked write.
    phase.drop_objection(this);
  endtask
endclass

class riscv_full_test extends riscv_base_test;
  `uvm_component_utils(riscv_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function riscv_base_seq make_sequence();
    return riscv_rand_seq::type_id::create("repeat_rom");
  endfunction
endclass

// Bring-up control: load a shorter image and exercise a RAW dependency and zero.
class riscv_program_smoke_test extends riscv_base_test;
  `uvm_component_utils(riscv_program_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function riscv_base_seq make_sequence();
    riscv_base_seq seq = super.make_sequence();
    seq.program_words = '{
      32'h002082b3, // add x5, x1, x2 -> 3
      32'h403283b3, // sub x7, x5, x3 -> 0
      32'h0053e433, // or  x8, x7, x5 -> 3
      32'h00540333  // add x6, x8, x5 -> 6
    };
    return seq;
  endfunction
endclass
