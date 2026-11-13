class riscv_driver extends uvm_driver #(riscv_item);
  `uvm_component_utils(riscv_driver)

  virtual riscv_if vif;
  string imem_path;
  string regfile_path;
  uvm_analysis_port #(riscv_item) program_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    program_ap = new("program_ap", this);
    if (!uvm_config_db #(virtual riscv_if)::get(this, "", "riscv_vif", vif))
      `uvm_fatal("NO_VIF", "Missing RISC-V interface")
    if (!uvm_config_db #(string)::get(this, "", "imem_path", imem_path))
      `uvm_fatal("NO_IMEM", "Missing instruction memory path")
    void'(uvm_config_db #(string)::get(this, "", "regfile_path", regfile_path));
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive_program(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_program(riscv_item request);
    int words = request.program_words.size();
    if (words == 0) words = request.rom_words_to_run;
    if (words < 1 || words > ROM_WORDS)
      `uvm_fatal("ROM_SIZE", $sformatf("Requested %0d words from the %0d-word ROM", words, ROM_WORDS))
    if (!(request.initial_gprs.size() inside {0, 31}))
      `uvm_fatal("GPR_SIZE", "Stress initialization requires x1..x31")
    if (request.initial_gprs.size() && regfile_path == "")
      `uvm_fatal("NO_REGFILE", "Missing path for stress operand initialization")

    @(vif.driver_cb);
    vif.driver_cb.reset <= 1;
    repeat (5) @(vif.driver_cb);

    // Reset loads the built-in ROM. Deposit optional words after that load,
    // on the falling edge preceding the first checked write-back.
    foreach (request.program_words[i]) begin
      for (int b = 0; b < 4; b++) begin
        string path = $sformatf("%s[%0d]", imem_path, 4*i+b);
        if (!uvm_hdl_deposit(path, request.program_words[i][8*b +: 8]))
          `uvm_fatal("ROM_LOAD", $sformatf("Cannot write %s", path))
      end
    end
    foreach (request.initial_gprs[i]) begin
      string path = $sformatf("%s[%0d]", regfile_path, i+1);
      if (!uvm_hdl_deposit(path, request.initial_gprs[i]))
        `uvm_fatal("GPR_LOAD", $sformatf("Cannot write %s", path))
    end
    program_ap.write(request);
    vif.driver_cb.reset <= 0;
    vif.driver_cb.checking <= 1;
    repeat (words) @(vif.driver_cb);
    vif.driver_cb.checking <= 0;
  endtask
endclass
