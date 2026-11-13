# Called from run.do after every test has stopped and flushed its UCDB.
set vcover [file join $questa_home win64 vcover.exe]
set merged [file join $result_dir merged.ucdb]
puts [exec $vcover merge -checkinputs $merged {*}$databases]
foreach {name options} {
    functional {-cvg -details}
    assertions {-assert -details}
    code_by_design_unit {-bydu -code bcesft}
    code_details {-bydu -code bcesft -details -zeros}
    code_totals {-code bcesft -totals}
} {
    puts [exec $vcover report {*}$options -precision 4 -file $result_dir/${name}.txt $merged]
}

proc phase4_read {path} {
    set stream [open $path r]
    set contents [read $stream]
    close $stream
    return $contents
}

# Check absolute bin counts. A missing coverpoint or an empty report must
# not turn into a passing percentage. These are the 16 rows of plan sheet 5.
set targets {
    cp_opcode 1 cp_funct3 8 cp_funct7 3 cp_instr 9
    cp_in1_range 6 cp_in2_range 6 cp_shift 4 cp_zero 2
    cp_rs1 32 cp_rs2 32 cp_rd 32 cp_pc_seq 9
    op_x_zero 18 op_x_rd 288 cross_corner_operands 36 cross_raw_hazard 32
}
set functional [phase4_read $result_dir/functional.txt]
set missing {}
set hit_bins 0
set planned_bins 0
foreach {point count} $targets {
    set pattern [format {(?n)^\s*(?:Coverpoint|Cross) \w+::%s[^\n]*\n\s*covered/total bins:\s+(\d+)\s+(\d+)} $point]
    incr planned_bins $count
    if {[regexp $pattern $functional -> hit total]} {
        incr hit_bins $hit
        if {$hit == $count && $total == $count} { continue }
    }
    lappend missing $point
}
set checks [list "Regression: [llength $results] runs, $failures failed"]
set problems {}
if {$failures} { lappend problems regression }
if {$stress_length < 1000} { lappend problems "TC_CORE_05 requires at least 1000 instructions per seed for sign-off" }
lappend checks "Functional coverage: $hit_bins/$planned_bins planned bins (16 metrics)"
if {[llength $missing] || ![regexp {TOTAL COVERGROUP COVERAGE: 100\.0+%} $functional]} {
    lappend problems "Functional coverage incomplete; check functional.txt ($missing)"
}

# Same RTL definitions are instantiated at unit and core level. Sum the
# native design-unit bin counts once, including units with only wiring.
set by_du [phase4_read $result_dir/code_by_design_unit.txt]
foreach du {PROCESSOR DATAPATH ALU CONTROL IFU INST_MEM REG_FILE} {
    if {![regexp -line [format {^=== Design Unit: work\.%s\s*$} $du] $by_du]} {
        lappend problems "Missing design unit $du"
    }
}
foreach {metric minimum} {{Stmts} 100 {Branches} 95 {FEC Condition Terms} 95 {FEC Expression Terms} 95 {Toggle Bins} 90} {
    set pattern [format {(?n)^[ \t]*%s\s+(\d+)\s+(\d+)} $metric]
    set active 0
    set hits 0
    foreach {row denominator numerator} [regexp -all -inline $pattern $by_du] {
        incr active $denominator
        incr hits $numerator
    }
    if {$active == 0 || 100 * $hits < $minimum * $active} { lappend problems $metric }
    set percent [expr {$active ? 100.0 * $hits / $active : 0.0}]
    lappend checks [format "%s: %d/%d = %.4f%% (goal %d%%)" $metric $hits $active $percent $minimum]
    if {$metric eq "Toggle Bins"} {
        set toggle_bins $active
        set toggle_hits $hits
    }
}

# The -zeros report includes each partially or wholly untoggled bit once.
# A bit must have both edges to satisfy the verification plan.
set details [phase4_read $result_dir/code_details.txt]
set nodes [expr {$toggle_bins / 2}]
set missed_nodes 0
foreach {row count} [regexp -all -inline -line {^Untoggled Node Count[ \t]*=[ \t]*(\d+)} $details] {
    incr missed_nodes $count
}
set full_nodes [expr {$nodes - $missed_nodes}]
if {$nodes == 0 || $toggle_bins % 2 || ($toggle_hits < $toggle_bins && $missed_nodes == 0) ||
    100 * $full_nodes < 90 * $nodes} { lappend problems "Bidirectional bit toggle" }
lappend checks [format "Bits toggled both ways: %d/%d = %.4f%% (goal 90%%)" $full_nodes $nodes \
    [expr {$nodes ? 100.0 * $full_nodes / $nodes : 0.0}]]

set sva_count 0
set sva_failures 0
set unexercised 0
set assertions [phase4_read $result_dir/assertions.txt]
set pattern {(?n)^(/tb_top/[^\n]+)\n[^\n]+\n[ \t]+(\d+)[ \t]+(\d+)}
foreach {row assertion failed passed} [regexp -all -inline $pattern $assertions] {
    incr sva_count
    incr sva_failures $failed
    if {$passed == 0} { incr unexercised }
}
# 64 reset-image checks, 64 hold checks, 12 core/unit PC, ALU, decode and
# register checks plus the alternating-zero assertion.
if {$sva_count != 141 || $sva_failures || $unexercised} { lappend problems "Project assertions" }
lappend checks "Project assertions: $sva_count instances, $sva_failures failures, $unexercised without a pass"

set compared 0
set unit_checks 0
set random_checked 0
set stress_seeds {}
foreach record $results {
    lassign $record id status seed_field log_path
    set log [phase4_read [file join $result_dir $log_path]]
    if {[regexp {\[SCOREBOARD\] Planned=(\d+) Compared=(\d+) PASS=(\d+) FAIL=(\d+)} $log -> n c p f]} {
        if {$n == 0 || $n != $c || $p != $n || $f} { lappend problems "$id scoreboard" }
        incr compared $c
        if {$id eq "TC_CORE_05"} {
            if {$c != $stress_length} { lappend problems "$id stress length" }
            incr random_checked $p
            lappend stress_seeds $seed_field
        }
    } elseif {[regexp {\[UNIT_CHECKS\] \w+ checked ([1-9]\d*) expectations} $log -> n]} {
        incr unit_checks $n
    } else {
        lappend problems "$id missing checker evidence"
    }
}
lappend checks "Scoreboard: $compared instructions compared; pin-level unit checks: $unit_checks"
set distinct_seeds [llength [lsort -unique $stress_seeds]]
lappend checks "Constrained-random: $random_checked passed instruction transactions across $distinct_seeds seeds"
if {$random_checked < 10000 || $distinct_seeds != [llength $stress_seeds]} {
    lappend problems "Constrained-random transaction volume or duplicate seed"
}
set status [expr {[llength $problems] ? "FAIL" : "PASS"}]
lappend checks "SIGNOFF=$status"
if {[llength $problems]} { lappend checks "Unmet: [join $problems {, }]" }
set gate [open $result_dir/signoff.txt w]
puts $gate [join $checks "\n"]
close $gate
puts [join $checks "\n"]
if {$status eq "FAIL"} { incr failures }
