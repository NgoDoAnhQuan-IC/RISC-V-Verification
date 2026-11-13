# Run from the project root using QuestaSim 10.7c.
# vsim -c -do "do sim/run.do riscv_base_test"
# do sim/run.do TC_CORE_05 12345 1000   (ID, seed, stress length)
# do sim/run.do phase3 12345            (all 41 IDs in fresh simulations)
# do sim/run.do phase4 12345 1000       (matrix, smoke, closure and 10 stress seeds)
if {[batch_mode]} { onerror {quit -force -code 2} } else { onerror {abort} }

set test_name riscv_base_test
if {[info exists 1]} { set test_name $1 }
set seed 12345
set stress_length 1000
if {[info exists 2]} { set seed $2 }
if {[info exists 3]} { set stress_length $3 }
foreach value [list $seed $stress_length] {
    if {![string is integer -strict $value] || $value < 1 || $value > 2147483647} {
        error "Seed and stress length must be positive 32-bit integers"
    }
}
set matrix {}
foreach {group count} {SAN 3 ALU 14 REG 8 CTRL 5 IFU 5 CORE 6} {
    for {set i 1} {$i <= $count} {incr i} { lappend matrix [format "TC_%s_%02d" $group $i] }
}
if {[string match TC_* $test_name] && [lsearch -exact $matrix $test_name] < 0} {
    error "Unknown testcase $test_name"
}

if {[info exists ::env(MODEL_TECH)]} {
    set questa_home [file normalize [file join $::env(MODEL_TECH) ..]]
} else {
    set questa_home C:/questasim64_10.7c
}
set uvm_src [file join $questa_home verilog_src uvm-1.2 src]
set uvm_lib [file join $questa_home uvm-1.2]
set uvm_dpi [file join $uvm_lib win64 uvm_dpi]
if {![file exists [file join $uvm_lib _info]]} {
    error "UVM 1.2 library missing in $uvm_lib. Start QuestaSim from its win64 directory."
}

set phase4 [expr {$test_name eq "phase4"}]
if {![info exists project_root]} { set project_root [file normalize .] }
if {$phase4} {
    set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
    set result_dir [file join $project_root sim phase4 seed_${seed}_n${stress_length}_${stamp}_[pid]]
    file mkdir $result_dir/logs $result_dir/ucdb $result_dir/build
    puts "Phase 4 results: $result_dir"
    cd $result_dir/build
    vmap -c
}
if {![file isdirectory work]} { vlib work }
vmap work work
vmap uvm_1_2 $uvm_lib
set processor_dir [file join $project_root Processor]
set metrics [expr {$phase4 ? "bcesft" : "bst"}]
vlog -sv -timescale 1ns/1ps +cover=$metrics -work work +incdir+$processor_dir [file join $processor_dir PROCESSOR.v]
vlog -sv -mfcu -timescale 1ns/1ps -work work -L uvm_1_2 \
    +incdir+$project_root +incdir+$uvm_src [file join $project_root tb/if/riscv_if.sv] \
    [file join $project_root tb/if/riscv_unit_if.sv] [file join $project_root tb_top.sv]

set cases [list $test_name]
if {$test_name eq "phase3"} { set cases $matrix }
if {$phase4} {
    set cases [concat $matrix {riscv_base_test riscv_program_smoke_test riscv_full_test
        riscv_coverage_closure_test riscv_invalid_decode_test} [lrepeat 9 TC_CORE_05]]
} else {
    set result_dir sim/phase3/seed_${seed}_n${stress_length}
}
set failures 0
set results {}
set databases {}
set stress_index 0
foreach id $cases {
    set run_seed $seed
    if {$phase4 && $id eq "TC_CORE_05"} {
        set run_seed [expr {1 + (wide($seed) - 1 + $stress_index) % 2147483647}]
        incr stress_index
    }
    set test_class $id
    set options {}
    set sim_log sim/${id}.log
    set verbosity UVM_MEDIUM
    if {[string match TC_* $id]} {
        file mkdir $result_dir
        set sim_log $result_dir/${id}.log
        set test_class riscv_unit_matrix_test
        if {[string match TC_CORE_* $id] || $id in {TC_SAN_01 TC_SAN_03}} {
            set test_class riscv_core_matrix_test
        }
        set options [list +CASE=$id +N_INSTR=$stress_length]
        if {$id eq "TC_CORE_05"} { set verbosity UVM_LOW }
    } elseif {$id eq "riscv_base_test"} { set sim_log sim/uvm_run.log }

    set coverage_options {}
    if {$phase4} {
        set run_id ${id}_s${run_seed}
        set sim_log $result_dir/logs/${run_id}.log
        set coverage_options [list -testname $run_id -togglefixedsizearray -togglemaxfixedsizearray 4096 -wlfdeleteonquit]
        if {$id eq "riscv_coverage_closure_test"} { set verbosity UVM_LOW }
    }
    vsim -voptargs="+acc" -nodpiexports -coverage -onfinish stop -L uvm_1_2 \
        {*}$coverage_options -sv_lib $uvm_dpi -l $sim_log -sv_seed $run_seed +UVM_TESTNAME=$test_class \
        +UVM_VERBOSITY=$verbosity {*}$options work.tb_top
    if {![batch_mode] && $test_name ne "phase3" && !$phase4} {
        if {$test_class eq "riscv_unit_matrix_test"} {
            add wave /tb_top/clk /tb_top/unit_fixture/bus/*
        } else {
            add wave /tb_top/clk /tb_top/dut_if/reset /tb_top/dut_if/checking
            add wave -hex /tb_top/dut_if/pc /tb_top/dut_if/instruction_code
            add wave /tb_top/dut_if/regwrite /tb_top/dut_if/alu_control /tb_top/dut_if/write_reg
            add wave -hex /tb_top/dut_if/read_data1 /tb_top/dut_if/read_data2 /tb_top/dut_if/write_data
            add wave /tb_top/dut_if/zero
        }
    }
    run -all
    set completed [examine -radix unsigned sim:/tb_top/test_completed]
    set passed [examine -radix unsigned sim:/tb_top/test_passed]
    if {$completed != 1} { error "$id stopped before UVM completed; see $sim_log" }
    if {!$passed} { incr failures }
    if {$phase4} {
        set db $result_dir/ucdb/${run_id}.ucdb
        coverage save $db
        lappend databases $db
        set line "$id [expr {$passed ? {PASS} : {FAIL}}] seed=$run_seed logs/${run_id}.log"
    } else {
        set line "$id [expr {$passed ? {PASS} : {FAIL}}] $sim_log"
    }
    lappend results $line
    puts $line
    if {$test_name eq "phase3" || $phase4} {
        quit -sim
    } elseif {$test_class ne "riscv_unit_matrix_test"} {
        coverage report -cvg
    }
}
if {$test_name eq "phase3" || $phase4} {
    set summary [open $result_dir/summary.txt w]
    puts $summary "QuestaSim $test_name | seed=$seed | stress instructions=$stress_length"
    puts $summary [join $results "\n"]
    puts $summary "TOTAL=[llength $results] PASS=[expr {[llength $results]-$failures}] FAIL=$failures"
    close $summary
}
if {$phase4} {
    cd $result_dir
    source [file join $project_root sim phase4_report.tcl]
    cd $project_root
}
if {[batch_mode]} { quit -force -code [expr {$failures > 0 ? 1 : 0}] }
