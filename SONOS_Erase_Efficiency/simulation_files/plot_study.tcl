#======================================================================
#  Extended SONOS erase study -- post-processing (Sentaurus Visual)
#  run:  svisual -batchx plot_study.tcl     (or  svisual plot_study.tcl)
#  in :  study/...  (produced by run_study.sh)
#  out:  study/plots/*.png, study/*.csv, study/study_summary.txt
#======================================================================
set Lg_um   0.1
set Tnit_cm 5e-7
set Icc     [expr {1e-7/$Lg_um}]      ;# Vth criterion: 100 nA * W/L  [A/um]
file mkdir study/plots

set ETIMES {e_1us 1e-6 e_3us 3e-6 e_10us 1e-5 e_30us 3e-5 e_100us 1e-4 e_300us 3e-4
            e_1ms 1e-3 e_3ms 3e-3 e_10ms 1e-2 e_30ms 3e-2 e_100ms 1e-1 e_1s 1.0}
set RTIMES {r_100us 1e-4 r_10ms 1e-2 r_1s 1.0 r_100s 1e2 r_1e4s 1e4 r_1e6s 1e6
            r_1e8s 1e8 r_10yr 3.1536e8}
set VGES  {-8 -9 -10 -11}
set NITG  {nit0 0 nit1.1e11 1.1e11 nit2.3e11 2.3e11 nit5.0e11 5.0e11}
set CYC   {nit1.1e11 1 nit2.3e11 1e5 nit5.0e11 1e6}
set COL   {#1f77b4 #2ca02c #ff7f0e #d62728 #9467bd #8c564b #e377c2 #17becf}
set ::nds 0

#---------------------------------------------------------------- helpers
# Id-Vg of one read -> {Vg-list Id-list}, empty if the read failed
proc readIV {f} {
  if {![file exists $f]} { puts "WARNING: missing $f"; return {} }
  set ds DS[incr ::nds]
  load_file $f -name $ds
  set vg [get_variable_data "gate OuterVoltage"  -dataset $ds]
  set id [get_variable_data "drain TotalCurrent" -dataset $ds]
  set vd [lindex [get_variable_data "drain OuterVoltage" -dataset $ds] end]
  remove_datasets $ds
  if {abs($vd-0.05) > 1e-3 || [lindex $vg 0] > -3.5} { puts "WARNING: invalid read $f"; return {} }
  set ia {}; foreach i $id { lappend ia [expr {abs($i)+1e-30}] }
  return [list $vg $ia]
}
# gate voltage where |Id| first rises through Io (log interpolation)
proc vAt {iv Io} {
  if {$iv eq ""} { return "" }
  lassign $iv vg id
  for {set k 1} {$k < [llength $vg]} {incr k} {
    set i0 [lindex $id [expr {$k-1}]]; set i1 [lindex $id $k]
    if {$i0 < $Io && $i1 >= $Io} {
      set v0 [lindex $vg [expr {$k-1}]]; set v1 [lindex $vg $k]
      return [expr {$v0 + ($v1-$v0)*(log10($Io)-log10($i0))/(log10($i1)-log10($i0))}]
    }
  }
  return ""
}
proc vth {iv} { return [vAt $iv $::Icc] }
# subthreshold swing [mV/dec] between Id = 1e-11 and 1e-9 A/um
proc ss {iv} {
  set a [vAt $iv 1e-11]; set b [vAt $iv 1e-9]
  if {$a eq "" || $b eq ""} { return "" }
  return [expr {($b-$a)*1000.0/2.0}]
}
# time where a sampled curve y(t) (log t) first crosses level y0 going down
proc tCross {ts ys y0} {
  if {[llength $ts] && [lindex $ys 0] <= $y0} { return "<[lindex $ts 0]" }
  for {set k 1} {$k < [llength $ts]} {incr k} {
    set y0a [lindex $ys [expr {$k-1}]]; set y1 [lindex $ys $k]
    if {$y0a > $y0 && $y1 <= $y0} {
      set t0 [lindex $ts [expr {$k-1}]]; set t1 [lindex $ts $k]
      return [expr {pow(10, log10($t0)+(log10($t1)-log10($t0))*($y0-$y0a)/($y1-$y0a))}]
    }
  }
  return ""
}
proc f3 {v {fmt %.3f}} { if {$v eq ""} {return "n/a"}; if {![string is double -strict $v]} {return $v}; return [format $fmt $v] }
proc newPlot {name title xt yt xlog ylog {xrange ""}} {
  create_plot -1d -name $name
  set_plot_prop -plot $name -title $title -show_legend
  set_axis_prop -plot $name -axis x -title $xt -type [expr {$xlog ? "log" : "linear"}]
  if {$xrange ne ""} { set ::XRANGE($name) $xrange }
  set_axis_prop -plot $name -axis y -title $yt -type [expr {$ylog ? "log" : "linear"}]
}
proc addCsv {plot csv x y label color {style solid} {markers 1}} {
  set ds [file rootname [file tail $csv]]
  if {[lsearch [list_datasets] $ds] < 0} { load_file $csv -name $ds }
  set c ${plot}_[incr ::nds]
  create_curve -name $c -dataset $ds -plot $plot -axisX $x -axisY $y
  set_curve_prop $c -plot $plot -label $label -color $color -line_width 3 -line_style $style
  if {$markers} { set_curve_prop $c -plot $plot -show_markers -markers_type circle }
}

#---------------------------------------------------------------- fresh / programmed per group
foreach {g nit} $NITG {
  set IV($g,fresh) [readIV study/$g/idvg_fresh_idvg_des.plt]
  set IV($g,prog)  [readIV study/$g/idvg_programmed_idvg_des.plt]
  set VF($g) [vth $IV($g,fresh)]
  set VP($g) [vth $IV($g,prog)]
  # fresh device, DC read with ACTIVE interface traps (degradation of Vth and SS)
  set IVD($g) [readIV study/$g/idvg_freshdit_idvg_des.plt]
  set VFD($g) [vth $IVD($g)]
  set SSD($g) [ss  $IVD($g)]
}

# erase case -> csv (t, Vth, dVth, completion %) ; returns lists
proc eraseCase {g v tag} {
  global ETIMES VP VF IV
  set fo [open study/$tag.csv w]
  puts $fo "t_erase_s,Vth_V,dVth_V,erase_completion_pct"
  set ts {}; set vs {}
  foreach {n t} $ETIMES {
    set iv [readIV study/$g/vge$v/idvg_${n}_idvg_des.plt]
    set IV($g,$v,$n) $iv
    set vt [vth $iv]
    if {$vt eq "" || $VP($g) eq "" || $VF($g) eq ""} continue
    set cp [expr {100.0*($VP($g)-$vt)/($VP($g)-$VF($g))}]
    puts $fo "$t,$vt,[expr {$vt-$VP($g)}],$cp"
    lappend ts $t; lappend vs $vt
  }
  close $fo
  return [list $ts $vs]
}
# erase transient -> csv (|Ig|, net trapped charge) ; returns {Ig@1ms Qnet@10ms Qnet@1s}
proc eraseTransient {g v tag} {
  global Tnit_cm
  set f study/$g/vge$v/erase_des.plt
  if {![file exists $f]} { return {"" "" ""} }
  set ds DS[incr ::nds]; load_file $f -name $ds
  set t  [get_variable_data time -dataset $ds]
  set ig [get_variable_data "gate TotalCurrent" -dataset $ds]
  set ne [get_variable_data "AveNitrideAsSemiconductor eTrappedCharge" -dataset $ds]
  set nh [get_variable_data "AveNitrideAsSemiconductor hTrappedCharge" -dataset $ds]
  remove_datasets $ds
  set fo [open study/$tag.csv w]
  puts $fo "time_s,abs_Igate_A_um,Qnet_q_cm2"
  set r {"" "" ""}
  for {set k 0} {$k < [llength $t]} {incr k} {
    set tk [lindex $t $k]
    if {$tk < 2e-7 || $tk > 0.9999} continue      ;# skip gate-ramp displacement current
    set q [expr {([lindex $nh $k]-[lindex $ne $k])*$Tnit_cm}]
    puts $fo [format "%.6e,%.6e,%.6e" $tk [expr {abs([lindex $ig $k])}] $q]
    if {$tk <= 1e-3} { lset r 0 [expr {abs([lindex $ig $k])}] }
    if {$tk <= 1e-2} { lset r 1 $q }
    lset r 2 $q
  }
  close $fo
  return $r
}

set SUM {}
lappend SUM "======================= SONOS extended erase study ======================="
lappend SUM "Vth: Id = [format %.1e $Icc] A/um at Vd = 0.05 V.  Completion = (Vth_prog - Vth)/(Vth_prog - Vth_fresh)"
lappend SUM ""

#================================================================ A. erase voltage / partial erase
newPlot A_Vth        "Erase: V<sub>th</sub> vs erase pulse width (cf. paper Fig. 6)" "Erase pulse width \[s\]" "V<sub>th</sub> \[V\]" 1 0 {1e-6 1}
newPlot A_Completion "Partial erase: erase completion vs time" "Erase pulse width \[s\]" "Erase completion \[%\]" 1 0 {1e-6 1}
newPlot A_Ierase     "Erase current vs time" "Erase time \[s\]" "|I<sub>gate</sub>| \[A/<greek>m</greek>m\]" 1 1 {1e-7 1}
lappend SUM "A. ERASE VOLTAGE / PARTIAL ERASE   (Nit = 0, Vth_prog = [f3 $VP(nit0)] V, Vth_fresh = [f3 $VF(nit0)] V)"
lappend SUM [format "%6s %10s %10s %10s %11s %11s %12s %12s" Vge dVth@1ms dVth@10ms dVth@1s t_50% t_100% Ig@1ms Qres@1s]
lappend SUM [format "%6s %10s %10s %10s %11s %11s %12s %12s" "\[V\]" "\[V\]" "\[V\]" "\[V\]" "\[s\]" "\[s\]" "\[A/um\]" "\[q/cm2\]"]
set k 0; set T50 {}
foreach v $VGES {
  lassign [eraseCase nit0 $v A_vge$v] ts vs
  lassign [eraseTransient nit0 $v A_Ierase_vge$v] ig1 q10 q1s
  set c [lindex $COL $k]; incr k
  addCsv A_Vth        study/A_vge$v.csv t_erase_s Vth_V "V<sub>ge</sub> = $v V" $c
  addCsv A_Completion study/A_vge$v.csv t_erase_s erase_completion_pct "V<sub>ge</sub> = $v V" $c
  if {[file exists study/A_Ierase_vge$v.csv]} {
    addCsv A_Ierase study/A_Ierase_vge$v.csv time_s abs_Igate_A_um "V<sub>ge</sub> = $v V" $c solid 0
  }
  set d {}
  foreach tt {1e-3 1e-2 1.0} {
    set i [lsearch -real $ts $tt]
    lappend d [expr {$i >= 0 ? [lindex $vs $i]-$VP(nit0) : ""}]
  }
  set t50 ""; set t100 ""
  if {$VP(nit0) ne "" && $VF(nit0) ne ""} {
    set v50  [expr {$VP(nit0) - 0.5*($VP(nit0)-$VF(nit0))}]
    set t50  [tCross $ts $vs $v50]
    set t100 [tCross $ts $vs $VF(nit0)]
  }
  lappend T50 $v $t50
  lappend SUM [format "%6s %10s %10s %10s %11s %11s %12s %12s" $v [f3 [lindex $d 0]] [f3 [lindex $d 1]] \
      [f3 [lindex $d 2]] [f3 $t50 %.2e] [f3 $t100 %.2e] [f3 $ig1 %.2e] [f3 $q1s %.2e]]
}
# decades of erase time per volt (paper: ~1 decade / V)
set dv {}
foreach {va ta} [lrange $T50 0 end-2] {vb tb} [lrange $T50 2 end] {
  if {[string is double -strict $ta] && [string is double -strict $tb] && $ta ne "" && $tb ne ""} { lappend dv [format "%.2f" [expr {log10($ta/$tb)}]] }
}
lappend SUM "   t_50% speed-up per 1 V more negative Vge (decades): [join $dv {, }]   (paper: ~1 decade/V)"
lappend SUM "   t_50% / t_100% = time to remove 50% / 100% of the programmed window; 'n/a' = not reached in 1 s (partial erase)"
lappend SUM ""
# reference lines
set fo [open study/A_ref.csv w]; puts $fo "t,prog,fresh"
puts $fo "1e-6,$VP(nit0),$VF(nit0)"; puts $fo "1,$VP(nit0),$VF(nit0)"; close $fo
addCsv A_Vth study/A_ref.csv t prog  "programmed" black dash 0
addCsv A_Vth study/A_ref.csv t fresh "fresh"      #808080 dot 0

#================================================================ B. degradation (Vge = -10 V)
newPlot B_dVth  "Degradation: erase <greek>D</greek>V<sub>th</sub> vs time (V<sub>ge</sub> = -10 V)" "Erase pulse width \[s\]" "<greek>D</greek>V<sub>th</sub> \[V\]" 1 0 {1e-6 1}
newPlot B_IdVg  "Degradation: I<sub>d</sub>-V<sub>g</sub> programmed / erased (10 ms)" "Gate Voltage \[V\]" "Drain Current \[A/<greek>m</greek>m\]" 0 1 {-4 8}
newPlot B_FreshIdVg "Degradation: fresh-device I<sub>d</sub>-V<sub>g</sub> with interface traps (DC)" "Gate Voltage \[V\]" "Drain Current \[A/<greek>m</greek>m\]" 0 1 {-2 3}
newPlot B_SS "Degradation: subthreshold swing vs P/E cycles (fresh device, DC)" "P/E cycles (equivalent, from N<sub>it</sub>)" "SS \[mV/dec\]" 1 0 {0.5 3e6}
newPlot B_Endur "Memory window vs P/E cycles (cf. paper Fig. 9)" "P/E cycles (equivalent, from N<sub>it</sub>)" "V<sub>th</sub> \[V\]" 1 0 {0.5 3e6}
lappend SUM "B. DEGRADATION BY P/E CYCLING (interface traps at Si/tunnel oxide, Vge = -10 V)"
lappend SUM " (1) fresh device, DC Id-Vg, interface traps ACTIVE:"
lappend SUM [format "%14s %9s %13s %13s %12s" Nit cycles "Vth_fresh" "dVth_fresh" "SS"]
lappend SUM [format "%14s %9s %13s %13s %12s" "\[cm-2\]" "" "\[V\]" "\[V\]" "\[mV/dec\]"]
set fd [open study/B_dc_degradation.csv w]; puts $fd "cycles,Vth_fresh_V,SS_mV_dec"
set k 0
foreach {g nit} $NITG {
  set c [lindex $COL $k]; incr k
  set lab [expr {$nit == 0 ? "ideal (N<sub>it</sub>=0)" : "N<sub>it</sub> = $nit cm<sup>-2</sup>"}]
  if {[dict exists $CYC $g]} { set cyc [format %.0e [dict get $CYC $g]] } else { set cyc ideal }
  set dv [expr {$VFD($g) ne "" && $VFD(nit0) ne "" ? $VFD($g)-$VFD(nit0) : ""}]
  lappend SUM [format "%14s %9s %13s %13s %12s" [format %.1e $nit] $cyc [f3 $VFD($g)] [f3 $dv] [f3 $SSD($g) %.1f]]
  if {$IVD($g) ne ""} {
    set tag B_[string map {. p} $g]_fresh_dc
    set fo [open study/$tag.csv w]; puts $fo "Vg,Id"
    foreach a [lindex $IVD($g) 0] b [lindex $IVD($g) 1] { puts $fo "$a,$b" }; close $fo
    addCsv B_FreshIdVg study/$tag.csv Vg Id $lab $c solid 0
  }
  if {[dict exists $CYC $g] && $SSD($g) ne ""} { puts $fd "[dict get $CYC $g],$VFD($g),$SSD($g)" }
}
close $fd
addCsv B_SS study/B_dc_degradation.csv cycles SS_mV_dec "SS (fresh, DC)" #d62728
lappend SUM " (2) erase at Vge = -10 V with interface traps (pulsed read: interface traps held at"
lappend SUM "     their end-of-pulse state during the read, cf. paper Fig. 7 dynamic measurement):"
lappend SUM [format "%11s %9s %10s %11s %9s %10s %11s" Nit cycles Vth_prog Vth_e10ms window dVth@1s t_100%]
lappend SUM [format "%11s %9s %10s %11s %9s %10s %11s" "\[cm-2\]" "" "\[V\]" "\[V\]" "\[V\]" "\[V\]" "\[s\]"]
set fe [open study/B_endurance.csv w]; puts $fe "cycles,Vth_prog_V,Vth_erased10ms_V,window_V"
set k 0
foreach {g nit} $NITG {
  set tag B_[string map {. p} $g]
  lassign [eraseCase $g -10 $tag] ts vs
  set c [lindex $COL $k]; incr k
  set lab [expr {$nit == 0 ? "ideal (N<sub>it</sub>=0)" : "N<sub>it</sub> = $nit cm<sup>-2</sup>"}]
  addCsv B_dVth study/$tag.csv t_erase_s dVth_V $lab $c
  # Id-Vg programmed & erased(10 ms)
  foreach {key ivl sty} [list prog $IV($g,prog) solid ers [set IV($g,-10,e_10ms)] dash] {
    if {$ivl eq ""} continue
    set fo [open study/${tag}_IdVg_$key.csv w]; puts $fo "Vg,Id"
    foreach a [lindex $ivl 0] b [lindex $ivl 1] { puts $fo "$a,$b" }; close $fo
    addCsv B_IdVg study/${tag}_IdVg_$key.csv Vg Id "$lab, [expr {$key eq "prog" ? "programmed" : "erased 10 ms"}]" $c $sty 0
  }
  set ve [vth $IV($g,-10,e_10ms)]
  set i1 [lsearch -real $ts 1.0]
  set d1 [expr {$i1 >= 0 && $VP($g) ne "" ? [lindex $vs $i1]-$VP($g) : ""}]
  set win [expr {$ve ne "" && $VP($g) ne "" ? $VP($g)-$ve : ""}]
  if {[dict exists $CYC $g]} { set cyc [format %.0e [dict get $CYC $g]] } else { set cyc ideal }
  lappend SUM [format "%11s %9s %10s %11s %9s %10s %11s" [format %.1e $nit] $cyc \
      [f3 $VP($g)] [f3 $ve] [f3 $win] [f3 $d1] [f3 [tCross $ts $vs $VF($g)] %.2e]]
  if {[dict exists $CYC $g] && $win ne ""} { puts $fe "[dict get $CYC $g],$VP($g),$ve,$win" }
}
close $fe
addCsv B_Endur study/B_endurance.csv cycles Vth_prog_V      "programmed"    red
addCsv B_Endur study/B_endurance.csv cycles Vth_erased10ms_V "erased (10 ms)" blue
lappend SUM "   cycles mapped from paper Fig. 13 charge pumping: Nit = Qcp/(q*A), A = 10x4 um^2"
lappend SUM ""

#================================================================ C. retention
newPlot C_Ret "Retention at V<sub>g</sub> = 0 (cf. paper Fig. 10)" "Retention time \[s\]" "V<sub>th</sub> \[V\]" 1 0 {1e-6 1e9}
lappend SUM "C. RETENTION (Vg = 0, room temperature, Nit = 0)"
lappend SUM [format "%-28s %10s %10s %10s %10s" state "Vth(start)" "Vth(1 s)" "Vth(1e6 s)" "Vth(10 yr)"]
foreach {which lab c} {prog "programmed" red ers "erased (10 ms @ -10 V)" blue} {
  set d study/nit0/retention_$which
  set v0 [vth [readIV $d/idvg_start_idvg_des.plt]]
  set fo [open study/C_ret_$which.csv w]; puts $fo "t_s,Vth_V"
  if {$v0 ne ""} { puts $fo "1e-6,$v0" }
  foreach {n t} $RTIMES {
    set vt [vth [readIV $d/idvg_${n}_idvg_des.plt]]
    set R($which,$n) $vt
    if {$vt ne ""} { puts $fo "$t,$vt" }
  }
  close $fo
  addCsv C_Ret study/C_ret_$which.csv t_s Vth_V $lab $c
  lappend SUM [format "%-28s %10s %10s %10s %10s" $lab [f3 $v0] [f3 $R($which,r_1s)] [f3 $R($which,r_1e6s)] [f3 $R($which,r_10yr)]]
}
if {$R(prog,r_10yr) ne "" && $R(ers,r_10yr) ne ""} {
  lappend SUM "   memory window after 10 years: [format %.3f [expr {$R(prog,r_10yr)-$R(ers,r_10yr)}]] V"
}
lappend SUM "=========================================================================="

#================================================================ export
foreach p {A_Vth A_Completion A_Ierase B_FreshIdVg B_SS B_dVth B_IdVg B_Endur C_Ret} {
  if {[info exists ::XRANGE($p)]} { set_axis_prop -plot $p -axis x -range $::XRANGE($p) }
  export_view study/plots/$p.png -plots $p -format png -overwrite -resolution 1000x750
}
set fo [open study/study_summary.txt w]
foreach l $SUM { puts $fo $l; puts $l }
close $fo
