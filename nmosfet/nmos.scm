(sdegeo:create-rectangle (position 0 0 0) (position 1.1 0.5 0) "Silicon" "substrate")


(sdegeo:create-rectangle (position 0.05 0.5 0) (position 1.05 0.504 0) "SiO2" "gate_oxide")


(sdegeo:create-rectangle (position 0.05 0.504 0) (position 1.05 0.506 0) "Molybdenum" "gate_metal")


(sdedr:define-refinement-size "RefinementDefinition_Gate" 0.01 0.005 0.1 0.002 0.002 0.1)
(sdedr:define-refinement-placement "RefinementPlacement_Gate" "RefinementDefinition_Gate" (list "region" "gate_metal"))


(sdedr:define-refinement-size "RefinementDefinition_Oxide" 0.01 0.001 0.1 0.002 0.0005 0.1)
(sdedr:define-refinement-placement "RefinementPlacement_Oxide" "RefinementDefinition_Oxide" (list "region" "gate_oxide"))


(sdedr:define-refinement-size "RefinementDefinition_Sub" 0.1 0.1 0.1 0.05 0.05 0.1)
(sdedr:define-refinement-placement "RefinementPlacement_Sub" "RefinementDefinition_Sub" (list "region" "substrate"))


(sdedr:define-refinement-window "Channel_SD_Window" "Rectangle" (position 0.05 0.4 0) (position 1.05 0.5 0))
(sdedr:define-refinement-size "RefinementDefinition_Channel" 0.01 0.005 0.1 0.002 0.001 0.1)
(sdedr:define-refinement-placement "RefinementPlacement_Channel" "RefinementDefinition_Channel" "Channel_SD_Window")


(sdedr:define-constant-profile "Substrate_Profile" "BoronActiveConcentration" 1e+16)
(sdedr:define-constant-profile-region "Substrate_Placement" "Substrate_Profile" "substrate")


(sdedr:define-refinement-window "Source_Window" "Rectangle" (position 0 0.4 0) (position 0.05 0.5 0))
(sdedr:define-refinement-window "Drain_Window" "Rectangle" (position 1.05 0.4 0) (position 1.1 0.5 0))


(sdedr:define-constant-profile "N_Plus_Profile" "PhosphorusActiveConcentration" 1e+19)
(sdedr:define-constant-profile-placement "Source_Placement" "N_Plus_Profile" "Source_Window")

(sdedr:define-constant-profile "N_Plus_Profile_18" "PhosphorusActiveConcentration" 1e+18)
(sdedr:define-constant-profile-placement "Drain_Placement" "N_Plus_Profile_18" "Drain_Window")


(sdegeo:define-contact-set "gate" 4 (color:rgb 1 0 0) "##")
(sdegeo:set-current-contact-set "gate")
(sdegeo:set-contact (list (car (find-edge-id (position 0.55 0.506 0)))) "gate") 


(sdegeo:define-contact-set "source" 4 (color:rgb 0 1 0) "##")
(sdegeo:set-current-contact-set "source")
(sdegeo:set-contact (list (car (find-edge-id (position 0.025 0.5 0)))) "source")


(sdegeo:define-contact-set "drain" 4 (color:rgb 0 1 0) "##")
(sdegeo:set-current-contact-set "drain")
(sdegeo:set-contact (list (car (find-edge-id (position 1.075 0.5 0)))) "drain")


(sdegeo:define-contact-set "body" 4 (color:rgb 0 0 1) "##")
(sdegeo:set-current-contact-set "body")
(sdegeo:set-contact (list (car (find-edge-id (position 0.55 0 0)))) "body")


(sdeio:save-tdr-bnd (get-body-list) "mos_structure_bnd.tdr")
(sde:build-mesh "snmesh" "" "mos_structure")
