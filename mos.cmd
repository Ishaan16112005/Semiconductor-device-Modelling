File {
  Grid    = "nmos_msh.tdr"
  Plot    = "nmos"
  Current = "nmos"
  Output  = "nmos"
  *Param   = "@parameter@"
} 

Electrode {
  { Name="gate"    Voltage= 0.0}
  { Name="source"     Voltage= 0.0}
  { Name="drain"   Voltage= 1.0}
  { Name="body"    Voltage= 0.0}
}


Physics {
  Mobility(
    PhuMob
    eHighFieldsaturation
    hHighFieldsaturation
    Enormal
  )
  Recombination(
    SRH( DopingDep )
  )  
}

Plot {
  *--Density and Currents, etc
  eDensity hDensity
  TotalCurrent/Vector eCurrent/Vector hCurrent/Vector
  eMobility hMobility
  eVelocity hVelocity
  eQuasiFermi hQuasiFermi
  
  *--Temperature 
  *eTemperature * Temperature hTemperature
  
  *--Fields and charges
  ElectricField/Vector Potential SpaceCharge
  
  *--Doping Profiles
  Doping DonorConcentration AcceptorConcentration
  
  *--Generation/Recombination
  SRH *Band2Band * Auger
  AvalancheGeneration eAvalancheGeneration hAvalancheGeneration
  
  *--Driving forces
  eEparallel hEparallel eENormal hENormal
  
  *--Band structure/Composition
  BandGap 
  BandGapNarrowing
  Affinity
  ConductionBand ValenceBand
  
  *--Traps
  * eTrappedCharge  hTrappedCharge
  * eGapStatesRecombination hGapStatesRecombination
}

Math {
  Extrapolate
  Avalderivatives
  RelErrControl
  Digits=5
  ErRef(electron)=1.e10
  ErRef(hole)=1.e10
  Notdamped=50
  Iterations=20
  DirectCurrent
}

Solve {
  NewCurrentPrefix="init"
  Coupled(Iterations=100){ Poisson }
  Coupled{ Poisson Electron Hole }
  

  NewCurrentPrefix=""
  Quasistationary(
    DoZero
    InitialStep=5e-2 Increment=1.5
    Minstep=1e-5 MaxStep=0.05
    Goal{ Name="gate" Voltage= 1 }
  ){ Coupled{ Poisson Electron Hole }

  }
}
