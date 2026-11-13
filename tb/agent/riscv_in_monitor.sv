// =============================================================================
// File: riscv_in_monitor.sv
// Description: UVM Input Monitor for RISC-V Processor Testbench
//              Samples instruction_code at posedge clock when reset=0,
//              decodes R-type fields, and writes to analysis port.
// =============================================================================

class riscv_in_monitor extends uvm_monitor;
  `uvm_component_utils(riscv_in_monitor)

  // Virtual interface handle
  virtual riscv_if vif;

  // Analysis port: sends captured items to ref model and coverage collector
  uvm_analysis_port #(riscv_item) ap;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Get virtual interface and create analysis port
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual riscv_if)::get(this, "", "riscv_vif", vif)) begin
      `uvm_fatal(get_name(), "riscv_in_monitor: Failed to get virtual interface 'riscv_vif' from config_db!")
    end
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.in_mon_cb);
      if (vif.in_mon_cb.checking) begin
        riscv_item item = riscv_item::type_id::create("in_item");
        item.pc = vif.in_mon_cb.pc;
        item.decode(vif.in_mon_cb.instruction_code);
        ap.write(item);
        `uvm_info(get_name(), $sformatf("IN_MON: Captured instr=0x%08h [%s] rd=x%0d rs1=x%0d rs2=x%0d",
          item.instruction_code, item.get_instr_name(), item.rd, item.rs1, item.rs2), UVM_MEDIUM)
      end
    end
  endtask

endclass : riscv_in_monitor
