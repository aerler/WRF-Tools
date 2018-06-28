;------------------------------------------------------------------

undef("smthcurve")

function smthcurve(var, nharm, cyclic)

local newvar, ntime, itime, section
begin

if (nharm.eq.0) then 

	return(var)

else

	newvar = var
 	ntime = dimsizes(var)

	do itime=0,ntime-1
		
		if (cyclic.eq.0) then
			itime1=max((/0,itime-nharm/))	
			itime2=min((/ntime-1,itime+nharm/))	


			newvar(itime) = dim_avg(var(itime1:itime2))	
		else
			if (itime-nharm.lt.0) then
				section = array_append_record (ispan(0,itime+nharm,1),ispan(ntime-1-nharm+itime,ntime-1,1),0)
				newvar(itime) = dim_avg(var(section))	
			else if (itime+nharm.gt.ntime-1) then
					section = array_append_record (ispan(0,itime+nharm-ntime+1,1),ispan(itime-nharm,ntime-1,1),0)
					newvar(itime) = dim_avg(var(section))	
			     else
					newvar(itime) = dim_avg(var(itime-nharm:itime+nharm))	
			     end if

			end if



		end if
	end do

	return(newvar)
 
end if

end

;------------------------------------------------------------------

undef("rcm2rcm")

function rcm2rcm(lat, lon, Champs, newlat, newlon)

local newChamps,lonjoe,latjoe,Champsregrid0
begin

 nyx = dimsizes(lon)


   lonjoe = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))
   latjoe = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))
   Champsregrid0 = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))


 	 do i = 0, nyx(0)-1
  	 lonjoe(nyx(1)*i:nyx(1)*(i+1)-1) = lon(i,:)
   	 latjoe(nyx(1)*i:nyx(1)*(i+1)-1) = lat(i,:)
  	 Champsregrid0(nyx(1)*i:nyx(1)*(i+1)-1) = Champs(i,:)

  	end do

 
  newChamps = triple2grid2d(lonjoe,latjoe,Champsregrid0, newlon,newlat, False)
  return(newChamps)

end


;------------------------------------------------------------------
;------------------------------------------------------------------

undef("rcm2rcmbilin")

function rcm2rcmbilin(lat, lon, Champs, newlat, newlon)

local newChamps,lonjoe,latjoe,Champsregrid0
begin

 nyx = dimsizes(newlat)
 newChamps = 0*newlat
 
 	 do i = 0, nyx(0)-1

  		newChamps(i,:)=rcm2points (lat, lon, Champs, newlat(i,:), newlon(i,:), 2)

  	 end do	

  return(newChamps)

end
;------------------------------------------------------------------
undef("CopyAtt")

procedure CopyAtt( a , b )

local yo, i
begin

		yo = getvaratts(b)

		do i = 0,dimsizes(yo)-1
			a@$yo(i)$ = b@$yo(i)$
		end do

end

;------------------------------------------------------------------
undef("AttWRFgrid221")

function AttWRFgrid221()

begin

  globalAtt             = True
  globalAtt@DX = 30000.0  ; // float
  globalAtt@DY = 30000.0  ; // float
  globalAtt@GRIDTYPE = "C" ;
  globalAtt@CEN_LAT = 53.252613  ; // float
  globalAtt@CEN_LON = -106.266266  ; // float
  globalAtt@TRUELAT1 = 50.0  ; // float
  globalAtt@TRUELAT2 = 50.0  ; // float
  globalAtt@MOAD_CEN_LAT = 53.252613  ; // float
  globalAtt@STAND_LON = -107.0  ; // float
  globalAtt@POLE_LAT = 90.0  ; // float
  globalAtt@POLE_LON = 0.0  ; // float
  globalAtt@MAP_PROJ = 1 ; // int

  return(globalAtt)

end
;------------------------------------------------------------------
;------------------------------------------------------------------
undef("AttWRFgrid221ontario")

function AttWRFgrid221ontario()

begin

  globalAtt             = True
  globalAtt@DX = 10000.0  ; // float
  globalAtt@DY = 10000.0  ; // float
  globalAtt@GRIDTYPE = "C" ;
  globalAtt@CEN_LAT = 48.07455  ; // float
  globalAtt@CEN_LON = -83.98303  ; // float
  globalAtt@TRUELAT1 = 50.0  ; // float
  globalAtt@TRUELAT2 = 50.0  ; // float
  globalAtt@MOAD_CEN_LAT = 53.252613  ; // float
  globalAtt@STAND_LON = -107.0  ; // float
  globalAtt@POLE_LAT = 90.0  ; // float
  globalAtt@POLE_LON = 0.0  ; // float
  globalAtt@MAP_PROJ = 1 ; // int

  return(globalAtt)

end
;------------------------------------------------------------------
undef("rcm2rgridv2")

function rcm2rgridv2(lat2d, lon2d, Champs, lat1d, lon1d)

local newChamps,lonjoe,latjoe,Champsregrid0,nyx
begin

 nyx = dimsizes(lat2d)


   lonjoe = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))
   latjoe = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))
   Champsregrid0 = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))

 	 do i = 0, nyx(0)-1
  		lonjoe(nyx(1)*i:nyx(1)*(i+1)-1) = lon2d(i,:)
   	 	latjoe(nyx(1)*i:nyx(1)*(i+1)-1) = lat2d(i,:)
  	 	Champsregrid0(nyx(1)*i:nyx(1)*(i+1)-1) = Champs(i,:)
  	 end do

	; do i = 0, nyx(0)-1
 	; do j = 0, nyx(1)-1
	;	if (ismissing(Champs(i,j))) then
  	; 	lonjoe(nyx(1)*i+j) = 0
   	; 	latjoe(nyx(1)*i+j) = 0
  	;	Champsregrid0(nyx(1)*i+j) = 0
	;	else
  	;	lonjoe(nyx(1)*i+j) = lon2d(i,j)
   	; 	latjoe(nyx(1)*i+j) = lat2d(i,j)
  	;	Champsregrid0(nyx(1)*i+j) = Champs(i,j)
	;	end if
	;end do
  	;end do 	


   newChamps = triple2grid(lonjoe,latjoe,Champsregrid0, lon1d,lat1d, False)

  return(newChamps)

end

;------------------------------------------------------------------

undef("rgrid2rcmv2")

function rgrid2rcmv2(lat, lon, Champs, newlat, newlon)

local newChamps,lonjoe,latjoe,Champsregrid0
begin

 nyx = (/dimsizes(lon),dimsizes(lat)/)


   lonjoe = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))
   latjoe = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))
   Champsregrid0 = fspan(0,nyx(1)*nyx(0)-1, nyx(1)*nyx(0))


 	 do i = 0, nyx(0)-1
		do j = 0, nyx(1)-1
			lonjoe(nyx(1)*i+j) = lon(i)
   			latjoe(nyx(1)*i+j) = lat(j)
	  	  	Champsregrid0(nyx(1)*i+j) = Champs(j,i)
  		end do
  	end do

 
  newChamps = triple2grid2d(lonjoe,latjoe,Champsregrid0, newlon,newlat, False)
  return(newChamps)

end


;------------------------------------------------------------------
;------------------------------------------------------------------
;------------------------------------------------------------------

undef("lagrangeintrp")

function lagrangeintrp(x1i,x2i,x3i,y1,y2,y3,xi)

	local a1,a2,a3,y,x1,x2,x3,x
	begin

		x=xi*1.
		x1=x1i*1.
		x2=x2i*1.			
		x3=x3i*1.		

      		a1 = (x-x2)*(x-x3)/((x1-x2)*(x1-x3))
      		a2 = (x-x1)*(x-x3)/((x2-x1)*(x2-x3))
     		a3 = (x-x1)*(x-x2)/((x3-x1)*(x3-x2))

      		y  = y1*a1 + y2*a2 + y3*a3 

		return(y)
      	end


;------------------------------------------------------------------
;------------------------------------------------------------------

undef("lagrangeintrpn")

function lagrangeintrpn(x,y,x0)

	local n,a,xxn,xx0
	begin

		result=0*y(0,:,:)
		a=0*x

		do n = 0, dimsizes(x)-1
			xxn = x(n)-x
			xx0 = x0-x
			xxn@_FillValue = 0
			xx0@_FillValue = x0-x(n)
      			a(n) = product(xx0/xxn)
                	result=result+a(n)*y(n,:,:)
			delete(xxn)
			delete(xx0)
		end do

      		return(result)
      	end


;------------------------------------------------------------------
;------------------------------------------------------------------

undef("percentile")

function percentile(listdata,percent)

	local j,f,j1,j2

	begin

	qsort(listdata)
	j=percent/100.*(dimsizes(listdata)+1)
	f=j-floor(j)

	j1=floattointeger(floor(j))
	j2=floattointeger(floor(j))+1

	result = (1.-f)*listdata(j1-1)+f*listdata(j2-1)

      	return(result)

 end

;------------------------------------------------------------------
;------------------------------------------------------------------

undef("lagrangeintrpn")

function lagrangeintrpn(x,y,x0)

	local n,a,xxn,xx0
	begin

		result=0*y(0,:,:)
		a=0*x

		do n = 0, dimsizes(x)-1
			xxn = x(n)-x
			xx0 = x0-x
			xxn@_FillValue = 0
			xx0@_FillValue = x0-x(n)
      			a(n) = product(xx0/xxn)
                	result=result+a(n)*y(n,:,:)
			delete(xxn)
			delete(xx0)
		end do

      		return(result)
      	end


;------------------------------------------------------------------

;--------------------------------------------------------------------------------

 
undef("wrf_user_getvar_nopb")
function wrf_user_getvar_nopb( nc_file:file, nc_filepb:file, varin[*]:string, time:integer )

begin

  variable = varin(0)

  if( (variable .eq. "uvmet") .or. (variable .eq. "uvmet10") ) then
       ;; Calculate winds rotated to earth coord. 

       pii = 3.14159265
       radians_per_degree = pii/180.

       if( (variable .eq. "uvmet") )  then
         getU = "U" 
         getV = "V" 
         if(.not. isfilevar(nc_file,"U")) then
           if(isfilevar(nc_file,"UU")) then
             getU = "UU"
             getV = "VV"
           end if
         end if
         if ( time .eq. -1 ) then
           u_in = nc_file->$getU$
           v_in = nc_file->$getV$
           u = wrf_user_unstagger(u_in,u_in@stagger)
           v = wrf_user_unstagger(v_in,v_in@stagger)
         else
           u_in   = nc_file->$getU$(time,:,:,:)
           v_in   = nc_file->$getV$(time,:,:,:)
           u = wrf_user_unstagger(u_in,u_in@stagger)
           v = wrf_user_unstagger(v_in,v_in@stagger)
         end if
       end if  

       if( (variable .eq. "uvmet10") )  then
         if(isfilevar(nc_file,"U10")) then
           if ( time .eq. -1 ) then
             u_in   = nc_file->U10
             v_in   = nc_file->V10
             u = wrf_user_unstagger(u_in,u_in@stagger)
             v = wrf_user_unstagger(v_in,v_in@stagger)
           else
             u_in  = nc_file->U10(time,:,:)
             v_in  = nc_file->V10(time,:,:)
             u = wrf_user_unstagger(u_in,u_in@stagger)
             v = wrf_user_unstagger(v_in,v_in@stagger)
           end if
         else  ; may be a met file, so get lowest level of UU and VV
           if(isfilevar(nc_file,"UU")) then
             print("Assume this is a met_em file - getting lowest level from UU and VV fields")
             if ( time .eq. -1 ) then
               u_in  = nc_file->UU(:,0,:,:)
               v_in  = nc_file->VV(:,0,:,:)
               u = wrf_user_unstagger(u_in,u_in@stagger)
               v = wrf_user_unstagger(v_in,v_in@stagger)
             else
               u_in  = nc_file->UU(time,0,:,:)
               v_in  = nc_file->VV(time,0,:,:)
               u = wrf_user_unstagger(u_in,u_in@stagger)
               v = wrf_user_unstagger(v_in,v_in@stagger)
             end if
           end if
         end if  
       end if  


       map_projection = nc_file@MAP_PROJ


       if( any(map_projection.eq.(/0,3,6/)) ) then  ; no rotation needed
         dims = dimsizes(u)
         nd = dimsizes(dims)
         if ( nd .eq. 5 ) then
           uvmet = new( (/ 2, dims(0), dims(1), dims(2), dims(3), dims(4) /), typeof(u))
           uvmet(0,:,:,:,:,:) = u(:,:,:,:,:) 
           uvmet(1,:,:,:,:,:) = v(:,:,:,:,:)
         end if
         if ( nd .eq. 4 ) then
           uvmet = new( (/ 2, dims(0), dims(1), dims(2), dims(3) /), typeof(u))
           uvmet(0,:,:,:,:) = u(:,:,:,:) 
           uvmet(1,:,:,:,:) = v(:,:,:,:)
         end if
         if ( nd .eq. 3 ) then
           uvmet = new( (/ 2, dims(0), dims(1), dims(2) /), typeof(u))
           uvmet(0,:,:,:) = u(:,:,:) 
           uvmet(1,:,:,:) = v(:,:,:)
         end if
         if ( nd .eq. 2 ) then
           uvmet = new( (/ 2, dims(0), dims(1) /), typeof(u))
           uvmet(0,:,:) = u(:,:) 
           uvmet(1,:,:) = v(:,:)
         end if
         delete_VarAtts(u,(/"description","units"/))
         copy_VarAtts(u,uvmet)
         uvmet@description = " u,v met velocity"
         uvmet!0 = "u_v"
       end if


       if( any(map_projection.eq.(/1,2/)) ) then  ; no rotation needed
         cen_lat  = nc_file@CEN_LAT
         if(isatt(nc_file,"STAND_LON")) then
             cen_long = nc_file@STAND_LON
         else
             cen_long = nc_file@CEN_LON
         end if
         true_lat1 = nc_file@TRUELAT1
         true_lat2 = nc_file@TRUELAT2
  
         getLAT = "XLAT" 
         getLON = "XLONG" 
         if(.not. isfilevar(nc_file,"XLAT")) then
           if(isfilevar(nc_file,"XLAT_M")) then
             getLAT = "XLAT_M"
             getLON = "XLONG_M"
           end if
         end if
         if ( time .eq. -1 ) then
           latitude  = nc_file->$getLAT$
           longitude = nc_file->$getLON$
         else
           latitude  = nc_file->$getLAT$(time,:,:)
           longitude = nc_file->$getLON$(time,:,:)
         end if

         cone = 1.
         if( map_projection .eq. 1) then    ; Lambert Conformal mapping
           if( (fabs(true_lat1 - true_lat2) .gt. 0.1) .and.  \
               (fabs(true_lat2 - 90. )      .gt. 0.1)       ) then
               cone = 10^(cos(true_lat1*radians_per_degree)) \
                     -10^(cos(true_lat2*radians_per_degree))
               cone = cone/(10^(tan(45. -fabs(true_lat1/2.)*radians_per_degree)) - \
                            10^(tan(45. -fabs(true_lat2/2.)*radians_per_degree))   )
           else
               cone = sin(fabs(true_lat1)*radians_per_degree)
           end if
         end if
         if(map_projection .eq. 2) then      ; polar stereographic
           cone = 1.
         end if
         if(map_projection .eq. 3) then      ; Mercator
           cone = 0.
         end if

         uvmet = wrf_uvmet( u, v, latitude, longitude, cen_long, cone )
         delete_VarAtts(u,(/"description","units"/))
         copy_VarAtts(u,uvmet)

       end if  
       
       if( (variable .eq. "uvmet10") )  then
         uvmet@description = " u10,v10 met velocity"
       end if
       return(uvmet)

  end if



  if( variable .eq. "ua" ) then
       ;  U interpolated to mass points
       getTHIS = "U" 
       if(.not. isfilevar(nc_file,"U")) then
         if(isfilevar(nc_file,"UU")) then
           getTHIS = "UU"
         end if
       end if
       if ( time .eq. -1 ) then
         var = nc_file->$getTHIS$
       else
         var = nc_file->$getTHIS$(time,:,:,:)
       end if

       ua = wrf_user_unstagger(var,var@stagger)

       return(ua)
  end if



  if( variable .eq. "va" ) then
       ; V interpolated to mass points
       getTHIS = "V" 
       if(.not. isfilevar(nc_file,"V")) then
         if(isfilevar(nc_file,"VV")) then
           getTHIS = "VV"
         end if
       end if
       if ( time .eq. -1 ) then
         var = nc_file->$getTHIS$
       else
         var = nc_file->$getTHIS$(time,:,:,:)
       end if

       va = wrf_user_unstagger(var,var@stagger)

       return(va)
  end if



  if( variable .eq. "wa" ) then
       ; W interpolated to mass points
       if ( time .eq. -1 ) then
         var = nc_file->W
       else
         var = nc_file->W(time,:,:,:)
       end if

       wa = wrf_user_unstagger(var,var@stagger)

       return(wa)
  end if



  if( any( variable .eq. (/"p","pres","pressure"/) ) ) then
       ; Full model pressure [=base pressure (PB) + pertubation pressure (P)]
       if(isfilevar(nc_file,"P")) then
         if ( time .eq. -1 ) then
           var = nc_file->P
           PB  = nc_filepb->PB
         else
           var = nc_file->P(time,:,:,:)
           PB  = nc_filepb->PB(0,:,:,:)
         end if
         var = var + PB
       else
         ;; may be a met_em file - see if we can get PRES
         if(isfilevar(nc_file,"PRES")) then
           if ( time .eq. -1 ) then
             var = nc_file->PRES
           else
             var = nc_file->PRES(time,:,:,:)
           end if
         end if
       end if
       var@description = "Pressure"
       if( variable .eq. "pressure" ) then
         var = var * 0.01
         var@units = "hPa"
       end if
       return(var)
  end if



  if( any( variable .eq. (/"geopt","geopotential","z","height"/) ) ) then
       ; Height [=full geopotentail height / 9.81]
       if(isfilevar(nc_file,"PH")) then
         if ( time .eq. -1 ) then
           var = nc_file->PH
           PHB = nc_filepb->PHB
         else
           var = nc_file->PH(time,:,:,:)
           PHB = nc_filepb->PHB(0,:,:,:)
         end if

         var = var + PHB 
         z = wrf_user_unstagger(var,var@stagger)
         z@description = "Geopotential"

       else
         ;; may be a met_em file - see if we can get GHT
         if(isfilevar(nc_file,"GHT")) then
           if ( time .eq. -1 ) then
             z = nc_file->GHT
           else
             z = nc_file->GHT(time,:,:,:)
           end if
         end if
       end if  

       if( any( variable .eq. (/"z","height"/) ) ) then
         z = z / 9.81
         z@description = "Height"
         z@units       = "m"
       end if
       return(z)
  end if



  if( any( variable .eq. (/"th","theta"/) ) ) then
       ; Potentail Temperature is model output T + 300K
       if ( time .eq. -1 ) then
         var = nc_file->T
       else
         var = nc_file->T(time,:,:,:)
       end if  
       var = var + 300.
       var@description = "Potential Temperature (theta) "
       return(var)
  end if



  if( any( variable .eq. (/"tk","tc"/) ) ) then
       ;; function wrf_tk needs theta and pressure (Pa) on input and returns temperature in K on return
       if(isfilevar(nc_file,"T")) then
         if ( time .eq. -1 ) then
           T  = nc_file->T
           P  = nc_file->P
           PB = nc_filepb->PB
         else
           T  = nc_file->T(time,:,:,:)
           P  = nc_file->P(time,:,:,:)
           PB = nc_filepb->PB(0,:,:,:)
         end if  
         T = T + 300.
         P = P + PB
         t = wrf_tk( P , T )
         delete_VarAtts(T,(/"description"/))
         copy_VarAtts(T,t)
       else
         ;; may be a met_em file - see if we can get TT
         if(isfilevar(nc_file,"TT")) then
           if ( time .eq. -1 ) then
             t = nc_file->TT
           else
             t = nc_file->TT(time,:,:,:)
           end if  
         end if  
       end if  
       if( variable .eq. "tc" ) then
         t = t - 273.16
         t@units = "C"     ; Overwrite return units
       end if
       return(t)
  end if



  if( variable .eq. "td" ) then
       ;; function wrf_td needs qv and pressure (Pa) on input and returns dewpoint temperature on return
       if ( time .eq. -1 ) then
         P      = nc_file->P
         PB     = nc_file->PB
         QVAPOR = nc_file->QVAPOR
       else
         P      = nc_file->P(time,:,:,:)
         PB     = nc_file->PB(time,:,:,:)
         QVAPOR = nc_file->QVAPOR(time,:,:,:)
       end if
       P = P + PB
       td  = wrf_td( P , QVAPOR )
       delete_VarAtts(QVAPOR,(/"description","units"/))
       copy_VarAtts(QVAPOR,td)
       return(td)
  end if



  if( variable .eq. "td2" ) then
       ;; function wrf_td needs qv and pressure (Pa) on input and returns dewpoint temperature on return
       if ( time .eq. -1 ) then
         PSFC = nc_file->PSFC
         Q2   = nc_file->Q2
       else
         PSFC = nc_file->PSFC(time,:,:) 
         Q2   = nc_file->Q2(time,:,:)
       end if
       td = wrf_td( PSFC , Q2 )
       delete_VarAtts(Q2,(/"description","units"/))
       copy_VarAtts(Q2,td)
       td@description = "2m Dewpoint Temperature"   ; Overwrite return description
       return(td)
  end if



  if( variable .eq. "slp" ) then
       if(isfilevar(nc_file,"T")) then
         ;; first compute theta - function wrf_tk needs theta and pressure (Pa) on input
         ;; THEN compute sea level pressure, from qv, p (Pa), tk, z
         if ( time .eq. -1 ) then
           T      = nc_file->T
           P      = nc_file->P
           PB     = nc_file->PB
           QVAPOR = nc_file->QVAPOR
           PH     = nc_file->PH
           PHB    = nc_filepb->PHB
         else
           T      = nc_file->T(time,:,:,:)
           P      = nc_file->P(time,:,:,:)
           PB     = nc_file->PB(time,:,:,:)
           QVAPOR = nc_file->QVAPOR(time,:,:,:)
           PH     = nc_file->PH(time,:,:,:)
           PHB    = nc_filepb->PHB(0,:,:,:)
         end if
         T = T + 300.
         P = P + PB
         QVAPOR = QVAPOR > 0.000
         PH    = ( PH + PHB ) / 9.81
         z = wrf_user_unstagger(PH,PH@stagger)

         tk = wrf_tk( P , T )    ; calculate TK
         slp   = wrf_slp( z, tk, P, QVAPOR )  ; calculate slp
         delete_VarAtts(T,(/"description","units"/))
         copy_VarAtts(T,slp)
       else
         ;; may be a met_em file - see if we can get PMSL
         if(isfilevar(nc_file,"PMSL")) then
           if ( time .eq. -1 ) then
             slp = nc_file->PMSL
           else
             slp = nc_file->PMSL(time,:,:)
           end if
         end if
       end if  

       return(slp)
  end if



  if( variable .eq. "rh" ) then
       if(isfilevar(nc_file,"T")) then
         ;; first compute theta - function wrf_tk needs theta and pressure (Pa) on input
         ;; THEN compute rh, using tk, p (Pa), QVAPOR
         if ( time .eq. -1 ) then
           T      = nc_file->T
           P      = nc_file->P
           PB     = nc_file->PB
           QVAPOR = nc_file->QVAPOR
         else
           T      = nc_file->T(time,:,:,:)
           P      = nc_file->P(time,:,:,:)
           PB     = nc_file->PB(time,:,:,:)
           QVAPOR = nc_file->QVAPOR(time,:,:,:)
         end if  
         T = T + 300.
         P  = P + PB
         QVAPOR = QVAPOR > 0.000
         tk = wrf_tk( P , T )
         rh = wrf_rh( QVAPOR, P, tk )
         delete_VarAtts(T,(/"description","units"/))
         copy_VarAtts(T,rh)
       else
         ;; may be a met_em file - see if we can get RH
         if(isfilevar(nc_file,"RH")) then
           if ( time .eq. -1 ) then
             rh = nc_file->RH
           else
             rh = nc_file->RH(time,:,:,:)
           end if
         end if
       end if  
       return(rh)
  end if



  if( variable .eq. "rh2" ) then
       if(isfilevar(nc_file,"T2")) then
         ;; Compute rh2, using T2, PSFC, Q2
         if ( time .eq. -1 ) then
           T2   = nc_file->T2
           PSFC = nc_file->PSFC
           Q2   = nc_file->Q2
         else
           T2   = nc_file->T2(time,:,:)
           PSFC = nc_file->PSFC(time,:,:)
           Q2   = nc_file->Q2(time,:,:)
         end if  
         Q2 = Q2 > 0.000
         tk = wrf_tk( PSFC , T2 )
         rh = wrf_rh( Q2, PSFC, tk )
         delete_VarAtts(T2,(/"description","units"/))
         copy_VarAtts(T2,rh)
         rh@description = "2m Relative Humidity"           
       else
         ;; may be a met_em file - see if we can get RH
         if(isfilevar(nc_file,"RH")) then
           print("Probably a met_em file - get lowerst level from RH field")
           if ( time .eq. -1 ) then
             rh2 = nc_file->RH(:,0,:,:)
           else
             rh2 = nc_file->RH(time,0,:,:)
           end if
         end if
       end if  
       return(rh)
  end if



  if( variable .eq. "pvo" ) then
       if ( time .eq. -1 ) then
         U    = nc_file->U
         V    = nc_file->V
         T    = nc_file->T
         P    = nc_file->P
         PB   = nc_file->PB
         MSFU = nc_file->MAPFAC_U
         MSFV = nc_file->MAPFAC_V
         MSFM = nc_file->MAPFAC_M
         COR  = nc_file->F
       else
         U    = nc_file->U(time,:,:,:)
         V    = nc_file->V(time,:,:,:)
         T    = nc_file->T(time,:,:,:)
         P    = nc_file->P(time,:,:,:)
         PB   = nc_file->PB(time,:,:,:)
         MSFU = nc_file->MAPFAC_U(time,:,:)
         MSFV = nc_file->MAPFAC_V(time,:,:)
         MSFM = nc_file->MAPFAC_M(time,:,:)
         COR  = nc_file->F(time,:,:)
       end if  
       T = T + 300.
       P = P + PB
       DX = nc_file@DX
       DY = nc_file@DY

       pvo = wrf_pvo( U, V, T, P, MSFU, MSFV, MSFM, COR, DX, DY, 0)

       delete_VarAtts(T,(/"description","units"/))
       copy_VarAtts(T,pvo)
       return(pvo)
  end if



  if( variable .eq. "avo" ) then
       if ( time .eq. -1 ) then
         U    = nc_file->U
         V    = nc_file->V
         MSFU = nc_file->MAPFAC_U
         MSFV = nc_file->MAPFAC_V
         MSFM = nc_file->MAPFAC_M
         COR  = nc_file->F
       else
         U    = nc_file->U(time,:,:,:)
         V    = nc_file->V(time,:,:,:)
         MSFU = nc_file->MAPFAC_U(time,:,:)
         MSFV = nc_file->MAPFAC_V(time,:,:)
         MSFM = nc_file->MAPFAC_M(time,:,:)
         COR  = nc_file->F(time,:,:)
       end if  
       DX = nc_file@DX
       DY = nc_file@DY

       avo = wrf_avo( U, V, MSFU, MSFV, MSFM, COR, DX, DY, 0)

       delete_VarAtts(COR,(/"description","units"/))
       copy_VarAtts(COR,avo)
       return(avo)
  end if



  if( variable .eq. "dbz" .or. variable .eq. "mdbz" ) then
       ; calculate dbz
       ivarint  = 0 
       iliqskin = 0
       dim_vars = dimsizes(varin)
       do idims = 1,dim_vars-1
         if ( idims .eq. 1 ) then
           if ( varin(idims) .eq. "1" ) then
             ivarint = 1
           end if
         end if
         if ( idims .eq. 2 ) then
           if ( varin(idims) .eq. "1" ) then
             iliqskin = 1
           end if
         end if
       end do

       if ( time .eq. -1 ) then
         T  = nc_file->T
         P  = nc_file->P
         PB = nc_filepb->PB
         qv = nc_file->QVAPOR
         qr = nc_file->QRAIN
         if(isfilevar(nc_file,"QSNOW"))
           qs = nc_file->QSNOW
         end if
         if(isfilevar(nc_file,"QGRAUP"))
           qg = nc_file->QGRAUP
         end if
       else
         T  = nc_file->T(time,:,:,:)
         P  = nc_file->P(time,:,:,:)
         PB = nc_filepb->PB(0,:,:,:)
         qv = nc_file->QVAPOR(time,:,:,:)
         qr = nc_file->QRAIN(time,:,:,:)
         if(isfilevar(nc_file,"QSNOW"))
           qs = nc_file->QSNOW(time,:,:,:)
         end if
         if(isfilevar(nc_file,"QGRAUP"))
           qg = nc_file->QGRAUP(time,:,:,:)
         end if
       end if
       T  = T + 300.
       P  = P + PB
       tk = wrf_tk( P , T )

       if ( .not. isvar("qs") ) then
         qs = qv
         qs = 0.0
       end if
       if ( .not. isvar("qg") ) then
         qg = qv
         qg = 0.0
       end if

       dbz = wrf_dbz ( P, tk, qv, qr, qs, qg, ivarint, iliqskin)
       delete(qs)
       delete(qg)

       delete_VarAtts(T,(/"description","units"/))
       copy_VarAtts(T,dbz)


       if ( variable .eq. "mdbz") then
         dims = getvardims(dbz)
         rank = dimsizes(dims)
         if ( rank .eq. 5 ) then
            mdbz = dim_max ( dbz($dims(0)$|:,$dims(1)$|:,$dims(3)$|:,$dims(4)$|:,$dims(2)$|:) )
            mdbz!0 = dbz!0
            mdbz!1 = dbz!1
         end if
         if ( rank .eq. 4 ) then
            mdbz = dim_max ( dbz($dims(0)$|:,$dims(2)$|:,$dims(3)$|:,$dims(1)$|:) )
            mdbz!0 = dbz!0
         end if
         if ( rank .eq. 3 ) then
            mdbz = dim_max ( dbz($dims(1)$|:,$dims(2)$|:,$dims(0)$|:) )
         end if
         nn = rank-1
         nm = rank-2
         mdbz!nm = dbz!nn
         nn = rank-2
         nm = rank-3
         mdbz!nm = dbz!nn
         copy_VarAtts(dbz,mdbz)
         mdbz@description = "Max Reflectivity"
         return(mdbz)
       else
         return(dbz)
       end if

  end if



  if( any( variable .eq. (/"cape_3d","cape_2d"/) ) ) then
       if ( time .eq. -1 ) then
         T  = nc_file->T
         P  = nc_file->P
         PB = nc_filepb->PB
         QV = nc_file->QVAPOR
         PH  = nc_file->PH
         PHB = nc_filepb->PHB
         HGT = nc_file->HGT
         PSFC = nc_file->PSFC
       else
         T  = nc_file->T(time,:,:,:)
         P  = nc_file->P(time,:,:,:)
         PB = nc_filepb->PB(0,:,:,:)
         QV = nc_file->QVAPOR(time,:,:,:)
         PH  = nc_file->PH(time,:,:,:)
         PHB = nc_filepb->PHB(0,:,:,:)
         HGT = nc_file->HGT(time,:,:)
         PSFC = nc_file->PSFC(time,:,:)
       end if
       T = T + 300.
       P  = P + PB 
       tk = wrf_tk( P , T )
       PH =  PH + PHB 
       z = wrf_user_unstagger(PH,PH@stagger)
       z = z/9.81

       if( variable .eq. "cape_3d" ) then
         cape = wrf_cape_3d( P, tk, QV, z, HGT, PSFC, True )
         cape@descriptsion = "cape ; cin"
       end if
       if( variable .eq. "cape_2d" ) then
         cape = wrf_cape_2d( P, tk, QV, z, HGT, PSFC, True )
         delete_VarAtts(T,(/"MemoryOrder"/))
         cape@MemoryOrder = "XY"
         cape@descriptsion = "mcape ; mcin ; lcl ; lfc"
       end if
       delete_VarAtts(T,(/"description","units"/))
       copy_VarAtts(T,cape)

       return(cape)
  end if



  if( any( variable .eq. (/"ter","HGT","HGT_M"/) ) ) then
    variable = "HGT" 
    if(.not. isfilevar(nc_file,"HGT")) then
      variable = "HGT_M"
    end if
  end if


  if( any( variable .eq. (/"lat","XLAT","XLAT_M"/) ) ) then
    variable = "XLAT" 
    if(.not. isfilevar(nc_file,"XLAT")) then
      variable = "XLAT_M"
    end if
  end if


  if( any( variable .eq. (/"lon","long","XLONG","XLONG_M"/) ) ) then
    variable = "XLONG" 
    if(.not. isfilevar(nc_file,"XLONG")) then
      variable = "XLONG_M"
    end if
  end if



;  end of diagnostic variable list - we must want a variable already in the file.  

  if ( time .eq. -1 ) then
    var = nc_file->$variable$
  else
    ;  check variable dimensionality and pull proper time  out of file
    ndims = dimsizes(filevardimsizes(nc_file,variable))
    if( ndims .eq. 4) then
      var = nc_file->$variable$(time,:,:,:)
    end if
    if( ndims .eq. 3) then
      var = nc_file->$variable$(time,:,:)
    end if
    if( ndims .eq. 2) then
      var = nc_file->$variable$(time,:)
    end if
    if( ndims .eq. 1) then
      var = nc_file->$variable$(time)
    end if
  end if

  return(var)

end


;--------------------------------------------------------------------------------

;------------------------------------------------------------------

;------------------------------------------------------------------

;------------------------------------------------------------------
;------------------------------------------------------------------

undef("reversevar")

function reversevar(x,ivar)

	local n,nx
	begin

	nx = dimsizes(x)
	n = dimsizes(nx)
	xrev=x

	if (n .eq. 1) then
		do i=0,nx-1
			xrev(i)=x(nx-1-i)
		end do
      	return(xrev)
	end if


	if ((n .eq. 2) .and. (ivar .eq. 0)) then
		do i=0,nx(ivar)-1
			xrev(i,:)=x(nx(ivar)-1-i,:)
		end do
      	return(xrev)
	end if

	if ((n .eq. 2) .and. (ivar .eq. 1)) then
		do i=0,nx(ivar)-1
			xrev(:,i)=x(:,nx(ivar)-1-i)
		end do
      	return(xrev)
	end if


	if ((n .eq. 3) .and. (ivar .eq. 0)) then
		do i=0,nx(ivar)-1
			xrev(i,:,:)=x(nx(ivar)-1-i,:,:)
		end do
      	return(xrev)
	end if

	if ((n .eq. 3) .and. (ivar .eq. 1)) then
		do i=0,nx(ivar)-1
			xrev(:,i,:)=x(:,nx(ivar)-1-i,:)
		end do
      	return(xrev)
	end if	

	if ((n .eq. 3) .and. (ivar .eq. 2)) then
		do i=0,nx(ivar)-1
			xrev(:,:,i)=x(:,:,nx(ivar)-1-i)
		end do
      	return(xrev)
	end if	



      	end


;------------------------------------------------------------------








