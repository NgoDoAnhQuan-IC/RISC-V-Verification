`ifndef RISCV_TB_PKG_SV
`define RISCV_TB_PKG_SV

package riscv_tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  localparam int ROM_WORDS = 8;  // INST_MEM has 32 bytes.
  typedef enum {ADD, SUB, MUL, SLL, SRL, XOR, OR, AND, SLT, UNKNOWN} riscv_op_e;
  function automatic logic [31:0] reset_reg_value(int i);
    return (i / 10) * 16 + i % 10;
  endfunction
  localparam logic [31:0] RESET_PROGRAM[ROM_WORDS] = '{
    32'h00940333, 32'h413903b3, 32'h035a02b3, 32'h017b4e33,
    32'h019c1eb3, 32'h01bd5f33, 32'h00d67fb3, 32'h00f768b3
  };
  
  // 1. Item/Transaction (no dependencies)
  `include "tb/seq/riscv_item.sv"
  
  // 2. Sequencer
  `include "tb/agent/riscv_sequencer.sv"
  
  // 3. Driver and Monitors
  `include "tb/agent/riscv_driver.sv"
  `include "tb/agent/riscv_in_monitor.sv"
  `include "tb/agent/riscv_out_monitor.sv"
  
  // 4. Agents
  `include "tb/agent/riscv_in_agent.sv"
  `include "tb/agent/riscv_out_agent.sv"
  
  // 5. Reference Model
  `uvm_analysis_imp_decl(_program)
  `include "tb/model/riscv_ref_model.sv"
  
  // 6. Scoreboard and Coverage
  `include "tb/scb/riscv_scoreboard.sv"
  `include "tb/cov/riscv_coverage.sv"
  
  // 7. Environment
  `include "tb/env/riscv_env.sv"
  
  // 8. Sequences
  `include "tb/seq/riscv_base_seq.sv"
  `include "tb/seq/riscv_core_seq.sv"
  `include "tb/seq/riscv_closure_seq.sv"
  `include "tb/seq/riscv_invalid_decode_seq.sv"
  `include "tb/seq/riscv_unit_seq.sv"
  
  // 9. Tests
  `include "tb/test/riscv_base_test.sv"
  `include "tb/test/riscv_matrix_test.sv"
  
endpackage : riscv_tb_pkg

`endif
