'''
Created on 2012-11-08

A script to average CFSR monthly data to create a monthly climatology. 
This script does not rely on PyGeode but instead uses netCDF4 and numpy directly.

@author: Andre R. Erler
'''

## imports
# numpy
from numpy import arange, array, zeros
# import netCDF4-python and added functionality
from netcdf import Dataset, copy_ncatts, copy_vars, copy_dims, add_coord

## settings
CFSRroot = '/home/DATA/DATA/CFSR/'
CFSRdata = CFSRroot + 'Monthly/'
test = 'test_'
# output settings
finyr = 10; finmon = 0 # same as 
datestr = '1979-%04i'%(1979+finyr-1)
if finmon: datestr = '%s_%02i'(datestr,finmon)
fnoutfile = 'cfsr_fn_clim_%s.nc'%datestr
hioutfile = 'cfsr_hi_clim_%s.nc'%datestr
#test = 'test/'
# files
zsfile = 'flxf06.gdas.HGT.SFC.grb2.nc' # topography (surface geopotential)
lndfile = 'flxf06.gdas.LAND.SFC.grb2.nc' # land mask
prtfile = 'flxf06.gdas.PRATE.SFC.grb2.nc' # precipitation rate
psfile = 'flxf06.gdas.PRES.SFC.grb2.nc' # surface pressure 
pmslfile = 'pgbh06.gdas.PRMSL.MSL.grb2.nc' # MSL pressure (lower resolution!)
T2file = 'flxf06.gdas.TMP.2m.grb2.nc' # 2m temperature
Tsfile = 'flxf06.gdas.TMP.SFC.grb2.nc' # skin temperature
snowhfile = 'flxf06.gdas.SNO_D.SFC.grb2.nc' # snow depth
snowfile = 'flxf06.gdas.WEASD.SFC.grb2.nc' # water-equivalent of accumulated snow  
# data groups
# static highest resolution gaussian grid (lat = 576 / lon = 1152)
fnstatfile = dict(zs=zsfile, lnd=lndfile) 
fnstatvar = dict(zs='HGT_L1', lnd='LAND_L1')
# time-dependent fine (highest) resolution gaussian grid (lat = 576 / lon = 1152)
fndynfile = dict(rain=prtfile, ps=psfile, Ts=Tsfile, T2=T2file, snowh=snowhfile, snow=snowfile)
fndynvar = dict(rain='PRATE_L1', ps='PRES_L1', Ts='TMP_L1', T2='TMP_L103_Avg', 
                snowh='SNO_D_L1', snow='WEASD_L1')
# time-dependent high resolution regular 0.5 deg lat/lon grid (lat = 361 / lon = 720)
hidynfile = dict(pmsl=pmslfile) 
hidynvar = dict(pmsl='PRMSL_L101') 
# dimensions
#tdim = dict(time='time',tstrlen='tstrlen')
fndim = dict(lat='lat',lon='lon'); hidim = fndim

## start execution
if __name__ == '__main__':

  ## open input datasets
  fnstatset = dict(); fndynset = dict(); hidynset = dict() 
  for (key,value) in fnstatfile.iteritems(): fnstatset[key] = Dataset(CFSRdata+value, 'r')
  for (key,value) in fndynfile.iteritems(): fndynset[key] = Dataset(CFSRdata+value, 'r')
  for (key,value) in hidynfile.iteritems(): hidynset[key] = Dataset(CFSRdata+value, 'r')
  fnshape = fndynset['rain'].variables[fndynvar['rain']].shape # (time, lat, lon)
  hishape = hidynset['pmsl'].variables[hidynvar['pmsl']].shape # (time, lat, lon)  
  
  ## perform actual computation of climatologies
  ntime = 12
  if finyr:
    fnmax = 12*(finyr-1) + finmon; himax = fnmax          
  else: 
    fnmax = fnshape[0]; himax = hishape[0]
  
  fndynclim = dict(); hidynclim = dict()
  for (key,value) in fndynvar.iteritems():
    tmp = zeros((ntime, fnshape[1],fnshape[2])); cnt = 0
    while cnt <= fnmax:      
      if key =='rain': print('Processing year %04i'%(cnt/ntime +1979,))
      cnt += ntime
      tmp +=  fndynset[key].variables[value][cnt-ntime:cnt,:,:]
#    if key =='rain': print(cnt/ntime)
    fndynclim[key] = tmp / (cnt/ntime)            
  for (key,value) in hidynvar.iteritems():
    tmp = zeros((ntime, hishape[1],hishape[2])); cnt = 0
    while cnt <= himax:      
      cnt += ntime
      tmp +=  hidynset[key].variables[value][cnt-ntime:cnt,:,:]
    hidynclim[key] = tmp / (cnt/ntime)
      
  ## initialize netcdf dataset structure
  print('\nWriting data to disk:')  
  # create groups for different resolution
  fngrp = Dataset(CFSRroot+test+fnoutfile, 'w', format='NETCDF4') # outgrp.createGroup('fineres')
  higrp = Dataset(CFSRroot+test+hioutfile, 'w', format='NETCDF4') # outgrp.createGroup('highres')
  # new time dimensions
  months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
            'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
  days = array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31])
  # create time dimensions and coordinate variables
  for grp in [fngrp, higrp]:
    add_coord(grp,'time',arange(1,ntime+1),dtype='i4')
    grp.createDimension('tstrlen', 9) # name of month string
    grp.createVariable('ndays','i4',('time',))[:] = days
    # names of months (as char array)
    coord = grp.createVariable('month','S1',('time','tstrlen'))
    for m in xrange(ntime): 
      for n in xrange(9): coord[m,n] = months[m][n]
  # global attributes
  if finmon: description = \
    'Climatology of CFSR monthly means, averaged from January 1979 to %s %04i'%(months[finmon],1979+finyr-1)
  else: description = 'Climatology of CFSR monthly means, averaged from 1979 to %04i'%(1979+finyr-1)
  creator = 'Andre R. Erler'
  # fine grid
  fngrp.description = description
  fngrp.creator = creator 
  copy_ncatts(fngrp,fndynset['rain'],prefix='CFSR_')
#  for att in fndynset['prt'].ncattrs(): fngrp.setncattr('SRC_'+att,fndynset['prt'].getncattr(att))
  higrp.description = description
  higrp.creator = creator 
  copy_ncatts(fngrp,hidynset['pmsl'],prefix='CFSR_')
  # create old lat/lon dimensions and coordinate variables
  copy_dims(fngrp, fndynset['rain'], dimlist=fndim.keys(), namemap=fndim, copy_coords=True)
  copy_dims(higrp, hidynset['pmsl'], dimlist=hidim.keys(), namemap=hidim, copy_coords=True)
  # copy static variables into new dataset
  for (key,value) in fnstatset.iteritems():
    copy_vars(fngrp, value, [key], namemap=fnstatvar, remove_dims=['time'], incl_=False) # '_' causes problems
  # create dynamic/time-dependent variables  
  for (key,value) in fndynset.iteritems():
    copy_vars(fngrp, value, [key], namemap=fndynvar, copy_data=False)
    fngrp.variables[key][:,:,:] = fndynclim[key] 
  for (key,value) in hidynset.iteritems():
    copy_vars(higrp, value, [key], namemap=hidynvar, copy_data=False)
    higrp.variables[key][:,:,:] = hidynclim[key]
    
  
  ## dataset feedback and diagnostics
  # dataset and groups
#  print outgrp
#  print outgrp.file_format
#  print fngrp
#  print higrp
  # dimensions
#  for dimobj in outgrp.dimensions.values():
#    print dimobj
#  for dimobj in fngrp.dimensions.values():
#    print dimobj
#  for dimobj in higrp.dimensions.values():
#    print dimobj
  # variables
#  for varobj in outgrp.variables.values():
#    print varobj
#  for varobj in fngrp.variables.values():
#    print varobj
#  for varobj in higrp.variables.values():
#    print varobj
    
  ## close
  # input
  for ncset in fnstatset.itervalues(): ncset.close()
  for ncset in fndynset.itervalues(): ncset.close()
  for ncset in hidynset.itervalues(): ncset.close()
  # output
#  outgrp.close()
  fngrp.close()
  print('   %s'%(test+fnoutfile,))
  higrp.close()
  print('   %s'%(test+hioutfile,))
  