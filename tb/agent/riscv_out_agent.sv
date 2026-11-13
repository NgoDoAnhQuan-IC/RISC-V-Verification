// =============================================================================
// File   : riscv_out_agent.sv
// Purpose: UVM Passive Output Agent - only monitors the output side of the DUT.
//          No sequencer or driver (passive agent).
// =============================================================================

class riscv_out_agent extends uvm_agent;
  `uvm_component_utils(riscv_out_agent)

  // -------------------------------------------------------------------------
  // Sub-components
  // -------------------------------------------------------------------------
  riscv_out_monitor out_monitor;

  // Analysis port forwarded from out_monitor to the outside world (env/scoreboard)
  uvm_analysis_port #(riscv_item) ap;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // Build Phase
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    ap          = new("ap", this);
    out_monitor = riscv_out_monitor::type_id::create("out_monitor", this);
  endfunction

  // -------------------------------------------------------------------------
  // Connect Phase
  // -------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    // Forward out_monitor's analysis port to this agent's analysis port
    out_monitor.ap.connect(ap);
  endfunction

endclass : riscv_out_agent
