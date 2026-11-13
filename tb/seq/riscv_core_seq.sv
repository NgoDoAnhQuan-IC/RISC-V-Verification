class riscv_core_seq extends riscv_base_seq;
  `uvm_object_utils(riscv_core_seq)
  string case_id;
  int instruction_count = 1000;

  function new(string name = "riscv_core_seq");
    super.new(name);
  endfunction

  task body();
    case (case_id)
      "TC_SAN_01", "TC_SAN_03", "TC_CORE_01": ; // Fetch from the physical reset ROM.
      "TC_CORE_02": program_words = '{
        32'h002082b3,  // add x5,x1,x2
        32'h40328333   // sub x6,x5,x3
      };
      "TC_CORE_03": program_words = '{
        32'h002082b3,  // add x5,x1,x2
        32'h0041e3b3,  // or  x7,x3,x4
        32'h00728433   // add x8,x5,x7
      };
      "TC_CORE_04": program_words = '{32'h40318333}; // sub x6,x3,x3
      "TC_CORE_05": begin
        void'($value$plusargs("N_INSTR=%d", instruction_count));
        if (instruction_count < 1)
          `uvm_fatal("STRESS_SIZE", "N_INSTR must be positive")
        num_runs = 1 + (instruction_count - 1) / ROM_WORDS;
      end
      "TC_CORE_06": repeat (ROM_WORDS / 2) begin
        program_words.push_back(32'h40318333); // sub x6,x3,x3 -> zero
        program_words.push_back(32'h002082b3); // add x5,x1,x2 -> nonzero
      end
      default: `uvm_fatal("CASE_ID", $sformatf("Unknown core case %s", case_id))
    endcase
    super.body();
  endtask

  virtual function void prepare_program(riscv_item req, int run_index);
    int remaining;
    riscv_item instr;
    logic [31:0] operand;
    super.prepare_program(req, run_index);
    if (case_id inside {"TC_SAN_01", "TC_SAN_03"}) req.rom_words_to_run = 1;
    if (case_id != "TC_CORE_05") return;

    // Each ROM bank starts at PC=0 after a real reset. Seed x1..x31 with
    // both full-width and boundary operands; x0 is always owned by the DUT.
    repeat (31) begin
      if (!std::randomize(operand) with {
          operand dist {0 := 4, 1 := 4, 31 := 4, 32 := 4,
                        32'h7fff_ffff := 4, 32'h8000_0000 := 4,
                        32'hffff_ffff := 4, [0:32'hffff_ffff] :/ 72};
        }) `uvm_fatal("RANDOMIZE", "Cannot generate stress operands")
      req.initial_gprs.push_back(operand);
    end
    remaining = instruction_count - run_index * ROM_WORDS;
    instr = riscv_item::type_id::create("random_instruction");
    repeat (remaining < ROM_WORDS ? remaining : ROM_WORDS) begin
      if (!instr.randomize()) `uvm_fatal("RANDOMIZE", "Cannot generate a legal R-type word")
      req.program_words.push_back(instr.instruction_code);
    end
  endfunction
endclass
