class riscv_ref_model extends uvm_component;
  `uvm_component_utils(riscv_ref_model)

  uvm_analysis_imp #(riscv_item, riscv_ref_model) analysis_export;
  uvm_analysis_imp_program #(riscv_item, riscv_ref_model) program_export;
  uvm_analysis_port #(riscv_item) ap;
  virtual riscv_if vif;
  logic [31:0] shadow_reg[32];
  logic [31:0] next_pc;
  bit allow_unsupported;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    program_export = new("program_export", this);
    ap = new("ap", this);
    void'(uvm_config_db #(bit)::get(this, "", "allow_unsupported", allow_unsupported));
    if (!uvm_config_db #(virtual riscv_if)::get(this, "", "riscv_vif", vif))
      `uvm_fatal("NO_VIF", "Missing reset observation for the reference model")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.reset);
      next_pc = 0;
      // Project reset image uses hex literals with the decimal register digits.
      // For example, x20 = 32'h20 (32 decimal).
      foreach (shadow_reg[i]) shadow_reg[i] = reset_reg_value(i);
    end
  endtask

  function void write_program(riscv_item request);
    foreach (request.initial_gprs[i]) shadow_reg[i+1] = request.initial_gprs[i];
  endfunction

  function void write(riscv_item item);
    riscv_item exp_item;
    logic [31:0] a, b, result;
    riscv_op_e op = item.get_op();

    if ($isunknown(item.instruction_code))
      `uvm_fatal("FETCH_X", $sformatf("PC=%08h instruction=%08h", item.pc, item.instruction_code))
    a = shadow_reg[item.rs1];
    b = shadow_reg[item.rs2];
    case (op)
      ADD: result = a + b;
      SUB: result = a - b;
      MUL: result = a * b;
      SLL: result = a << b[4:0];
      SRL: result = a >> b[4:0];
      SLT: result = {31'b0, ($signed(a) < $signed(b))};
      XOR: result = a ^ b;
      OR:  result = a | b;
      AND: result = a & b;
      default: begin
        if (!allow_unsupported)
          `uvm_fatal("UNSUPPORTED", $sformatf("PC=%08h instruction=%08h", item.pc, item.instruction_code))
        result = 0; // The disabled writeback bus does not update the model.
      end
    endcase
    if (op != UNKNOWN && item.rd != 0) shadow_reg[item.rd] = result;

    exp_item = riscv_item::type_id::create("exp_item");
    exp_item.decode(item.instruction_code);
    exp_item.pc = next_pc;
    exp_item.read_data1 = a;
    exp_item.read_data2 = b;
    next_pc += 4;
    exp_item.expected_regwrite = op != UNKNOWN;
    exp_item.expected_write_reg = item.rd;
    exp_item.expected_write_data = result;
    exp_item.expected_zero = (result == 0);
    `uvm_info("PREDICT", $sformatf("PC=%08h %s x%0d(%08h), x%0d(%08h) -> x%0d=%08h",
      exp_item.pc, op.name(), item.rs1, a, item.rs2, b, item.rd, result), UVM_MEDIUM)
    ap.write(exp_item);
  endfunction
endclass
