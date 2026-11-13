// =============================================================================
// File   : riscv_if.sv
// Purpose: Virtual Interface - Cau noi giua UVM Env va DUT PROCESSOR.v
//          Chua tat ca tin hieu Input/Output va Internal Probe cua Datapath
// =============================================================================

interface riscv_if(input logic clock);

    // --- Primary I/O Signals (Ket noi truc tiep voi PROCESSOR.v) ---
    logic        reset;
    // TB-owned window: one active rising edge per requested program word.
    bit          checking;
    logic [31:0] pc;
    logic [31:0] instruction_code; // Output cua IFU -> Control & Datapath
    logic        zero;             // Output cua DATAPATH (zero_flag)

    // --- Internal Datapath Probe Signals ---
    // (Ket noi vao noi bo DATAPATH.v va REG_FILE.v de Monitor quan sat)
    logic        regwrite;         // Tin hieu ghi thanh ghi tu CONTROL
    logic [4:0]  write_reg;        // So hieu thanh ghi se ghi (rd = instr[11:7])
    logic [31:0] write_data;       // Gia tri se ghi vao thanh ghi (ket qua ALU)
    logic [31:0] read_data1;       // Gia tri doc ra tu rs1
    logic [31:0] read_data2;       // Gia tri doc ra tu rs2
    logic [3:0]  alu_control;      // Ma dieu khien ALU tu CONTROL

    // =========================================================================
    // Clocking Block cho DRIVER (Active - In-Agent)
    // Drive on the falling edge, before the DUT's rising-edge write-back.
    // =========================================================================
    clocking driver_cb @(negedge clock);
        default input #1step output #0;
        output reset, checking;
    endclocking

    // =========================================================================
    // Clocking Block cho IN-MONITOR (quan sat lenh nap vao CPU)
    // =========================================================================
    clocking in_mon_cb @(posedge clock);
        default input #1step;
        input checking, reset, pc, instruction_code;
    endclocking

    // =========================================================================
    // Clocking Block cho OUT-MONITOR (quan sat ket qua thuc thi Datapath)
    // =========================================================================
    clocking out_mon_cb @(posedge clock);
        default input #1step;
        input checking, reset, pc, instruction_code;
        input regwrite;
        input write_reg;
        input write_data;
        input read_data1;
        input read_data2;
        input alu_control;
        input zero;
    endclocking

    // --- Modports phan quyen truy cap cho tung thanh phan UVM ---
    modport driver_mp   (clocking driver_cb,  input clock);
    modport in_mon_mp   (clocking in_mon_cb,  input clock);
    modport out_mon_mp  (clocking out_mon_cb, input clock);

endinterface : riscv_if
