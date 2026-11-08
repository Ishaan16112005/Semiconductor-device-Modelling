#======================================================================
#  SONOS erase-efficiency post-processing (Sentaurus Visual)
#  run:  svisual -batchx plot_erase.tcl     (after idvg_des.cmd)
#
#  Plots  (PNG):  IdVg_erase.png     Id-Vg during / after erase
#                 dVth_vs_time.png   dVth vs erase time
#                 erase_current.png  |Ig|, |Isub| vs erase time
#                 trapped_charge.png trapped / residual nitride charge
#  Tables (CSV):  erase_vth.csv       t_e, Vth, dVth per read state
#                 erase_transient.csv time, currents, nitride charge
#  Summary     :  erase_summary.txt
#======================================================================
load_library extract

#---------------------------------------------------- user settings
set Lg_um      0.1       ;# gate length [um]
set Tnit_cm    5e-7      ;# nitride thickness [cm]  (5 nm)
set Icc        [expr {1e-7/$Lg_um}]   ;# const-current Vth: 100 nA*W/L [A/um]
set dVthTarget -2.0      ;# erase time = first t_e with dVth <= this [V]

set states {fresh programmed ers_1us ers_3us ers_10us ers_30us ers_100us \
            ers_300us ers_1ms ers_3ms ers_10ms erased}
array set tE {ers_1us 1e-6 ers_3us 3e-6 ers_10us 1e-5 ers_30us 3e-5 \
              ers_100us 1e-4 ers_300us 3e-4 ers_1ms 1e-3 ers_3ms 3e-3 ers_10ms 1e-2}
array set LABEL {fresh "Fresh device" programmed "Programmed" \
  ers_1us "Erase 1 <greek>m</greek>s" ers_3us "Erase 3 <greek>m</greek>s" ers_10us "Erase 10 <greek>m</greek>s" \
  ers_30us "Erase 30 <greek>m</greek>s" ers_100us "Erase 100 <greek>m</greek>s" ers_300us "Erase 300 <greek>m</greek>s" \
  ers_1ms "Erase 1 ms" ers_3ms "Erase 3 ms" ers_10ms "Erase 10 ms" erased "After erase (V<sub>g</sub>=0)"}
array set DSNAME {fresh IdVg_Fresh programmed IdVg_Programmed ers_1us IdVg_Erase_1us \
  ers_3us IdVg_Erase_3us ers_10us IdVg_Erase_10us ers_30us IdVg_Erase_30us \
  ers_100us IdVg_Erase_100us ers_300us IdVg_Erase_300us ers_1ms IdVg_Erase_1ms \
  ers_3ms IdVg_Erase_3ms ers_10ms IdVg_Erase_10ms erased IdVg_After_Erase}
set COLORS {black blue #1f77b4 #2ca02c #17becf #9467bd #8c564b #e377c2 \
            #ff7f0e #d62728 #bcbd22 red}

#---------------------------------------------------- 1. Id-Vg family
create_plot -1d -name Plot_IdVg
set_plot_prop -plot Plot_IdVg -title "I<sub>d</sub>-V<sub>g</sub> during / after erase (V<sub>d</sub>=0.05 V)" -show_legend
set_axis_prop -plot Plot_IdVg -axis x -title {Gate Voltage [V]}
set_axis_prop -plot Plot_IdVg -axis y -title {Drain Current [A/<greek>m</greek>m]} -type log
set_legend_prop -plot Plot_IdVg -location bottom_right

set k 0
foreach s $states {
  set f idvg_${s}_idvg_des.plt
  if {![file exists $f]} { puts "WARNING: $f not found, skipped"; incr k; continue }
  load_file $f -name $DSNAME($s)
  create_curve -name C_$s -dataset $DSNAME($s) -plot Plot_IdVg \
      -axisX "gate OuterVoltage" -axisY "drain TotalCurrent"
  set_curve_prop C_$s -plot Plot_IdVg -label $LABEL($s) -color [lindex $COLORS $k] -line_width 2
  incr k

  set Vg [get_variable_data "gate OuterVoltage"  -dataset $DSNAME($s)]
  set Id [get_variable_data "drain TotalCurrent" -dataset $DSNAME($s)]
  set Ida {}
  foreach i $Id { lappend Ida [expr {abs($i)}] }
  # sanity check: a failed read never reaches Vd = 0.05 V
  set Vd [lindex [get_variable_data "drain OuterVoltage" -dataset $DSNAME($s)] end]
  set vt ""
  set gm ""
  if {abs($Vd - 0.05) > 1e-3} {
    puts "WARNING: $s read is invalid (Vd = $Vd V), check idvg_${s}_des.log"
  } else {
    catch { ext::ExtractVti -out vt -name noprint -v $Vg -i $Ida -io $Icc }
    catch { ext::ExtractVtgm -out gm -name noprint -v $Vg -i $Ida }
  }
  if {![string is double -strict $vt]} { set vt "" }
  if {![string is double -strict $gm]} { set gm "" }
  set VTH($s) $vt
  set VTGM($s) $gm
}

#---------------------------------------------------- 2. dVth vs t_e
set fo [open erase_vth.csv w]
puts $fo "t_erase_s,Vth_cc_V,dVth_cc_V,Vth_gm_V"
set Vp ""
if {[info exists VTH(programmed)]} { set Vp $VTH(programmed) }
set tErase ""
set tPrev ""; set dPrev ""
foreach s $states {
  if {![info exists tE($s)] || ![info exists VTH($s)] || $VTH($s) eq "" || $Vp eq ""} continue
  set d [expr {$VTH($s) - $Vp}]
  puts $fo "$tE($s),$VTH($s),$d,$VTGM($s)"
  # log-time interpolation of the target crossing
  if {$tErase eq "" && $d <= $dVthTarget} {
    if {$tPrev eq ""} { set tErase $tE($s) } else {
      set fr [expr {($dVthTarget - $dPrev)/($d - $dPrev)}]
      set tErase [expr {pow(10, log10($tPrev) + $fr*(log10($tE($s)) - log10($tPrev)))}]
    }
  }
  set tPrev $tE($s); set dPrev $d
}
close $fo

load_file erase_vth.csv -name dVth_vs_EraseTime
create_plot -1d -name Plot_dVth
set_plot_prop -plot Plot_dVth -title "Erase: <greek>D</greek>V<sub>th</sub> vs erase time" -show_legend
set_axis_prop -plot Plot_dVth -axis x -title {Erase time [s]} -type log
set_axis_prop -plot Plot_dVth -axis y -title {<greek>D</greek>V<sub>th</sub> [V]}
create_curve -name C_dvth -dataset dVth_vs_EraseTime -plot Plot_dVth -axisX t_erase_s -axisY dVth_cc_V
set_curve_prop C_dvth -plot Plot_dVth -label "<greek>D</greek>V<sub>th</sub> (V<sub>th</sub> @ I<sub>d</sub>=100nA*W/L)" -color blue -line_width 3 -show_markers -markers_type circle

#---------------------------------------------------- 3/4. erase transient
load_file erase_des.plt -name Erase_Transient_raw
set t   [get_variable_data time                  -dataset Erase_Transient_raw]
set Ig  [get_variable_data "gate TotalCurrent"   -dataset Erase_Transient_raw]
set Is  [get_variable_data "substrate TotalCurrent" -dataset Erase_Transient_raw]
set Ne  [get_variable_data "AveNitrideAsSemiconductor eTrappedCharge" -dataset Erase_Transient_raw]
set Nh  [get_variable_data "AveNitrideAsSemiconductor hTrappedCharge" -dataset Erase_Transient_raw]

set fo [open erase_transient.csv w]
puts $fo "time_s,abs_Igate_A_um,abs_Isub_A_um,eTrapped_cm2,hTrapped_cm2,Qnet_cm2"
set n [llength $t]
for {set i 0} {$i < $n} {incr i} {
  set ti [lindex $t $i]
  if {$ti <= 0} continue
  set ne [expr {[lindex $Ne $i]*$Tnit_cm}]
  set nh [expr {[lindex $Nh $i]*$Tnit_cm}]
  puts $fo [format "%.6e,%.6e,%.6e,%.6e,%.6e,%.6e" $ti \
      [expr {abs([lindex $Ig $i])}] [expr {abs([lindex $Is $i])}] $ne $nh [expr {$nh-$ne}]]
}
close $fo
# values at the end of the erase pulse (t = 10 ms) = residual charge
set iEnd 0
for {set i 0} {$i < $n} {incr i} { if {[lindex $t $i] <= 1.0e-2} { set iEnd $i } }
set QeEnd [expr {[lindex $Ne $iEnd]*$Tnit_cm}]
set QhEnd [expr {[lindex $Nh $iEnd]*$Tnit_cm}]
set IgEnd [expr {abs([lindex $Ig $iEnd])}]
set Qe0   [expr {[lindex $Ne 0]*$Tnit_cm}]
set Qh0   [expr {[lindex $Nh 0]*$Tnit_cm}]

load_file erase_transient.csv -name Erase_Transient
create_plot -1d -name Plot_Ierase
set_plot_prop -plot Plot_Ierase -title "Erase current" -show_legend
set_axis_prop -plot Plot_Ierase -axis x -title {Erase time [s]} -type log
set_axis_prop -plot Plot_Ierase -axis y -title {|Current| [A/<greek>m</greek>m]} -type log
create_curve -name C_ig -dataset Erase_Transient -plot Plot_Ierase -axisX time_s -axisY abs_Igate_A_um
create_curve -name C_is -dataset Erase_Transient -plot Plot_Ierase -axisX time_s -axisY abs_Isub_A_um
set_curve_prop C_ig -plot Plot_Ierase -label "|I<sub>gate</sub>| (erase current)" -color red  -line_width 3
set_curve_prop C_is -plot Plot_Ierase -label "|I<sub>substrate</sub>|"  -color blue -line_width 2 -line_style dash

create_plot -1d -name Plot_Q
set_plot_prop -plot Plot_Q -title "Nitride trapped charge during erase" -show_legend
set_axis_prop -plot Plot_Q -axis x -title {Erase time [s]} -type log
set_axis_prop -plot Plot_Q -axis y -title {Trapped charge [q cm<sup>-2</sup>]}
create_curve -name C_qe -dataset Erase_Transient -plot Plot_Q -axisX time_s -axisY eTrapped_cm2
create_curve -name C_qh -dataset Erase_Transient -plot Plot_Q -axisX time_s -axisY hTrapped_cm2
create_curve -name C_qn -dataset Erase_Transient -plot Plot_Q -axisX time_s -axisY Qnet_cm2
set_curve_prop C_qe -plot Plot_Q -label "trapped electrons" -color blue  -line_width 3
set_curve_prop C_qh -plot Plot_Q -label "trapped holes"     -color red   -line_width 3
set_curve_prop C_qn -plot Plot_Q -label "net (holes - electrons)" -color black -line_width 3 -line_style dash

#---------------------------------------------------- export + summary
export_view IdVg_erase.png     -plots Plot_IdVg   -format png -overwrite -resolution 1000x750
export_view dVth_vs_time.png   -plots Plot_dVth   -format png -overwrite -resolution 1000x750
export_view erase_current.png  -plots Plot_Ierase -format png -overwrite -resolution 1000x750
export_view trapped_charge.png -plots Plot_Q      -format png -overwrite -resolution 1000x750

proc fmt {v f} { if {$v eq ""} { return "n/a" } ; return [format $f $v] }
set fo [open erase_summary.txt w]
foreach ch [list stdout $fo] {
  puts $ch "================ SONOS erase summary ================"
  puts $ch "Vth criterion        : Id = [format %.2e $Icc] A/um @ Vd = 0.05 V"
  foreach s {fresh programmed ers_10ms erased} {
    if {[info exists VTH($s)]} { puts $ch [format "Vth(%-10s)     : %s V" $s [fmt $VTH($s) %.3f]] }
  }
  if {$Vp ne "" && [info exists VTH(ers_10ms)] && $VTH(ers_10ms) ne ""} {
    puts $ch "Erase dVth @ 10 ms   : [format %.3f [expr {$VTH(ers_10ms)-$Vp}]] V"
  }
  if {$Vp ne "" && [info exists VTH(erased)] && $VTH(erased) ne ""} {
    puts $ch "Erase dVth (Vg=0)    : [format %.3f [expr {$VTH(erased)-$Vp}]] V"
  }
  puts $ch "Erase time to dVth=[format %.1f $dVthTarget] V : [fmt $tErase %.3e] s"
  puts $ch "Erase |Ig| @ 10 ms   : [format %.3e $IgEnd] A/um"
  puts $ch "Trapped e-  start/end: [format %.3e $Qe0] / [format %.3e $QeEnd] cm^-2"
  puts $ch "Trapped h+  start/end: [format %.3e $Qh0] / [format %.3e $QhEnd] cm^-2"
  puts $ch "Residual net charge  : [format %.3e [expr {$QhEnd-$QeEnd}]] q/cm^2  (holes - electrons)"
  puts $ch "====================================================="
}
close $fo
