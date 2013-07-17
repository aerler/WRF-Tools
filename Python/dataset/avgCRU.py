'''
Created on 2012-11-08

A script to average CFSR monthly data to create a monthly climatology. 
This script does not rely on PyGeode but instead uses netCDF4 and numpy directly.

@author: Andre R. Erler
'''

## imports
# numpy
import numpy as np
import numpy.ma as ma
# import netCDF4-python and added functionality
from netcdf import Dataset, copy_ncatts, add_var, copy_dims, add_coord

## settings
CRUroot = '/home/DATA/DATA/CRU/'
CRUdata = CRUroot + '/Time-series 3.2/data/'
test = ''
# output settings
debyr = 1979
finyr = 1981
datestr = '%04i-%04i'%(debyr,finyr)
outfile = 'cru_clim_%s.nc'%(datestr,)
# files (one per variable)
varlist = dict(rain='pre', T2='tmp', Tmin='tmn', Tmax='tmx', Q2='vap') # for now... there are more variables to come!
filelist = dict() # construct file list from variable list 
for (key,value) in varlist.iteritems():
  filelist[key] = 'cru_ts3.20.1901.2011.%s.dat.nc'%(value,)  
# dimensions
dimlist = dict(lat='lat',lon='lon') # these dimensions will be copied - 'time' is different!

## start execution
if __name__ == '__main__':

  ## open input datasets
  indata = dict() 
  # loop over all source files and open them
  for (key,value) in filelist.iteritems(): 
    indata[key] = Dataset(CRUdata+value, 'r')
    indata[key].variables[varlist[key]].set_auto_maskandscale(False)
  # get some meta data and create land mask  
  datashape = indata['rain'].variables[varlist['rain']].shape # (time, lat, lon)
  missing_value = indata['rain'].variables[varlist['rain']].getncattr('_FillValue')
  dataMask = ( indata['rain'].variables[varlist['rain']][1,:,:] == missing_value ) 
#  # print some meta data  
#  print indata['rain'].variables[varlist['rain']]
#  print indata['rain'].dimensions[dimlist['lat']]
#  print indata.variables.keys()
#  print indata.dimensions.keys()
  
  ## perform actual computation of climatologies
  ntime = 12 # 12 month per year...
  debmon = max((debyr-1901)*ntime,0) # time begins in 1901 
  finmon = min((finyr-1901)*ntime,datashape[0]) # time ends in 2010
  # loop over variables 
  climdata = dict()
  for (key,value) in varlist.iteritems():
    print('\nProcessing %s'%(key))
    sumtmp = ma.array(np.zeros((ntime, datashape[1],datashape[2])), keep_mask=True, hard_mask=True,
                      mask=dataMask.reshape(1,datashape[1],datashape[2]).repeat(ntime,axis=0))
#     sumtmp = zeros((ntime, datashape[1],datashape[2])); 
    cnt = debmon # start here
    while cnt <= finmon: # including last year   
      print('  %04i'%(cnt/12 +1901,))    
      cnt += ntime
      sumtmp +=  indata[key].variables[value][cnt-ntime:cnt,:,:]
    climdata[key] = sumtmp / (finyr-debyr+1)
    
  ## convert values if necessary
  days_per_month = np.array([31,28.25,31,30,31,30,31,31,30,31,30,31])
  climdata['rain'] /= days_per_month.reshape((len(days_per_month),1,1)) # convert to mm/day
  climdata['Tmin'] += 273.15 # convert to Kelvin
  climdata['T2'] += 273.15 # convert to Kelvin
  climdata['Tmax'] += 273.15 # convert to Kelvin
      
  ## initialize netcdf dataset structure
  print('\nWriting data to disk:')
  # create groups for different resolution
  outdata = Dataset(CRUroot+test+outfile, 'w', format='NETCDF4') # outgrp.createGroup('fineres')
  # new time dimensions
  months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
            'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
  # create time dimensions and coordinate variables
  add_coord(outdata,'time',np.arange(1,ntime+1),dtype='i4')
  outdata.createDimension('tstrlen', 9) # name of month string
  outdata.createVariable('ndays','i4',('time',))[:] = days_per_month
  # names of months (as char array)
  coord = outdata.createVariable('month','S1',('time','tstrlen'))
  for m in xrange(ntime): 
    for n in xrange(9): coord[m,n] = months[m][n]
  # global attributes
  outdata.description = 'Climatology of CRU monthly climate data, averaged from %04i to %04i'%(debyr,finyr)
  outdata.creator = 'Andre R. Erler' 
  copy_ncatts(outdata,indata['rain'],prefix='CRU_')
  # create old lat/lon dimensions and coordinate variables
  copy_dims(outdata, indata['rain'], dimlist=dimlist.keys(), namemap=dimlist, copy_coords=True)
  # create climatology variables  
  dims = ('time','lat','lon'); fill_value = -9999
  # precipitation
  atts = dict(long_name='Precipitation', units='mm/day')
  add_var(outdata, 'rain', dims, values=climdata['rain'].filled(fill_value), atts=atts, fill_value=fill_value)
  # 2m mean Temperature
  atts = dict(long_name='Temperature at 2m', units='K')
  add_var(outdata, 'T2', dims, values=climdata['T2'].filled(fill_value), atts=atts, fill_value=fill_value)  
  # 2m maximum Temperature
  atts = dict(long_name='Maximum 2m Temperature', units='K')
  add_var(outdata, 'Tmax', dims, values=climdata['Tmax'].filled(fill_value), atts=atts, fill_value=fill_value)  
  # 2m minimum Temperature
  atts = dict(long_name='Minimum 2m Temperature', units='K')
  add_var(outdata, 'Tmin', dims, values=climdata['Tmin'].filled(fill_value), atts=atts, fill_value=fill_value)  
  # 2m water vapor
  atts = dict(long_name='Water Vapor Pressure at 2m', units='hPa')
  add_var(outdata, 'Q2', dims, values=climdata['Q2'].filled(fill_value), atts=atts, fill_value=fill_value)  
  # land mask
  atts = dict(long_name='Land Mask', units='')
  tmp = ma.masked_array(ma.ones((datashape[1],datashape[2])), mask=dataMask)
  add_var(outdata, 'landmask', ('lat','lon'), values=tmp.filled(0)) # create climatology variables  
#   for (key,value) in indata.iteritems():
#     copy_vars(outdata, value, [key], namemap=varlist, copy_data=False, fill_value=) # , incl_=True
#     outdata.variables[key][:,:,:] = climdata[key] 
        
  
#  ## dataset feedback and diagnostics
#  # print dataset meta data
#  print outdata
#  # print dimensions meta data
#  for dimobj in outdata.dimensions.values():
#    print dimobj
#  # print variable meta data
#  for varobj in outdata.variables.values():
#    print varobj
    
  ## close netcdf files  
  for ncset in indata.itervalues(): ncset.close() # input
  outdata.close() # output
  print('   %s'%(test+outfile,))