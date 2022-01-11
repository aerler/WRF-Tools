#!/usr/bin/python

# ===============================================================================
# === Script to fix ERA5-jpeg-compressed-grib2-produced intermediate files,   ===
# === by fixing the SEAICE missing values (originally +9999, corrected value  ===
# === -1E30) and start lon and start lat values (values get slightly altered  ===
# === during making of grib2 files from grib1 files. We replace the altered   ===
# === values by the original ones).                                           === 
# ===                                                                         ===
# === Created on 2022-01-04.                                                  ===
# ===                                                                         ===
# === Author: Mani Mahdinia                                                   ===
# ===============================================================================    


# =================================================================================
# =================================== Imports =====================================
# =================================================================================

import os
from sys import argv
import pygrib
import numpy as np
import pywinter.winter as pyw


# =================================================================================
# ================================ Pre-requisites =================================
# =================================================================================

pfx_f = "FILE-F:"                                                              # Pywinter output IM file prefix.
fileout = "FILEOUT"                                                            # Output file name ("FILEOUT"'s a convention in pyWPS).
SEAICE_fill_missing = -1E30                                                    # Value to use to fill SEAICE missing points.
[stlat_a, stlon_a] = [86.95000457763672,-199.20001220703125]                   # Correct (grib1) IM start lat and start lon. 
sl_layers = ['000007','007028','028100','100289']                              # Soil layers (cm-cm).
plevs = np.array([                                                             # Grib pressure levels (Pa).
  100000.0, 97500.0, 95000.0, 92500.0, 90000.0, 87500.0, 85000.0, 82500.0,               
  80000.0,  77500.0, 75000.0, 70000.0, 65000.0, 60000.0, 55000.0, 50000.0, 
  45000.0,  40000.0, 35000.0, 30000.0, 25000.0, 22500.0, 20000.0, 17500.0, 
  15000.0,  12500.0, 10000.0, 7000.0,  5000.0,  3000.0,  2000.0,  1000.0, 
  700.0,    500.0,   300.0,   200.0,   100.0])          


# ===============================================================================
# ================================= Main program ================================
# ===============================================================================
    
if __name__ == '__main__':

  # Retreive date and pl and sl grib files' and IM file's names (and paths)  
  IMDate = argv[1]
  Grb_pl = argv[2]
  Grb_sl = argv[3]
  IMF = argv[4]
  
  # Prompt on screen
  print('\n================================== Processing ' + IMDate + ' ==================================')
  
  # Open IM file
  interf = pyw.rinter(IMF)
    
  # Display keys
  print('\nInput IM keys =',interf.keys())  
  
  # Get IM SEAICE values
  IM_SEAICE = interf['SEAICE'].val
  
  # Open grib SL file & read seaice values
  grbs = pygrib.open(Grb_sl)
  grb = grbs.select(name='Sea ice area fraction')[0]
  GRB_SEAICE = grb.values
  
  # Check that IM_SEAICE and GRB_SEAICE arrays are the same shape
  if (IM_SEAICE.shape!=GRB_SEAICE.shape):
    raise ValueError("IM_SEAICE.shape!=GRB_SEAICE.shape. "
      "Intermediate and grib SEAICE arrays should be the same size.") 
  
  # Retreive stalt and stlon
  stlat = interf['UU'].geoinfo['STARTLAT']
  stlon = interf['UU'].geoinfo['STARTLON']
  dlat = interf['UU'].geoinfo['DELTALAT']
  dlon = interf['UU'].geoinfo['DELTALON']   
  # NOTE: Here we assume all fields have the same stlat, etc.
  
  # Fix stlat and stlon values, if needed 
  if ((stlat!=stlat_a) or (stlon!=stlon_a)):
    stlat = stlat_a
    stlon = stlon_a
    print('\nstlat,stlon != stlat_a.stlon_a, so fixed the values.') 
    
  # Fix IM sea ice values
  SEAICE = np.array(IM_SEAICE,copy=True) 
  SEAICE[GRB_SEAICE.mask==True] = SEAICE_fill_missing
  print('\nFixed seaice missing values.') 
  
  # Setup geo
  geo = pyw.Geo0(stlat,stlon,dlat,dlon)
    
  # Gather all non-soil variables
  landsea = pyw.V2d('LANDSEA',interf['LANDSEA'].val,'Land/Sea flag','0/1 Flag','200100')
  tt = pyw.V3dp('TT',interf['TT'].val,plevs)
  snow = pyw.V2d('SNOW',interf['SNOW'].val,'Water Equivalent of Accumulated Snow Depth','kg m-2','200100')
  ght = pyw.V3dp('GHT',interf['GHT'].val,plevs)
  sst = pyw.V2d('SST',interf['SST'].val,'Sea-Surface Temperature','K','200100')
  dewpt = pyw.V2d('DEWPT',interf['DEWPT'].val,'At 2 m','K','200100')
  uu = pyw.V3dp('UU',interf['UU'].val,plevs)
  psfc = pyw.V2d('PSFC',interf['PSFC'].val,'Surface Pressure','Pa','200100')
  seaice = pyw.V2d('SEAICE',SEAICE,'Sea-Ice Fraction','fraction','200100')
  pmsl = pyw.V2d('PMSL',interf['PMSL'].val,'Sea-level Pressure','Pa','201300')
  skintemp = pyw.V2d('SKINTEMP',interf['SKINTEMP'].val,'Sea-Surface Temperature','K','200100')
  rh = pyw.V3dp('RH',interf['RH'].val,plevs)
  vv = pyw.V3dp('VV',interf['VV'].val,plevs)
  snowh = pyw.V2d('SNOWH',interf['SNOWH'].val,'Physical Snow Depth','m','200100')
  tt2m = pyw.V2d('TT',interf['TT2M'].val,'Temperature','K','200100')
  rh2m = pyw.V2d('RH',interf['RH2M'].val,'Relative Humidity','%','200100')
  uu10m = pyw.V2d('UU',interf['UU10M'].val,'U','m s-1','200100')
  vv10m = pyw.V2d('VV',interf['VV10M'].val,'V','m s-1','200100')
  
  # Gather soil variables
  st = pyw.Vsl('ST',interf['ST'].val,sl_layers)
  sm = pyw.Vsl('SM',interf['SM'].val,sl_layers)
  
  # Assemble all variables into one variable
  total_fields = [st,landsea,tt,snow,ght,sst,dewpt,uu,psfc,seaice,sm,pmsl,skintemp,rh,vv,snowh,tt2m,rh2m,uu10m,vv10m]
    
  # Write output IM file
  print('\nWriting new IM file:')
  pyw.cinter(pfx_f[:-1],IMDate,geo,total_fields,'./')   
  
  # Rename output file
  os.rename(pfx_f+IMDate,fileout) 
  
  

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
  
  
  
  
  
  
