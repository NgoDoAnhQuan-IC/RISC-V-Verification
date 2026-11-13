class riscv_invalid_decode_seq extends riscv_base_seq;
  `uvm_object_utils(riscv_invalid_decode_seq)

  localparam int INVALID_KINDS = 5;

  function new(string name = "riscv_invalid_decode_seq");
    super.new(name);
    num_runs = 2 * INVALID_KINDS;
  endfunction

  function logic [31:0] rejected_word(int kind);
    case (kind)
      0: return 32'h0000_0000; // All-zero illegal instruction.
      1: return 32'hffff_ffff; // All-ones illegal instruction.
      2: return {7'h7f, 5'd1, 5'd2, 3'd0, 5'd30, 7'h33}; // ADD with unsupported funct7.
      3: return {7'h00, 5'd3, 5'd4, 3'd3, 5'd17, 7'h33}; // Unsupported funct3.
      4: return {7'h00, 5'd5, 5'd6, 3'd0, 5'd9,  7'h4c}; // Non-R opcode, otherwise ADD.
      default: `uvm_fatal("REJECT_KIND", "Unknown negative vector")
    endcase
  endfunction

  virtual function void prepare_program(riscv_item req, int run_index);
    logic [4:0] last_rd = 31;
    logic [4:0] dest;
    logic [31:0] word;
    // Give every writable destination a nonzero, distinct sentinel.
    for (int r = 1; r < 32; r++) req.initial_gprs.push_back(32'h5a5a_0000 + r);
    for (int slot = 0; slot < ROM_WORDS; slot++) begin
      if (slot % 2 == run_index % 2) begin
        word = rejected_word((run_index / 2 + slot / 2) % INVALID_KINDS);
        last_rd = word[11:7];
      end else begin
        // Consume the preceding rejected destination and compare against the
        // model's unchanged value. The last slot also gets a full RF hold check.
        dest = 10 + slot;
        word = {7'h00, 5'd1, last_rd, 3'd0, dest, 7'h33};
      end
      req.program_words.push_back(word);
    end
  endfunction
endclass
