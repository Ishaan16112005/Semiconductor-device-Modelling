*======================================================================
*  SONOS FET -- STEP 1: PROGRAM (prepare the charged state to be erased)
*  run:  sdevice program_des.cmd
*  in :  sonos_msh.tdr, sdevice.par, datexcodes.txt
*  out:  fresh.sav, programmed.sav  (+ _des.tdr snapshots)
*        program_des.plt  (trapped charge / currents vs time)
*
*  Program pulse  : Vg = +VGP = +10 V for TP = 1 ms (100 ns edges),
*                   then 1 ms relaxation at Vg = 0.
*  To change it, edit the gate "Voltage=(...)" list and FinalTime.
*
*  NOTE: Physics / Traps / Math NonLocal must stay IDENTICAL in
*        program_des.cmd, erase_des.cmd and idvg_des.cmd, otherwise trap
*        occupations are not restored correctly by Load().
*======================================================================

File {
  Grid      = "sonos_msh.tdr"
  Parameter = "sdevice.par"
  Current   = "program_des.plt"
  Plot      = "program_des.tdr"
  Output    = "program_des.log"
}

Electrode {
  { Name="gate"      Voltage=0
    Voltage=( 0 at 0, 10 at 1e-7, 10 at 1e-3, 0 at 1.0001e-3 ) }
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
  Iterations=25
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
  * fresh device: all nitride traps empty
  Set( TrapFilling=Empty )
  Coupled (Iterations=100) { Poisson }
  Coupled (Iterations=100) { Poisson Electron }
  Coupled (Iterations=100 Digits=8) { Poisson Electron Hole }
  Save( FilePrefix="fresh" )
  Plot( FilePrefix="fresh" )
  UnSet( TrapFilling )

  * program pulse + relaxation
  Transient (
    InitialTime=0 FinalTime=2e-3
    InitialStep=1e-9 MaxStep=5e-5 MinStep=1e-15
  ){ Coupled { Poisson Electron Hole } }

  Save( FilePrefix="programmed" )
  Plot( FilePrefix="programmed" )
}
