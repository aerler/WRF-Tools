'''
Created on 2013-06-06

Script to read PRISM data from ASCII files and write to NetCDF format

@author: Andre R. Erler
'''

# imports
from numpy import array, arange
from socket import gethostname
## global data
days_per_month = array([31,28.25,31,30,31,30,31,31,30,31,30,31])
# days_per_month = array([31]) # for development
ntime = len(days_per_month) # number of month
# data root folder
hostname = gethostname()
if hostname=='komputer':
  PRISMroot = '/home/DATA/DATA/PRISM/'
#   PRISMroot = '/media/tmp/PRISM/' # RAM disk for development
else:
  PRISMroot = '/home/me/DATA/PRISM/'


# loads data from original ASCII files and returns numpy arrays
# data is assumed to be stored in monthly intervals
def loadASCII(var, fileformat='BCY_%s.%02ia', arrayshape=(601,697)):
  # local imports
  from numpy.ma import zeros
  from numpy import genfromtxt, flipud
  # definitions
  datadir = PRISMroot + 'Climatology/ASCII/' # data folder   
  ntime = len(days_per_month) # number of month
  # allocate space
  data = zeros((ntime,)+arrayshape) # time = ntime, (x, y) = arrayshape  
  # loop over month
  print('  Loading variable %s from file.'%(var))
  for m in xrange(ntime):
    # read data into array
    filename = fileformat%(var,m+1)
    tmp = genfromtxt(datadir+filename, dtype=float, skip_header=5, missing_values=-9999, filling_values=-9999, usemask=True)
    data[m,:] = flipud(tmp)  
    # N.B.: the data is loaded in a masked array (where missing values are omitted)   
  # return array
  return data

# function to generate lat/lon coordinate axes for the data set
# the data is assumed to be in a simple lat/lon projection
def genCoord():
  # imports
  from numpy import linspace, diff, finfo
  eps = finfo(float).eps  
  # settings / PRISM meta data
  nlat = 601
  nlon = 697
  llclat = 46.979166666667
  llclon = -142.020833333333
  dlat = dlon = 0.041666666667  
  # generate coordinate arrays
  lat = linspace(llclat, llclat+(nlat-1)*dlat, nlat)
  assert (diff(lat).mean() - dlat) < eps 
  lon = linspace(llclon, llclon+(nlon-1)*dlon, nlon)
  assert (diff(lon).mean() - dlon) < eps  
  # return coordinate arrays (in degree)
  return lat, lon

if __name__ == '__main__':
    
    ## load data
    
    # read precip data        
    ppt = loadASCII('Ppt')
    # rescale data (divide by 100 & days per month)
    ppt /= days_per_month.reshape((len(days_per_month),1,1)) * 100. # convert to mm/day
    # print diagnostic
    print('Mean Precipitation: %3.1f mm/day'%ppt.mean())
    
    # read temperature data
    Tmin = loadASCII('Tmin'); Tmin /= 100.; Tmin += 273.15 # convert to Kelvin
    Tmax = loadASCII('Tmax'); Tmax /= 100.; Tmax += 273.15    
#     Tavg = loadASCII('Tavg'); Tavg /= 100.; Tavg += 273.15
    Tavg = ( Tmin + Tmax ) / 2. # temporary solution for Tavg, because the data seems to be corrupted
    # print diagnostic
    print('Min/Mean/Max Temperature: %3.1f / %3.1f / %3.1f C'%(Tmin.mean(),Tavg.mean(),Tmax.mean()))
    
    # get coordinate axes
    lat, lon = genCoord()
    
#     # display
#     import pylab as pyl
#     pyl.pcolormesh(lon, lat, ppt.mean(axis=0))
#     pyl.colorbar()
#     pyl.show(block=True)

    ## create NetCDF file
    # import netCDF4-python and added functionality
    from netcdf import Dataset, add_coord, add_var
    # settings
    outfile = 'prism_clim.nc'
#     prefix = 'test_' # development prefix
    prefix = 'prismavg/' # production prefix
    
    
    # initialize netcdf dataset structure
    print('\nWriting data to disk: %s'%(prefix+outfile,))
    # create groups for different resolution
    outdata = Dataset(PRISMroot+prefix+outfile, 'w', format='NETCDF4') # outgrp.createGroup('fineres')
    # new time dimensions
    months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
              'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
    # create time dimensions and coordinate variables
    add_coord(outdata,'time',arange(1,ntime+1),dtype='i4')
    outdata.createDimension('tstrlen', 9) # name of month string
    outdata.createVariable('ndays','i4',('time',))[:] = days_per_month
    # names of months (as char array)
    coord = outdata.createVariable('month','S1',('time','tstrlen'))
    for m in xrange(ntime): 
      for n in xrange(9): coord[m,n] = months[m][n]
    # global attributes
    outdata.description = 'Climatology of monthly PRISM data'
    outdata.creator = 'Andre R. Erler' 
    
#     copy_ncatts(outdata,indata['rain'],prefix='GPCC_')
    # create new lat/lon dimensions and coordinate variables
    add_coord(outdata, 'lat', values=lat, atts=None)
    add_coord(outdata, 'lon', values=lon, atts=None)
    # create climatology variables  
    fill_value = -9999
    atts = dict(long_name='Precipitation', units='mm/day')
    add_var(outdata, 'rain', ('time','lat','lon'), values=ppt.filled(fill_value), atts=atts, fill_value=fill_value)
    atts = dict(long_name='Minimum Temperature', units='deg. C')
    add_var(outdata, 'Tmin', ('time','lat','lon'), values=Tmin.filled(fill_value), atts=atts, fill_value=fill_value)
    atts = dict(long_name='Average Temperature', units='deg. C')
    add_var(outdata, 'T2', ('time','lat','lon'), values=Tavg.filled(fill_value), atts=atts, fill_value=fill_value)
    atts = dict(long_name='Maximum Temperature', units='deg. C')
    add_var(outdata, 'Tmax', ('time','lat','lon'), values=Tmax.filled(fill_value), atts=atts, fill_value=fill_value)
    
    # dataset feedback and diagnostics
    # print dataset meta data
    print outdata
    # print dimensions meta data
    for dimobj in outdata.dimensions.values():
      print dimobj
    # print variable meta data
    for varobj in outdata.variables.values():
      print varobj
    
    # close netcdf files  
    outdata.close() # output
