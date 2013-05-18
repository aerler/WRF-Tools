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
CRUroot = '/home/DATA/DATA/CRU/'
CRUdata = CRUroot + '/Time-series 3.2/data/'
test = ''
# output settings
debyr = 1979
finyr = 1988
datestr = '%04i-%04i'%(debyr,finyr)
outfile = 'cru_clim_%s.nc'%(datestr,)
# files (one per variable)
varlist = dict(rain='pre', T2='tmn', Q2='vap') # for now... there are more variables to come!
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
  datashape = indata['rain'].variables[varlist['rain']].shape # (time, lat, lon)
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
    tmp = zeros((ntime, datashape[1],datashape[2])); 
    cnt = debmon # start here
    while cnt <= finmon: # including last year   
      if key =='rain': print('Processing year %04i'%(cnt/12 +1901,))    
      cnt += ntime
      tmp +=  indata[key].variables[value][cnt-ntime:cnt,:,:]
    climdata[key] = tmp / (finyr-debyr+1)        
      
  ## initialize netcdf dataset structure
  print('\nWriting data to disk: %s'%(test+outfile,))
  # create groups for different resolution
  outdata = Dataset(CRUroot+test+outfile, 'w', format='NETCDF4') # outgrp.createGroup('fineres')
  # new time dimensions
  months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
            'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
  days = array([31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31])
  # create time dimensions and coordinate variables
  add_coord(outdata,'time',arange(1,ntime+1),dtype='i4')
  outdata.createDimension('tstrlen', 9) # name of month string
  outdata.createVariable('ndays','i4',('time',))[:] = days
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
  for (key,value) in indata.iteritems():
    copy_vars(outdata, value, [key], namemap=varlist, copy_data=False) # , incl_=True
    outdata.variables[key][:,:,:] = climdata[key] 
        
  
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
  