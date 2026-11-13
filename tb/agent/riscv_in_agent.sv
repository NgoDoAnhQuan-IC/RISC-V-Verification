// =============================================================================
// File   : riscv_in_agent.sv
// Purpose: UVM Active Input Agent - drives and monitors the input side
//          Instantiates sequencer, driver, and in_monitor.
// =============================================================================

class riscv_in_agent extends uvm_agent;
  `uvm_component_utils(riscv_in_agent)

  // -------------------------------------------------------------------------
  // Sub-components
  // -------------------------------------------------------------------------
  riscv_sequencer  sequencer;
  riscv_driver     driver;
  riscv_in_monitor in_monitor;

  // Analysis port forwarded from in_monitor to the outside world (env/scoreboard)
  uvm_analysis_port #(riscv_item) ap;
  uvm_analysis_port #(riscv_item) program_ap;

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

    ap = new("ap", this);
    program_ap = new("program_ap", this);

    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = riscv_sequencer::type_id::create("sequencer", this);
      driver    = riscv_driver::type_id::create("driver",    this);
    end

    in_monitor = riscv_in_monitor::type_id::create("in_monitor", this);
  endfunction

  // -------------------------------------------------------------------------
  // Connect Phase
  // -------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.program_ap.connect(program_ap);
    end

    // Forward in_monitor's analysis port to this agent's analysis port
    in_monitor.ap.connect(ap);
  endfunction

endclass : riscv_in_agent
