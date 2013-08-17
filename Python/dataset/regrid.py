'''
Created on 2013-07-29

An extension of the NetCDF-4 Dataset class with GDAL reprojection and resampling features

@author: Andre R. Erler
'''

import numpy as np
import netCDF4 as nc
from osgeo import gdal, osr

# register RAM driver
ramdrv = gdal.GetDriverByName('MEM')

## geo-reference base class for datasets
class ProjDataset(object):
  '''
  A container class for GDAL geo-referencing information with regriding functionality
  '''
  # constructor routine
  def __init__(self, projection=None, geotransform=None, size=None):
    '''
    initialize dataset (GDAL projection objects are passed explicitly); 
    this function should be overloaded to load projections for specific datasets 
    '''    
    # create GDAL meta data and objects
    self.projection = projection # GDAL projection object
    self.geotransform = geotransform # GDAL geotransform vector
    self.size = size # x/y size tuple, can be None
    ## GeoTransform Vector definition:
    # GT(2) & GT(4) are zero for North-up
    # GT(1) & GT(5) are image width and height in pixels
    # GT(0) & GT(3) are the (x/y) coordinates of the top left corner
  # function to return a GDAL dataset
  def getProj(self, bands, dtype='float32', size=None):
    '''
    generic function that returns a gdal dataset, ready for use 
    '''
    # determine GDAL data type
    if dtype == 'float32': gdt = gdal.GDT_Float32
    # determine size
    if not size: size = self.size # should be default  
    # create GDAL dataset 
    dset = ramdrv.Create('', int(size[0]), int(size[1]), int(bands), int(gdt)) 
    #if bands > 6: # add more bands, if necessary
      #for i in xrange(bands-6): dset.AddBand()
    # N.B.: for some reason a dataset is always initialized with 6 bands
    # set projection parameters
    dset.SetGeoTransform(self.geotransform) # does the order matter?
    dset.SetProjection(self.projection.ExportToWkt()) # is .ExportToWkt() necessary?
    # return dataset
    return dset

## simple lat/lon geo-referencing system
class LatLonProj(ProjDataset):
  '''
  A container class for GDAL geo-referencing information with regriding functionality
  '''
  def __init__(self, lon, lat):
    '''
    initialize projection dataset based on (regular) lat/lon vectors
    '''    
    epsg = 4326 # EPSG code for regular lat/long grid
    # size of dataset
    size = (len(lon), len(lat))
    # GDAL geotransform vector
    dx = lon[1]-lon[0]; dy = lat[1]-lat[0]
    ulx = lon[0]-dx/2.; uly = lat[0]-dy/2. # coordinates of upper left corner (same for source and sink)
    # GT(2) & GT(4) are zero for North-up; GT(1) & GT(5) are pixel width and height; (GT(0),GT(3)) is the top left corner
    geotransform = (ulx, dx, 0., uly, 0., dy) 
    # GDAL projection 
    projection = osr.SpatialReference()
    projection.ImportFromEPSG(epsg)
    # create GDAL projection object from parent instance
    super(LatLonProj,self).__init__(projection=projection, geotransform=geotransform, size=size)
    self.epsg = epsg # save projection code number
    
## function to reproject and resample a 2D array
def regridArray(data, srcprj, tgtprj, interpolation='bilinear', missing=None):
  '''
  Function that regrids an array based on a source and a target projection object
  '''
  # condition data (assuming a numpy array)
  dshape = data.shape[0:-2]; ndim = data.ndim
  assert ndim > 1, 'data array needs to have at least two dimensions' 
  sxe = data.shape[-1]; sye = data.shape[-2] # (bnd,lat,lon)
  if ndim == 2: bnds = 1
  else: bnds = np.prod(dshape)
  data = data.reshape(bnds,sye,sxe)    
  ## create source and target dataset
  assert srcprj.size == (sxe, sye), 'data array and data grid have to be of compatible size'
  srcdata = srcprj.getProj(bnds); tgtdata = tgtprj.getProj(bnds)
  txe, tye = tgtprj.size
  fill = np.zeros((tye,txe))
  if missing: fill += missing     
  # assign data
  for i in xrange(bnds):
    srcdata.GetRasterBand(i+1).WriteArray(data[i,:,:])
    # srcdata.GetRasterBand(i+1).WriteArray(np.flipud(data[i,:,:]))
    tgtdata.GetRasterBand(i+1).WriteArray(fill.copy())
    if missing: 
      srcdata.GetRasterBand(i+1).SetNoDataValue(missing)
      tgtdata.GetRasterBand(i+1).SetNoDataValue(missing)
  # determine GDAL interpolation
  if interpolation == 'bilinear': gdal_interp = gdal.GRA_Bilinear
  elif interpolation == 'nearest': gdal_interp = gdal.GRA_NearestNeighbour
  elif interpolation == 'lanczos': gdal_interp = gdal.GRA_Lanczos
  elif interpolation == 'convolution': gdal_interp = gdal.GRA_Cubic # cubic convolution
  elif interpolation == 'cubicspline': gdal_interp = gdal.GRA_CubicSpline # cubic spline
  else: print('Unknown interpolation method: '+interpolation)
  ## reproject and resample
  # srcproj = srcprj.projection.ExportToWkt(); tgtproj =  tgtprj.projection.ExportToWkt()
  # err = gdal.ReprojectImage(srcdata, tgtdata, srcproj, tgtproj, gdal_interp)
  err = gdal.ReprojectImage(srcdata, tgtdata, None, None, gdal_interp)
  if err != 0: print('ERROR CODE %i'%err)  
  # get data field
  if bnds == 1: outdata = tgtdata.ReadAsArray()[:,:] # for 2D fields
  else: outdata = tgtdata.ReadAsArray(0,0,txe,tye)[0:bnds,:,:] # ReadAsArray(0,0,xe,ye)
  if ndim == 2: outdata = outdata.squeeze()
  else: outdata = outdata.reshape(dshape+outdata.shape[-2:])
  # return data    
  return outdata


# run a test    
if __name__ == '__main__':
  
  # input
  folder = '/media/tmp/' # RAM disk
  infile = 'prismavg/prism_clim.nc'
#   infile = 'gpccavg/gpcc_25_clim_1979-1981.nc'
  likefile = 'gpccavg/gpcc_05_clim_1979-1981.nc'

  # load input dataset
  inData = nc.Dataset(filename=folder+infile)
  lon = inData.variables['lon'][:]; lat = inData.variables['lat'][:]
  inProj = LatLonProj(lon=lon, lat=lat)
#   print inData.variables['lat'][:]
  
#   # load pattern dataset
#   likeData = nc.Dataset(filename=folder+likefile)
#   likeProj = LatLonProj(lon=likeData.variables['lon'][:], lat=likeData.variables['lat'][:])
#   print likeData.variables['lat'][:]
  # define new grid
  dlon = dlat = 0.125
  slon = np.floor(lon[0]); elon = np.ceil(lon[-1])
  slat = np.floor(lat[0]); elat = np.ceil(lat[-1])
  newlon = np.linspace(slon+dlon/2,elon-dlon/2,(elon-slon)/dlon)
  newlat = np.linspace(slat+dlat/2,elat-dlat/2,(elat-slat)/dlat)
  likeProj = LatLonProj(lon=newlon, lat=newlat)
  
  # create lat/lon projection
  outdata = regridArray(inData.variables['rain'][:], inProj, likeProj, interpolation='convolution', missing=-9999)
  
  # display
  import pylab as pyl
  for i in xrange(1):
#     pyl.imshow(outdata[i,:,:]); pyl.colorbar(); pyl.show(block=True)
#     pyl.imshow(np.flipud(likeData.variables['rain'][i,:,:])); pyl.colorbar(); pyl.show(block=True)
    pyl.imshow(np.flipud(outdata[i,:,:])); pyl.colorbar(); pyl.show(block=True)
#     pyl.imshow(np.flipud(outdata[i,:,:]-likeData.variables['rain'][i,:,:])); pyl.colorbar(); pyl.show(block=True)  
    
