// =============================================================================
// File: tb_top.sv
// Description: Top-level testbench module for RISC-V UVM Verification
//              Instantiates DUT + interface, connects hierarchical probes,
//              registers virtual interface in config_db, and starts UVM.
// =============================================================================

`timescale 1ns/1ps
`include "tb/env/riscv_tb_pkg.sv"
`include "tb/sva/riscv_assertions.sv"
`include "tb/if/riscv_unit_fixture.sv"

// RTL is compiled separately (see sim/run.do). PROCESSOR.v `includes the
// rest of the design; including those files here as well defines every
// module twice.

module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import riscv_tb_pkg::*;

  // ---------------------------------------------------------------------------
  // Clock Generation — 100 MHz (period = 10 ns)
  // ---------------------------------------------------------------------------
  logic clk;
  bit test_passed;
  bit test_completed, core_initialized, audit_reset, check_zero_toggle;
  string case_id;
  initial clk = 1'b0;
  always #5ns clk = ~clk;

  // ---------------------------------------------------------------------------
  // Interface Instantiation
  // ---------------------------------------------------------------------------
  riscv_if dut_if(.clock(clk));
  riscv_unit_fixture unit_fixture(clk);

  // ---------------------------------------------------------------------------
  // DUT Instantiation
  // reset driven by interface (driver asserts it at start of each test)
  // zero  is an output of PROCESSOR; captured via interface
  // ---------------------------------------------------------------------------
  PROCESSOR dut(
    .clock (clk),
    .reset (dut_if.reset),
    .zero  (dut_if.zero)
  );

  // ---------------------------------------------------------------------------
  // Hierarchical Probe Connections
  // Internal DUT signals → interface wires so monitors can observe them
  // ---------------------------------------------------------------------------
  // IFU output: current instruction word
  assign dut_if.instruction_code = dut.instruction_code;
  assign dut_if.pc = dut.IFU_module.PC;

  // Control signals (from CONTROL module)
  assign dut_if.regwrite   = dut.control_module.regwrite_control;
  assign dut_if.alu_control = dut.alu_control;

  // Datapath write-back signals (from DATAPATH module)
  assign dut_if.write_reg  = dut.datapath_module.write_reg;
  assign dut_if.write_data = dut.datapath_module.write_data;

  // Datapath source operands (from DATAPATH / REG_FILE outputs)
  assign dut_if.read_data1 = dut.datapath_module.read_data1;
  assign dut_if.read_data2 = dut.datapath_module.read_data2;

  always @(posedge dut_if.reset) core_initialized = 1;
  riscv_pc_assertions pc_checks(clk, dut_if.reset, core_initialized, dut_if.pc);
  riscv_alu_assertions alu_checks(clk, dut_if.checking, dut_if.zero, dut_if.write_data);
  riscv_decode_assertions ctrl_checks(clk, dut_if.checking, dut_if.regwrite,
      dut_if.instruction_code[6:0], dut_if.instruction_code[31:25],
      dut_if.instruction_code[14:12], dut_if.alu_control);
  riscv_rf_assertions rf_checks(clk, dut_if.reset, dut_if.checking, dut_if.regwrite,
      dut_if.write_reg, dut_if.write_data, dut.datapath_module.reg_file_module.reg_memory);

  for (genvar r = 0; r < 32; r++) begin : reset_image
    wire [31:0] value = dut.datapath_module.reg_file_module.reg_memory[r];
    // Sample both the initialized image and the image delivered to the first instruction.
    ap_init: assert property (@(posedge clk) audit_reset && $rose(dut_if.reset) |->
        value == reset_reg_value(r))
      else `uvm_error("SVA_RESET_INIT", $sformatf("x%0d=%08h", r, $sampled(value)))
    ap_release: assert property (@(negedge dut_if.reset) audit_reset |->
        value == reset_reg_value(r))
      else `uvm_error("SVA_RESET_RELEASE", $sformatf("x%0d expected=%08h actual=%08h",
        r, reset_reg_value(r), $sampled(value)))
  end
  ap_zero_toggle: assert property (@(posedge clk) disable iff (dut_if.reset)
      check_zero_toggle && dut_if.checking && $past(dut_if.checking) |->
      !$isunknown(dut_if.zero) && dut_if.zero != $past(dut_if.zero))
    else `uvm_error("SVA_ZERO_TOGGLE", $sformatf("zero did not alternate at PC=%08h", $sampled(dut_if.pc)))

  // ---------------------------------------------------------------------------
  // UVM Startup
  // ---------------------------------------------------------------------------
  initial begin
    uvm_root root;
    uvm_report_server reports;
    root = uvm_root::get();
    void'($value$plusargs("CASE=%s", case_id));
    audit_reset = case_id == "TC_SAN_01";
    check_zero_toggle = case_id == "TC_CORE_06";
    uvm_config_db #(virtual riscv_unit_if)::set(null, "uvm_test_top", "unit_vif", unit_fixture.bus);
    // Register the virtual interface so all UVM components can get it
    uvm_config_db #(virtual riscv_if)::set(null, "*", "riscv_vif", dut_if);
    uvm_config_db #(string)::set(null, "uvm_test_top.env.in_agent.driver",
      "imem_path", "tb_top.dut.IFU_module.instr_mem.Memory");
    uvm_config_db #(string)::set(null, "uvm_test_top.env.in_agent.driver",
      "regfile_path", "tb_top.dut.datapath_module.reg_file_module.reg_memory");

    // Waveform dump (VCD for modelsim / iverilog)
    if ($test$plusargs("DUMP_VCD")) begin
      $dumpfile("riscv_uvm.vcd");
      $dumpvars(0, tb_top);
    end

    // Run the test specified by +UVM_TESTNAME (default: riscv_base_test)
    root.finish_on_completion = 0;
    run_test("riscv_base_test");
    reports = uvm_report_server::get_server();
    test_passed = reports.get_severity_count(UVM_ERROR) == 0 &&
                  reports.get_severity_count(UVM_FATAL) == 0;
    test_completed = 1;
    $finish;
  end

endmodule : tb_top
