class riscv_closure_seq extends riscv_base_seq;
  `uvm_object_utils(riscv_closure_seq)

  localparam int RD_BANKS = 9 * 32 / ROM_WORDS;
  localparam int CORNER_BANKS = 6;
  localparam int ZERO_BANKS = 9;
  localparam int RAW_BANKS = 32 * 2 / ROM_WORDS;

  function new(string name = "riscv_closure_seq");
    super.new(name);
    num_runs = RD_BANKS + CORNER_BANKS + ZERO_BANKS + RAW_BANKS;
  endfunction

  function logic [31:0] encode(riscv_op_e op, logic [4:0] rd, rs1, rs2);
    logic [6:0] funct7 = 0;
    logic [2:0] funct3 = 0;
    case (op)
      ADD: ;
      SUB: funct7 = 7'h20;
      MUL: funct7 = 7'h01;
      SLL: funct3 = 1;
      SLT: funct3 = 2;
      XOR: funct3 = 4;
      SRL: funct3 = 5;
      OR:  funct3 = 6;
      AND: funct3 = 7;
      default: `uvm_fatal("CLOSURE_OP", "Unsupported operation")
    endcase
    return {funct7, rs2, rs1, funct3, rd, 7'h33};
  endfunction

  virtual function void prepare_program(riscv_item req, int run_index);
    const logic [31:0] corner[6] = '{0, 3, 32'h7fff_ffff, 32'h8000_0000,
                                       32'hffff_fffe, 32'hffff_ffff};
    int bank = run_index;
    riscv_op_e op;
    if (bank < RD_BANKS) begin
      op = riscv_op_e'(bank / (32 / ROM_WORDS));
      for (int i = 0; i < ROM_WORDS; i++) begin
        int rd = (bank * ROM_WORDS + i) % 32;
        req.program_words.push_back(encode(op, rd, rd, 31-rd));
      end
      return;
    end
    bank -= RD_BANKS;
    if (bank < CORNER_BANKS) begin
      for (int r = 1; r < 32; r++)
        req.initial_gprs.push_back(r <= 6 ? corner[r-1] : 0);
      foreach (corner[j])
        req.program_words.push_back(encode(ADD, 7, bank+1, j+1));
      return;
    end
    bank -= CORNER_BANKS;
    if (bank < ZERO_BANKS) begin
      op = riscv_op_e'(bank);
      for (int r = 1; r < 32; r++) req.initial_gprs.push_back(r);
      req.program_words.push_back(encode(op, 7, 0, 0)); // Zero result for all nine ops.
      if (op == SLT) req.program_words.push_back(encode(op, 7, 1, 3));
      else req.program_words.push_back(encode(op, 7, 3, 1));
      if (op inside {SLL, SRL}) begin
        req.initial_gprs[3] = 32;
        req.program_words.push_back(encode(op, 7, 1, 16));
        req.program_words.push_back(encode(op, 7, 1, 4));
      end
      return;
    end
    bank -= ZERO_BANKS;
    for (int i = 0; i < ROM_WORDS/2; i++) begin
      int rd = bank * (ROM_WORDS/2) + i;
      req.program_words.push_back(encode(ADD, rd, 1, 2));
      if (rd % 2) req.program_words.push_back(encode(XOR, 31, 2, rd));
      else        req.program_words.push_back(encode(SUB, 31, rd, 2));
    end
  endfunction
endclass
