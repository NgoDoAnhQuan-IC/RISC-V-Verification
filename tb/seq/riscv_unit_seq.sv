// Pin-level virtual sequence. Drive between rising edges and sample after
// the DUT has settled. Expected vectors are independent of the core predictor.
class riscv_unit_seq extends uvm_sequence #(riscv_item);
  `uvm_object_utils(riscv_unit_seq)
  virtual riscv_unit_if vif;
  string case_id;
  int unsigned checks;

  function new(string name = "riscv_unit_seq");
    super.new(name);
  endfunction

  function void check_value(string signal_name, logic [31:0] actual, expected);
    checks++;
    if (actual !== expected)
      `uvm_error(case_id, $sformatf("%s expected=%08h actual=%08h", signal_name, expected, actual))
  endfunction

  task alu(logic [3:0] op, logic [31:0] a, b, expected);
    @(negedge vif.clock);
    vif.alu_check = 1;
    vif.alu_op = op;
    vif.a = a;
    vif.b = b;
    @(posedge vif.clock);
    check_value($sformatf("ALU[%h](%08h,%08h)", op, a, b), vif.result, expected);
    check_value("zero", vif.zero, expected == 0);
    #1ns;
  endtask

  task alu_vectors();
    case (case_id)
      "TC_ALU_01": begin
        alu(4'h2, 100, 250, 350);
        // An unused control code after a nonzero result must clear the ALU.
        alu(4'hf, 100, 250, 0);
      end
      "TC_ALU_02": begin
        alu(4'h2, 32'h12345678, 0, 32'h12345678);
        alu(4'h2, 0, 32'h12345678, 32'h12345678);
      end
      "TC_ALU_03": alu(4'h2, 32'h7fffffff, 1, 32'h80000000);
      "TC_ALU_04": alu(4'h2, 32'hffffffff, 1, 0);
      "TC_ALU_05": alu(4'h4, 32'ha5a5a5a5, 32'ha5a5a5a5, 0);
      "TC_ALU_06": alu(4'h4, 10, 15, 32'hfffffffb);
      "TC_ALU_07": alu(4'h0, 32'haaaaaaaa, 32'h55555555, 0);
      "TC_ALU_08": alu(4'h1, 32'haaaaaaaa, 32'h55555555, 32'hffffffff);
      "TC_ALU_09": alu(4'h7, 32'h12345678, 32'h12345678, 0);
      "TC_ALU_10": for (int n = 1; n <= 31; n++) alu(4'h3, 1, n, 32'b1 << n);
      "TC_ALU_11": begin
        alu(4'h3, 1, 32, 1);
        // Exercise the same five-bit mask on the right-shift path.
        alu(4'h5, 32'h80000000, 33, 32'h40000000);
      end
      "TC_ALU_12": alu(4'h5, 32'h80000000, 1, 32'h40000000);
      "TC_ALU_13": begin
        alu(4'h6, 32'h00010000, 32'h00020000, 0);
        alu(4'h6, 32'h80000001, 3, 32'h80000003);
      end
      "TC_ALU_14": begin
        alu(4'h8, 5, 10, 1);
        alu(4'h8, 32'hffffffff, 1, 1);
        alu(4'h8, 1, 32'hffffffff, 0);
        alu(4'h8, 5, 5, 0);
      end
      default: `uvm_fatal("CASE_ID", case_id)
    endcase
  endtask

  task decode(logic [6:0] opcode, funct7, logic [2:0] funct3,
              bit expected_we, logic [3:0] expected_op = 0);
    @(negedge vif.clock);
    vif.ctrl_check = 1;
    vif.opcode = opcode;
    vif.funct7 = funct7;
    vif.funct3 = funct3;
    @(posedge vif.clock);
    check_value("regwrite_control", vif.decode_we, expected_we);
    if (expected_we)
      check_value($sformatf("alu_control funct7=%02h funct3=%h", funct7, funct3),
                  vif.decoded_op, expected_op);
    #1ns;
  endtask

  task control_vectors();
    case (case_id)
      "TC_CTRL_01": decode(7'h33, 0, 0, 1, 4'h2);
      "TC_CTRL_02": decode(7'h33, 7'h20, 0, 1, 4'h4);
      "TC_CTRL_03": begin
        decode(7'h33, 0, 1, 1, 4'h3);
        decode(7'h33, 0, 2, 1, 4'h8);
        decode(7'h33, 0, 4, 1, 4'h7);
        decode(7'h33, 0, 5, 1, 4'h5);
        decode(7'h33, 0, 6, 1, 4'h1);
        decode(7'h33, 0, 7, 1, 4'h0);
        decode(7'h33, 1, 0, 1, 4'h6);
      end
      "TC_CTRL_04", "TC_CTRL_05": begin
        decode(7'h33, 0, 0, 1, 4'h2); // Expose a stale write enable.
        if (case_id == "TC_CTRL_04") begin
          decode(7'h7f, 0, 0, 0); // Original matrix vector.
          // Changing any one opcode bit must disable writeback.
          for (int bit_index = 0; bit_index < 7; bit_index++)
            decode(7'h33 ^ (7'b1 << bit_index), 0, 0, 0);
        end else begin
          decode(7'h33, 0, 3, 0);      // Unsupported SLTU
          decode(7'h33, 7'h20, 5, 0);  // Unsupported SRA shares funct3 with SRL
          decode(7'h33, 1, 1, 0);      // Unsupported MULH shares funct3 with SLL
          decode(7'h33, 2, 0, 0);      // Reserved funct7 on the ADD path
        end
      end
      default: `uvm_fatal("CASE_ID", case_id)
    endcase
  endtask

  task read_pair(int r1, r2, logic [31:0] expected1, expected2);
    vif.rs1 = r1;
    vif.rs2 = r2;
    #1ns;
    check_value($sformatf("port1 x%0d", r1), vif.rdata1, expected1);
    check_value($sformatf("port2 x%0d", r2), vif.rdata2, expected2);
  endtask

  task write_reg(int rd, logic [31:0] data, bit we, logic [31:0] expected);
    @(negedge vif.clock);
    vif.rd = rd;
    vif.rs1 = rd;
    vif.rf_we = we;
    vif.wdata = data;
    #1ns;
    if (case_id == "TC_REG_07") check_value("x7 before write edge", vif.rdata1, 7);
    @(posedge vif.clock);
    #1ns;
    check_value($sformatf("x%0d after write edge", rd), vif.rdata1, expected);
    vif.rf_we = 0;
  endtask

  task register_vectors();
    logic [31:0] data[32];
    @(negedge vif.clock);
    vif.rf_reset = 1;
    @(negedge vif.clock);
    vif.rf_reset = 0;
    vif.rf_check = 1;
    case (case_id)
      "TC_REG_01": for (int r = 0; r < 32; r++)
        read_pair(r, 31-r, reset_reg_value(r), reset_reg_value(31-r));
      "TC_REG_02": begin
        for (int r = 1; r < 32; r++) begin
          data[r] = $urandom();
          write_reg(r, data[r], 1, data[r]);
        end
        for (int r = 1; r < 32; r++) read_pair(r, 32-r, data[r], data[32-r]);
      end
      "TC_REG_03": begin
        write_reg(5, 32'haaaa0001, 1, 32'haaaa0001);
        write_reg(5, 32'hbbbb0002, 1, 32'hbbbb0002);
        write_reg(5, 32'hcccc0003, 1, 32'hcccc0003);
      end
      "TC_REG_04": write_reg(0, 32'hdeadbeef, 1, 0);
      "TC_REG_05": read_pair(10, 20, 32'h10, 32'h20);
      "TC_REG_06": read_pair(15, 15, 32'h15, 32'h15);
      "TC_REG_07": write_reg(7, 32'h55aa, 1, 32'h55aa);
      "TC_REG_08": write_reg(3, 32'h9999, 0, 3);
      default: `uvm_fatal("CASE_ID", case_id)
    endcase
    @(negedge vif.clock);
    #1ns; // Retire post-write assertions before the UVM objection drops.
  endtask

  task fetch_vectors();
    int cycles;
    time previous_edge;
    logic [31:0] oob_first;
    @(negedge vif.clock); // PC has already left its declaration-time value.
    vif.ifu_reset = 1;
    vif.ifu_check = 1;
    #1ns;
    check_value("asynchronous reset PC", vif.pc, 0);
    @(negedge vif.clock);
    vif.ifu_reset = 0;
    case (case_id)
      "TC_IFU_01": cycles = 0;
      "TC_IFU_03": begin
        check_value("little-endian fetch at PC=0", vif.instruction, RESET_PROGRAM[0]);
        cycles = 0;
      end
      "TC_IFU_02": cycles = 8;
      "TC_IFU_04": cycles = 7;
      "TC_IFU_05": cycles = 9;
      "TC_SAN_02": cycles = 10;
      default: `uvm_fatal("CASE_ID", case_id)
    endcase
    for (int i = 1; i <= cycles; i++) begin
      @(posedge vif.clock);
      if (case_id == "TC_SAN_02" && i > 1)
        check_value("clock period (ns)", $time - previous_edge, 10ns);
      previous_edge = $time;
      #1ns;
      check_value("PC after active edge", vif.pc, 4*i);
      if (i == 7 && case_id == "TC_IFU_04")
        check_value("last little-endian word", vif.instruction, RESET_PROGRAM[7]);
      if (i == 8 && case_id == "TC_IFU_05") oob_first = vif.instruction;
      if (i == 9 && case_id == "TC_IFU_05") begin
        if (oob_first === 32'bx && vif.instruction === 32'bx)
          `uvm_info("IFU_OOB", "PC=32,36 both fetched X (out of bounds)", UVM_NONE)
        else if (oob_first === RESET_PROGRAM[0] && vif.instruction === RESET_PROGRAM[1])
          `uvm_info("IFU_OOB", "PC=32,36 wrapped to ROM words 0,1", UVM_NONE)
        else
          `uvm_error("IFU_OOB", $sformatf("Unclassified fetch at PC=32,36: %08h %08h", oob_first, vif.instruction))
      end
    end
    @(negedge vif.clock);
    #1ns;
  endtask

  task body();
    case (case_id.substr(0,6))
      "TC_ALU_": alu_vectors();
      "TC_REG_": register_vectors();
      "TC_IFU_": fetch_vectors();
      default: begin
        if (case_id == "TC_SAN_02") fetch_vectors();
        else if (case_id.substr(0,7) == "TC_CTRL_") control_vectors();
        else `uvm_fatal("CASE_ID", case_id)
      end
    endcase
  endtask
endclass
