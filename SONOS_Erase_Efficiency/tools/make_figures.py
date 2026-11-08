"""Figures for the slides/report, drawn from the simulation output files."""
import re, os, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch
# SIM: folder where the simulation flow was run (holds *_des.plt, erase_vth.csv, study/)
HERE = os.path.dirname(os.path.abspath(__file__))
SIM = os.environ.get("SONOS_SIM", os.path.join(HERE, "..", "simulation_files"))
OUT = os.path.join(HERE, "..", "figures")
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11})

def read_plt(path):
    txt = open(path).read()
    names = re.findall(r'"([^"]+)"', txt.split("functions")[0])
    vals = np.array(txt.split("Data {")[1].split("}")[0].split(), float)
    return dict(zip(names, vals.reshape(-1, len(names)).T))

def vth(vg, idr, icrit=1e-6):
    i = np.abs(idr); k = np.where(i >= icrit)[0][0]
    return np.interp(np.log10(icrit), np.log10(i[k-1:k+1]), vg[k-1:k+1])

# ---------- 1. device schematic ----------
fig, ax = plt.subplots(figsize=(8, 5.2))
nm = 1e-3
Lg, Lext, Tsub = 100, 80, 200   # S/D drawn wider than the real 50 nm for readability
L = [("Poly-Si gate  (n$^+$ 10$^{20}$ cm$^{-3}$)  50 nm", 50, "#c9a227"),
     ("Blocking oxide  SiO$_2$  6 nm", 6, "#9ecae1"),
     ("Si$_3$N$_4$ charge-trap layer  5 nm", 5, "#e6550d"),
     ("Tunnel oxide  SiO$_2$  2 nm", 2, "#c6dbef")]
# exaggerate thin layers for visibility
draw_h = {50: 34, 6: 12, 5: 12, 2: 7}
ax.add_patch(Rectangle((-Lext, -120), Lg + 2*Lext, 120, fc="#d9d9d9", ec="k"))
ax.text(Lg/2, -90, "p-Si substrate  (B 10$^{17}$ cm$^{-3}$)", ha="center", fontsize=11)
for x0 in (-Lext, Lg):
    ax.add_patch(FancyBboxPatch((x0, -28), Lext, 28, boxstyle="round,pad=0,rounding_size=8", fc="#74c476", ec="k"))
ax.text(-Lext/2, -15, "n$^+$ source\n(As 10$^{20}$)", ha="center", va="center", fontsize=9.5)
ax.text(Lg+Lext/2, -15, "n$^+$ drain\n(As 10$^{20}$)", ha="center", va="center", fontsize=9.5)
y = 0
for (lab, t, c) in reversed(L):
    h = draw_h[t]; ax.add_patch(Rectangle((0, y), Lg, h, fc=c, ec="k"))
    ax.annotate(lab, (Lg, y + h/2), (Lg + Lext + 12, {50: 75, 6: 48, 5: 28, 2: 4}[t]),
                va="center", fontsize=10, arrowprops=dict(arrowstyle="-", lw=0.8))
    y += h
ax.plot([Lg/2, Lg/2], [y, y + 14], "k", lw=2); ax.text(Lg/2, y + 17, "Gate (G)", ha="center", fontsize=10.5, weight="bold")
for (x, lab) in [(-Lext + 22, "S"), (Lg + Lext - 22, "D")]:
    ax.plot([x, x], [0, 9], "k", lw=2); ax.text(x, 11, lab, ha="center", fontsize=11, weight="bold")
ax.plot([Lg/2, Lg/2], [-120, -134], "k", lw=2); ax.text(Lg/2, -146, "Substrate (B)", ha="center", fontsize=10.5, weight="bold")
ax.annotate("", (0, -38), (Lg, -38), arrowprops=dict(arrowstyle="<->"))
ax.text(Lg/2, -46, "L$_g$ = 100 nm", ha="center", fontsize=10)
ax.text(-Lext + 4, -40, "X$_j$ = 20 nm", fontsize=9)
ax.set_xlim(-Lext - 10, Lg + Lext + 230); ax.set_ylim(-155, y + 32); ax.axis("off")
ax.set_title("2-D SONOS n-channel FET simulated in Sentaurus (not to scale)", fontsize=12)
fig.tight_layout(); fig.savefig(f"{OUT}/sim_device_schematic.png", dpi=200); plt.close(fig)

# ---------- 2. simulated Id-Vg: fresh / programmed / erased ----------
states = [("idvg_erased", "Erased (-10 V, 10 ms)", "#2166ac"),
          ("idvg_fresh", "Fresh (virgin)", "k"),
          ("idvg_programmed", "Programmed (+10 V, 1 ms)", "#b2182b")]
fig, ax = plt.subplots(figsize=(6.4, 4.8)); summary = {}
for f, lab, c in states:
    d = read_plt(f"{SIM}/{f}_idvg_des.plt")
    vg, idr = d["gate OuterVoltage"], np.abs(d["drain TotalCurrent"])
    m = (d["drain OuterVoltage"] > 0.049) & (idr > 1e-15)
    v = vth(vg[m], idr[m]); summary[lab] = v
    ax.semilogy(vg[m], idr[m], color=c, lw=2.2, label=f"{lab}:  V$_{{th}}$ = {v:+.2f} V")
ax.axhline(1e-6, color="gray", ls=":", lw=1); ax.text(-3.9, 1.6e-6, "V$_{th}$ criterion 1 µA/µm", fontsize=8.5, color="gray")
ax.set_xlim(-4, 5); ax.set_ylim(1e-15, 1e-3)
ax.set_xlabel("Gate voltage V$_{GS}$ (V)"); ax.set_ylabel("Drain current I$_{DS}$ (A/µm)")
ax.set_title("Simulated subthreshold Id–Vg, V$_{DS}$ = 50 mV", fontsize=12)
ax.grid(True, which="major", alpha=0.35); ax.legend(fontsize=9, loc="lower right")
fig.tight_layout(); fig.savefig(f"{OUT}/sim_IdVg_fresh_prog_erased.png", dpi=200); plt.close(fig)
print("Vth:", summary)

# ---------- 3. study plots redrawn with readable fonts ----------
ST = f"{SIM}/study"
def csv(path):
    a = np.genfromtxt(path, delimiter=",", names=True); return a

# A: Vth vs erase time for 4 erase voltages
fig, ax = plt.subplots(figsize=(6.4, 4.8))
ref = csv(f"{ST}/A_ref.csv")
for v, c in [(-8, "#1b9e77"), (-9, "#7570b3"), (-10, "#d95f02"), (-11, "#e7298a")]:
    a = csv(f"{ST}/A_vge{v}.csv"); ax.semilogx(a["t_erase_s"], a["Vth_V"], "o-", color=c, lw=2, ms=5, label=f"V$_{{GE}}$ = {v} V")
ax.axhline(ref["prog"][0], color="#b2182b", ls="--", lw=1.5, label="programmed")
ax.axhline(ref["fresh"][0], color="k", ls=":", lw=1.5, label="fresh")
ax.set_xlabel("Erase pulse width (s)"); ax.set_ylabel("Threshold voltage V$_{th}$ (V)")
ax.set_title("Simulated V$_{th}$ vs erase time (cf. paper Fig. 6)", fontsize=12); ax.grid(True, which="major", alpha=0.35)
ax.legend(fontsize=9, loc="lower left"); ax.set_xlim(1e-6, 1)
fig.tight_layout(); fig.savefig(f"{OUT}/sim_A_Vth_vs_erase_time.png", dpi=200); plt.close(fig)

# B: fresh-device Id-Vg with interface traps
fig, ax = plt.subplots(figsize=(6.4, 4.8))
deg = csv(f"{ST}/B_dc_degradation.csv")
for tag, lab, c in [("nit0", "ideal, N$_{it}$ = 0", "k"), ("nit1p1e11", "1 cycle, 1.1×10$^{11}$ cm$^{-2}$", "#1b9e77"),
                    ("nit2p3e11", "10$^5$ cycles, 2.3×10$^{11}$ cm$^{-2}$", "#d95f02"), ("nit5p0e11", "10$^6$ cycles, 5.0×10$^{11}$ cm$^{-2}$", "#b2182b")]:
    a = csv(f"{ST}/B_{tag}_fresh_dc.csv"); m = a["Id"] > 1e-15
    ax.semilogy(a["Vg"][m], a["Id"][m], color=c, lw=2, label=lab)
ax.set_xlim(-1.5, 2); ax.set_ylim(1e-15, 1e-3)
ax.set_xlabel("Gate voltage V$_{GS}$ (V)"); ax.set_ylabel("Drain current I$_{DS}$ (A/µm)")
ax.set_title("Simulated degradation: interface traps from P/E cycling", fontsize=12)
ax.grid(True, which="major", alpha=0.35); ax.legend(fontsize=9, loc="lower right")
ax.text(-1.4, 3e-5, "SS: 133 → 147 mV/dec\nV$_{th}$: +0.09 V after 10$^6$ cycles", fontsize=9.5, va="top")
fig.tight_layout(); fig.savefig(f"{OUT}/sim_B_degradation_IdVg.png", dpi=200); plt.close(fig)

# C: retention
fig, ax = plt.subplots(figsize=(6.4, 4.8))
for f, lab, c in [("C_ret_prog", "programmed", "#b2182b"), ("C_ret_ers", "erased (−10 V, 10 ms)", "#2166ac")]:
    a = csv(f"{ST}/{f}.csv"); ax.semilogx(a["t_s"], a["Vth_V"], "o-", color=c, lw=2, ms=5, label=lab)
ax.axhline(ref["fresh"][0], color="k", ls=":", lw=1.5, label="fresh")
ax.axvline(3.15e8, color="gray", ls="--", lw=1); ax.text(2.2e8, 0.6, "10 years", rotation=90, fontsize=9, color="gray", ha="right")
ax.set_xlabel("Retention time at V$_G$ = 0 (s)"); ax.set_ylabel("Threshold voltage V$_{th}$ (V)")
ax.set_title("Simulated retention (cf. paper Fig. 10)", fontsize=12); ax.grid(True, which="major", alpha=0.35)
ax.legend(fontsize=9, loc="center left"); ax.set_ylim(-1.8, 1.6)
fig.tight_layout(); fig.savefig(f"{OUT}/sim_C_retention.png", dpi=200); plt.close(fig)

# base-flow erase plots: dVth vs time, erase current, trapped charge from erase_transient.csv / erase_vth.csv
ev = csv(f"{SIM}/erase_vth.csv"); tr = csv(f"{SIM}/erase_transient.csv")
fig, ax = plt.subplots(figsize=(6.4, 4.8))
ax.semilogx(ev["t_erase_s"], ev["dVth_cc_V"], "o-", color="#d95f02", lw=2.2, ms=6)
ax.axhline(-2, color="gray", ls=":", lw=1); ax.text(1.2e-6, -1.93, "erase-time criterion ΔV$_{th}$ = −2 V", fontsize=9, color="gray")
ax.axvline(1.096e-3, color="gray", ls="--", lw=1); ax.text(1.25e-3, -0.4, "t$_{erase}$ = 1.1 ms", fontsize=9.5)
ax.set_xlabel("Erase time at V$_{GE}$ = −10 V (s)"); ax.set_ylabel("ΔV$_{th}$ = V$_{th}$(t) − V$_{th}$(prog)  (V)")
ax.set_title("Erase ΔV$_{th}$ vs time", fontsize=12); ax.grid(True, which="major", alpha=0.35)
fig.tight_layout(); fig.savefig(f"{OUT}/sim_base_dVth_vs_time.png", dpi=200); plt.close(fig)

fig, ax = plt.subplots(figsize=(6.4, 4.8)); m = tr["time_s"] <= 1e-2
ax.loglog(tr["time_s"][m], tr["abs_Igate_A_um"][m], color="#b2182b", lw=2, label="|I$_{gate}$|")
ax.loglog(tr["time_s"][m], tr["abs_Isub_A_um"][m], color="#2166ac", lw=1.6, ls="--", label="|I$_{substrate}$|")
ax.axvspan(1e-10, 1e-7, color="#fee0d2", alpha=0.6); ax.text(1.3e-10, 3e-17, "gate ramp:\ndisplacement\ncurrent", fontsize=8.5)
ax.set_xlabel("Erase time (s)"); ax.set_ylabel("Current (A/µm)"); ax.set_ylim(1e-17, 1e-7)
ax.set_title("Erase current at V$_{GE}$ = −10 V", fontsize=12); ax.grid(True, which="major", alpha=0.35); ax.legend(fontsize=9)
fig.tight_layout(); fig.savefig(f"{OUT}/sim_base_erase_current.png", dpi=200); plt.close(fig)

fig, ax = plt.subplots(figsize=(6.4, 4.8))
ax.semilogx(tr["time_s"][m], tr["eTrapped_cm2"][m]/1e12, color="#2166ac", lw=2, label="trapped electrons")
ax.semilogx(tr["time_s"][m], tr["hTrapped_cm2"][m]/1e12, color="#b2182b", lw=2, label="trapped holes")
ax.semilogx(tr["time_s"][m], tr["Qnet_cm2"][m]/1e12, "k--", lw=2, label="net (holes − electrons)")
ax.axhline(0, color="gray", lw=0.8)
ax.set_xlabel("Erase time (s)"); ax.set_ylabel("Charge in nitride (10$^{12}$ q/cm$^2$)")
ax.set_title("Nitride trapped charge during erase", fontsize=12); ax.grid(True, which="major", alpha=0.35); ax.legend(fontsize=9, loc="center left")
fig.tight_layout(); fig.savefig(f"{OUT}/sim_base_trapped_charge.png", dpi=200); plt.close(fig)
print("study + base plots done")
