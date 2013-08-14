'''
Created on 2013-08-13

This module provides a class that contains definitions of source and target datasets and methods to process variables 
in these datasets. This class can be imported and extended by modules that perform specific tasks on specific datasets.
Simple methods for copying and averaging variables are already provided in this class.

@author: Andre R. Erler
'''

# import netCDF4-python and added functionality
from netcdf import Dataset, copy_ncatts, add_var, copy_dims, add_coord
# numpy
import numpy as np
import numpy.ma as ma
# misc system stuff
from warnings import warn
import os

## Dataset Definition Class for NetCDF files
class NetcdfProcessor(object):
  
  ## member variables
  # input
  infiles = [''] # path and name of all input files 
  prefixes = [''] # prefixes associated with each input file (used to prevent naming conflicts)
  # output
  outfile = '' # path and name of the output file
  zlib = False # use netcdf-4 compression feature 
  lgrp = False # store input datasets in different groups (use prefixes as names)
  lvarpfx = False # also use prefixes for variables, not only for global attributes  
  
  ## member methods
  # constructor
  def __init__(self, infiles=None, outfile='', folder='', infile='', prefixes=None, prefix='', **kwargs):
    ''' Define names of input and output datasets and set general processing parameters. '''
    # required arguments
    if infile and not infiles: infiles = [infile] 
    if not prefixes: 
      if prefix: self.prefixes = [prefix]
      else: self.prefixes = ['']*len(infiles)
    assert len(infiles) == len(self.prefixes), 'Input file list and prefix list have to be of the same length!'
    if folder:
      assert os.path.exists(folder), 'Folder \'%s\' does not exist!'%folder
      self.infiles = ['%s/%s'%(folder,infile) for infile in infiles]
      self.outfile = '%s/%s'%(folder,outfile)
    else:
      self.infiles = infiles
      self.outfile = outfile
    # check if input files and output folder are present
    for infile in self.infiles:
      assert os.path.exists(infile), 'Input file \'%s\' does not exist!'%infile
    assert os.path.exists(os.path.dirname(self.outfile)), 'Output folder \'%s\' does not exist!'%folder
    # optional arguments, if given
    # N.B.: at the moment all kwrgs are translated into member variables; if they don't exist, they are added
    for key,val in kwargs.iteritems():
      self.__dict__[key] = val # if the variable doesn't exist, it will be added
#     varset = set(vars(self))
#     for key,val in kwargs.iteritems():
#       if key in varset: self.__dict__[key] = val 
#       else: warn('invalid key-word argument \'%s\''%kwarg)
      
    
  # define parameters of input dataset
  def initInput(self):
    ''' This method defines input parameters and initializes the input dataset(s). '''
    # open input datasets
    self.indatas = [Dataset(infile, 'r') for infile in self.infiles] # read only
    self.indata = self.indatas[0] # "active dataset"
    self.prefix = self.prefixes[0] 
    
  # define parameters of output dataset
  def initOutput(self):
    ''' This method defines output parameters and initializes the output dataset. '''
    # create output dataset
    self.outdata = Dataset(self.outfile, 'w', format='NETCDF4') # write new netcdf-4 file
  
  # set operation parameters
  def defineOperation(self):
    ''' This method defines the operation and the parameters for the operation performed on the dataset. '''
    pass
  
  # perform operation (dummy method)
  def performOperation(self, **kwargs):
    ''' This method performs the actual operation on the variables; it is defined in specialized child classes. '''
    # dummy method: look up variable in current input dataset and copy everything
    varname = kwargs['name']
    ncvar = self.indata.variables[varname]
    newname = varname
    newvals = ncvar[:]
    newdims = ncvar.dimensions
    newdtype = ncvar.dtype
    newatts = dict(zip(ncvar.ncattrs(),[ncvar.getncattr(att) for att in ncvar.ncattrs()])) 
    # this method needs to return all the information needed to create a new netcdf variable    
    return newname, newvals, newdims, newatts, newdtype
  
  # main processor function
  def processDataset(self):
    ''' This method creates the output dataset and applies the desired operation to each variable. '''    
    # loop over input datasets
    for indata,prefix in zip(self.indatas,self.prefixes):
      self.indata = indata # active file/dataset
      self.prefixes = prefix
      # copy global attributes
      copy_ncatts(self.outdata, self.indata, prefix=self.prefix)
      # loop over variables
      for varname in self.indata.variables.keys():
        # apply operation 
        print varname
        newname, newvals, newdims, newatts, newdtype = self.performOperation(name=varname)
        # create new variable in output dataset
        add_var(self.outdata, newname, newdims, values=newvals, atts=newatts, dtype=newdtype, zlib=self.zlib)
        
    # close output dataset and return handle
    self.outdata.close()


## Class for regridding  datasets
class NetcdfRegrid(NetcdfProcessor):

  ## member variables
  inCoords = None # names and values of input coordinate vectors (dict)
  outCoords = None # names and values of output coordinate vectors (dict)
  mapCoords = None # mapping of map coordinates, i.e. lon -> x / lat -> y (dict)

  ## member methods
  # constructor
  def __init__(self, **kwargs):
    ''' Define names of input and output datasets and set general processing parameters. '''
    super(NetcdfRegrid,self).__init__(**kwargs)
    self.inCoords = dict()
    self.outCoords = dict()
    self.mapCoords = dict()      
  
  # define parameters of input dataset
  def initInput(self, epsg=4326, **kwargs):
    ''' This method defines parameters of the input dataset. '''
    # open input datasets
    super(NetcdfRegrid,self).initInput(**kwargs)
    # add regridding functionality
    if epsg == 4326:
      # spherical coordinates
      from regrid import LatLonProj
      lon = self.indata.variables['lon'][:]; self.inCoords['lon'] = lon
      lat = self.indata.variables['lat'][:]; self.inCoords['lat'] = lat
      self.inProj = LatLonProj(lon, lat)
    elif epsg is None:
      # euclidian coordinates 
      x = self.indata.variables['x'][:]; self.inCoords['x'] = x
      y = self.indata.variables['y'][:]; self.inCoords['y'] = y      
    
  # define parameters of output dataset
  def initOutput(self, template=None, lon=None, lat=None, x=None, y=None, epsg=4326, **kwargs):
    ''' This method defines output parameters and initializes the output dataset. '''
    assert ( isinstance(lon,np.ndarray) and isinstance(lat,np.ndarray) ) or \
           ( isinstance(x,np.ndarray) and isinstance(y,np.ndarray) ) or \
           ( isinstance(template,Dataset) or isinstance(template,str) ), \
           'Either input arguments \'lon\'/\'lat\' or \'x\'/\'y\' need to be defined (as numpy arrays)!' 
    # create output dataset
    super(NetcdfRegrid,self).initOutput(**kwargs)
    # check template
    if template: 
      if isinstance(template,str): template = Dataset(template)
      if template.variables.has_key('lon') and template.variables.has_key('lat') and \
         (len(template.variables['lon'].dimensions) == 1) and \
         (len(template.variables['lat'].dimensions) == 1): epsg = 4326 
    # add regridding functionality
    if epsg == 4326:
      # spherical coordinates
      from regrid import LatLonProj
      if template: # get coordinate arrays from template 
        lon = template.variables['lon'][:]; lat = template.variables['lat'][:]
      self.outCoords['lon'] = lon; self.outCoords['lat'] = lat
      self.outProj = LatLonProj(lon, lat)
    elif epsg is None: 
      # euclidian coordinates
      if template: # get coordinate arrays from template 
        x = template.variables['x'][:]; y = template.variables['y'][:]
      self.outCoords['x'] = x; self.outCoords['y'] = x
  
  # set operation parameters
  def defineOperation(self, interpolation='', **kwargs):
    ''' This method defines the operation and the parameters for the operation performed on the dataset. '''
    super(NetcdfRegrid,self).defineOperation(**kwargs)
    self.interpolation = interpolation
    self.mapCoords = dict(zip(self.inCoords.keys(), self.outCoords.keys()))
  
  # perform operation (dummy method)
  def performOperation(self, **kwargs):
    ''' This method performs the actual operation on the variables; it is defined in specialized child classes. '''
    # regridding is performed by regridArray function
    from regrid import regridArray
    # get variable
    varname = kwargs['name']
    ncvar = self.indata.variables[varname]
    # copy meta data 
    newname = varname
    newdims = [self.mapCoords.get(dim,dim) for dim in ncvar.dimensions] # map horizontal coordinate dimensions
    newdtype = ncvar.dtype
    newatts = dict(zip(ncvar.ncattrs(),[ncvar.getncattr(att) for att in ncvar.ncattrs()]))
    # decide what to do
#     print ncvar
#     print self.inCoords.keys()
#     print self.outCoords.keys()
#     print '\n\n'
    if self.inCoords.viewkeys() <= set(ncvar.dimensions): # 2D or more will be regridded
      data = ncvar[:] # the netcdf module returns masked arrays! 
      if '_FillValue' in ncvar.ncattrs(): 
        fillValue = ncvar.getncattr('_FillValue')
        if isinstance(data,np.ma.masked_array): data = data.filled(fillValue)
      else: fillValue = None
      newvals = regridArray(data, self.inProj, self.outProj, interpolation=self.interpolation, missing=fillValue)
#       if fillValue: 
#         newvals = np.ma.masked_where(newvals == 0, newvals)
#       import pylab as pyl
#       pyl.imshow(np.flipud(newvals[0,:,:])); pyl.colorbar(); pyl.show(block=True)
    elif varname in self.inCoords: 
      newname = self.mapCoords[varname] # new name for map coordinate
      newvals = self.outCoords[newname] # assign new coordinate values
    else: # other coordinate variables are left alone
      newvals = ncvar[:]
    # this method needs to return all the information needed to create a new netcdf variable    
    return newname, newvals, newdims, newatts, newdtype

## some code for testing 
if __name__ == '__main__':

  # input dataset
  infolder = '/media/tmp/' # RAM disk
  prismfile = infolder + 'prismavg/prism_clim.nc'
  gpccfile = infolder + 'gpccavg/gpcc_05_clim_1979-1981.nc' 
  # output dataset
  outfolder = '/media/tmp/test/' # RAM disk
#   outfile = outfolder + 'prism_test.nc'
  outfile = outfolder + 'gpcc_test.nc'

  ## launch test
#   ncpu = NetcdfProcessor(infile=infile, outfile=outfile, prefix='test_')
#   ncpu.initInput(); ncpu.initOutput(); ncpu.defineOperation()
  ncpu = NetcdfRegrid(infile=gpccfile, outfile=outfile, prefix='test_')
  ncpu.initInput()
  dx = 0.5
  lon = np.linspace(-145+dx/2,-115-dx/2,30/dx); lat = np.linspace(45+dx/2,65-dx/2,20/dx) 
  ncpu.initOutput(template=prismfile,lon=lon,lat=lat)
  ncpu.defineOperation(interpolation='bilinear')
  outdata = ncpu.processDataset()
  
  ## show output
  outdata = Dataset(outfile, 'r')
  print
  print outdata
  
    # display
  import pylab as pyl
  vardata = outdata.variables['rain']
  for i in xrange(1):
#     pyl.imshow(outdata[i,:,:]); pyl.colorbar(); pyl.show(block=True)
#     pyl.imshow(np.flipud(likeData.variables['rain'][i,:,:])); pyl.colorbar(); pyl.show(block=True)
    pyl.imshow(np.flipud(vardata[i,:,:])); pyl.colorbar(); pyl.show(block=True)
#     pyl.imshow(np.flipud(outdata[i,:,:]-likeData.variables['rain'][i,:,:])); pyl.colorbar(); pyl.show(block=True)  
    

  