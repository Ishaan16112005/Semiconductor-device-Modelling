#!/bin/bash
#======================================================================
#  SONOS erase-efficiency flow:  sde -> program -> erase -> Id-Vg -> plots
#
#  Single erase condition (Vge = -10 V, as written in erase_des.cmd):
#      ./run_sonos.sh
#  Several erase voltages run IN PARALLEL (one sub-folder each):
#      VGE_LIST="-8 -10 -12" ./run_sonos.sh
#  Threads per sdevice job (4 threads = 1 parallel license):
#      THREADS=8 ./run_sonos.sh
#======================================================================
set -e
cd "$(dirname "$0")"

# Sentaurus environment: source your site's Synopsys setup (PATH + license)
# before running this script.
command -v sdevice >/dev/null || { echo "sdevice not found: source your Sentaurus environment first"; exit 1; }

THREADS=${THREADS:-4}

echo ">> [1/5] sde: building sonos_msh.tdr"
sde -e -l device.scm > sde_run.log 2>&1

echo ">> [2/5] sdevice: program"
sdevice --threads "$THREADS" program_des.cmd > program_run.log 2>&1

run_erase () {   # $1 = working dir
  ( cd "$1"
    echo ">> [3/5] sdevice: erase       ($1)"
    sdevice --threads "$THREADS" erase_des.cmd > erase_run.log 2>&1
    echo ">> [4/5] sdevice: Id-Vg reads ($1)"
    sdevice --threads "$THREADS" idvg_des.cmd  > idvg_run.log  2>&1
    echo ">> [5/5] svisual: plots       ($1)"
    svisual -batchx plot_erase.tcl > plot_run.log 2>&1
    cat erase_summary.txt )
}

if [ -z "$VGE_LIST" ]; then
  run_erase .
else
  for v in $VGE_LIST; do
    d="vge_${v}"
    mkdir -p "$d"
    for f in sonos_msh.tdr sdevice.par datexcodes.txt fresh*_des.sav programmed*_des.sav; do
      ln -sf "../$f" "$d/$f"
    done
    cp idvg_des.cmd plot_erase.tcl "$d/"
    # replace the erase voltage on the line tagged #VGE
    sed "/#VGE/s/-10 at/${v} at/g" erase_des.cmd > "$d/erase_des.cmd"
    run_erase "$d" > "$d/flow.log" 2>&1 &
  done
  wait
  for v in $VGE_LIST; do echo "===== Vge = $v V"; cat "vge_${v}/erase_summary.txt"; done
fi
