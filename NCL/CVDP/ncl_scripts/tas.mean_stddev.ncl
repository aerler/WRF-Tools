; Calculates 2m air temperature global means and standard deviations
;
; Variables used: TREFHT (TAS)
;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
load "ncl_scripts/functions.ncl"

begin
  print("Running tas.mean_stddev.ncl")
  
  SCALE_TIMESERIES = getenv("SCALE_TIMESERIES")  
  OUTPUT_DATA      = getenv("OUTPUT_DATA")  
  PNG_SCALE        = tofloat(getenv("PNG_SCALE"))
  OPT_CLIMO        = getenv("OPT_CLIMO")
  CLIMO_SYEAR      = toint(getenv("CLIMO_SYEAR"))
  CLIMO_EYEAR      = toint(getenv("CLIMO_EYEAR"))
  OUTPUT_TYPE      = getenv("OUTPUT_TYPE") 
  COLORMAP         = getenv("COLORMAP")
  
  nsim = numAsciiRow("namelist_byvar/namelist_trefht")
  na = asciiread("namelist_byvar/namelist_trefht",(/nsim/),"string")
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
  wks_djf = gsn_open_wks(wks_type,getenv("OUTDIR")+"tas.mean_stddev.djf")
  wks_mam = gsn_open_wks(wks_type,getenv("OUTDIR")+"tas.mean_stddev.mam")
  wks_jja = gsn_open_wks(wks_type,getenv("OUTDIR")+"tas.mean_stddev.jja")
  wks_son = gsn_open_wks(wks_type,getenv("OUTDIR")+"tas.mean_stddev.son")
  wks_ann = gsn_open_wks(wks_type,getenv("OUTDIR")+"tas.mean_stddev.ann")
  
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
     tas = data_read_in(paths(ee),"TREFHT",syear(ee),eyear(ee))    ; read in data, orient lats/lons correctly, set time coordinate variable up   
     if (isatt(tas,"is_all_missing")) then
        delete(tas)
        continue
     end if 
     tas_seas = runave_n_Wrap(tas,3,0,0)
     tas_seas(0,:,:) = (/ dim_avg_n(tas(:1,:,:),0) /)
     tas_seas(dimsizes(tas&time)-1,:,:) = (/ dim_avg_n(tas(dimsizes(tas&time)-2:,:,:),0) /)
     tas_ann = runave_n_Wrap(tas,12,0,0)
     delete(tas)
     
     tas_mean_djf = dim_avg_n_Wrap(tas_seas(0::12,:,:),0)
     tas_mean_mam = dim_avg_n_Wrap(tas_seas(3::12,:,:),0)
     tas_mean_jja = dim_avg_n_Wrap(tas_seas(6::12,:,:),0)
     tas_mean_son = dim_avg_n_Wrap(tas_seas(9::12,:,:),0)
     tas_mean_ann = dim_avg_n_Wrap(tas_ann(5::12,:,:),0)
     
     tas_sd_djf = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),tas_seas(0::12,:,:),False,False,0),0)
     tas_sd_mam = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),tas_seas(3::12,:,:),False,False,0),0)
     tas_sd_jja = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),tas_seas(6::12,:,:),False,False,0),0)
     tas_sd_son = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),tas_seas(9::12,:,:),False,False,0),0)
     tas_sd_ann = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),tas_ann(5::12,:,:),False,False,0),0)
     
     copy_VarMeta(tas_mean_djf,tas_sd_djf)
     copy_VarMeta(tas_mean_mam,tas_sd_mam)
     copy_VarMeta(tas_mean_jja,tas_sd_jja)
     copy_VarMeta(tas_mean_son,tas_sd_son)
     copy_VarMeta(tas_mean_ann,tas_sd_ann)
     
     delete([/tas_seas,tas_ann/])
     
     if (OUTPUT_DATA.eq."True") then
        modname = str_sub_str(names(ee)," ","_")
        fn = getenv("OUTDIR")+modname+".cvdp_data."+syear(ee)+"-"+eyear(ee)+".nc"
        if (.not.isfilepresent(fn)) then
           z = addfile(fn,"c")
           z@source = systemfunc("pwd")+"/"+get_script_name()
           z@notes = "Data from "+names(ee)+" from "+syear(ee)+"-"+eyear(ee)
           if (OPT_CLIMO.eq."Full") then
              z@climatology = syear(ee)+"-"+eyear(ee)+" climatology removed prior to all calculations (other than means)"
           else
              z@climatology = CLIMO_SYEAR+"-"+CLIMO_EYEAR+" climatology removed prior to all calculations (other than means)"
           end if
        else
           z = addfile(fn,"w")
        end if

        z->tas_spatialmean_djf     = tas_mean_djf
        z->tas_spatialmean_mam     = tas_mean_mam
        z->tas_spatialmean_jja     = tas_mean_jja
        z->tas_spatialmean_son     = tas_mean_son
        z->tas_spatialmean_ann     = tas_mean_ann
        
        z->tas_spatialstddev_djf     = tas_sd_djf
        z->tas_spatialstddev_mam     = tas_sd_mam
        z->tas_spatialstddev_jja     = tas_sd_jja
        z->tas_spatialstddev_son     = tas_sd_son
        z->tas_spatialstddev_ann     = tas_sd_ann
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
     res@mpFillOn = False
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
     res@cnLevels = fspan(.4,3.2,8)
     if (COLORMAP.eq.0) then
        res@cnFillColors = (/54,80,95,125,175,185,195,205,236/)
     end if
     if (COLORMAP.eq.1) then
        res@cnFillColors = (/35,47,63,79,95,111,124,155,175/)
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
     sres@cnLevels  = ispan(-80,40,4)    
     sres@cnLinesOn = True
     sres@gsnDraw   = False
     sres@gsnFrame  = False
     sres@tiMainOn = False
     sres@cnInfoLabelOn = False
     sres@cnLineColor = "white"
     sres@cnLineLabelsOn = True
     sres@cnLineLabelsOn = True
     sres@cnLineDashSegLenF          = 0.18          ; assist in controlling concentration
     sres@cnLineLabelInterval        = 2             ; default = 2
     sres@cnLineLabelPlacementMode   = "constant"    ; choose constant label method
     sres@cnLineLabelFontColor = "white"
     if (nsim.le.5) then
        sres@cnLineLabelFontHeightF = 0.010
     else
        sres@cnLineLabelFontHeightF = 0.018
     end if
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
     res@gsnRightString = tas_mean_djf@units
     res@gsnCenterString = names(ee)
     
     plot_djf(ee) = gsn_csm_contour_map_overlay(wks_djf,tas_sd_djf,tas_mean_djf,res,sres)
     plot_mam(ee) = gsn_csm_contour_map_overlay(wks_mam,tas_sd_mam,tas_mean_mam,res,sres)
     plot_jja(ee) = gsn_csm_contour_map_overlay(wks_jja,tas_sd_jja,tas_mean_jja,res,sres)
     plot_son(ee) = gsn_csm_contour_map_overlay(wks_son,tas_sd_son,tas_mean_son,res,sres)
     plot_ann(ee) = gsn_csm_contour_map_overlay(wks_ann,tas_sd_ann,tas_mean_ann,res,sres)
     delete([/tas_sd_djf,tas_sd_mam,tas_sd_jja,tas_sd_son,tas_sd_ann,tas_mean_djf,tas_mean_mam,tas_mean_jja,tas_mean_son,tas_mean_ann/])
  end do     
     
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
  
  panres@txString = "TAS Means / Standard Deviations (DJF)"
  gsn_panel(wks_djf,plot_djf,(/nrow,ncol/),panres)
  delete(wks_djf)
  
  panres@txString = "TAS Means / Standard Deviations (MAM)"
  gsn_panel(wks_mam,plot_mam,(/nrow,ncol/),panres)
  delete(wks_mam)
  
  panres@txString = "TAS Means / Standard Deviations (JJA)"
  gsn_panel(wks_jja,plot_jja,(/nrow,ncol/),panres)
  delete(wks_jja)
  
  panres@txString = "TAS Means / Standard Deviations (SON)"
  gsn_panel(wks_son,plot_son,(/nrow,ncol/),panres)
  delete(wks_son)
  
  panres@txString = "TAS Means / Standard Deviations (Annual)"
  gsn_panel(wks_ann,plot_ann,(/nrow,ncol/),panres)
  delete(wks_ann)
  delete(panres)
end
