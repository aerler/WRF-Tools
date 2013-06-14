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
#   folder = '/home/DATA/DATA/GPCC/gpccavg/'
  folder = '/media/tmp/gpccavg/' # RAM disk  
  infile = 'normals_v2011_25.nc'
  outfile = 'test.nc'
  
  ## set up projections and grids
  ramdrv = gdal.GetDriverByName('MEM')
  # source projection
  src_epsg =  4326 # ordinary lat/lon projection
  xe = 144; ye = 72; dx = 2.5; dy = dx; ulx = -180. ; uly = 90.
  srcgeot = (ulx,dx,0.,uly,0.,-dy) # GT(2) & GT(4) are zero for North-up; GT(1) & GT(5) are pixel width and height; (GT(0),GT(3)) is the top left corner
  srcproj = osr.SpatialReference()
  srcproj.ImportFromEPSG(src_epsg)
  srcdata = ramdrv.Create('', xe, ye, gdal.GDT_Float32)
  srcdata.SetProjection(srcproj.ExportToWkt())
  srcdata.SetGeoTransform(srcgeot)
  # target projection
  tgt_epsg =  4326 # ordinary lat/lon projection
  xe = 360; ye = 180; dx = 1.0; dy = dx; ulx = -180. ; uly = 90.
  tgtgeot = (ulx,dx,0.,uly,0.,-dy) # GT(2) & GT(4) are zero for North-up; GT(1) & GT(5) are pixel width and height; (GT(0),GT(3)) is the top left corner
  tgtproj = osr.SpatialReference()
  tgtproj.ImportFromEPSG(tgt_epsg)
  tgtdata = ramdrv.Create('', xe, ye, gdal.GDT_Float32)
  tgtdata.SetProjection(srcproj.ExportToWkt())
  tgtdata.SetGeoTransform(srcgeot)
  # transformation object
  tx = osr.CoordinateTransformation(srcproj, tgtproj)

  ## set up data sets
  # load source data set from NetCDF
  indata = Dataset(folder+infile, 'r', format='NETCDF4')
  srcdata.GetRasterBand (1).WriteArray(indata.variables['p'][1,:,:].astype(np.float32))
  # set up target dataset
  
  ## reproject and resample
  err = gdal.ReprojectImage( srcdata, tgtdata, srcproj.ExportToWkt(), tgtproj.ExportToWkt(), gdal.GRA_Bilinear )
  
  ## display data
  # get data field
  outdata = tgtdata.ReadAsArray()
  
  # print diagnostic
  print('Mean Precipitation: %3.1f mm/day'%outdata.mean()) 
  
  # display
  import pylab as pyl
  pyl.imshow(outdata.mean(axis=0))
  pyl.colorbar()
  pyl.show()
