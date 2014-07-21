; Calculates SST global means and standard deviations
;
; Variables used: TS
;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
load "ncl_scripts/functions.ncl"

begin
  print("Running sst.mean_stddev.ncl")
  
  SCALE_TIMESERIES = getenv("SCALE_TIMESERIES")  
  OUTPUT_DATA      = getenv("OUTPUT_DATA")  
  PNG_SCALE        = tofloat(getenv("PNG_SCALE"))
  OPT_CLIMO        = getenv("OPT_CLIMO")
  CLIMO_SYEAR      = toint(getenv("CLIMO_SYEAR"))
  CLIMO_EYEAR      = toint(getenv("CLIMO_EYEAR"))
  CLIMO_FILE       = getenv("CLIMO_FILE")
  OUTPUT_TYPE      = getenv("OUTPUT_TYPE") 
  COLORMAP         = getenv("COLORMAP")
  
  nsim = numAsciiRow("namelist_byvar/namelist_ts")
  na = asciiread("namelist_byvar/namelist_ts",(/nsim/),"string")
  names = new(nsim,"string")
  paths = new(nsim,"string")
  syear = new(nsim,"integer",-999)
  eyear = new(nsim,"integer",-999)
  delim = "|"

  do gg = 0,nsim-1
     names(gg) = str_strip(str_get_field(na(gg),1,delim))
     paths(gg) = str_strip(str_get_field(na(gg),2,delim))
     syear(gg) = stringtointeger(str_strip(str_get_field(na(gg),3,delim)))
     eyear(gg) = stringtointeger(str_strip(str_get_field(na(gg),4,delim)))
  end do
  nyr = eyear-syear+1
  nyr_max = max(nyr)
  
  wks_type = OUTPUT_TYPE
  if (wks_type.eq."png") then
     wks_type@wkWidth = 1500*PNG_SCALE
     wks_type@wkHeight = 1500*PNG_SCALE
  end if
  wks_djf = gsn_open_wks(wks_type,getenv("OUTDIR")+"sst.mean_stddev.djf")
  wks_mam = gsn_open_wks(wks_type,getenv("OUTDIR")+"sst.mean_stddev.mam")
  wks_jja = gsn_open_wks(wks_type,getenv("OUTDIR")+"sst.mean_stddev.jja")
  wks_son = gsn_open_wks(wks_type,getenv("OUTDIR")+"sst.mean_stddev.son")
  wks_ann = gsn_open_wks(wks_type,getenv("OUTDIR")+"sst.mean_stddev.ann")
  
  if (COLORMAP.eq.0) then
     gsn_define_colormap(wks_djf,"rainbow+white") 
     gsn_define_colormap(wks_mam,"rainbow+white")  
     gsn_define_colormap(wks_jja,"rainbow+white") 
     gsn_define_colormap(wks_son,"rainbow+white")  
     gsn_define_colormap(wks_ann,"rainbow+white")
  end if
  if (COLORMAP.eq.1) then
     gsn_define_colormap(wks_djf,"cb_rainbow") 
     gsn_define_colormap(wks_mam,"cb_rainbow")  
     gsn_define_colormap(wks_jja,"cb_rainbow") 
     gsn_define_colormap(wks_son,"cb_rainbow")  
     gsn_define_colormap(wks_ann,"cb_rainbow")
  end if

  plot_djf = new(nsim,"graphic")  
  plot_mam = new(nsim,"graphic")  
  plot_jja = new(nsim,"graphic")  
  plot_son = new(nsim,"graphic")   
  plot_ann = new(nsim,"graphic")  
  do ee = 0,nsim-1
     sst = data_read_in(paths(ee),"TS",syear(ee),eyear(ee))    ; read in data, orient lats/lons correctly, set time coordinate variable up
     if (isatt(sst,"is_all_missing")) then
        delete(sst)
        continue
     end if 
     if (isfilepresent("obs_ts").and.ee.eq.0) then   ; mask out land in array going into EOF functions
     else
        sst = where(sst.le.-1.8,-1.8,sst)
        d = addfile("$NCARG_ROOT/lib/ncarg/data/cdf/landsea.nc","r")   
        basemap = d->LSMASK
        lsm = landsea_mask(basemap,sst&lat,sst&lon)
        sst = mask(sst,conform(sst,lsm,(/1,2/)).ge.1,False)
;        printStatInfo(sst)
        delete([/lsm,basemap/])
        delete(d)
     end if    
     sst_seas = runave_n_Wrap(sst,3,0,0)
     sst_seas(0,:,:) = (/ dim_avg_n(sst(:1,:,:),0) /)
     sst_seas(dimsizes(sst&time)-1,:,:) = (/ dim_avg_n(sst(dimsizes(sst&time)-2:,:,:),0) /)
     sst_ann = runave_n_Wrap(sst,12,0,0)
     delete(sst)
     
     sst_mean_djf = dim_avg_n_Wrap(sst_seas(0::12,:,:),0)
     sst_mean_mam = dim_avg_n_Wrap(sst_seas(3::12,:,:),0)
     sst_mean_jja = dim_avg_n_Wrap(sst_seas(6::12,:,:),0)
     sst_mean_son = dim_avg_n_Wrap(sst_seas(9::12,:,:),0)
     sst_mean_ann = dim_avg_n_Wrap(sst_ann(5::12,:,:),0)
     
     sst_sd_djf = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),sst_seas(0::12,:,:),False,False,0),0)
     sst_sd_mam = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),sst_seas(3::12,:,:),False,False,0),0)
     sst_sd_jja = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),sst_seas(6::12,:,:),False,False,0),0)
     sst_sd_son = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),sst_seas(9::12,:,:),False,False,0),0)
     sst_sd_ann = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),sst_ann(5::12,:,:),False,False,0),0)

     copy_VarMeta(sst_mean_djf,sst_sd_djf)
     copy_VarMeta(sst_mean_mam,sst_sd_mam)
     copy_VarMeta(sst_mean_jja,sst_sd_jja)
     copy_VarMeta(sst_mean_son,sst_sd_son)
     copy_VarMeta(sst_mean_ann,sst_sd_ann)

     delete([/sst_seas,sst_ann/])
     
     if (OUTPUT_DATA.eq."True") then
        modname = str_sub_str(names(ee)," ","_")
        fn = getenv("OUTDIR")+modname+".cvdp_data."+syear(ee)+"-"+eyear(ee)+".nc"
        if (.not.isfilepresent(fn)) then
           z = addfile(fn,"c")
           z@source = systemfunc("pwd")+"/"+get_script_name()
           z@notes = "Data from "+names(ee)+" from "+syear(ee)+"-"+eyear(ee)
           if (OPT_CLIMO.eq."Full") then
              z@climatology = syear(ee)+"-"+eyear(ee)+" climatology removed prior to all calculations (other than means)"
           else if (OPT_CLIMO.eq."External") then
              z@climatology = "An external climatology from "+CLIMO_SYEAR+"-"+CLIMO_EYEAR+" was removed prior to all calculations (other than means)"  
              z@clim_file = CLIMO_FILE
           else
              z@climatology = CLIMO_SYEAR+"-"+CLIMO_EYEAR+" climatology removed prior to all calculations (other than means)"
           end if
           end if
        else
           z = addfile(fn,"w")
        end if

        z->sst_spatialmean_djf     = sst_mean_djf
        z->sst_spatialmean_mam     = sst_mean_mam
        z->sst_spatialmean_jja     = sst_mean_jja
        z->sst_spatialmean_son     = sst_mean_son
        z->sst_spatialmean_ann     = sst_mean_ann
        
        z->sst_spatialstddev_djf     = sst_sd_djf
        z->sst_spatialstddev_mam     = sst_sd_mam
        z->sst_spatialstddev_jja     = sst_sd_jja
        z->sst_spatialstddev_son     = sst_sd_son
        z->sst_spatialstddev_ann     = sst_sd_ann
        delete(z)
     end if
;==========================================================================================
     res = True
     res@mpProjection = "WinkelTripel"
     res@mpGeophysicalLineColor = "gray42"
     res@mpPerimOn    = False
     res@mpGridLatSpacingF =  90            ; change latitude  line spacing
     res@mpGridLonSpacingF = 180.           ; change longitude line spacing
     res@mpGridLineColor   = "transparent"  ; trick ncl into drawing perimeter
     res@mpGridAndLimbOn   = True           ; turn on lat/lon lines  
     
     res@mpCenterLonF = 210.
     res@mpOutlineOn = True  
     res@mpDataSetName = "Earth..4"
     res@gsnDraw      = False
     res@gsnFrame     = False
  
     res@cnLineLabelsOn = False
     res@cnFillOn        = True
     res@cnLinesOn       = False
     res@lbLabelBarOn    = False

     res@cnLevelSelectionMode = "ExplicitLevels"
     res@cnLevels = fspan(.2,1.6,8)
     if (COLORMAP.eq.0) then
        res@cnFillColors = (/54,80,95,125,175,185,195,205,236/)
        res@mpLandFillColor = "gray75"
     end if
     if (COLORMAP.eq.1) then
        res@cnFillColors = (/35,47,63,79,95,111,124,155,175/)
        res@mpLandFillColor = "gray30"
     end if

     res@gsnLeftStringOrthogonalPosF = -0.05
     res@gsnLeftStringParallelPosF = .005
     res@gsnRightStringOrthogonalPosF = -0.05
     res@gsnRightStringParallelPosF = 0.96
     res@gsnRightString = ""
     res@gsnLeftString = ""
     res@gsnLeftStringFontHeightF = 0.014
     res@gsnCenterStringFontHeightF = 0.018
     res@gsnRightStringFontHeightF = 0.014

     sres = True
     sres@cnLevelSelectionMode = "ExplicitLevels"
     sres@cnLevels  = fspan(5.,31.,14)     ;13)
     sres@cnLinesOn = True
     sres@gsnDraw   = False
     sres@gsnFrame  = False
     sres@tiMainOn = False
     sres@cnInfoLabelOn = False
     sres@cnLineColor = "white"
     sres@cnMonoLineThickness = False
     tarr = new(dimsizes(sres@cnLevels),float)
     if (wks_type.eq."png") then
        tarr = 2.
        tarr(10:11) = 4.
        tarr(12:) = 6.
     else
        tarr = 1.
        tarr(10:11) = 2.
        tarr(12:) = 3.
     end if
     sres@cnLineThicknesses = tarr
     sres@cnLineLabelsOn = True
     sres@cnLineDashSegLenF          = 0.18          ; assist in controlling concentration
     sres@cnLineLabelInterval        = 2             ; default = 2
     sres@cnLineLabelPlacementMode   = "constant"    ; choose constant label method
     sres@cnLineLabelFontColor = "white"
     sres@cnLineDrawOrder = "PostDraw"
     sres@cnLabelDrawOrder = sres@cnLineDrawOrder

     if (wks_type.eq."png") then
        sres@cnLineThicknessF   = 2.
        res@mpGeophysicalLineThicknessF = 2.  
     else
        sres@cnLineThicknessF   = 1.
        res@mpGeophysicalLineThicknessF = 1.  
     end if
     
     res@gsnLeftString = syear(ee)+"-"+eyear(ee) 
     res@gsnRightString = sst_mean_djf@units
     res@gsnCenterString = names(ee)
     
     if (isfilepresent("obs_ts").and.ee.eq.0) then    ; for pattern correlation table
        patcor = new((/nsim,dimsizes(sst_sd_ann&lat),dimsizes(sst_sd_ann&lon)/),typeof(sst_sd_ann))
        patcor!1 = "lat"
        patcor&lat = sst_sd_ann&lat
        patcor!2 = "lon"
        patcor&lon = sst_sd_ann&lon
        patcor(ee,:,:) = (/ sst_sd_ann /)
     end if
     if (isfilepresent("obs_ts").and.ee.ge.1) then
        patcor(ee,:,:) = (/ linint2(sst_sd_ann&lon,sst_sd_ann&lat,sst_sd_ann,True,patcor&lon,patcor&lat,0) /)
     end if
     
     plot_djf(ee) = gsn_csm_contour_map_overlay(wks_djf,sst_sd_djf,sst_mean_djf,res,sres)
     plot_mam(ee) = gsn_csm_contour_map_overlay(wks_mam,sst_sd_mam,sst_mean_mam,res,sres)
     plot_jja(ee) = gsn_csm_contour_map_overlay(wks_jja,sst_sd_jja,sst_mean_jja,res,sres)
     plot_son(ee) = gsn_csm_contour_map_overlay(wks_son,sst_sd_son,sst_mean_son,res,sres)
     plot_ann(ee) = gsn_csm_contour_map_overlay(wks_ann,sst_sd_ann,sst_mean_ann,res,sres)
     delete([/sst_sd_djf,sst_sd_mam,sst_sd_jja,sst_sd_son,sst_sd_ann,sst_mean_djf,sst_mean_mam,sst_mean_jja,sst_mean_son,sst_mean_ann/])
  end do     
  
  if (isfilepresent("obs_ts")) then    ; for pattern correlation table  
     clat = cos(0.01745329*patcor&lat)
     finpr   = "SST Std Dev (Ann) "    ; Must be 18 characters long
     line3   = "                  "    ; Must be 18 characters long
     line4   = line3
     do hh = 1,nsim-1
        dimY = dimsizes(tochar(names(hh)))
        nchar = dimY
        nchar = where(nchar.le.10,10,nchar)
        if (dimY.lt.10) then
           ntb = ""
           do ii = 0,10-dimY-1
              ntb = ntb+" "
           end do
           ntb = ntb+names(hh)
        else
           ntb = names(hh)
        end if
        
        ntc = ""
        do ii = 0,nchar-1
           ntc = ntc+"-"
        end do
        format2 = "%"+(nchar-5+1)+".2f"
        format3 = "%4.2f"
        line3 = line3+" "+ntb   
        line4 = line4+" "+ntc 
        if (all(ismissing(patcor(hh,:,:)))) then
           finpr = finpr+sprintf(format2,9.99)+"/"+sprintf(format3,9.99)
        else
           finpr = finpr+sprintf(format2,(pattern_cor(patcor(0,:,:),patcor(hh,:,:),clat,0)))+"/"+sprintf(format3,(dim_rmsd(ndtooned(NewCosWeight(patcor(0,:,:))),ndtooned(NewCosWeight(patcor(hh,:,:))))))
        end if
     end do
     if (.not.isfilepresent(getenv("OUTDIR")+"metrics_orig.txt")) then
        header = (/"","Pattern Correlations/RMS Differences   Observations vs. Model(s)",""/)
        write_table(getenv("OUTDIR")+"metrics_orig.txt","w",[/header/],"%s")
        write_table(getenv("OUTDIR")+"metrics_orig.txt","a",[/line3/],"%s")
        write_table(getenv("OUTDIR")+"metrics_orig.txt","a",[/line4/],"%s")
        delete(header)
     end if
     write_table(getenv("OUTDIR")+"metrics_orig.txt","a",[/finpr/],"%s")
     delete([/finpr,line3,line4,format2,format3,nchar,ntc,clat,patcor,dimY,ntb/])
  end if
     
  panres = True
  panres@gsnMaximize = True
  panres@gsnPaperOrientation = "portrait"
  panres@gsnPanelLabelBar = True
  panres@gsnPanelYWhiteSpacePercent = 3.0
  panres@pmLabelBarHeightF = 0.05
  panres@pmLabelBarWidthF = 0.65
  panres@lbTitleOn = False
  panres@lbBoxLineColor = "gray70"
  if (nsim.le.5) then
     panres@txFontHeightF = 0.024
  else
     panres@txFontHeightF = 0.016
  end if
  panres@lbLabelFontHeightF = 0.013
  panres@lbLabelStride = 1
  ncol = floattointeger(sqrt(nsim))
  nrow = (nsim/ncol)+mod(nsim,ncol)  
  
  panres@txString = "TS Means / Standard Deviations (DJF)"
  gsn_panel(wks_djf,plot_djf,(/nrow,ncol/),panres)
  delete(wks_djf)
  
  panres@txString = "TS Means / Standard Deviations (MAM)"
  gsn_panel(wks_mam,plot_mam,(/nrow,ncol/),panres)
  delete(wks_mam)
  
  panres@txString = "TS Means / Standard Deviations (JJA)"
  gsn_panel(wks_jja,plot_jja,(/nrow,ncol/),panres)
  delete(wks_jja)
  
  panres@txString = "TS Means / Standard Deviations (SON)"
  gsn_panel(wks_son,plot_son,(/nrow,ncol/),panres)
  delete(wks_son)
  
  panres@txString = "TS Means / Standard Deviations (Annual)"
  gsn_panel(wks_ann,plot_ann,(/nrow,ncol/),panres)
  delete(wks_ann)
  delete(panres)
end
