## RISC-V 32-bit R-Type Core Verification

This project implements and verifies a small RISC-V processor focused on
register-register instructions. The design contains an instruction fetch unit,
control unit, register file, and ALU.

### Verified instruction scope

The verified core supports these nine operations:

- ADD, SUB, MUL
- SLL, SRL
- XOR, OR, AND
- SLT

The built-in instruction ROM contains eight 32-bit instructions. Verification
covers unit-level behavior and the core execution path from instruction fetch
through writeback. Tests also cover reset behavior, register x0, unsupported
instruction decoding, operand corner cases, RAW dependencies, and instruction
fetch beyond the ROM boundary.

I-type, load/store, branch, jump, CSR, trap, and other unimplemented
instruction groups are outside the current verification scope.

### Verification environment

- SystemVerilog UVM 1.2 testbench
- SystemVerilog Assertions (SVA)
- QuestaSim 10.7c regression and coverage collection
- Constrained-random stress tests with reproducible seeds

### Latest regression results

- 41/41 planned matrix testcases passed
- 55/55 simulation runs passed
- 10,000 constrained-random instructions checked across 10 seeds
- 10,550 scoreboard instruction comparisons passed
- Functional coverage: 518/518 planned bins
- Statement, branch, condition, and expression coverage: 100%
- Bits observed toggling in both directions: 94.13%
- 141 project assertion instances exercised with zero violations

### Running the regression

Run from the repository root in QuestaSim 10.7c with UVM 1.2 configured:

```tcl
do sim/run.do phase4 12345 1000
