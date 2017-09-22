;------------------------------------------------------------------------------------
;	This is the script to test various of NCL functions
;------------------------------------------------------------------------------------

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/popRemap.ncl"
load "$HOME/WRF-Tools/NCL/functions.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

;----------------------------------------------------
begin
;----------------------------------------------------

print("FUNCTIONS LOADED")

;-----------------------------------------------------------------------------------
;  load CMIP5 files
;-----------------------------------------------------------------------------------


;data_6hour = addfile ("MIROC5_2085010100_6hourly_sample.nc" , "r")
data_6hour = addfile ("merged_6hourly.nc" , "r")
data_day = addfile ("merged_daily.nc" , "r")
data_month = addfile ("merged_monthly.nc" , "r")
print(getfilevarnames(data_6hour))
print(getfilevarnames(data_day))
print(getfilevarnames(data_month))
print("FILE LOADED")

;-----------------------------------------------------------------------------------
;  extract model name to determine the expected model
;-----------------------------------------------------------------------------------

; get dimension sizes to verify grid
llev = getfilevardimsizes(data_6hour,"lev")
llat = getfilevardimsizes(data_6hour,"lat")
llon = getfilevardimsizes(data_6hour,"lon")

; Here the identification between historical and RCP85 needs to be added

; Here identify the name of the model
if  ( (llev .eq. 48) .and. (llat .eq. 90) .and. (llon .eq. 144) ) then
  ;.and. (nji(0) .eq. 384) .and. (nji(1) .eq. 320) ) then
  ; data source (which model)
  GCM = "CMIP5"
  atmgrid = "gfdl-cm3"
  ; file to convert from ocean to atmosphere grid
  wgtFileName = "ocn2atmweight_file.nc"
else if  ( (llev .eq. 24) .and. (llat .eq. 90) .and. (llon .eq. 144) ) then
  ;.and. (nji(0) .eq. 384) .and. (nji(1) .eq. 320) ) then
  ; data source (which model)
  GCM = "CMIP5"
  atmgrid = "gfdl-esm2m"
  ; file to convert from ocean to atmosphere grid
  wgtFileName = "ocn2atmweight_file.nc"
else if  ( (llev .eq. 40) .and. (llat .eq. 128) .and. (llon .eq. 256) ) then
  GCM = "CMIP5"
  atmgrid = "miroc5"
  ; file to convert from ocean to atmosphere grid
  wgtFileName = "ocn2atmweight_file.nc"
else
  ; print warning
  print("WARNING: CMIP5 grid type not recognized - unable to transform ice data to atmospheric grid!")
end if
end if
end if

print("MODEL DETERMINED AS "+atmgrid)

; More types of CMIP5 model needs to be added

;---------------------------------------------------------------------------------------------------------------------
;Here load the data without the group structure
;---------------------------------------------------------------------------------------------------------------------

data_varslice = data_6hour->ta
;printVarSummary(data_varslice)
print("SAMPLE DATA SELECTED")

; N.B.: for SEAICE define environment variable $NCL_POP_REMAP

;---------------------------------------------------------------------------------------------------------------------
;  Coordinates
;---------------------------------------------------------------------------------------------------------------------
; desired output levels [hPa] 

pnew = (/1000.0,975.0,950.0,925.0,900.0,850.0,800.0,750.0,700.0,650.0,600.0,550.0,500.0,450.0,400.0,350.0,300.0,250.0,200.0,150.0,100.0,70.0,50.0,30.0,20.0,10.0 /)
; pnew = (/1000.0,950.0,900.0,850.0,800.0,750.0,700.0,650.0,600.0,550.0,500.0,450.0,400.0,350.0,300.0,250.0,200.0,150.0,100.0,50.0,10.0/)

lon = data_6hour->lon
lat = data_6hour->lat
time = data_6hour->time


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;p0 not found in cdo merged file yet !!!

;p0 = data_6hour->p0
p0=100000
P0mb = 0.01*p0
hyam = data_6hour->a(::-1)
hybm = data_6hour->b(::-1)
lev = p0*data_6hour->lev(::-1)
;Here the coordinate data are from the hus data. Accuracy unknown and better to check if consistent with other variables.

nzyx = floattointeger(fspan(0,3, 4))
nzyx(0) = dimsizes(time)
nzyx(1) = dimsizes(lev)
nzyx(2) = dimsizes(data_6hour->lon)
nzyx(3) = dimsizes(data_6hour->lat)

print(nzyx)
print("COORDINATE LOADED")

;---------------------------------------------------------------------------------------------------------------------
; open output file
;---------------------------------------------------------------------------------------------------------------------

system ("rm "+"intermed"+".nc")
fncfout = addfile ("intermed" +".nc" , "c")
; add source data to file
fncfout@Map_Source = GCM
; add projection type
if ( ( (GCM .eq. "CESM") .and. (atmgrid .eq. "fv0.9x1.25") ) .or. \ 
     ( (GCM .eq. "CESM2x2") .and. (atmgrid .eq. "fv1.9x2.5") ) .or. \
     ( (GCM .eq. "CMIP5") .and. (atmgrid .eq. "gfdl-cm3") ) .or. \
     ( (GCM .eq. "CMIP5") .and. (atmgrid .eq. "gfdl-esm2m") ) )  then
  fncfout@Map_Proj_ID =  0
  fncfout@Map_Proj_Name = "Cylindrical Equidistant"
else if ( ( (GCM .eq. "CCSM")  .and. (atmgrid .eq. "T85") ) .or. \
     ( (GCM .eq. "CMIP5") .and. (atmgrid .eq. "miroc5") ) ) then
  fncfout@Map_Proj_ID =  4
  fncfout@Map_Proj_Name = "Gaussian Projection"
else
  print("Warning: unknown grid/projection type!")
end if ; NCL does not support elseif...
end if
;---------------------------------------------------------------------------------------------------------------------

ijouratm = 0 ; constant (one file per timestep), just for convenience
ijourocn = 0
; This needs to be adjusted so that the entire month is taken care of

;---------------------------------------------------------------------------------------------------------------------
;Here the variables are loaded from different data groups!!
;---------------------------------------------------------------------------------------------------------------------

; Here begin by load the previously used ensemble group. Somehow ncl does not recognize the group once it is loaded.

;T = atm->ta(ijouratm,::-1,:,:)
T = data_6hour->ta(ijouratm,::-1,:,:)

;U = atm->ua(ijouratm,::-1,:,:)
U = data_6hour->ua(ijouratm,::-1,:,:)

;V = atm->va(ijouratm,::-1,:,:)
V = data_6hour->va(ijouratm,::-1,:,:)

;CMIP Z3 not available, to be computed below

;Q = atm->hus(ijouratm,::-1,:,:)
Q = data_6hour->hus(ijouratm,::-1,:,:)

;CMIP RELHUM to be computed below

;PS = atm->ps(ijouratm,:,:)
PS = data_6hour->ps(ijouratm,:,:)

;PSL = atm->psl(ijouratm,:,:)
;Note here begins 6hrPlev data 
;---------------------------------------------------------------------------------------------------------------------
PSL = data_6hour->psl

;TS = atm->tas(ijouratm,:,:)
;Here begins 3hr data 
;---------------------------------------------------------------------------------------------------------------------
TS = data_6hour->tas(ijouratm,:,:)

HUSS = data_6hour->huss(ijouratm,:,:)

US = data_6hour->uas(ijouratm,:,:)

VS = data_6hour->vas(ijouratm,:,:)


;---------------------------------------------------------------------------------------------------------------------
;Here begins daily data 
;---------------------------------------------------------------------------------------------------------------------

SST0 = data_day->tos(ijourocn,:,:)

ICEFRAC0 = data_day->sic(ijourocn,:,:)/100.


if (isfilevar(data_day, "sit")) then 
  SITHIK0 = data_day->sit(ijourocn,:,:)
end if

if (atmgrid .eq. "miroc5") then
  TSLSI = data_day->tslsi(ijouratm,:,:)
  ;print("1")
else
  fncfout->SKT = TS ;
  ;print("0")
end if

SNOWHLND = data_day->snw(ijouratm,:,:)

;---------------------------------------------------------------------------------------------------------------------
;Here begins monthly data 
;---------------------------------------------------------------------------------------------------------------------

Tsoil = data_month->tsl(ijouratm,:,:,:)
level = data_month->depth ;The depth data is an attribute for the tsl variable
ldep = getfilevardimsizes(data_month,"depth")

Tlandmoi = data_month->mrlsl(ijouratm,:,:,:)
sdepth = data_month->depth_bnds ;Again an attribute

;data_lv_realm = data_lv_frequency=>/landIce
;data_lv_CMORtable = data_lv_realm=>/LImon
;data_lv_ensemble = data_lv_CMORtable=>/r1i1p1
;data_lv_vargroup = data_lv_ensemble=>/snw
;SNOWHLND = data_lv_vargroup->snw(ijouratm,:,:)

;---------------------------------------------------------------------------------------------------------------------
;This logic structure is refined as group structure does not present now
;---------------------------------------------------------------------------------------------------------------------

if (isfilevar(data_month, "snd")) then 
  SNOWSI0 = data_month->snd(ijourocn,:,:)
end if

;if (isfilevar(ice, "ialb")) then 
;                ALBSI0 = ice->ialb(ijourocn,:,:) ;ialb does not exist even for MIROC5!


;Here are the constant data that are in separate files
;---------------------------------------------------------------------------------------------------------------------
;orogdata = addfile ("orog_fx_MIROC5_historical_r0i0p0.nc" , "r")
orogdata = addfile ("orog_file.nc" , "r")
orog = orogdata->orog

;sftlfdata = addfile ("sftlf_fx_MIROC5_historical_r0i0p0.nc" , "r")
sftlfdata = addfile ("sftlf_file.nc" , "r")
landfrac = sftlfdata->sftlf/100




; Here the constant datas need to be treated with different file names. For now the name is hard coded.

print("variables loaded")

;---------------------------------------------------------------------------------------------------------------------
; Calculate Z3 and RELHUM here
;---------------------------------------------------------------------------------------------------------------------

pres= p0 * conform_dims( dimsizes(T) ,hyam,0) \
    + conform_dims( dimsizes(T) ,hybm,0) \
    * conform_dims( dimsizes(T) ,PS , (/1,2/) );
pres!1="lat"
pres!2="lon"
pres!0="lev"

RELHUM = relhum( T, Q, pres)
RELHUM = RELHUM < 100

RELHUM!1="lat"
RELHUM!2="lon"
RELHUM&lat = lat
RELHUM&lon = lon

PZ3=new( (/llat,llon,llev+1/), "double")
PZ3(:,:,0:llev-1)=pres(lat|:,lon|:,lev|:)
PZ3(:,:,llev)=PS
TZ3=new( (/llat,llon,llev+1/), "double")
TZ3(:,:,0:llev-1)=T(lat|:,lon|:,lev|:)*(1.0+0.61*Q(lat|:,lon|:,lev|:))
TZ3(:,:,llev)=TS*(1.0+0.61*HUSS)

;print("U=")
;print(U)
;print("V=")
;print(V)
;print("PS=")
;print(PS)

z3i = hydro(PZ3(:,:,::-1),TZ3(:,:,::-1),orog)
z3i!0="lat"
z3i!1="lon"
z3i!2="lev1"

Z3 = (/ z3i(lev1|1::-1,lat|:,lon|:) /)

Z3!0="lev1"
Z3!1="lat"
Z3!2="lon"
Z3&lat = lat
Z3&lon = lon

;---------------------------------------------------------------------------------------------------------------------
;  Interpolate and output 3D fields to pressure levels 'pnew'
;---------------------------------------------------------------------------------------------------------------------

fncfout->T = vinth2p_ecmwf(T,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
fncfout->U = vinth2p_ecmwf(U,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
fncfout->V = vinth2p_ecmwf(V,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
fncfout->Z3 = vinth2p_ecmwf(Z3,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:))
fncfout->RELHUM = vinth2p_ecmwf(RELHUM,hyam,hybm,pnew,PS,1,P0mb,1,True,1,TS,Z3(nzyx(1)-1,:,:)) 

;---------------------------------------------------------------------------------------------------------------------
;  Land Mask
;---------------------------------------------------------------------------------------------------------------------

landfrac = where(ismissing(landfrac),0,landfrac)
landfrac!0="lat"
landfrac!1="lon"
landfrac&lat = lat
landfrac&lon = lon
;landfrac(ind(ismissing(landfrac)))=0
fncfout->landmask = landfrac

;---------------------------------------------------------------------------------------------------------------------
;  Surface fields
;---------------------------------------------------------------------------------------------------------------------
 
fncfout->PS = PS
fncfout->PSL = PSL(0,:,:)
fncfout->TS = TS
RELHUMS=relhum(TS, HUSS, PS)
RELHUMS = RELHUMS < 100
RELHUMS!0="lat"
RELHUMS!1="lon"
RELHUMS&lat = lat
RELHUMS&lon = lon
fncfout->RELHUMS = RELHUMS
fncfout->US = US
fncfout->VS = VS



;---------------------------------------------------------------------------------------------------------------------
;  Skin temperature & SST
;---------------------------------------------------------------------------------------------------------------------

;TSLSI&lat = todouble(lat)
;TSLSI&lon = todouble(lon)

if (atmgrid .eq. "miroc5") then
  fncfout->SKT = TSLSI
  ;print("1")
else
  fncfout->SKT = TS ;
  ;print("0")
end if


printVarSummary(PS)

;---------------------------------------------------------------------------------------------------------------------
;  Soil temperature
;---------------------------------------------------------------------------------------------------------------------

stmp = rm_single_dims(linint1_n(level,Tsoil,False,.05,0,0))
;stmp!0="lat"
;stmp!1="lon"
;stmp&lat = lat
;stmp&lon = lon
stmp@_Fillvalue = 1e+20
stmp = where((ismissing(stmp).and.(landfrac>0.)),TS,stmp)
fncfout->ST000010 = stmp
stmp = linint1_n(level,Tsoil,False,.25,0,0)
stmp = where((ismissing(stmp).and.(landfrac>0.)),TS,stmp)
fncfout->ST010040 = stmp
stmp = linint1_n(level,Tsoil,False,.7,0,0)
stmp = where((ismissing(stmp).and.(landfrac>0.)),TS,stmp)
fncfout->ST040100 = stmp
stmp = linint1_n(level,Tsoil,False,1.5,0,0)
stmp = where((ismissing(stmp).and.(landfrac>0.)),TS,stmp)
fncfout->ST100200 = stmp
stmp = Tsoil(ldep-1,:,:)
stmp = where((ismissing(stmp).and.(landfrac>0.)),TS,stmp)
fncfout->TMN = stmp

;---------------------------------------------------------------------------------------------------------------------
;  Soil moisture
;---------------------------------------------------------------------------------------------------------------------

dlayer=dble2flt(sdepth(:,1)-sdepth(:,0))*1000.
Tlandmoi = Tlandmoi / conform_dims( dimsizes(Tlandmoi) ,dlayer,0) 
stmp = linint1_n(level,Tlandmoi,False,.05,0,0)
;stmp@_Fillvalue = 1e+20
fncfout->SM000010 = rm_single_dims(stmp)
stmp = linint1_n(level,Tlandmoi,False,.25,0,0)
fncfout->SM010040 = rm_single_dims(stmp)
stmp = linint1_n(level,Tlandmoi,False,.7,0,0)
fncfout->SM040100 = rm_single_dims(stmp)
stmp = linint1_n(level,Tlandmoi,False,1.5,0,0)
fncfout->SM100200 = rm_single_dims(stmp)

;---------------------------------------------------------------------------------------------------------------------
;  Snow
;---------------------------------------------------------------------------------------------------------------------

poisson_grid_fill ( SNOWHLND, True , 1, 1500,  1e-2, 0.6, 0) ;fill missing values
fncfout->SNOWHLND = SNOWHLND

;---------------------------------------------------------------------------------------------------------------------
;  SEAICE and stuff 
;---------------------------------------------------------------------------------------------------------------------

; Regrid ice data from ocean to atmosphere grid
Opt                = True
;   Opt@Debug          = True
Opt@PrintTimings   = True

ICEFRAC1 = ESMF_regrid_with_weights(ICEFRAC0,wgtFileName,Opt)
ICEFRAC1@_FillValue = 1e20

tgrid0  = where(.not.ismissing(ICEFRAC0),1.,0.)
tgrid = ESMF_regrid_with_weights(tgrid0,wgtFileName,Opt)
delete(tgrid0)
tgrid = where(tgrid.eq.0,tgrid@_FillValue,tgrid)
ICEFRAC = ICEFRAC1               ; done for metadata
ICEFRAC = (/ ICEFRAC1/tgrid /)     ; normalize the original regridded field by using remap2

print("Smooth Ice")
poisson_grid_fill ( ICEFRAC, True , 1, 1500,  1e-2, 0.6, 0)

;lat = floattolong(lat)
;lon = todouble(lon)
;print(getfilevarnames(ICEFRAC))
;ICEFRAC = todouble(ICEFRAC)

fncfout->ICEFRAC = ICEFRAC
;Here there is an unknown error of type mismatch with lat/lon when writing the ICEFRAC variable

;CMIP SSTs are on the ocean grid 
;SST0 = where(SST0.eq.0,SST0@_FillValue,SST0)
SST1 = ESMF_regrid_with_weights(SST0,wgtFileName,Opt)
SST = (/ SST1/tgrid /)
SST@_FillValue = 1e20
poisson_grid_fill ( SST, True , 1, 1500,  1e-2, 0.6, 0)

SST!0="lat"
SST!1="lon"
SST&lat = lat
SST&lon = lon

fncfout->SST = SST
;
SKT = fncfout->SKT
SKT = where(SKT.eq.0,SST,SKT)
SKT = where(ismissing(SKT),TS,SKT)
fncfout->SKT = SKT

if (isvar("SITHIK0")) then 
        ;SITHIK0 = ice->sit(ijourocn,:,:)
        print("sic available")
        SITHIK1 = ESMF_regrid_with_weights(SITHIK0,wgtFileName,Opt)
        SITHIK = (/ SITHIK1/tgrid /)
        SITHIK@_FillValue = 1e20
        SITHIK = where (SITHIK.gt.10.,10,SITHIK)
        poisson_grid_fill ( SITHIK, True , 1, 1500,  1e-2, 0.6, 0)
        SITHIK!0="lat"
        SITHIK!1="lon"
        SITHIK&lat = lat
        SITHIK&lon = lon
        fncfout->SITHIK = SITHIK
else
        SITHIK =  0*SNOWHLND
        SITHIK!0="lat"
        SITHIK!1="lon"
        SITHIK&lat = lat
        SITHIK&lon = lon
        fncfout->SITHIK =  SITHIK
end if

if (isvar("SNOWSI0")) then 
        ;SNOWSI0 = ice->snd(ijourocn,:,:)
        print("snd available")
        SNOWSI1 = ESMF_regrid_with_weights(SNOWSI0,wgtFileName,Opt)
        SNOWSI = (/ SNOWSI1/tgrid /)
        SNOWSI@_FillValue = 1e20
        SNOWSI = where (SNOWSI.gt.5.,5,SNOWSI)
        poisson_grid_fill ( SNOWSI, True , 1, 1500,  1e-2, 0.6, 0)
        SNOWSI!0="lat"
        SNOWSI!1="lon"
        SNOWSI&lat = lat
        SNOWSI&lon = lon
        fncfout->SNOWSI = SNOWSI
else
        SNOWSI =  0*SNOWHLND
        SNOWSI!0="lat"
        SNOWSI!1="lon"
        SNOWSI&lat = lat
        SNOWSI&lon = lon
        fncfout->SNOWSI =  SNOWSI
end if


;here ialb variable does not exist in any CMIP model.
if (isvar("ALBSI0")) then 
        ;ALBSI0 = ice->ialb(ijourocn,:,:)
        ALBSI1 = ESMF_regrid_with_weights(ALBSI0,wgtFileName,Opt)
        ALBSI = (/ ALBSI1/tgrid /)
        ALBSI@_FillValue = 1e20
        poisson_grid_fill ( ALBSI, True , 1, 1500,  1e-2, 0.6, 0)
        ALBSI!0="lat"
        ALBSI!1="lon"
        ALBSI&lat = lat
        ALBSI&lon = lon
        fncfout->ALBSI = ALBSI
else
        ALBSI =  0*SNOWHLND
        ALBSI!0="lat"
        ALBSI!1="lon"
        ALBSI&lat = lat
        ALBSI&lon = lon
        fncfout->ALBSI =  ALBSI
end if

if (atmgrid .eq. "gfdl-esm2m") then
  lat(0)=-90.0
  lat(llat-1)=90.0
  Reallat = lat
  print ("correction of grid regularity of gfdl-esm2m")
  lat&lat = Reallat
  fncfout->lat = lat
  ;print (lat)
end if

print("unCMIP5.ncl completed")

end

exit