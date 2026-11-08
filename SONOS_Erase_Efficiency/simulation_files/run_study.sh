#!/bin/bash
#======================================================================
#  Extended SONOS erase study (paper: White et al., IEEE C&D 2000)
#    A. erase-voltage sweep + partial erase   (Fig. 6)
#    B. P/E-cycling degradation, interface traps (Figs. 9, 13)
#    C. retention, programmed + erased, 10 years (Fig. 10)
#
#  Needs sonos_msh.tdr (run  sde -e -l device.scm  first).
#  usage:   ./run_study.sh                 12 jobs at a time, 4 threads each
#           NJOBS=16 ./run_study.sh        more parallel jobs (licenses!)
#  Results: study/plots/*.png, study/*.csv, study/study_summary.txt
#======================================================================
cd "$(dirname "$0")"
NJOBS=${NJOBS:-12}
THREADS=${THREADS:-4}

[ -f sonos_msh.tdr ] || { echo "sonos_msh.tdr missing: run  sde -e -l device.scm  first"; exit 1; }
[ -d study ] || python3 make_study.py || exit 1
# insulator-nitride mesh for the fresh-device interface-trap reads
[ -f device_fresh.scm ] || python3 make_study.py --freshdit-only || exit 1
[ -f sonos_fresh_msh.tdr ] || sde -e -l device_fresh.scm > sde_fresh.log 2>&1 || exit 1

run_stage () {
  echo ">> stage $1: $(wc -l < study/jobs_stage$1.txt) jobs, $NJOBS at a time  [$(date +%T)]"
  xargs -P "$NJOBS" -L 1 bash -c \
    'cd "study/$0" && sdevice --threads '"$THREADS"' "$1" > "${1%.cmd}.out" 2>&1; echo "   done  $0/$1"' \
    < study/jobs_stage$1.txt
}

run_stage 1     # program (one per degradation level)
run_stage 2     # erase transients (+ retention of programmed state)
run_stage 3     # Id-Vg reads of all erase states (+ retention of erased state)
run_stage 4     # Id-Vg reads of retention states

echo ">> checking for failed solves"
bad=$(grep -l "does not converge\|less than MinStep" study/*/*_des.log study/*/*/*_des.log 2>/dev/null)
if [ -n "$bad" ]; then echo "FAILED (re-run these decks in their folder):"; echo "$bad"; else echo "   none"; fi

echo ">> plots  [$(date +%T)]"
svisual -batchx plot_study.tcl > study/plot_study.log 2>&1
cat study/study_summary.txt
