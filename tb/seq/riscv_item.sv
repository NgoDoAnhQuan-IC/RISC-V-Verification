// =============================================================================
// File   : riscv_item.sv
// Purpose: UVM Sequence Item - RISC-V R-type instruction transaction
//          Carries instruction fields, actual DUT outputs, and expected results
// =============================================================================

class riscv_item extends uvm_sequence_item;

    // -------------------------------------------------------------------------
    // Randomizable instruction fields (R-type encoding)
    // -------------------------------------------------------------------------
    rand logic [6:0] opcode;
    rand logic [4:0] rd;
    rand logic [2:0] funct3;
    rand logic [4:0] rs1;
    rand logic [4:0] rs2;
    rand logic [6:0] funct7;

    // -------------------------------------------------------------------------
    // Assembled 32-bit instruction word (computed in post_randomize)
    // -------------------------------------------------------------------------
    logic [31:0] instruction_code;
    logic [31:0] pc;
    // Driver requests optionally replace the reset ROM, one word per address.
    // An empty queue selects the DUT's built-in eight-word program.
    logic [31:0] program_words[$];
    int unsigned rom_words_to_run = ROM_WORDS; // Used only for the built-in ROM.
    logic [31:0] initial_gprs[$]; // Optional stress operands for x1..x31.

    // -------------------------------------------------------------------------
    // Actual results - filled by out_monitor after sampling DUT outputs
    // -------------------------------------------------------------------------
    logic        actual_regwrite;
    logic [4:0]  actual_write_reg;
    logic [31:0] actual_write_data;
    logic        actual_zero;
    logic [3:0]  actual_alu_control;
    logic [31:0] read_data1, read_data2;

    // -------------------------------------------------------------------------
    // Expected results - filled by reference model (scoreboard)
    // -------------------------------------------------------------------------
    bit          expected_regwrite;
    logic [4:0]  expected_write_reg;
    logic [31:0] expected_write_data;
    logic        expected_zero;

    // Field macros must follow the declarations. Questa 10.7 expands them
    // immediately and otherwise reports every name as undefined.
    `uvm_object_utils_begin(riscv_item)
        `uvm_field_int(opcode,              UVM_ALL_ON)
        `uvm_field_int(rd,                  UVM_ALL_ON)
        `uvm_field_int(funct3,              UVM_ALL_ON)
        `uvm_field_int(rs1,                 UVM_ALL_ON)
        `uvm_field_int(rs2,                 UVM_ALL_ON)
        `uvm_field_int(funct7,              UVM_ALL_ON)
        `uvm_field_int(instruction_code,    UVM_ALL_ON)
        `uvm_field_int(pc,                  UVM_ALL_ON)
        `uvm_field_queue_int(program_words, UVM_ALL_ON)
        `uvm_field_int(rom_words_to_run, UVM_ALL_ON)
        `uvm_field_queue_int(initial_gprs, UVM_ALL_ON)
        `uvm_field_int(actual_regwrite,     UVM_ALL_ON)
        `uvm_field_int(actual_write_reg,    UVM_ALL_ON)
        `uvm_field_int(actual_write_data,   UVM_ALL_ON)
        `uvm_field_int(actual_zero,         UVM_ALL_ON)
        `uvm_field_int(actual_alu_control,  UVM_ALL_ON)
        `uvm_field_int(read_data1,          UVM_ALL_ON)
        `uvm_field_int(read_data2,          UVM_ALL_ON)
        `uvm_field_int(expected_regwrite,   UVM_ALL_ON)
        `uvm_field_int(expected_write_reg,  UVM_ALL_ON)
        `uvm_field_int(expected_write_data, UVM_ALL_ON)
        `uvm_field_int(expected_zero,       UVM_ALL_ON)
    `uvm_object_utils_end

    // -------------------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------------------

    // All instructions are R-type
    constraint c_opcode {
        opcode == 7'b0110011;
    }

    // Supported core-level encodings, including signed SLT.
    // MUL is the RISC-V M-extension encoding (funct7=0000001, funct3=000).
    constraint c_valid_combo {
        (funct3 == 3'b010 && funct7 == 7'b0000000) ||  // SLT
        (funct3 == 3'b000 && funct7 == 7'b0000000) ||  // ADD
        (funct3 == 3'b000 && funct7 == 7'b0100000) ||  // SUB
        (funct3 == 3'b000 && funct7 == 7'b0000001) ||  // MUL
        (funct3 == 3'b110 && funct7 == 7'b0000000) ||  // OR
        (funct3 == 3'b111 && funct7 == 7'b0000000) ||  // AND
        (funct3 == 3'b001 && funct7 == 7'b0000000) ||  // SLL
        (funct3 == 3'b101 && funct7 == 7'b0000000) ||  // SRL
        (funct3 == 3'b100 && funct7 == 7'b0000000);    // XOR
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "riscv_item");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // post_randomize: assemble instruction word from fields
    // Format: [31:25]=funct7 [24:20]=rs2 [19:15]=rs1 [14:12]=funct3
    //         [11:7]=rd [6:0]=opcode
    // -------------------------------------------------------------------------
    function void post_randomize();
        instruction_code = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    // -------------------------------------------------------------------------
    // get_instr_name: decode funct7+funct3 to mnemonic string
    // -------------------------------------------------------------------------
    function riscv_op_e get_op();
        if (opcode !== 7'b0110011) return UNKNOWN;
        case ({funct7, funct3})
            {7'b0000000, 3'b000}: return ADD;
            {7'b0100000, 3'b000}: return SUB;
            {7'b0000001, 3'b000}: return MUL;
            {7'b0000000, 3'b001}: return SLL;
            {7'b0000000, 3'b010}: return SLT;
            {7'b0000000, 3'b100}: return XOR;
            {7'b0000000, 3'b101}: return SRL;
            {7'b0000000, 3'b110}: return OR;
            {7'b0000000, 3'b111}: return AND;
            default:              return UNKNOWN;
        endcase
    endfunction

    function string get_instr_name();
        riscv_op_e op = get_op();
        return op.name();
    endfunction

    // Unpack a raw instruction word into the R-type fields.
    function void decode(logic [31:0] instr);
        instruction_code = instr;
        opcode           = instr[6:0];
        rd               = instr[11:7];
        funct3           = instr[14:12];
        rs1              = instr[19:15];
        rs2              = instr[24:20];
        funct7           = instr[31:25];
    endfunction

    // -------------------------------------------------------------------------
    // convert2string: human-readable transaction summary
    // -------------------------------------------------------------------------
    function string convert2string();
        return $sformatf(
            "%s x%0d = x%0d op x%0d | instr=0x%08h | exp_data=0x%08h exp_zero=%0b | act_data=0x%08h act_zero=%0b",
            get_instr_name(),
            rd, rs1, rs2,
            instruction_code,
            expected_write_data, expected_zero,
            actual_write_data,   actual_zero
        );
    endfunction

endclass : riscv_item
