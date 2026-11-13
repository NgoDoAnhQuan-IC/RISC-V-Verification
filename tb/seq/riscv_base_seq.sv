class riscv_base_seq extends uvm_sequence #(riscv_item);
  `uvm_object_utils(riscv_base_seq)
  
  int num_runs = 1; // số lần chạy program
  logic [31:0] program_words[$];
  
  function new(string name = "riscv_base_seq");
    super.new(name);
  endfunction
  
  virtual function void prepare_program(riscv_item req, int run_index);
    req.program_words = program_words;
  endfunction

  task body();
    riscv_item req;
    for (int run_index = 0; run_index < num_runs; run_index++) begin
      req = riscv_item::type_id::create("req");
      start_item(req);
      prepare_program(req, run_index);
      finish_item(req);
      `uvm_info(get_name(), "BASE_SEQ: One program run complete", UVM_MEDIUM)
    end
  endtask
endclass

// Existing full-test sequence: replay the same program across three resets.
class riscv_rand_seq extends riscv_base_seq;
  `uvm_object_utils(riscv_rand_seq)
  
  function new(string name = "riscv_rand_seq");
    super.new(name);
    num_runs = 3;
  endfunction
endclass
