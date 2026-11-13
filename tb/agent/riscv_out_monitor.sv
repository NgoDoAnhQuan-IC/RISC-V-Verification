// =============================================================================
// File: riscv_out_monitor.sv
// Description: UVM Output Monitor for RISC-V Processor Testbench
//              Samples register write-back results at posedge clock when
//              inside the requested program window. Sends captured items
//              to scoreboard via analysis port.
// =============================================================================

class riscv_out_monitor extends uvm_monitor;
  `uvm_component_utils(riscv_out_monitor)

  // Virtual interface handle
  virtual riscv_if vif;

  // Analysis port: sends captured actual results to scoreboard
  uvm_analysis_port #(riscv_item) ap;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Get virtual interface and create analysis port
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual riscv_if)::get(this, "", "riscv_vif", vif)) begin
      `uvm_fatal(get_name(), "riscv_out_monitor: Failed to get virtual interface 'riscv_vif' from config_db!")
    end
    ap = new("ap", this);
  endfunction

  // Include missing or unknown write enables so the scoreboard can detect them.
  task run_phase(uvm_phase phase);
    forever begin
      @(vif.out_mon_cb);
      if (vif.out_mon_cb.checking) begin
        riscv_item item = riscv_item::type_id::create("out_item");

        item.pc = vif.out_mon_cb.pc;
        item.decode(vif.out_mon_cb.instruction_code);
        item.actual_regwrite    = vif.out_mon_cb.regwrite;
        item.actual_write_reg   = vif.out_mon_cb.write_reg;
        item.actual_write_data  = vif.out_mon_cb.write_data;
        item.actual_zero        = vif.out_mon_cb.zero;
        item.actual_alu_control = vif.out_mon_cb.alu_control;
        item.read_data1         = vif.out_mon_cb.read_data1;
        item.read_data2         = vif.out_mon_cb.read_data2;

        ap.write(item);

        `uvm_info(get_name(), $sformatf("OUT_MON: [%s] rd=x%0d data=0x%08h zero=%0b alu_control=%04b",
          item.get_instr_name(), item.actual_write_reg, item.actual_write_data,
          item.actual_zero, item.actual_alu_control), UVM_MEDIUM)
      end
    end
  endtask

endclass : riscv_out_monitor
