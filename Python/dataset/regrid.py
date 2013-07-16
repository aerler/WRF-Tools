'''
Created on 2013-06-14

A script to reproject and resample NetCDF data sets using GDAL

@author: Andre R. Erler
'''

# load libraries
import numpy as np
from osgeo import gdal, osr # , ogr
from netcdf import Dataset

# run conversion
if __name__ == '__main__':
  
  ## settings
  ramdrv = gdal.GetDriverByName('MEM')
#   folder = '/home/DATA/DATA/GPCC/gpccavg/'
  # input
#   folder = '/media/tmp/gpccavg/' # RAM disk  
  folder = '/media/tmp/prismavg/' # RAM disk  
#   infile = 'normals_v2011_25.nc'
  infile = 'prism_clim.nc'
  src_epsg =  4326 # ordinary lat/lon projection
  # output
  outfile = 'test.nc'
  tgt_epsg =  4326 # ordinary lat/lon projection
  res = 0.25 # one degree resolution
  

  ## set up source data
  # load source data set from NetCDF
  print folder+infile
  indata = Dataset(folder+infile, 'r', format='NETCDF4')
  # source projection
  srcproj = osr.SpatialReference()
  srcproj.ImportFromEPSG(src_epsg)
  # get meta data (depends onthe grid)
  if src_epsg ==  4326:
    # get meta data for regular lat/lon grid
    lon = indata.variables['lon']; lat = indata.variables['lat'] # shortcut...
    sxe = len(lon); sye = len(lat)
    sdx = lon[1] - lon[0]; sdy = lat[1] - lat[0]
    sulx = lon[0]; suly = lat[-1] # coordinates of upper left corner (same for source and sink)
  srcgeot = (sulx,sdx,0.,suly,0.,-sdy) # GT(2) & GT(4) are zero for North-up; GT(1) & GT(5) are pixel width and height; (GT(0),GT(3)) is the top left corner
  # create projection object and assign source data
  srcdata = ramdrv.Create('', sxe, sye, gdal.GDT_Float32)
  srcdata.GetRasterBand(1).WriteArray(indata.variables['rain'][1,:,:].astype(np.float32))
  srcdata.SetProjection(srcproj.ExportToWkt())
  srcdata.SetGeoTransform(srcgeot)
  
  ## set up target projection and grid
  # target projection
  tgtproj = osr.SpatialReference()
  tgtproj.ImportFromEPSG(tgt_epsg)
  # transform object for coordinate transformations
  trafo = osr.CoordinateTransformation(srcproj, tgtproj)
  if tgt_epsg == src_epsg:
    tulx = sulx; tuly = suly
  else:
    (tulx, tuly, tulz) = trafo.TransformPoint(sulx, suly)
    (tlrx, tlry, tlrz) = trafo.TransformPoint(sulx+sdx*sxe, suly+sdy*sye)
  # define coordinates
  if tgt_epsg == 4326:
    # regular lat/lon grid
    tdx = res; tdy = res 
    txe = int(sxe*sdx/tdx); tye = int(sye*sdy/tdy)
  tgtgeot = (tulx,tdx,0.,tuly,0.,-tdy) # GT(2) & GT(4) are zero for North-up; GT(1) & GT(5) are pixel width and height; (GT(0),GT(3)) is the top left corner
  # create data set
  tgtdata = ramdrv.Create('', txe, tye, gdal.GDT_Float32)
  tgtdata.SetProjection(tgtproj.ExportToWkt())
  tgtdata.SetGeoTransform(tgtgeot)
  
  ## reproject and resample
  err = gdal.ReprojectImage(srcdata, tgtdata, srcproj.ExportToWkt(), tgtproj.ExportToWkt(), gdal.GRA_Bilinear)
  
  ## display data
  # get data field
  outdata = tgtdata.ReadAsArray()
  
  # print diagnostic
  print outdata.shape
#   print('Mean Precipitation: %3.1f mm/day'%outdata.mean()) 
  
  # display
  import pylab as pyl
  pyl.imshow(np.flipud(outdata[0,:,:])) 
  # N.B.: for some reason an array of the dimension 6 x xe x ye is created, but only the [0,:,:] slice actually contains data 
  pyl.colorbar()
  pyl.show(block=True)
