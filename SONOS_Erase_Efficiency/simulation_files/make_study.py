#!/usr/bin/env python3
"""
Generate the extended SONOS erase study (based on White et al., "On the Go
with SONOS", IEEE Circuits & Devices, July 2000) into ./study/

  A. Erase-voltage dependence + partial erase  (paper Fig. 6)
       Vge = -8, -9, -10, -11 V, erase pulse up to 1 s, Nit = 0
  B. Degradation by P/E cycling = interface traps (paper Figs. 9, 13)
       Nit at Si/tunnel-oxide from charge pumping Qcp/(q*A), A = 10x4 um^2:
       virgin 1.1e11, 1e5 cycles 2.3e11, 1e6 cycles 5.0e11 cm^-2 (Vge = -10 V)
  C. Retention of programmed and erased states up to 10 years (paper Fig. 10)

Physics / traps / Math are copied from program_des.cmd so that every deck in
a group is identical (required by Load()).  Run:  python3 make_study.py
"""
import os, re, shutil

ROOT  = os.path.dirname(os.path.abspath(__file__))
STUDY = os.path.join(ROOT, "study")

VGE_SWEEP = [-8, -9, -10, -11]                       # study A (Nit = 0)
GROUPS = {                                           # name: (Nit [cm^-2], Vge list)
    "nit0":       (0.0,    VGE_SWEEP),
    "nit1.1e11":  (1.1e11, [-10]),                   # virgin device
    "nit2.3e11":  (2.3e11, [-10]),                   # after 1e5 P/E cycles
    "nit5.0e11":  (5.0e11, [-10]),                   # after 1e6 P/E cycles
}
# erase save points (name, time [s])
ERASE_T = [("e_1us",1e-6),("e_3us",3e-6),("e_10us",1e-5),("e_30us",3e-5),
           ("e_100us",1e-4),("e_300us",3e-4),("e_1ms",1e-3),("e_3ms",3e-3),
           ("e_10ms",1e-2),("e_30ms",3e-2),("e_100ms",1e-1),("e_1s",1.0)]
# retention save points
RET_T = [("r_100us",1e-4),("r_10ms",1e-2),("r_1s",1.0),("r_100s",1e2),
         ("r_1e4s",1e4),("r_1e6s",1e6),("r_1e8s",1e8),("r_10yr",3.1536e8)]

# ------------------------------------------------------------------ helpers
src = open(os.path.join(ROOT, "program_des.cmd")).read()
COMMON = re.search(r"(\*-+ Physics.*?)\*-+ Solve", src, re.S).group(1)

def common(nit, read=False, robust=False):
    c = COMMON
    if robust:     # long trap transients: no extrapolation, 4 digits (tested: fast, <1% change)
        c = c.replace("  Extrapolate\n", "  * no Extrapolate: robust for long trap transients\n")
        c = c.replace("  Digits=5\n", "  Digits=4\n")
    if nit > 0:
        dit = nit / 1.12            # uniform over the Si bandgap [cm^-2 eV^-1]
        itr = f"""Physics (RegionInterface="Substrate/TunnelOxide") {{
  * interface traps from P/E-cycling degradation, Nit = {nit:.2e} cm^-2
  Traps(
    ( Acceptor Uniform fromMidBandGap EnergyMid=0.28  EnergySig=0.56
      Conc={dit:.4e} eXsection=1e-15 hXsection=1e-15 )
    ( Donor    Uniform fromMidBandGap EnergyMid=-0.28 EnergySig=0.56
      Conc={dit:.4e} eXsection=1e-15 hXsection=1e-15 )
  )
}}

"""
        c = c.replace("*---------------------------------------------------------------- Output",
                      itr + "*---------------------------------------------------------------- Output")
    if read:
        c = c.replace("  Iterations=25\n", "  Iterations=50\n")
    return c

def file_block(tag):
    return f"""File {{
  Grid      = "sonos_msh.tdr"
  Parameter = "sdevice.par"
  Current   = "{tag}_des.plt"
  Plot      = "{tag}_des.tdr"
  Output    = "{tag}_des.log"
}}
"""

def electrodes(gate_wave=None):
    g = f'\n    Voltage=( {gate_wave} )' if gate_wave else ""
    return f"""Electrode {{
  {{ Name="gate"      Voltage=0{g} }}
  {{ Name="source"    Voltage=0 }}
  {{ Name="drain"     Voltage=0 }}
  {{ Name="substrate" Voltage=0 }}
}}
"""

def decade_steps(t_end, frac=0.2, t0=1e-5):
    """TurningPoints: max step = frac * start of each decade (log-uniform)."""
    out, a = [f"      (Condition(Time(Range=(0 {t0:g}))) Value={frac*t0/10:g})"], t0
    while a < t_end:
        b = min(a * 10, t_end * 1.0001)
        out.append(f"      (Condition(Time(Range=({a:g} {b:g}))) Value={frac*a:g})")
        a *= 10
    return "    TurningPoints(\n" + "\n".join(out) + "\n    )"

def hdr(title, lines):
    return "*" + "=" * 70 + "\n*  " + title + "\n" + "".join(f"*  {l}\n" for l in lines) + "*" + "=" * 70 + "\n\n"

def link(dst_dir, target, name=None):
    p = os.path.join(dst_dir, name or os.path.basename(target))
    if os.path.lexists(p): os.remove(p)
    os.symlink(os.path.relpath(target, dst_dir), p)

def read_deck(state, load_prefix, nit):
    return (hdr(f"Id-Vg READ of state '{state}' (Vd=0.05 V, Vg -4 -> +8 V, traps frozen)",
                [f"run in this folder:  sdevice idvg_{state}_des.cmd"])
        + file_block(f"idvg_{state}").replace(f'Current   = "idvg_{state}_des.plt"',
                                              'Current   = "idvg_des.plt"')
        + "\n" + electrodes() + "\n" + common(nit, read=True, robust=True)
        + f"""*---------------------------------------------------------------- Solve
Solve {{
  Load( FilePrefix="{load_prefix}" )
  Set( Traps( Frozen ) )
  Coupled ( Iterations=100 LineSearchDamping=1e-4 ) {{ Poisson }}
  Coupled ( Iterations=200 LineSearchDamping=1e-4 ) {{ Poisson Electron Hole }}
  NewCurrentPrefix="prep_{state}_"
  Quasistationary( InitialStep=0.02 MaxStep=0.25 MinStep=1e-9
    Goal {{ Name="gate" Voltage=-4 }} ){{ Coupled {{ Poisson Electron Hole }} }}
  Quasistationary( InitialStep=0.1 MaxStep=0.5 MinStep=1e-9
    Goal {{ Name="drain" Voltage=0.05 }} ){{ Coupled {{ Poisson Electron Hole }} }}
  NewCurrentPrefix="idvg_{state}_"
  Quasistationary( InitialStep=0.004 MaxStep=0.004 MinStep=1e-9
    Goal {{ Name="gate" Voltage=8 }} ){{ Coupled {{ Poisson Electron Hole }} }}
  Set( Traps( -Frozen ) )
}}
""")

def freshdit_deck(nit):
    """Fresh device, DC Id-Vg with interface traps ACTIVE (paper Fig. 13 degradation).
    Uses sonos_fresh_msh.tdr (nitride = Si3N4 insulator, eps 7.5): a fresh cell stores
    no charge, so this is electrically identical but avoids freezing the traps."""
    c = common(nit, read=True)
    c = re.sub(r'Physics \{\n  eBarrierTunneling "NL_TO".*?\n\}\n', '', c, flags=re.S)
    c = re.sub(r'Physics \(Material="NitrideAsSemiconductor"\) \{.*?\n\}\n', '', c, flags=re.S)
    c = re.sub(r'CurrentPlot \{.*?\n\}\n', '', c, flags=re.S)
    assert 'BarrierTunneling "NL' not in c and 'Material="NitrideAsSemiconductor") {' not in c
    fb = file_block("idvg_freshdit").replace('Grid      = "sonos_msh.tdr"', 'Grid      = "sonos_fresh_msh.tdr"')
    fb = fb.replace('Current   = "idvg_freshdit_des.plt"', 'Current   = "idvg_des.plt"')
    return (hdr(f"FRESH device, DC Id-Vg with ACTIVE interface traps (Nit={nit:.2e} cm^-2)",
                ["run in this folder:  sdevice idvg_freshdit_des.cmd",
                 "out: idvg_freshdit_idvg_des.plt  (Vth and SS degradation vs P/E cycles)"])
        + fb + "\n" + electrodes() + "\n" + c
        + """*---------------------------------------------------------------- Solve
Solve {
  Coupled (Iterations=100) { Poisson }
  Coupled (Iterations=100) { Poisson Electron Hole }
  NewCurrentPrefix="prep_freshdit_"
  Quasistationary( InitialStep=0.02 MaxStep=0.25 MinStep=1e-9
    Goal { Name="gate" Voltage=-4 } ){ Coupled { Poisson Electron Hole } }
  Quasistationary( InitialStep=0.1 MaxStep=0.5 MinStep=1e-9
    Goal { Name="drain" Voltage=0.05 } ){ Coupled { Poisson Electron Hole } }
  NewCurrentPrefix="idvg_freshdit_"
  Quasistationary( InitialStep=0.004 MaxStep=0.004 MinStep=1e-9
    Goal { Name="gate" Voltage=8 } ){ Coupled { Poisson Electron Hole } }
}
""")

def write_fresh_scm():
    t = open(os.path.join(ROOT, "device.scm")).read()
    t2 = re.sub(r'"NitrideAsSemiconductor"(\s+)"Nitride"', r'"Si3N4"\1"Nitride"', t)
    t2 = t2.replace('(sde:build-mesh "sonos")', '(sde:build-mesh "sonos_fresh")')
    assert t2 != t and "sonos_fresh" in t2
    open(os.path.join(ROOT, "device_fresh.scm"), "w").write(
        "; AUTO-GENERATED by make_study.py from device.scm: nitride as Si3N4 insulator\n"
        "; (fresh-device interface-trap read).  run:  sde -e -l device_fresh.scm\n" + t2)

def add_freshdit(jobs_list):
    write_fresh_scm()
    for g, (nit, _) in GROUPS.items():
        gd = os.path.join(STUDY, g)
        link(gd, os.path.join(ROOT, "sonos_fresh_msh.tdr"))      # dangling until sde runs
        open(os.path.join(gd, "idvg_freshdit_des.cmd"), "w").write(freshdit_deck(nit))
        jobs_list.append((gd, "idvg_freshdit_des.cmd"))

import sys
if "--freshdit-only" in sys.argv:          # add to an existing study without touching results
    lst = []
    add_freshdit(lst)
    with open(os.path.join(STUDY, "jobs_freshdit.txt"), "w") as f:
        for d, c in lst:
            f.write(f"{os.path.relpath(d, STUDY)} {c}\n")
    print("fresh-device interface-trap decks added:", len(lst))
    sys.exit(0)

# ------------------------------------------------------------------ build
if os.path.isdir(STUDY):
    import sys
    if "--clean" not in sys.argv:
        sys.exit("study/ already exists (results would be lost). "
                 "Use  python3 make_study.py --clean  to regenerate it.")
    shutil.rmtree(STUDY)
jobs = {1: [], 2: [], 3: [], 4: []}           # stage -> list of (dir, deck)

for g, (nit, vges) in GROUPS.items():
    gd = os.path.join(STUDY, g); os.makedirs(gd)
    for f in ("sonos_msh.tdr", "sdevice.par", "datexcodes.txt"):
        link(gd, os.path.join(ROOT, f))
    # --- program (same pulse as program_des.cmd)
    prog = src.replace("program_des.", "program_des.")  # keep File names
    prog = re.sub(r"\*-+ Physics.*?(?=\*-+ Solve)", lambda m: common(nit), prog, flags=re.S)
    prog = prog.replace("STEP 1: PROGRAM", f"STEP 1: PROGRAM  [group {g}, Nit={nit:.2e} cm^-2]")
    open(os.path.join(gd, "program_des.cmd"), "w").write(prog)
    jobs[1].append((gd, "program_des.cmd"))
    for s, pre in (("fresh", "fresh"), ("programmed", "programmed")):
        open(os.path.join(gd, f"idvg_{s}_des.cmd"), "w").write(read_deck(s, pre, nit))
        jobs[3].append((gd, f"idvg_{s}_des.cmd"))

    # --- erase cases
    for v in vges:
        vd = os.path.join(gd, f"vge{v}"); os.makedirs(vd)
        for f in ("sonos_msh.tdr", "sdevice.par", "datexcodes.txt"):
            link(vd, os.path.join(ROOT, f))
        for f in ("programmed_des.sav", "programmed_circuit_des.sav"):
            link(vd, os.path.join(gd, f))          # dangling until program runs
        saves = "\n".join(f'     Save( FilePrefix="{n}" Time=({t:g}) )' for n, t in ERASE_T)
        er = (hdr(f"ERASE  Vge = {v} V up to 1 s   [group {g}, Nit={nit:.2e} cm^-2]",
                  ["in : ../programmed_des.sav (linked)",
                   "out: erase_des.plt, e_<t>_des.sav, erased_des.sav"])
              + file_block("erase") + "\n"
              + electrodes(f"0 at 0, {v} at 1e-7, {v} at 1, 0 at 1.00001")
              + "\n" + common(nit, robust=True)
              + f"""*---------------------------------------------------------------- Solve
Solve {{
  Load( FilePrefix="programmed" )
  Transient (
    InitialTime=0 FinalTime=1.001
    InitialStep=1e-10 MaxStep=0.2 MinStep=1e-15
{decade_steps(1.0)}
  ){{ Coupled {{ Poisson Electron Hole }}
{saves}
  }}
  Save( FilePrefix="erased" )
  Plot( FilePrefix="erased" )
}}
""")
        open(os.path.join(vd, "erase_des.cmd"), "w").write(er)
        jobs[2].append((vd, "erase_des.cmd"))
        for n, _ in ERASE_T:
            open(os.path.join(vd, f"idvg_{n}_des.cmd"), "w").write(read_deck(n, n, nit))
            jobs[3].append((vd, f"idvg_{n}_des.cmd"))

# --- retention (group nit0): programmed state and state erased 10 ms at -10 V
for which, srcdir, pre, stage in (("prog", "nit0", "programmed", 2),
                                  ("ers",  "nit0/vge-10", "e_10ms", 3)):
    rd = os.path.join(STUDY, "nit0", f"retention_{which}"); os.makedirs(rd)
    for f in ("sonos_msh.tdr", "sdevice.par", "datexcodes.txt"):
        link(rd, os.path.join(ROOT, f))
    for suf in ("_des.sav", "_circuit_des.sav"):
        link(rd, os.path.join(STUDY, srcdir, pre + suf), "start" + suf)
    saves = "\n".join(f'     Save( FilePrefix="{n}" Time=({t:g}) )' for n, t in RET_T)
    rt = (hdr(f"RETENTION of the {'programmed' if which=='prog' else 'erased (10 ms @ -10 V)'} state, Vg = 0, 10 years",
              ["in : start_des.sav (linked)", "out: retention_des.plt, r_<t>_des.sav"])
          + file_block("retention") + "\n"
          + electrodes("-10 at 0, 0 at 1e-7" if which == "ers" else None)
          + "\n" + common(0.0, robust=True)
          + f"""*---------------------------------------------------------------- Solve
Solve {{
  Load( FilePrefix="start" )
  * erased state was saved at Vg = -10 V: the gate waveform returns it to 0 V
  * in 100 ns (same edge as the erase pulse), then Vg = 0 for 10 years
  Transient (
    InitialTime=0 FinalTime=3.1536e8
    InitialStep=1e-9 MaxStep=1e7 MinStep=1e-12
  ){{ Coupled {{ Poisson Electron Hole }}
{saves}
  }}
}}
""")
    open(os.path.join(rd, "retention_des.cmd"), "w").write(rt)
    jobs[stage].append((rd, "retention_des.cmd"))
    open(os.path.join(rd, "idvg_start_des.cmd"), "w").write(read_deck("start", "start", 0.0))
    jobs[4].append((rd, "idvg_start_des.cmd"))
    for n, _ in RET_T:
        open(os.path.join(rd, f"idvg_{n}_des.cmd"), "w").write(read_deck(n, n, 0.0))
        jobs[4].append((rd, f"idvg_{n}_des.cmd"))

add_freshdit(jobs[1])

for st, lst in jobs.items():
    with open(os.path.join(STUDY, f"jobs_stage{st}.txt"), "w") as f:
        for d, c in lst:
            f.write(f"{os.path.relpath(d, STUDY)} {c}\n")
print("study generated:", {k: len(v) for k, v in jobs.items()}, "jobs per stage")
