// =============================================================================
// File   : riscv_sequencer.sv
// Purpose: UVM Sequencer - Routes riscv_item transactions from sequences
//          to the driver in the in_agent
// =============================================================================

class riscv_sequencer extends uvm_sequencer #(riscv_item);
    `uvm_component_utils(riscv_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : riscv_sequencer
