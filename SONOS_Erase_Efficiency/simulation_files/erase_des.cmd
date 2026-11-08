*======================================================================
*  SONOS FET -- STEP 2: ERASE TRANSIENT (erase efficiency)
*  run:  sdevice erase_des.cmd          (after program_des.cmd)
*  in :  programmed.sav
*  out:  erase_des.plt   -> erase current (gate/substrate TotalCurrent),
*                           trapped / residual nitride charge vs erase time
*        ers_<t>.sav     -> device state at each erase time, read by
*                           idvg_des.cmd for Id-Vg and dVth(t)
*        erased.sav      -> final state after the gate returns to 0 V
*
*  Erase pulse : Vg = VGE = -10 V, edges 100 ns, held 10 ms, t=0 is
*                the start of erase. Save points (erase time t_e):
*                1u 3u 10u 30u 100u 300u 1m 3m 10m  [s]
*  The line tagged "#VGE" is edited by run_sonos.sh for Vge sweeps.
*======================================================================

File {
  Grid      = "sonos_msh.tdr"
  Parameter = "sdevice.par"
  Current   = "erase_des.plt"
  Plot      = "erase_des.tdr"
  Output    = "erase_des.log"
}

Electrode {
  { Name="gate"      Voltage=0
    Voltage=( 0 at 0, -10 at 1e-7, -10 at 1e-2, 0 at 1.00001e-2 ) }   #VGE
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
  Load( FilePrefix="programmed" )

  Transient (
    InitialTime=0 FinalTime=1.1e-2
    InitialStep=1e-10 MaxStep=2e-4 MinStep=1e-15
  ){ Coupled { Poisson Electron Hole }
     Save( FilePrefix="ers_1us"   Time=(1e-6) )
     Save( FilePrefix="ers_3us"   Time=(3e-6) )
     Save( FilePrefix="ers_10us"  Time=(1e-5) )
     Save( FilePrefix="ers_30us"  Time=(3e-5) )
     Save( FilePrefix="ers_100us" Time=(1e-4) )
     Save( FilePrefix="ers_300us" Time=(3e-4) )
     Save( FilePrefix="ers_1ms"   Time=(1e-3) )
     Save( FilePrefix="ers_3ms"   Time=(3e-3) )
     Save( FilePrefix="ers_10ms"  Time=(1e-2) )
     Plot( FilePrefix="ers_10us"  Time=(1e-5) )
     Plot( FilePrefix="ers_1ms"   Time=(1e-3) )
     Plot( FilePrefix="ers_10ms"  Time=(1e-2) )
  }

  Save( FilePrefix="erased" )
  Plot( FilePrefix="erased" )
}
