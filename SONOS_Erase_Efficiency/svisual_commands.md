# Viewing the results in Sentaurus Visual

Run these inside the simulation folder after the flow has finished. The output files are not stored in
this repo; see [README.md](README.md#how-to-reproduce) to generate them.

## Base study (before comparing with the paper)

```bash
svisual sonos_msh.tdr &                                              # device + mesh
svisual fresh_des.tdr &                                              # fresh device
svisual program_des.plt programmed_des.tdr &                         # program pulse
svisual erase_des.plt ers_10us_des.tdr ers_1ms_des.tdr erased_des.tdr &   # erase pulse
svisual idvg_*_idvg_des.plt &                                        # Id-Vg reads of every state
svisual plot_erase.tcl &                                             # extraction + plots
cat erase_summary.txt
```

## Extended study (comparison with the paper)

```bash
# device without physics applied (insulating nitride)
svisual sonos_fresh_msh.tdr &

# erase-voltage sweep: Vge = -8 V ... -11 V, up to 1 s
svisual study/nit0/vge-*/erase_des.plt &

# Id-Vg at Vge = -10 V, from 1 us to 1 s of erase
svisual study/nit0/vge-10/idvg_e_*_idvg_des.plt &

# degradation: fresh vs. cycled devices
svisual study/nit*/idvg_freshdit_idvg_des.plt &
svisual study/nit*/vge-10/erase_des.plt study/nit*/vge-10/idvg_e_10ms_idvg_des.plt &

# retention
svisual study/nit0/retention_*/retention_des.plt &
svisual study/nit0/retention_prog/idvg_*_idvg_des.plt &

# all plots + summary
svisual plot_study.tcl &
cat study/study_summary.txt
```
