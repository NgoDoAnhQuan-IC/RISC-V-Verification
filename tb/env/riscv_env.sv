// =============================================================================
// File: riscv_env.sv
// Description: UVM Environment - instantiates and connects all TB components
// =============================================================================

class riscv_env extends uvm_env;
  `uvm_component_utils(riscv_env)
  
  // Component handles
  riscv_in_agent    in_agent;
  riscv_out_agent   out_agent;
  riscv_ref_model   ref_model;
  riscv_scoreboard  scoreboard;
  riscv_coverage    coverage;
  
  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  // Build Phase: create all sub-components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    uvm_config_db#(uvm_active_passive_enum)::set(this, "in_agent",  "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "out_agent", "is_active", UVM_PASSIVE);

    in_agent   = riscv_in_agent  ::type_id::create("in_agent",   this);
    out_agent  = riscv_out_agent ::type_id::create("out_agent",  this);
    ref_model  = riscv_ref_model ::type_id::create("ref_model",  this);
    scoreboard = riscv_scoreboard::type_id::create("scoreboard", this);
    coverage   = riscv_coverage  ::type_id::create("coverage",   this);
  endfunction
  
  // Connect Phase: wire up TLM analysis ports
  function void connect_phase(uvm_phase phase);
    in_agent.program_ap.connect(scoreboard.program_export);
    in_agent.program_ap.connect(ref_model.program_export);
    // in_agent.ap → ref_model (ref model receives instruction, computes expected)
    in_agent.ap.connect(ref_model.analysis_export);
    
    // in_agent.ap → coverage (coverage samples instruction type)
    in_agent.ap.connect(coverage.analysis_export);
    
    // ref_model.ap → scoreboard.expected_fifo (expected results)
    ref_model.ap.connect(scoreboard.expected_fifo.analysis_export);
    
    // out_agent.ap → scoreboard.actual_fifo (actual results from DUT)
    out_agent.ap.connect(scoreboard.actual_fifo.analysis_export);

    // out_agent.ap → coverage result covergroup (zero flag of the write-back)
    out_agent.ap.connect(coverage.result_export);
  endfunction

endclass : riscv_env
