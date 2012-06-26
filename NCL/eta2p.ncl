;---------------------------------------------------------------------------------------------------------------------
;	 Define environment variable $NCL_POP_REMAP (http://www.ncl.ucar.edu/Document/Functions/Pop_remap/PopLatLon.shtml)
;  CCSM: 'export NCL_POP_REMAP=/media/data/DATA/WRF/BC/CCSM/meta/'
;  CESM: 'export NCL_POP_REMAP=/media/data/DATA/WRF/BC/CESM/meta/'
;---------------------------------------------------------------------------------------------------------------------
;  Make sure "setup.ncl" is present in the data folder
;---------------------------------------------------------------------------------------------------------------------

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/popRemap.ncl"
load "$MODEL_ROOT/WRF Tools/NCL/functions.ncl"
load "meta/setup.ncl"

;--------------------------------------------------------
begin
;--------------------------------------------------------

;-----------------------------------------------------------------------------------
;  load CCSM/CESM files
;-----------------------------------------------------------------------------------

 atm = addfile ("atmfile.nc" , "r")  
 lnd = addfile ("lndfile.nc" , "r")  
 ice = addfile ("icefile.nc" , "r")  

;---------------------------------------------------------------------------------------------------------------------
;  Coordinates
;---------------------------------------------------------------------------------------------------------------------
; desired output levels [hPa] 

 pnew = (/1000.0,975.0,950.0,925.0,900.0,850.0,800.0,750.0,700.0,650.0,600.0,550.0,500.0,450.0,400.0,350.0,300.0,250.0,200.0,150.0,100.0,70.0,50.0,30.0,20.0,10.0 /)
; pnew = (/1000.0,950.0,900.0,850.0,800.0,750.0,700.0,650.0,600.0,550.0,500.0,450.0,400.0,350.0,300.0,250.0,200.0,150.0,100.0,50.0,10.0/)

 P0mb = 0.01*atm->P0              
 hyam = atm->hyam                   
 hybm = atm->hybm

	lon = doubletofloat(atm->lon)
	lat = doubletofloat(atm->lat)
	time = atm->time
  lev = atm->lev

;---------------------------------------------------------------------------------------------------------------------
;  Boucle Day (only one here)
;---------------------------------------------------------------------------------------------------------------------

  nzyx = floattointeger(fspan(0,3, 4))
  nzyx(0) = dimsizes(time)
  nzyx(1) = dimsizes(lev)
  nzyx(2) = dimsizes(atm->lon)
  nzyx(3) = dimsizes(atm->lat)

	; load output file
  ;system ("rm "+"intermed"+".nc")
  fncfout = addfile ("intermed" +".nc" , "c") 

;---------------------------------------------------------------------------------------------------------------------

 ijouratm = 0
 ijourocn = 0

;---------------------------------------------------------------------------------------------------------------------
;  load 3D fields
;---------------------------------------------------------------------------------------------------------------------
 
 T = atm->T(ijouratm,:,:,:)
 U = atm->U(ijouratm,:,:,:)
 V = atm->V(ijouratm,:,:,:)
 Z3 = atm->Z3(ijouratm,:,:,:)
 RELHUM = atm->RELHUM(ijouratm,:,:,:)

;---------------------------------------------------------------------------------------------------------------------
;  load 2D fields
;---------------------------------------------------------------------------------------------------------------------
 
 PS = atm->PS(ijouratm,:,:)
 PSL = atm->PSL(ijouratm,:,:)
 if (isfilevar(atm, "TREFHT")) then
 	TS = atm->TREFHT(ijouratm,:,:) ;use T at 2m if present
 else
 	TS = atm->T(nzyx(1)-1,:,:) ;else use T (3D) at lower level
 end if

;---------------------------------------------------------------------------------------------------------------------
;  Interpolate 3D fields to pressure levels 'pnew'
;---------------------------------------------------------------------------------------------------------------------
 
 fncfout->T = vinth2p_ecmwf(T,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
 fncfout->U = vinth2p_ecmwf(U,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
 fncfout->V = vinth2p_ecmwf(V,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
 fncfout->Z3 = vinth2p_ecmwf(Z3,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
 fncfout->RELHUM = vinth2p_ecmwf(RELHUM,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:)) 

;---------------------------------------------------------------------------------------------------------------------
;  Surface fields
;---------------------------------------------------------------------------------------------------------------------
 
 fncfout->PS = PS
 fncfout->PSL = PSL
 fncfout->TS = TS
 fncfout->RELHUMS = RELHUM(nzyx(1)-1,:,:)
 fncfout->US = U(nzyx(1)-1,:,:)
 fncfout->VS = V(nzyx(1)-1,:,:)

;---------------------------------------------------------------------------------------------------------------------
;  Skin temperature & SST
;---------------------------------------------------------------------------------------------------------------------
  
  fncfout->SKT = atm->TS(ijouratm,:,:) ;TS in atm is radiative surface temperature
  fncfout->SST = atm->TS(ijouratm,:,:) ;TS in atm is radiative surface temperature

;---------------------------------------------------------------------------------------------------------------------
;  Soil temperature
;---------------------------------------------------------------------------------------------------------------------

  Tsoil = lnd->TSOI(ijouratm,:,:,:)

	if (isfilevar(lnd, "levsoi")) then
	  level = lnd->levsoi
	else
	  level = lnd->levgrnd
	end if

  fncfout->ST000010 = lagrangeintrpn(level(0:2),Tsoil(0:2,:,:),.05)
  fncfout->ST010040 = lagrangeintrpn(level(3:5),Tsoil(3:5,:,:),0.25)
  fncfout->ST040100 = lagrangeintrpn(level(5:7),Tsoil(5:7,:,:),0.7)
  fncfout->ST100200 = lagrangeintrpn(level(7:9),Tsoil(7:9,:,:),1.5)
  fncfout->TMN = Tsoil(9,:,:)

;---------------------------------------------------------------------------------------------------------------------
;  Soil moisture
;---------------------------------------------------------------------------------------------------------------------

  Tlandmoi = lnd->H2OSOI(ijouratm,:,:,:)

  fncfout->SM000010 = lagrangeintrpn(level(0:2),Tlandmoi(0:2,:,:),.05)
  fncfout->SM010040 = lagrangeintrpn(level(3:5),Tlandmoi(3:5,:,:),0.25)
  fncfout->SM040100 = lagrangeintrpn(level(5:7),Tlandmoi(5:7,:,:),0.7)
  fncfout->SM100200 = lagrangeintrpn(level(7:9),Tlandmoi(7:9,:,:),1.5)

;---------------------------------------------------------------------------------------------------------------------
;  Land Mask -  Snow
;---------------------------------------------------------------------------------------------------------------------

  fncfout->landmask = lnd->landfrac

  SNOWHLND = lnd->H2OSNO(ijouratm,:,:)
  poisson_grid_fill ( SNOWHLND, True , 1, 1500,  1e-2, 0.6, 0) ;fill missing values
  fncfout->SNOWHLND = SNOWHLND

;---------------------------------------------------------------------------------------------------------------------
;  SEAICE and stuff 
;---------------------------------------------------------------------------------------------------------------------

	if (ismissing(ice)) then
	
	  print("no ice files, using icefrac from cam2")
	
		tmask = lnd->landfrac
	
		ICEFRAC1 = atm->ICEFRAC(ijouratm,:,:)
		ICEFRAC1@_FillValue = 1e20
		tgridfile = addfile ("$NCL_POP_REMAP/tgrid"+res+".nc" , "r") 
	  	tgrid = tgridfile->tgrid
	  	ICEFRAC = ICEFRAC1               ; done for metadata
	  	ICEFRAC = (/ ICEFRAC1/tgrid /)     ; normalize the original regridded field by using remap2
		fncfout->ICEFRAC = ICEFRAC
	 	fncfout->SITHIK =  0*SNOWHLND
	 	fncfout->SNOWSI =  0*SNOWHLND
		fncfout->ALBSI = 0*SNOWHLND
		
	else

;---------------------------------------------------------------------------------------------------------------------
;  seaice (if is present)
;---------------------------------------------------------------------------------------------------------------------

 	print("ice files ok, using ice from csim")

 	if (isfilevar(ice, "aice") .or. isfilevar(ice, "aice_1")) then

		if (isfilevar(ice, "aice")) then
			; for CCSM data
			ICEFRAC0 = ice->aice(ijourocn,:,:)/100.					
		else if (isfilevar(ice, "aice_1")) then
			; for CESM data
			ICEFRAC0 = ice->aice_1(ijourocn,:,:)/100.
		end if
		end if
  	
  	; Regrid ice data from ocean to atmosphere grid
  	ICEFRAC1 = PopLatLon(ICEFRAC0,grid,res,"aave","da",date)
		ICEFRAC1@_FillValue = 1e20
		tgrid0  = where(.not.ismissing(ICEFRAC0),1.,0.)   
		tgrid = PopLatLon(tgrid0,grid,res,"aave","da",date)
		delete(tgrid0)
		tgrid = where(tgrid.eq.0,tgrid@_FillValue,tgrid) 
		ICEFRAC = ICEFRAC1               ; done for metadata
		ICEFRAC = (/ ICEFRAC1/tgrid /)     ; normalize the original regridded field by using remap2

 		if (1 .eq. 1) then	
			print("Smooth Ice")
			poisson_grid_fill ( ICEFRAC, True , 1, 1500,  1e-2, 0.6, 0) 
		else
			print("No Smooth Ice")
		end if

		fncfout->ICEFRAC = ICEFRAC
	
	else
	
		print("Seaice area not found in dataset.")
 		
	end if

;---------------------------------------------------------------------------------------------------------------------
;  Ice thickness and snow thickness (for POLAR)
;---------------------------------------------------------------------------------------------------------------------

 	if (isfilevar(ice, "hi") .or. isfilevar(ice, "hi_1")) then

 		if (isfilevar(ice, "hi") .and. isfilevar(ice, "hs")) then
			; for CCSM data
  		SITHIK0 = ice->hi(ijourocn,:,:)
  		SNOWSI0 = ice->hs(ijourocn,:,:)		
		else if (isfilevar(ice, "hi_1") .and. isfilevar(ice, "hs_1")) then
			; for CESM data
  		SITHIK0 = ice->hi_1(ijourocn,:,:)
  		SNOWSI0 = ice->hs_1(ijourocn,:,:)
		end if
		end if

		SITHIK1 = PopLatLon(SITHIK0,grid,res,"aave","da",date)
		SNOWSI1 = PopLatLon(SNOWSI0,grid,res,"aave","da",date)
		
		SITHIK = (/ SITHIK1/tgrid /)   
		SNOWSI = (/ SNOWSI1/tgrid /)    

		SITHIK@_FillValue = 1e20
		SNOWSI@_FillValue = 1e20

		SITHIK = where (SITHIK.gt.10.,10,SITHIK)
		SNOWSI = where (SNOWSI.gt.5.,5,SNOWSI)

		poisson_grid_fill ( SITHIK, True , 1, 1500,  1e-2, 0.6, 0) 
		poisson_grid_fill ( SNOWSI, True , 1, 1500,  1e-2, 0.6, 0) 

		fncfout->SITHIK = SITHIK
		fncfout->SNOWSI = SNOWSI

	else

		print("Snow and ice depth not found.")
		fncfout->SITHIK =  0*SNOWHLND
 		fncfout->SNOWSI =  0*SNOWHLND

	end if
  
;---------------------------------------------------------------------------------------------------------------------
;  albedo
;---------------------------------------------------------------------------------------------------------------------

 	if (isfilevar(ice, "albsni") .or. isfilevar(ice, "albsno_1")) then

		if (isfilevar(ice, "albsni")) then
			; for CCSM data
			ALBSI0 = ice->albsni(ijourocn,:,:)
 		else if (isfilevar(ice, "albsno_1")) then
			; for CESM data
			ALBSI0 = ice->albsno_1(ijourocn,:,:)
		end if
		end if

		ALBSI1 = PopLatLon(ALBSI0,grid,res,"aave","da",date)
		ALBSI = (/ ALBSI1/tgrid /)  
  	ALBSI@_FillValue = 1e20

		poisson_grid_fill ( ALBSI, True , 1, 1500,  1e-2, 0.6, 0) 
		fncfout->ALBSI = ALBSI

 	else

 		print("Albedo field not found.")
		fncfout->SITHIK =  0*SNOWHLND
 		fncfout->ALBSI =  0*SNOWHLND

	end if

;---------------------------------------------------------------------------------------------------------------------
 end if ; if seaice 

 end

 exit
