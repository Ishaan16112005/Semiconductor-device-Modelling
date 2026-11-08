*======================================================================
*  SONOS FET -- Id-Vg READ of saved state "ers_10ms"  (one of 12 parallel jobs)
*  run from the project folder:  sdevice reads/idvg_ers_10ms_des.cmd
*  out:  idvg_ers_10ms_idvg_des.plt   (Vd = 0.05 V, Vg -4 -> +8 V, traps frozen)
*  Same physics as idvg_des.cmd (which reads all states serially).
*======================================================================

File {
  Grid      = "sonos_msh.tdr"
  Parameter = "sdevice.par"
  Current   = "idvg_des.plt"
  Plot      = "idvg_ers_10ms_des.tdr"
  Output    = "idvg_ers_10ms_des.log"
}

Electrode {
  { Name="gate"      Voltage=0 }
  { Name="source"    Voltage=0 }
  { Name="drain"     Voltage=0 }
  { Name="substrate" Voltage=0 }
}

*---------------------------------------------------------------- Physics
Physics {
  eBarrierTunneling "NL_TO"
  hBarrierTunneling "NL_TO"
  eBarrierTunneling "NL_BO"
  hBarrierTunneling "NL_BO"
}

Physics (Material="Silicon") {
  Recombination( SRH(DopingDependence) )
  Mobility( DopingDependence HighFieldSaturation Enormal )
}

Physics (Material="NitrideAsSemiconductor") {
  Traps(
    ( Donor Level EnergyMid=2.5 FromConductionBand
      Conc=1e19
      eXSection=1e-13 hXSection=1e-13
      eBarrierTunneling( NonLocal="NL_TO" NonLocal="NL_BO" )
      hBarrierTunneling( NonLocal="NL_TO" NonLocal="NL_BO" )
      PooleFrenkel
      TrapVolume=1e-15 )
    ( Acceptor Level EnergyMid=1.0 FromConductionBand
      Conc=1e19
      eXSection=1e-13 hXSection=1e-13
      eBarrierTunneling( NonLocal="NL_TO" NonLocal="NL_BO" )
      hBarrierTunneling( NonLocal="NL_TO" NonLocal="NL_BO" )
      PooleFrenkel
      TrapVolume=1e-15 )
  )
}

*---------------------------------------------------------------- Output
CurrentPlot {
  eTrappedCharge( Average(Material="NitrideAsSemiconductor") )
  hTrappedCharge( Average(Material="NitrideAsSemiconductor") )
  SpaceCharge(    Average(Material="NitrideAsSemiconductor") )
  eDensity(       Average(Material="NitrideAsSemiconductor") )
  hDensity(       Average(Material="NitrideAsSemiconductor") )
}

Plot {
  eDensity hDensity eCurrent/Vector hCurrent/Vector
  ElectricField/Vector Potential SpaceCharge
  ConductionBandEnergy ValenceBandEnergy eQuasiFermi hQuasiFermi
  Doping DonorConcentration AcceptorConcentration
  eTrappedCharge hTrappedCharge
  eBarrierTunneling hBarrierTunneling
  NonLocal
}

*---------------------------------------------------------------- Math
Math {
  NonLocal "NL_TO" (            * substrate -> tunnel oxide -> nitride
    RegionInterface="TunnelOxide/Substrate"
    Length=6.8e-7  Digits=4  EnergyResolution=1e-4 )
  NonLocal "NL_BO" (            * poly gate -> blocking oxide -> nitride
    RegionInterface="BlockOxide/GatePoly"
    Length=8e-7    Digits=4  EnergyResolution=1e-4 )

  Extrapolate
  Derivatives
  RelErrControl
  Digits=5
  Iterations=50
  NotDamped=50
  Transient=BE

  * multicore: 4 threads = 1 parallel license (override: --threads N)
  Method=ParDiSo
  NumberOfThreads=4
  ParallelLicense(Serial)
  Wallclock
}

*---------------------------------------------------------------- Solve
Solve {
  *--- ers_10ms
  Load( FilePrefix="ers_10ms" )
  Set( Traps( Frozen ) )
  * relax free carriers at the loaded bias before the sweep
  Coupled ( Iterations=100 LineSearchDamping=1e-4 ) { Poisson }
  Coupled ( Iterations=200 LineSearchDamping=1e-4 ) { Poisson Electron Hole }
  NewCurrentPrefix="prep_ers_10ms_"
  Quasistationary( InitialStep=0.02 MaxStep=0.25 MinStep=1e-9
    Goal { Name="gate" Voltage=-4 } ){ Coupled { Poisson Electron Hole } }
  Quasistationary( InitialStep=0.1 MaxStep=0.5 MinStep=1e-9
    Goal { Name="drain" Voltage=0.05 } ){ Coupled { Poisson Electron Hole } }
  NewCurrentPrefix="idvg_ers_10ms_"
  Quasistationary( InitialStep=0.004 MaxStep=0.004 MinStep=1e-9
    Goal { Name="gate" Voltage=8 } ){ Coupled { Poisson Electron Hole } }
  Set( Traps( -Frozen ) )
}
