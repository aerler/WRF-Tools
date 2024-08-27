#/usr/bin/env python3
'''
Date: May 14th, 2023

This is the main script to drive the CMIP6-WRF data extraction. 

Original author: Zhenning Li
Modified by: Mani Mahdinia
'''


# Modules
import os
from sys import argv
import numpy as np
import pandas as pd
import datetime
import cftime
import struct
import glob
import xarray as xr
from scipy.io import FortranFile
from scipy.interpolate import griddata


# ==========================================================================================
# ============================ Function to generate WRF template ===========================
# ==========================================================================================

def gen_wrf_mid_template():
    slab_dict={
        'IFV':5, 'HDATE':'0000-00-00_00:00:00:0000',
        'XFCST':0.0, 'MAP_SOURCE':'CMIP6',
        'FIELD':'', 'UNIT':'', 'DESC':'', 
        'XLVL':0.0, 'NX':360, 'NY':180,
        'IPROJ':0,'STARTLOC':'SWCORNER',
        'STARTLAT':-90.0, 'STARTLON':0.0,
        'DELTLAT':1.0, 'DELTLON':1.0, 'EARTH_RAD':6371.229,
        'IS_WIND_EARTH_REL': 0, 
        'SLAB':np.array(np.zeros((180,360)), dtype=np.float32),
        'key_lst':['IFV', 'HDATE', 'XFCST', 'MAP_SOURCE', 'FIELD', 'UNIT', 
        'DESC', 'XLVL', 'NX', 'NY', 'IPROJ', 'STARTLOC', 
        'STARTLAT', 'STARTLON', 'DELTLAT', 'DELTLON', 
        'EARTH_RAD', 'IS_WIND_EARTH_REL', 'SLAB']
    }
    return slab_dict


# ==========================================================================================
# ================== Function to Write a record to a WRF intermediate file =================
# ==========================================================================================

def write_record(out_file, slab_dic):

    # Left justify some elements
    slab_dic['MAP_SOURCE']='CMIP6'.ljust(32)
    slab_dic['FIELD']=slab_dic['FIELD'].ljust(9)
    slab_dic['UNIT']=slab_dic['UNIT'].ljust(25)
    slab_dic['DESC']=slab_dic['DESC'].ljust(46)
    # NOTE: s.ljust(n) returns an n charachter string with string s at the most left part,
    #   followed by some spaces such that the total length of the result is n+1.    
    
    # IFV header
    out_file.write_record(struct.pack('>I',slab_dic['IFV']))
    # NOTE: write_record is to write a record (including sizes) to a file.
    
    # HDATE header
    pack=struct.pack('>24sf32s9s25s46sfIII', 
        slab_dic['HDATE'].encode(), slab_dic['XFCST'],
        slab_dic['MAP_SOURCE'].encode(), slab_dic['FIELD'].encode(),
        slab_dic['UNIT'].encode(), slab_dic['DESC'].encode(),
        slab_dic['XLVL'], slab_dic['NX'], slab_dic['NY'],
        slab_dic['IPROJ'])
    out_file.write_record(pack)

    # STARTLOC header
    pack=struct.pack('>8sfffff',
        slab_dic['STARTLOC'].encode(), slab_dic['STARTLAT'],
        slab_dic['STARTLON'], slab_dic['DELTLAT'], slab_dic['DELTLON'],
        slab_dic['EARTH_RAD'])
    out_file.write_record(pack)

    # IS_WIND_EARTH_REL header
    pack=struct.pack('>I', slab_dic['IS_WIND_EARTH_REL'])
    out_file.write_record(pack)

    # Write the SLAB
    out_file.write_record(slab_dic['SLAB'].astype('>f'))
    
    
# ==========================================================================================
# ================================== CMIP6Handler class ====================================
# ==========================================================================================

class CMIPHandler(object):

    '''
    Construct CMIP Handler 

    Methods
    -----------
    __init__: Initialize CMIP Handler with config and loading data.
    interp_data: Interpolate data to common mesh.
    write_wrfinterm: Write wrfinterm file.
    '''
    
    # ===================== Initialize CMIP Handler with config and loading data ===================
    def __init__(self, inp_date, datafolderlink):
        
        # ================= Find the containing files' start and end dates ===============
        def find_file_start_and_end_dates(self, input_root, vns, stL, edL):
    
            # Find the file date list
            self.filestrdates = []
            for idx, itm in self.vtable.iterrows():
                if itm['sp_dates']!=-1:
                    # Var name and other info
                    varname = itm['src_v']
                    lvlmark = itm['lvlmark']
                    frq = itm['freq']          
                    if pd.isna(lvlmark):
                        lvlmark = ''
                    # Make initial part of file name
                    fn_pre = input_root+'/'+varname+'_'+frq+lvlmark+'_'+self.model_name
                    fn_pre += '_'+self.exp_id+'_'+self.esm_flag+'_'+self.grid_flag  
                    # Search for files
                    filenames = sorted(glob.glob(fn_pre+'*.nc'))
                    dates = [ele[len(fn_pre):-3] for ele in filenames]
                    startdates_t = []
                    enddates_t = []
                    for ele in dates:
                        ele_split = ele.split("-")
                        startdates_t.append(ele_split[0])
                        enddates_t.append(ele_split[1])
                    startdates = []
                    enddates = []
                    if len(startdates_t[0])==12:
                        dformat = '%Y%m%d%H%M'
                        dlen = 12
                    elif len(startdates_t[0])==8:
                        dformat = '%Y%m%d'
                        dlen = 8
                    elif len(startdates_t[0])==6:
                        dformat = '%Y%m'
                        dlen = 6
                    else:
                        raise ValueError('Error: File date format not recognized.')
                    for stdate, endate in zip(startdates_t, enddates_t):
                        if ((len(stdate)!=dlen) or (len(endate)!=dlen)):
                            print('dformat: '+dformat)
                            print('stdate: '+stdate)
                            print('endate: '+endate)
                            raise ValueError('Error: Files do not have a consistent date format.')
                        startdates.append(datetime.datetime.strptime(stdate,dformat))
                        enddates.append(datetime.datetime.strptime(endate,dformat))        
                    # Actual start and end dates
                    locf = [i for i, x in enumerate(vns) if x==varname]
                    startdatesa = stL[locf][0]; enddatesa = edL[locf][0]    
                    # Find the file      
                    ndatefound = 0
                    for i in range(len(startdatesa)):
                        if ((startdatesa[i]<=self.input_date) and (self.input_date<=enddatesa[i])):
                            ndatefound += 1
                            filestartdate = startdates[i]
                            fileenddate = enddates[i]
                    if ndatefound!=1:
                        if not itm['approx_dates']:
                            raise ValueError('Error: Item is needed at exact dates, but number of files found is not 1.')
                        else:
                            if ndatefound>1:
                                raise ValueError('Error: Number of files containing item is greater than 1.')
                            else:
                                if self.input_date<startdatesa[0]:
                                    filestartdate = startdates[0]
                                    fileenddate = enddates[0]
                                elif enddatesa[-1]<self.input_date:
                                    filestartdate = startdates[-1]
                                    fileenddate = enddates[-1]
                                else:
                                    ndatefound2 = 0
                                    for i in range(len(startdatesa)-1):
                                        if ((enddatesa[i]<=self.input_date) and (self.input_date<=startdatesa[i+1])):
                                            delt1 = abs(self.input_date-enddatesa[i])
                                            delt2 = abs(startdatesa[i+1]-self.input_date)
                                            if abs(delt1-delt2)<=pd.Timedelta(seconds=1):
                                                filestartdate = startdates[i+1]
                                                fileenddate = enddates[i+1]
                                                ndatefound2 = ndatefound2+1
                                            elif delt1<delt2:
                                                filestartdate = startdates[i]
                                                fileenddate = enddates[i]
                                                ndatefound2 = ndatefound2+1    
                                            elif delt2<delt1:
                                                filestartdate = startdates[i+1]
                                                fileenddate = enddates[i+1]
                                                ndatefound2 = ndatefound2+1
                                    if ndatefound2!=1:
                                        raise ValueError('Error: Could not find the file with the input data.')
                    self.filestrdates.append(filestartdate.strftime(dformat)+'-'+fileenddate.strftime(dformat))
                else:
                    self.filestrdates.append('')
               
        # Input data directory
        input_root = os.readlink(datafolderlink)

        # CMIP6 model name, exp_id, esm_flag and grid_flag 
        elemsr = input_root.split(".")
        self.model_name = elemsr[3]
        self.exp_id = elemsr[4]
        self.esm_flag = elemsr[5]
        self.grid_flag = elemsr[7]
        # NOTE: Here we assume that there are no other dots in the input_root other than those
        #   associated with the seperators for the CMIP6 name.
        
        # Load start and end dates and varnames
        stL = np.load(input_root+'/startdates.npy',allow_pickle=True)
        edL = np.load(input_root+'/enddates.npy',allow_pickle=True) 
        vns = np.load(input_root+'/varnames.npy',allow_pickle=True)
        
        # Check the model 
        if not(self.model_name in ['MPI-ESM1-2-HR','CESM2','MRI-ESM2-0']):
            raise NotImplementedError('Model not implemented.')
        
        # The date to be handled
        if (self.model_name in ['MPI-ESM1-2-HR','MRI-ESM2-0']):
            self.input_date = datetime.datetime.strptime(inp_date,'%Y%m%d%H')
            # NOTE: The strptime() method creates a datetime object from the given string.
        elif self.model_name=='CESM2':
            self.input_date = cftime.datetime.strptime(inp_date,"%Y%m%d%H",calendar='noleap')
        
        # Display info about time
        print('\nHandeling time:',self.input_date)

        # VTABLE
        self.vtable = pd.read_csv('./Vtable')
             
        # Soil information
        SM_layers = []; ST_layers = []
        SM_depths = []; ST_depths = []
        for idx, itm in self.vtable.iterrows():
            outname = itm['aim_v']
            if outname[0:2]=='SM':
                SM_layers.append(outname[2:8])
                SM_depths.append(itm['soil_depth'])
            if outname[0:2]=='ST':
                ST_layers.append(outname[2:8])
                ST_depths.append(itm['soil_depth'])
        if SM_layers!=sorted(SM_layers):
            raise ValueError('SM layers are not sorted in the table.')
        if ST_layers!=sorted(ST_layers):
            raise ValueError('ST layers are not sorted in the table.')
        if SM_layers!=ST_layers:
            raise ValueError('ST and SM must have the same layers.')
        if SM_depths!=sorted(SM_depths):
            raise ValueError('SM depths are not sorted in the table.')
        if ST_depths!=sorted(ST_depths):
            raise ValueError('ST depths are not sorted in the table.')
        if SM_depths!=ST_depths:
            raise ValueError('ST and SM must have the same depths.')    
        self.outsoillayers = SM_layers
        self.soildepths = SM_depths
        self.soillayerthicks = []
        for i in range(len(SM_layers)):
            strl = SM_layers[i]
            d1 = float(strl[0:3])*0.01
            d2 = float(strl[3:6])*0.01
            self.soillayerthicks.append(round(d2-d1,2))        
        print('Soil layers are: ')
        print('  ',self.outsoillayers) 
        print('Soil layer depths are: ')
        print('  ',self.soildepths)
        print('Soil layer thicknesses are: ')
        print('  ',self.soillayerthicks)     

        # Generate wrf intermidiate slab template for mtemplate ?????
        self.mtemplate=gen_wrf_mid_template()
        
        # Init empty cmip container dict
        self.ds,self.outfrm = {},{}
        # NOTE: ds is to hold the original data array and outfrm is to hold the interpolated one.
        
        # Generate wrf intermidiate slab template for out_slab
        self.out_slab = gen_wrf_mid_template()
        # NOTE: The out_slab is used to write the data into intermediate file one level at a time.
        
        # Find the containing files' start and end dates
        find_file_start_and_end_dates(self, input_root, vns, stL, edL)  

        # NOTE: For the CESM2 data, we did not include the surface fields, as those were not available. If we process
        #   the data without surface fields, real.exe says e.g., "Missing surface temp, replaced with closest level, 
        #   use_surface set to false.". This is acceptable because: The pressure formula for the model levels is 
        #   p = a.p0+b.ps. At the lowest model level the pressure is only 7.5 hPa lower than surface pressure. Assuming
        #   8m ~ 1hPa, then this is only ~60 meters or with a lapse rate of -6.5 K/km, it is a T diff of 0.4 K.        
        
        # plev and lat and lon variables
        self.plev = np.array(None)
        self.lat = np.array(None)
        self.lon = np.array(None)

        # Assemble lats, lons, and the data
        print('Loading data ...')
        c = 0 # Counter.
        for idx, itm in self.vtable.iterrows():
            # Var name and other info
            varname = itm['src_v']
            outvarname = itm['aim_v']
            lvltype = itm['type']
            lvlmark = itm['lvlmark']
            frq = itm['freq']            
            if pd.isna(lvlmark):
                lvlmark = ''
            # File name
            fn = input_root+'/'+varname+'_'+frq+lvlmark+'_'+self.model_name
            fn += '_'+self.exp_id+'_'+self.esm_flag+'_'+self.grid_flag
            if self.filestrdates[c]!='':
                fn += '_'+self.filestrdates[c]+'.nc'
            else:    
                fn += '.nc'  
            # Open dataset
            ds = xr.open_dataset(fn)
            # lat and lon handeling
            if ((self.lat==None).all() and (self.lon==None).all()):
                if ((varname=='tos') or (varname=='siconc') or (varname=='sithick')):
                    raise ValueError("The first field in the table should be a variable different than tos, siconc or sithick.")
                self.lat = np.array(ds.lat.values)
                self.lon = np.array(ds.lon.values)
            else:
                if ((varname!='tos') and (varname!='sithick') and (varname!='siconc')):
                    if not((np.allclose(np.array(ds.lat.values),self.lat,rtol=0.0,atol=2.0e-5)) and \
                        (np.allclose(np.array(ds.lon.values),self.lon,rtol=0.0,atol=2.0e-5))):
                        raise ValueError("Error: Inconsistent lat/lon values between different fields.")
                    # NOTE: For MPI model this tolerance can be set to 10^-12. For the CESM2 model, it is also
                    #   the same for all fields other than the mrsol and tsl. For the soil vars, it needs to be 
                    #   increased to a larger value of 10^-5. This value is 2x10^-5 for MRI.                    
            # plev handeling for 3D fields
            if lvltype=='3d':
                if ((self.plev==None).all()):
                    if (varname=='ua') or (varname=='va'):
                        raise ValueError("The first 3D field in the table should be a variable different than ua and va.")
                    self.plev = np.array(ds.plev.values)
                else:
                    if not(np.allclose(np.array(ds.plev.values),self.plev,rtol=0.0,atol=1.0e-12)):
                        raise ValueError("Error: Inconsistent pressure levels between 3D fields.")            
            # Find the soil layer, if needed
            if (varname=='mrsol' or varname=='tsl'):
                n_found = 0
                for i in range(len(self.outsoillayers)):
                    if outvarname[2:]==self.outsoillayers[i]:
                        slvl = i
                        n_found += 1
                if not(n_found==1):
                    raise ValueError("Error: Difficulty finding the soil layer.")
                # NOTE: This code assumes the same layers for soil moisture and temperature.    
            # Read appropriate section of data
            if (varname=='mrsol' or varname=='tsl'):
                ds[varname] = ds[varname].sel(depth=self.soildepths[slvl],method='nearest',tolerance=1.0e-7)
                # NOTE: We have to use the nearest method here, rather than direct selection, becuase, e.g., for CESM2,
                #   the depths are specified as 0.00999999977648258, 0.0399999991059303, etc.
                # NOTE: For the CESM2 data, we have removed the first layer [-0.005 to 0.025] m, and only kept the layers
                #   up to 1.89 meters (10 layers total). This is because the LSM expects inputs up to 2 meters. Originally 
                #   we had the first layer and the last layer to 2.29 meters, but we removed them due to the count (real 
                #   can only accept maximum of 10 layers). This is done only through the Vtable and METGRID.TBL.
            if (self.filestrdates[c]!=''):
                # Approx tol days
                seltolapr_days = 20            
                # Tolerance and selection
                t1 = ds['time'].values[0] # To find time axis dtype.
                if isinstance(t1,np.datetime64):
                    seltol = str(seltolapr_days)+'D' if itm['approx_dates'] else '0'
                    ds_sel = ds[varname].sel(time=self.input_date,method='nearest',tolerance=seltol)
                elif isinstance(t1,cftime.DatetimeNoLeap):
                    seltol = datetime.timedelta(days=seltolapr_days) if itm['approx_dates'] else datetime.timedelta(seconds=0)                    
                    t_vals = ds['time'].values
                    t_select = t_vals[np.argmin((t_vals-self.input_date).abs())]
                    if abs(t_select-self.input_date)>seltol:
                        raise ValueError('Minimum difference bigger than tolerance!')  
                    ds_sel = ds[varname].sel(time=t_select)
                else:
                    raise ValueError('Time dtype not recognized!')                    
                # NOTE: The above two methods for the time selection is because CESM2 has time type of cftime.DatetimeNoLeap,
                #   which does not work with the method='nearest' route (datetime.datetime does). So we externalize the 
                #   selection of the time.                 
                if (varname=='mrsol' or varname=='tsl'):	
                    self.ds[varname+str(slvl)] = ds_sel
                else:
                    self.ds[varname] = ds_sel  
            else:
                if (varname=='mrsol' or varname=='tsl'):
                    self.ds[varname+str(slvl)] = ds[varname]
                else:
                    self.ds[varname] = ds[varname]
            # Close dataset
            ds.close()               
            # Display info about dates for this variable
            print('  Var: '+varname)
            if self.filestrdates[c]!='':
                print('    - Available times:',self.filestrdates[c])
            else:
                print('    - Available times: NA')
            print('    - Freq: '+frq)
            print('    - approx_dates:',itm['approx_dates'])
            if (self.filestrdates[c]!=''):
                if (varname=='mrsol' or varname=='tsl'):
                    print('    - Chosen date:',self.ds[varname+str(slvl)].time.values)
                else:
                    print('    - Chosen date:',self.ds[varname].time.values)
            else:
                print('    - Chosen date: NA')
            # Increment the counter
            c += 1             
        
        # Fix the lats not being uniform issue for some models
        if (self.model_name in ['MPI-ESM1-2-HR','MRI-ESM2-0']):
            locs = 4 # From this index forwards, d_dlats is smaller than 0.0002 deg.
            loce = (len(self.lat)-2)-1-locs # From this index backwards, d_dlats is smaller than 0.0002 deg.
            dlats = self.lat[1:]-self.lat[0:-1]               
            dy = np.mean(dlats[locs+1:loce+1])
            n_lats = len(self.lat)
            if (n_lats%2)!=0:
                raise ValueError("Number of lats must be even!")
            nn_lats = round(n_lats/2)
            self.lat = np.array(np.concatenate((-dy*range(nn_lats-1,-1,-1)-dy/2,dy/2+dy*range(0,nn_lats,1))))
        
        # Handle self.out_slab
        self.out_slab['NX'] = len(self.lon)
        self.out_slab['NY'] = len(self.lat)
        self.out_slab['SLAB'] = np.array(np.zeros((len(self.lat),len(self.lon))),dtype=np.float32)
        self.out_slab['STARTLAT'] = self.lat[0]
        self.out_slab['STARTLON'] = self.lon[0]
        self.out_slab['DELTLAT'] = self.lat[1]-self.lat[0]
        self.out_slab['DELTLON'] = self.lon[1]-self.lon[0]            

    # ================================= Interpolate data to common mesh ===================================
    def interp_data(self):

        # Go over all vtable rows and alter values as needed
        for idx, itm in self.vtable.iterrows():
            # Var name and lvltype
            varname = itm['src_v']
            outvarname = itm['aim_v']
            lvltype = itm['type'] 
            frq = itm['freq']
            if (varname=='mrsol' or varname=='tsl'):
                n_found = 0
                for i in range(len(self.outsoillayers)):                    
                    if outvarname[2:]==self.outsoillayers[i]:
                        slvl = i
                        n_found += 1
                if not(n_found==1):
                    raise ValueError("Error: Difficulty finding the soil layer.")               
                # NOTE: This code assumes the same layers for soil moisture and temperature.                    
                # Select variable
                da = self.ds[varname+str(slvl)]
                # Handle soil moisture, if needed
                if ((varname=='mrsol') and (itm['units']=="kg m-2")): 
                    da /= 997.0474*self.soillayerthicks[slvl]
                # NOTE: In some model data soil moisture is in units of kg/m^2, so to convert that to m3 m-3, 
                #   which is what also, e.g., ERA5 uses, we divide by 997.0474 kg/m^3 and by the layer thickness (m).
                #   Also we do not need to worry about missing values as xarray reads those as nans and they remain 
                #     nans after the above operations.
                if lvltype=='2d-soil':                                        
                    array = np.ma.masked_invalid(da.values)
                    xx,yy = np.meshgrid(self.lon,self.lat)
                    xx1 = xx[~array.mask]
                    yy1 = yy[~array.mask]
                    array1 = array[~array.mask]
                    self.outfrm[varname+str(slvl)] = da.copy(deep=True) 
                    self.outfrm[varname+str(slvl)].values = griddata((xx1,yy1),array1,(xx,yy),method='nearest')                       
                    # NOTE: This is to remove nan values (missing values that xarray replaces with nans).
                    if varname=='mrsol':
                        Temp = self.outfrm[varname+str(slvl)].values
                        Temp[Temp<0.05] = 0.05
                        self.outfrm[varname+str(slvl)].values = Temp
                    # NOTE: This prevents unphysically low soil moisture levels and potentially helps with spin-up.
                else:
                    raise ValueError("Error: Incorrect level type for soil data.")
            else:            
                # Select variable
                da = self.ds[varname] 
                # Handle tos variable, if needed  
                if (varname=='tos' and itm['units']=='degC'):
                    da += 273.15
                # NOTE: This is because in some model data tos is in degress C and WRF expects degrees K.
                #   Also we do not need to worry about missing values as xarray reads those as nans and they  
                #   remain nans after the above operations. 
                # Handle sftlf variable, if needed
                if (varname=='sftlf' and itm['units']=='%'):
                    da = (da/100).round()
                # NOTE: This is because in some model data sftlf is in percentage and WRF expects 0-1 values. 
                #   Also we do not need to worry about missing values as I checked and there are none of those 
                #   in the sftlf data.
                # Handle siconc variable, if needed  
                if (varname=='siconc' and itm['units']=='%'):
                    da = da/100.0
                # NOTE: This is because in some model data siconc is in percentage and WRF expects 0-1 values.
                #   Also we do not need to worry about missing values as xarray reads those as nans and they  
                #   remain nans after the above operations.    
                # Perform the interpolation
                if lvltype=='3d':
                    Temp = da.values
                    largetemp = Temp[Temp>1.e10]
                    n_nan = np.isnan(Temp).sum()
                    n_large = largetemp.sum()
                    n_nanorlarge = n_nan+n_large
                    if n_nanorlarge==0:                        
                        self.outfrm[varname] = da.copy(deep=True)                            
                    else:                        
                        if n_large>0:
                            raise ValueError("Error: There are extremely large values in the 3D data.")
                        else:
                            K = da.shape[0]
                            da_f = da.copy(deep=True)
                            for k in range(K):
                                da_l = da[k,:,:].copy(deep=True)
                                n_nan_l = np.isnan(da_l).sum()
                                if n_nan_l>0:
                                    array = np.ma.masked_invalid(da_l.values)
                                    xx,yy = np.meshgrid(self.lon,self.lat)
                                    xx1 = xx[~array.mask]
                                    yy1 = yy[~array.mask]
                                    array1 = array[~array.mask]
                                    da_f[k,:,:] = griddata((xx1,yy1),array1,(xx,yy),method='nearest')
                            self.outfrm[varname] = da_f                                       
                            # NOTE: This is to remove nan values (missing values that xarray replaces with nans).                    
                elif lvltype=='2d':
                    if ((varname=='tos') or (varname=='siconc') or (varname=='sithick')):                    
                        if (self.model_name in ['MPI-ESM1-2-HR','MRI-ESM2-0']):
                            lons_loc = da['longitude'].values
                            lats_loc = da['latitude'].values
                        elif self.model_name=='CESM2':
                            lons_loc = da['lon'].values
                            lats_loc = da['lat'].values
                        array = np.ma.masked_invalid(da.values)                        
                        xx1 = lons_loc[~array.mask]
                        yy1 = lats_loc[~array.mask]
                        array1 = array[~array.mask]
                        xx,yy = np.meshgrid(self.lon,self.lat)                         
                        interp_data_temp = griddata((xx1,yy1),array1,(xx,yy),method='linear')
                        # NOTE: This is because the grid of ocean is different than other vars' grid and we have to  
                        #   interpolate into the common grid for the ocean variables. 
                        array = np.ma.masked_invalid(interp_data_temp)                        
                        xx1 = xx[~array.mask]
                        yy1 = yy[~array.mask]
                        array1 = array[~array.mask]
                        tos_temp2 = griddata((xx1,yy1),array1,(xx,yy),method='nearest')                       
                        # NOTE: This is to remove nan values (missing values that xarray replaces with nans).
                        self.outfrm[varname] = tos_temp2                        
                        Temp = self.outfrm[varname]
                        largetemp = Temp[Temp>1.e10]
                        if (np.isnan(Temp).sum()+largetemp.sum())!=0:
                           raise ValueError('Error: There are nan or large values in the ocean data (after filling).')                        
                    else:                        
                        self.outfrm[varname] = da.copy(deep=True)                            

    # ================================= Write WRF Interim file ===================================
    def write_wrfinterm(self):
    
        # Output file path and name
        out_fn = './CMIP6:'+self.input_date.strftime('%Y-%m-%d_%H')
        
        # Display message
        print('  Writing '+out_fn)
        
        # Start Fortran file 
        wrf_mid = FortranFile(out_fn, 'w', header_dtype=np.dtype('>u4'))
        # NOTE: In numpy and dtype='>u4' we have: > = big-endian, and u4 = 32-bit unsigned integer.
        
        # Make out_dict
        out_dic = self.out_slab
        out_dic['HDATE'] = self.input_date.strftime('%Y-%m-%d_%H:%M:%S:0000')

        # Go over all vtable rows and write all the data
        for idx, itm in self.vtable.iterrows():
            # Var name, lvltype, field, units and description
            varname = itm['src_v']
            outvarname = itm['aim_v']
            lvltype = itm['type']
            out_dic['FIELD'] = itm['aim_v']            
            out_dic['UNIT'] = itm['units']
            if (varname=='tos' and itm['units']=='degC'):
                out_dic['UNIT'] = 'K'
            # NOTE: This is because in some model data tos is in degress C and WRF expects degrees K.
            if (varname=='mrsol' and itm['units']=="kg m-2"):
                out_dic['UNIT'] = 'm3 m-3'                
            # NOTE: This is because in some model data mrsos is in kg/m^2 and WRF expects m^3/m^3.
            if (varname=='sftlf' and itm['units']=='%'):
                out_dic['UNIT'] = '0/1 Flag'
            # NOTE: This is because in some model data sftlf is in % and WRF expects 0/1 Flag. 
            if (varname=='siconc' and itm['units']=='%'):
                out_dic['UNIT'] = 'fraction'
            # NOTE: This is because in some model data siconc is in % and WRF expects 0-1 value.    
            out_dic['DESC'] = itm['desc']
            # Identify level and values and write record            
            out_dic['XLVL'] = 200100.0
            if lvltype=='3d':
                for lvl in self.plev:
                    out_dic['XLVL'] = lvl
                    out_dic['SLAB'] = self.outfrm[varname].sel(plev=lvl).values
                    write_record(wrf_mid, out_dic)
            else:
                if ((varname=='tos') or (varname=='siconc') or (varname=='sithick')): 
                    out_dic['SLAB'] = self.outfrm[varname]
                # NOTE: This is because for these 3 values the outfrm has array values already (and not dataset),
                #   and so we do not need to put ".values" at the end. 
                elif (varname=='mrsol' or varname=='tsl'):
                    n_found = 0
                    for i in range(len(self.outsoillayers)):                    
                        if outvarname[2:]==self.outsoillayers[i]:
                            slvl = i
                            n_found += 1
                    if not(n_found==1):
                        raise ValueError("Error: Difficulty finding the soil layer.")               
                    # NOTE: This code assumes the same layers for soil moisture and temperature.
                    out_dic['SLAB'] = self.outfrm[varname+str(slvl)].values                
                else:
                    out_dic['SLAB'] = self.outfrm[varname].values
                write_record(wrf_mid, out_dic)
       
        # Close file
        wrf_mid.close()


# Main
def main_run():

    # Retreive date   
    InDate = argv[1]
    DataDirLnk = argv[2]
    
    # Construct CMIP handler
    cmip_hdl = CMIPHandler(InDate,DataDirLnk)

    # Interpolate data
    print('Interpolating data ...')
    cmip_hdl.interp_data()
    
    # Write intermediate file
    print('Writing WRF intermediate file ...')
    cmip_hdl.write_wrfinterm()
    

# Main
if __name__=='__main__':
    main_run()
