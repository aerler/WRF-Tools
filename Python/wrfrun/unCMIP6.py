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
import struct
import glob
import xarray as xr
import configparser
from scipy.io import FortranFile
from scipy.interpolate import griddata


# ==========================================================================================
# ============================== Function to read config files =============================
# ==========================================================================================

def read_cfg(config_file):

    config = configparser.ConfigParser()
    config.read(config_file)
    
    return config


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
        
        # The date to be handled 
        self.input_date = datetime.datetime.strptime(inp_date,'%Y%m%d%H')
        # NOTE: The strptime() method creates a datetime object from the given string.
        
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
        
        # Find the file date list
        self.filestrdates = []
        for idx, itm in self.vtable.iterrows():
            if itm['sp_dates']!=-1:
                # Var name and other info
                varname = itm['src_v']
                lvlmark = itm['lvlmark']
                frq = itm['freq']            
                if lvlmark == 'None':
                    lvlmark = ''
                # Make initial part of file name
                fn_pre = input_root+'/'+varname+'_'+frq+lvlmark+'_'+self.model_name
                fn_pre = fn_pre+'_'+self.exp_id+'_'+self.esm_flag+'_'+self.grid_flag  
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
                for ele in startdates_t:
                    if len(ele)!=dlen:
                        raise ValueError('Error: Files do not have a consistent date format.')
                    startdates.append(datetime.datetime.strptime(ele,dformat))    
                for ele in enddates_t:
                    if len(ele)!=dlen:   
                        raise ValueError('Error: Files do not have a consistent date format.')
                    enddates.append(datetime.datetime.strptime(ele,dformat))        
                ndatefound = 0
                for i in range(len(startdates)):
                    if ((startdates[i]<=self.input_date) and (self.input_date<=enddates[i])):
                        ndatefound = ndatefound+1
                        filestartdate = startdates[i]
                        fileenddate = enddates[i]
                if ndatefound!=1:
                    if not(itm['approx_dates']):
                        raise ValueError('Error: Item is needed at exact dates, but number of files found is not 1.')
                    else:
                        if ndatefound>1:
                            raise ValueError('Error: Number of files containing item is greater than 1.')
                        else:
                            if self.input_date<startdates[0]:
                                filestartdate = startdates[0]
                                fileenddate = enddates[0]
                            elif enddates[-1]<self.input_date:
                                filestartdate = startdates[-1]
                                fileenddate = enddates[-1]
                            else:
                                ndatefound2 = 0
                                for i in range(len(startdates)-1):
                                    if ((enddates[i]<=self.input_date) and (self.input_date<=startdates[i+1])):
                                        delt1 = abs(self.input_date-enddates[i])
                                        delt2 = abs(startdates[i+1]-self.input_date)
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
            if lvlmark == 'None':
                lvlmark = ''
            # File name
            fn = input_root+'/'+varname+'_'+frq+lvlmark+'_'+self.model_name
            fn = fn+'_'+self.exp_id+'_'+self.esm_flag+'_'+self.grid_flag
            if self.filestrdates[c]!='':
                fn = fn+'_'+self.filestrdates[c]+'.nc'
            else:    
                fn = fn+'.nc'  
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
                    if not((np.allclose(np.array(ds.lat.values),self.lat,rtol=0.0,atol=1.0e-12)) and \
                        (np.allclose(np.array(ds.lon.values),self.lon,rtol=0.0,atol=1.0e-12))):
                        raise ValueError("Error: Inconsistent lat/lon values between different fields.")
            # plev handeling for 3D fields
            if lvltype=='3d':
                if ((self.plev==None).all()):
                    if (varname=='ua') or (varname=='va'):
                        raise ValueError("The first 3D field in the table should be a variable different than ua and va.")
                    self.plev = np.array(ds.plev.values)
                else:
                    if not(np.allclose(np.array(ds.plev.values),self.plev,rtol=0.0,atol=1.0e-12)):
                        raise ValueError("Error: Inconsistent pressure levels between 3D fields.")            
            # Find the date to read
            if (self.filestrdates[c]!=''):
                avail_times_t = ds[varname].time.values
                avail_times = [pd.to_datetime(ele) for ele in avail_times_t]
                if itm['approx_dates']==False: 
                    if self.input_date in avail_times:
                        if avail_times.count(self.input_date)!=1:
                            raise ValueError('Error: Number of times that date/time appears in file is not 1.')
                        cdate = self.input_date
                    else:
                        raise ValueError('Error: Could not find the exact date and time in the file.')
                else:
                    if (not(sorted(avail_times)==avail_times)):
                        raise ValueError('Error: File times are not sorted.')
                    if self.input_date<pd.to_datetime(avail_times[0]):
                        cdate = pd.to_datetime(avail_times[0])    
                    elif pd.to_datetime(avail_times[-1])<self.input_date:
                        cdate = pd.to_datetime(avail_times[-1])
                    else:
                        if self.input_date in avail_times:
                            if avail_times.count(self.input_date)!=1:
                                raise ValueError('Error: Number of times that date/time appears in file is not 1.')
                            cdate = self.input_date
                        else:
                            ndatefound2 = 0
                            for j in range(len(avail_times)-1):
                                eledt1 = pd.to_datetime(avail_times[j])
                                eledt2 = pd.to_datetime(avail_times[j+1])
                                if ((eledt1<=self.input_date) and (self.input_date<=eledt2)):
                                    delt1 = abs(self.input_date-eledt1)
                                    delt2 = abs(eledt2-self.input_date)
                                    if abs(delt1-delt2)<=pd.Timedelta(seconds=1):
                                        cdate = eledt2
                                        ndatefound2 = ndatefound2+1
                                    elif delt1<delt2:
                                        cdate = eledt1
                                        ndatefound2 = ndatefound2+1    
                                    elif delt2<delt1:
                                        cdate = eledt2
                                        ndatefound2 = ndatefound2+1
                            if ndatefound2!=1:
                                raise ValueError('Error: Could not find the closest date/time.')
            else:
                cdate = 'NA'
            # Read appropriate section of data
            if (varname=='mrsol' or varname=='tsl'):
                n_found = 0
                for i in range(len(self.outsoillayers)):                    
                    if outvarname[2:]==self.outsoillayers[i]:
                        slvl = i
                        n_found = n_found+1
                if not(n_found==1):
                    raise ValueError("Error: Difficulty finding the soil layer.")               
                # NOTE: This code assumes the same layers for soil moisture and temperature.
                if cdate!='NA':
                    self.ds[varname+str(slvl)] = ds[varname].sel(time=cdate,depth=self.soildepths[slvl])
                else:
                    self.ds[varname+str(slvl)] = ds[varname].sel(depth=self.soildepths[slvl])
            else:
                if (cdate!='NA'):
                    self.ds[varname] = ds[varname].sel(time=cdate)
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
            print('    - Chosen date:',cdate)
            # Increment the counter
            c = c+1             
        
        # Fix the lats not being uniform issue for the MPI model
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
                        n_found = n_found+1
                if not(n_found==1):
                    raise ValueError("Error: Difficulty finding the soil layer.")               
                # NOTE: This code assumes the same layers for soil moisture and temperature.                    
                # Select variable
                ds = self.ds[varname+str(slvl)]
                # Handle soil moisture, if needed
                if ((varname=='mrsol') and (itm['units']=="kg m-2")):
                    Temp = ds.values 
                    Temp = Temp/997.0474/self.soillayerthicks[slvl]
                    ds.values = Temp
                # NOTE: In MPI-ESM1-2-HR data soil moisture is in units of kg/m^2, so to convert that to m3 m-3, 
                #   which is what also, e.g., ERA5 uses, we divide by 997.0474 kg/m^3 and by the layer thickness (m).
                #   Also we do not need to worry about missing values as xarray reads those as nans and they remain 
                #     nans after the above operations.
                if lvltype=='2d-soil':                                        
                    array = np.ma.masked_invalid(ds.values)
                    xx,yy = np.meshgrid(self.lon,self.lat)
                    xx1 = xx[~array.mask]
                    yy1 = yy[~array.mask]
                    array1 = array[~array.mask]
                    self.outfrm[varname+str(slvl)] = ds.copy(deep=True) 
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
                ds = self.ds[varname] 
                # Handle tos variable, if needed  
                if (varname=='tos' and itm['units']=='degC'):
                    Temp = ds.values
                    Temp = Temp+273.15
                    ds.values = Temp
                # NOTE: This is because in MPI-ESM1-2-HR data tos is in degress C and WRF expects degrees K.
                #   Also we do not need to worry about missing values as xarray reads those as nans and they  
                #   remain nans after the above operations. 
                # Handle sftlf variable, if needed
                if (varname=='sftlf' and itm['units']=='%'):
                    Temp = ds.values
                    Temp = Temp/100.0
                    Temp = Temp.tolist()
                    Temp = [[round(ii) for ii in nested] for nested in Temp]
                    Temp = np.array(Temp)                                       
                    ds.values = Temp
                # NOTE: This is because in MPI-ESM1-2-HR data sftlf is in percentage (either 0 or 100, not 
                #   in between) and WRF expects 0 or 1 values. Also we do not need to worry about missing values   
                #   as I checked and there are none of those in the sftlf data.
                # Handle siconc variable, if needed  
                if (varname=='siconc' and itm['units']=='%'):
                    Temp = ds.values
                    Temp = Temp/100.0
                    ds.values = Temp
                # NOTE: This is because in MPI-ESM1-2-HR data siconc is in percentage and WRF expects 0-1 values.
                #   Also we do not need to worry about missing values as xarray reads those as nans and they  
                #   remain nans after the above operations.    
                # Perform the interpolation
                if lvltype=='3d':
                    Temp = ds.values
                    largetemp = Temp[Temp>1.e10]
                    n_nanorlarge = np.isnan(Temp).sum()+largetemp.sum()
                    if n_nanorlarge==0:                        
                        self.outfrm[varname] = ds.copy(deep=True)                            
                    else:
                        raise ValueError("Error: There are nans or extremely large values in the 3D data.")                    
                elif lvltype=='2d':
                    if ((varname=='tos') or (varname=='siconc') or (varname=='sithick')):                    
                        lons_loc = ds['longitude'].values
                        lats_loc = ds['latitude'].values
                        array = np.ma.masked_invalid(ds.values)                        
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
                        self.outfrm[varname] = ds.copy(deep=True)                            

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
            # NOTE: This is because in MPI-ESM1-2-HR data tos is in degress C and WRF expects degrees K.
            if (varname=='mrsol' and itm['units']=="kg m-2"):
                out_dic['UNIT'] = 'm3 m-3'                
            # NOTE: This is because in MPI-ESM1-2-HR data mrsos is in kg/m^2 and WRF expects m^3/m^3.
            if (varname=='sftlf' and itm['units']=='%'):
                out_dic['UNIT'] = '0/1 Flag'
            # NOTE: This is because in MPI-ESM1-2-HR data sftlf is in % and WRF expects 0/1 Flag. 
            if (varname=='siconc' and itm['units']=='%'):
                out_dic['UNIT'] = 'fraction'
            # NOTE: This is because in MPI-ESM1-2-HR data siconc is in % and WRF expects 0-1 value.    
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
                            n_found = n_found+1
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
