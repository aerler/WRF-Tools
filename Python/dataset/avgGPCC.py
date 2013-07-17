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
GPCCroot = '/home/DATA/DATA/GPCC/'
GPCCdata = GPCCroot + 'full_data_1900-2010/'
res = '05' # 
test = ''
# output settings
debyr = 1979
finyr = 1981
datestr = '%04i-%04i'%(debyr,finyr)
outfile = 'gpcc_%s_clim_%s.nc'%(res,datestr)
# files
filelist = dict(rain = 'full_data_v6_precip_%s.nc'%(res,), #
                stns = 'full_data_v6_statio_%s.nc'%(res,))  
varlist = dict(rain='p', stns='s')
# dimensions
dimlist = dict(lat='lat',lon='lon') # these dimensions will be copied - 'time' is different!

## start execution
if __name__ == '__main__':

  ## open input datasets
  indata = dict()
  # loop over all source files and open them
  for (key,value) in filelist.iteritems(): 
    indata[key] = Dataset(GPCCdata+value, 'r')
    indata[key].variables[varlist[key]].set_auto_maskandscale(False)
  # get some meta data and create land mask  
  datashape = indata['rain'].variables[varlist['rain']].shape # (time, lat, lon)
  missing_value = indata['rain'].variables[varlist['rain']].getncattr('_FillValue')
  dataMask = ( indata['rain'].variables[varlist['rain']][1,:,:] == missing_value )
  # random check that mask is consistent
#   assert ( (indata['rain'].variables[varlist['rain']][16,:,:] == missing_value ) == dataMask ).all()
#   dataMask = 
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
#     sumtmp = np.zeros((ntime, datashape[1],datashape[2]))
    cnt = debmon # start here
    while cnt <= finmon: # including last year   
      print('  %04i'%(cnt/12 +1901,))    
      cnt += ntime      
      sumtmp += indata[key].variables[value][cnt-ntime:cnt,:,:]
#       climdata[key] = ma.array( sumtmp / (finyr-debyr+1), mask=dataMask.repeat(ntime,axis=0))
#                       keep_mask=True, hard_mask=True)
    climdata[key] = sumtmp / (finyr-debyr+1)
#     climdata[key] = ma.masked_less(sumtmp, 0) / (finyr-debyr+1)
      
  ## convert values to mm/day
  days_per_month = np.array([31,28.25,31,30,31,30,31,31,30,31,30,31])
  climdata['rain'] /= days_per_month.reshape((len(days_per_month),1,1)) # convert to mm/day
      
  ## initialize netcdf dataset structure
  print('\nWriting data to disk: %s'%(test+outfile,))
  # create groups for different resolution
  outdata = Dataset(GPCCroot+test+outfile, 'w', format='NETCDF4') # outgrp.createGroup('fineres')
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
  outdata.description = 'Climatology of GPCC monthly precipitation, averaged from %04i to %04i'%(debyr,finyr)
  outdata.creator = 'Andre R. Erler' 
  copy_ncatts(outdata,indata['rain'],prefix='GPCC_')
  # create old lat/lon dimensions and coordinate variables
  copy_dims(outdata, indata['rain'], dimlist=dimlist.keys(), namemap=dimlist, copy_coords=True)
  # create climatology variables  
  dims = ('time','lat','lon'); fill_value = -9999
  # precipitation
  atts = dict(long_name='Precipitation', units='mm/day')
  add_var(outdata, 'rain', dims, values=climdata['rain'].filled(fill_value), atts=atts, fill_value=fill_value)
  # station density
  atts = dict(long_name='Station Density', units='#')
  add_var(outdata, 'stns', dims, values=climdata['stns'].filled(fill_value), atts=atts, fill_value=fill_value)  
  # land mask
  atts = dict(long_name='Land Mask', units='')
  tmp = ma.masked_array(ma.ones((datashape[1],datashape[2])), mask=dataMask)
  add_var(outdata, 'landmask', ('lat','lon'), values=tmp.filled(0))
  
#   ## dataset feedback and diagnostics
#   # print dataset meta data
#   print('\n\n')
#   print(outdata)
#   # print dimensions meta data
#   for dimobj in outdata.dimensions.values():
#     print dimobj
#   # print variable meta data
#   for varobj in outdata.variables.values():
#     print varobj
    
  ## close netcdf files  
  for ncset in indata.itervalues(): ncset.close() # input
  outdata.close() # output
  