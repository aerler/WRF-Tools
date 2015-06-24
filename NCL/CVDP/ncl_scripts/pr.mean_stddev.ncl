; Calculates precipitation global means, zonal means, and standard deviations
;
; Variables used: pr
;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
load "ncl_scripts/functions.ncl"

begin
  print("Running pr.mean_stddev.ncl")
  
  SCALE_TIMESERIES = getenv("SCALE_TIMESERIES")  
  OUTPUT_DATA      = getenv("OUTPUT_DATA")  
  PNG_SCALE        = tofloat(getenv("PNG_SCALE"))
  OPT_CLIMO        = getenv("OPT_CLIMO")
  CLIMO_SYEAR      = toint(getenv("CLIMO_SYEAR"))
  CLIMO_EYEAR      = toint(getenv("CLIMO_EYEAR"))
  CLIMO_FILE       = getenv("CLIMO_FILE")
  OUTPUT_TYPE      = getenv("OUTPUT_TYPE") 
  COLORMAP         = getenv("COLORMAP")
  
  nsim = numAsciiRow("namelist_byvar/namelist_prect")
  na = asciiread("namelist_byvar/namelist_prect",(/nsim/),"string")
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
  wks_djf = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.mean_stddev.djf")
  wks_mam = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.mean_stddev.mam")
  wks_jja = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.mean_stddev.jja")
  wks_son = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.mean_stddev.son")
  wks_ann = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.mean_stddev.ann")
  wks_za_djf = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.za.djf")
  wks_za_mam = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.za.mam")
  wks_za_jja = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.za.jja")
  wks_za_son = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.za.son")   
  wks_za_ann = gsn_open_wks(wks_type,getenv("OUTDIR")+"pr.za.ann")  
  
  if (COLORMAP.eq.0) then
     gsn_define_colormap(wks_djf,"rainbow+white") 
     gsn_define_colormap(wks_mam,"rainbow+white")  
     gsn_define_colormap(wks_jja,"rainbow+white") 
     gsn_define_colormap(wks_son,"rainbow+white")  
     gsn_define_colormap(wks_ann,"rainbow+white")
     gsn_define_colormap(wks_za_djf,"cb_9step")  
     gsn_define_colormap(wks_za_mam,"cb_9step")  
     gsn_define_colormap(wks_za_jja,"cb_9step")  
     gsn_define_colormap(wks_za_son,"cb_9step")  
     gsn_define_colormap(wks_za_ann,"cb_9step")
  end if
  if (COLORMAP.eq.1) then
     gsn_define_colormap(wks_djf,"cb_rainbow") 
     gsn_define_colormap(wks_mam,"cb_rainbow")  
     gsn_define_colormap(wks_jja,"cb_rainbow") 
     gsn_define_colormap(wks_son,"cb_rainbow")  
     gsn_define_colormap(wks_ann,"cb_rainbow")
     gsn_define_colormap(wks_za_djf,"cb_9step")  
     gsn_define_colormap(wks_za_mam,"cb_9step")  
     gsn_define_colormap(wks_za_jja,"cb_9step")  
     gsn_define_colormap(wks_za_son,"cb_9step")  
     gsn_define_colormap(wks_za_ann,"cb_9step")
  end if

  

  plot_djf = new(nsim,"graphic")  
  plot_mam = new(nsim,"graphic")  
  plot_jja = new(nsim,"graphic")  
  plot_son = new(nsim,"graphic")   
  plot_ann = new(nsim,"graphic")  
  
  plot_za_djf = new(nsim,"graphic")  
  plot_za_mam = new(nsim,"graphic")  
  plot_za_jja = new(nsim,"graphic")  
  plot_za_son = new(nsim,"graphic")   
  plot_za_ann = new(nsim,"graphic")  
  
  if (isfilepresent("obs_pr")) then
     c1 = 1
  else
     c1 = 76
  end if  
  color = (/c1,2,6,11,5,3,7,15,23,31,39,47,55,63,71,79,c1,2,6,11,5,3,7,15,23,31,39,47,55,63,71,79,c1,2,6,11,5,3,7,15,23,31,39,47,55,63,71,79,c1,2/)   
  dash   = (/0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3/)   
  
  do ee = 0,nsim-1
     ppt = data_read_in(paths(ee),"PRECT",syear(ee),eyear(ee))    ; read in data, orient lats/lons correctly, set time coordinate variable up   
     if (isatt(ppt,"is_all_missing")) then
        delete(ppt)
        continue
     end if 
     ppt_seas = runave_n_Wrap(ppt,3,0,0)
     ppt_seas(0,:,:) = (/ dim_avg_n(ppt(:1,:,:),0) /)
     ppt_seas(dimsizes(ppt&time)-1,:,:) = (/ dim_avg_n(ppt(dimsizes(ppt&time)-2:,:,:),0) /)
     ppt_ann = runave_n_Wrap(ppt,12,0,0)
     delete(ppt)
     
     ppt_mean_djf = dim_avg_n_Wrap(ppt_seas(0::12,:,:),0)
     ppt_mean_mam = dim_avg_n_Wrap(ppt_seas(3::12,:,:),0)
     ppt_mean_jja = dim_avg_n_Wrap(ppt_seas(6::12,:,:),0)
     ppt_mean_son = dim_avg_n_Wrap(ppt_seas(9::12,:,:),0)
     ppt_mean_ann = dim_avg_n_Wrap(ppt_ann(5::12,:,:),0)
     
     ppt_zamean_djf = dim_avg_n_Wrap(ppt_mean_djf,1)
     ppt_zamean_mam = dim_avg_n_Wrap(ppt_mean_mam,1)
     ppt_zamean_jja = dim_avg_n_Wrap(ppt_mean_jja,1)
     ppt_zamean_son = dim_avg_n_Wrap(ppt_mean_son,1)
     ppt_zamean_ann = dim_avg_n_Wrap(ppt_mean_ann,1)
     
     ppt_sd_djf = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),ppt_seas(0::12,:,:),False,False,0),0)
     ppt_sd_mam = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),ppt_seas(3::12,:,:),False,False,0),0)
     ppt_sd_jja = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),ppt_seas(6::12,:,:),False,False,0),0)
     ppt_sd_son = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),ppt_seas(9::12,:,:),False,False,0),0)
     ppt_sd_ann = dim_stddev_n_Wrap(dtrend_msg_n(ispan(0,nyr(ee)-1,1),ppt_ann(5::12,:,:),False,False,0),0)
     
     copy_VarMeta(ppt_mean_djf,ppt_sd_djf)
     copy_VarMeta(ppt_mean_mam,ppt_sd_mam)
     copy_VarMeta(ppt_mean_jja,ppt_sd_jja)
     copy_VarMeta(ppt_mean_son,ppt_sd_son)
     copy_VarMeta(ppt_mean_ann,ppt_sd_ann)     
     
     delete([/ppt_seas,ppt_ann/])
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

        z->ppt_spatialmean_djf     = ppt_mean_djf
        z->ppt_spatialmean_mam     = ppt_mean_mam
        z->ppt_spatialmean_jja     = ppt_mean_jja
        z->ppt_spatialmean_son     = ppt_mean_son
        z->ppt_spatialmean_ann     = ppt_mean_ann
        
        z->ppt_spatialstddev_djf     = ppt_sd_djf
        z->ppt_spatialstddev_mam     = ppt_sd_mam
        z->ppt_spatialstddev_jja     = ppt_sd_jja
        z->ppt_spatialstddev_son     = ppt_sd_son
        z->ppt_spatialstddev_ann     = ppt_sd_ann
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
     res@cnLevels = (/.2,.4,.6,1.0,1.5,2.0,2.5,3.5/)
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
     sres@cnLevels  = (/2,6,10,14,18/)   
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
     res@gsnRightString = ppt_mean_djf@units
     res@gsnCenterString = names(ee)
     
     if (isfilepresent("obs_prect").and.ee.eq.0) then    ; for pattern correlation table
        patcor = new((/nsim,dimsizes(ppt_sd_ann&lat),dimsizes(ppt_sd_ann&lon)/),typeof(ppt_sd_ann))
        patcor!1 = "lat"
        patcor&lat = ppt_sd_ann&lat
        patcor!2 = "lon"
        patcor&lon = ppt_sd_ann&lon
        patcor(ee,:,:) = (/ ppt_sd_ann /)
     end if
     if (isfilepresent("obs_prect").and.ee.ge.1) then
        patcor(ee,:,:) = (/ linint2(ppt_sd_ann&lon,ppt_sd_ann&lat,ppt_sd_ann,True,patcor&lon,patcor&lat,0) /)
     end if
     
     
     plot_djf(ee) = gsn_csm_contour_map_overlay(wks_djf,ppt_sd_djf,ppt_mean_djf,res,sres)
     plot_mam(ee) = gsn_csm_contour_map_overlay(wks_mam,ppt_sd_mam,ppt_mean_mam,res,sres)
     plot_jja(ee) = gsn_csm_contour_map_overlay(wks_jja,ppt_sd_jja,ppt_mean_jja,res,sres)
     plot_son(ee) = gsn_csm_contour_map_overlay(wks_son,ppt_sd_son,ppt_mean_son,res,sres)
     plot_ann(ee) = gsn_csm_contour_map_overlay(wks_ann,ppt_sd_ann,ppt_mean_ann,res,sres)
     delete([/ppt_sd_djf,ppt_sd_mam,ppt_sd_jja,ppt_sd_son,ppt_sd_ann,ppt_mean_djf,ppt_mean_mam,ppt_mean_jja,ppt_mean_son,ppt_mean_ann/])
    
     zres = True
     zres@vpXF = 0.15
     zres@vpWidthF = 0.55
     zres@vpHeightF = 0.55
     zres@trYMinF = 0.
     zres@trYMaxF = 11.0
     zres@gsnDraw = False
     zres@gsnFrame = False
 
     zres@tmXTLabelFontHeightF = 0.018
     zres@tmXBLabelFontHeightF = 0.018
     zres@tmYLLabelFontHeightF = 0.018
     zres@tiMainString = ""
     zres@txFontHeightF = 0.015
     zres@xyLineLabelFontHeightF = 0.016
     zres@tiXAxisFontHeightF = 0.019
     zres@tiYAxisFontHeightF = 0.019
     zres@tiMainFontHeightF = 0.03
  
     zres@pmLegendDisplayMode    = "Never"
     zres@tiYAxisString = "mm day~S~-1~N~"
  
     zres@xyLineColor   =  "black"         
     zres@xyDashPattern = 0
     if (wks_type.eq."png") then
        zres@xyLineThicknessF = 3.5
        if (isfilepresent("obs_prect").and.ee.eq.0) then
           zres@xyLineThicknessF   = 7.
        end if
     else
        zres@xyLineThicknessF = 2.
        if (isfilepresent("obs_prect").and.ee.eq.0) then
           zres@xyLineThicknessF   = 4.
        end if
     end if
     
     zres@xyDashPattern = dash(mod(ee,50))
     zres@xyLineColor = color(mod(ee,50))
     zres@tiMainFont = "helvetica"
     
     polyres = True
     polyres@gsLineColor = color(mod(ee,50))
     polyres@gsLineThicknessF = zres@xyLineThicknessF
     polyres@gsLineDashPattern = dash(mod(ee,50))
     
     txres = True
     if (nsim.ge.36) then
       txres@txFontHeightF = 0.009
       yeval = .0175
     else
       txres@txFontHeightF = 0.012
       yeval = .02
     end if
     txres@txJust = "CenterLeft"
     
     zres@tiMainString = "PR Zonal Average (DJF)"
     zres@gsnRightString = "mm/day"
     plot_za_djf(ee) = gsn_csm_xy(wks_za_djf,ppt_zamean_djf&lat,ppt_zamean_djf,zres) 
     if (ee.ne.0) then
        overlay(plot_za_djf(0),plot_za_djf(ee))
     end if     
     gsn_text_ndc(wks_za_djf,names(ee),0.765,0.8-(ee*yeval),txres)
     gsn_polyline_ndc(wks_za_djf,(/0.72,.75/),(/0.8-(ee*yeval),0.8-(ee*yeval)/),polyres)
     
     zres@tiMainString = "PR Zonal Average (MAM)"
     plot_za_mam(ee) = gsn_csm_xy(wks_za_mam,ppt_zamean_mam&lat,ppt_zamean_mam,zres) 
     if (ee.ne.0) then
        overlay(plot_za_mam(0),plot_za_mam(ee))
     end if     
     gsn_text_ndc(wks_za_mam,names(ee),0.765,0.8-(ee*yeval),txres)
     gsn_polyline_ndc(wks_za_mam,(/0.72,.75/),(/0.8-(ee*yeval),0.8-(ee*yeval)/),polyres)
     
     zres@tiMainString = "PR Zonal Average (JJA)"
     plot_za_jja(ee) = gsn_csm_xy(wks_za_jja,ppt_zamean_jja&lat,ppt_zamean_jja,zres) 
     if (ee.ne.0) then
        overlay(plot_za_jja(0),plot_za_jja(ee))
     end if     
     gsn_text_ndc(wks_za_jja,names(ee),0.765,0.8-(ee*yeval),txres)
     gsn_polyline_ndc(wks_za_jja,(/0.72,.75/),(/0.8-(ee*yeval),0.8-(ee*yeval)/),polyres)
     
     zres@tiMainString = "PR Zonal Average (SON)"
     plot_za_son(ee) = gsn_csm_xy(wks_za_son,ppt_zamean_son&lat,ppt_zamean_son,zres) 
     if (ee.ne.0) then
        overlay(plot_za_son(0),plot_za_son(ee))
     end if     
     gsn_text_ndc(wks_za_son,names(ee),0.765,0.8-(ee*yeval),txres)
     gsn_polyline_ndc(wks_za_son,(/0.72,.75/),(/0.8-(ee*yeval),0.8-(ee*yeval)/),polyres)
     
     zres@tiMainString = "PR Zonal Average (ANN)"
     plot_za_ann(ee) = gsn_csm_xy(wks_za_ann,ppt_zamean_ann&lat,ppt_zamean_ann,zres) 
     if (ee.ne.0) then
        overlay(plot_za_ann(0),plot_za_ann(ee))
     end if     
     gsn_text_ndc(wks_za_ann,names(ee),0.765,0.8-(ee*yeval),txres)
     gsn_polyline_ndc(wks_za_ann,(/0.72,.75/),(/0.8-(ee*yeval),0.8-(ee*yeval)/),polyres)
     delete([/zres,polyres,txres,ppt_zamean_djf,ppt_zamean_mam,ppt_zamean_jja,ppt_zamean_son,ppt_zamean_ann/])
  end do    
  
   if (isfilepresent("obs_prect")) then    ; for pattern correlation table  
     clat = cos(0.01745329*patcor&lat)
     finpr   = "PR Std Dev (Ann)  "    ; Must be 18 characters long
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
  
  panres@txString = "PR Means / Standard Deviations (DJF)"
  gsn_panel(wks_djf,plot_djf,(/nrow,ncol/),panres)
  delete(wks_djf)
  
  panres@txString = "PR Means / Standard Deviations (MAM)"
  gsn_panel(wks_mam,plot_mam,(/nrow,ncol/),panres)
  delete(wks_mam)
  
  panres@txString = "PR Means / Standard Deviations (JJA)"
  gsn_panel(wks_jja,plot_jja,(/nrow,ncol/),panres)
  delete(wks_jja)
  
  panres@txString = "PR Means / Standard Deviations (SON)"
  gsn_panel(wks_son,plot_son,(/nrow,ncol/),panres)
  delete(wks_son)
  
  panres@txString = "PR Means / Standard Deviations (Annual)"
  gsn_panel(wks_ann,plot_ann,(/nrow,ncol/),panres)
  delete(wks_ann)
  delete(panres)
  
  draw(plot_za_djf(0))
  frame(wks_za_djf)
  delete(wks_za_djf)
  
  draw(plot_za_mam(0))
  frame(wks_za_mam)
  delete(wks_za_mam)
  
  draw(plot_za_jja(0))
  frame(wks_za_jja)
  delete(wks_za_jja)
  
  draw(plot_za_son(0))
  frame(wks_za_son)
  delete(wks_za_son)
  
  draw(plot_za_ann(0))
  frame(wks_za_ann)
  delete(wks_za_ann)
end
