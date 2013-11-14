'''
Created on 2013-10-01

A module defining a base class and some instances, which provide a mechanism to add derived/secondary variables
to WRF monthly means generated with the wrfout_average module.
The DerivedVariable instances are imported by wrfout_average and its methods are executed at the appropriate 
points during the averaging process.   

@author: Andre R. Erler
'''

## imports
import netCDF4 as nc
# import numpy as np
# my own netcdf stuff
from geodata.nctools import add_var

# class for errors with derived variables
class DerivedVariableError(Exception):
  ''' Exceptions related to derived variables. '''
  pass

class DerivedVariable(object):
  '''
    Instances of this class are imported by wrfout_average; it defines methods that the averaging script uses,
    to create the NetCDF variable and compute the values for a given derived variable.
    This is the base class and variable creation etc. is defined here.
    Computation of the values has to be defined in the appropriate child classes, as it depends on the variable.
  '''

  def __init__(self, name=None, units=None, prerequisites=None, axes=None, dtype=None, atts=None, linear=False):
    ''' Create and instance of the class, to be imported by wrfout_average. '''
    # set general attributes
    self.prerequisites = prerequisites # a list of variables that this variable depends upon 
    self.linear = linear # only linear computation are supported, i.e. they can be performed after averaging
    self.checked = False # indicates whether prerequisites were checked
    # set NetCDF attributes
    self.axes = axes # dimensions of NetCDF variable 
    self.dtype = dtype # data type of NetCDF variable
    self.atts = atts # attributes; mainly used as NetCDF attributes
    # infer more attributes
    self.atts = atts or dict()
    if name is not None: 
      self.atts['name'] = self.name = name # name of the variable, also used as the NetCDF variable name
    else: self.name = atts['name']
    if units is not None:    
      self.atts['units'] = self.units = units  # units... also
    else: self.units = atts['units']
    
  def checkPrerequisites(self, target, const=None):
    ''' Check if all required variables are in the source NetCDF dataset. '''
    if not isinstance(target, nc.Dataset): raise TypeError
    if not (const is None or isinstance(const, nc.Dataset)): raise TypeError
    check = True # any mismatch will set this to False
    # check all prerequisites
    for var in self.prerequisites:
      if var in target.variables:
        # check if prerequisite variable has compatible dimensions (including broadcasting) 
        check = all([ax in self.axes for ax in target.variables[var].dimensions])
      elif const is not None and var in const.variables:
        check = all([ax in self.axes for ax in const.variables[var].dimensions])         
      else: 
        check = False # prerequisite variable not found
    self.checked = check 
    return check
  
  def createVariable(self, target):
    ''' Create a NetCDF Variable for this variable. '''
    if not isinstance(target, nc.Dataset): raise TypeError    
    if not self.checked: # check prerequisites
      raise DerivedVariableError, "Prerequisites for variable '%s' are not satisfied."%(self.name)
    # create netcdf variable; some parameters were omitted: zlib, fillValue
    ncvar = add_var(target, name=self.name, dims=self.axes, data=None, atts=self.atts, dtype=self.dtype )
    return ncvar
    
  def computeValues(self, avgdata, const=None):
    ''' Compute values for new variable from existing stock; child classes have to overload this method. '''
    if not isinstance(avgdata,dict): raise TypeError
    if not (const is None or isinstance(const,nc.Dataset)): raise TypeError
    if not self.checked: # check prerequisites
      raise DerivedVariableError, "Prerequisites for variable '%s' are not satisfied."%(self.name)
    return NotImplemented
  
  
class Rain(DerivedVariable):
  ''' DerivedVariable child implementing computation of total precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(Rain,self).__init__(name='RAIN', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAINNC', 'RAINC'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, wrfdata, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(Rain,self).computeValues(wrfdata, const=None) # perform some type checks    
    outdata = wrfdata['RAINNC'] + wrfdata['RAINC'] # compute
    return outdata

    
class LiquidPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of liquid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(LiquidPrecip,self).__init__(name='LiquidPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SR'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) # this computation is actually linear

  def computeValues(self, wrfdata, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(LiquidPrecip,self).computeValues(wrfdata, const=None) # perform some type checks    
    outdata = wrfdata['RAIN'] * ( 1 - wrfdata['SR'] ) # compute
    return outdata


class SolidPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of solid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(SolidPrecip,self).__init__(name='SolidPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SR'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) # this computation is actually linear

  def computeValues(self, wrfdata, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(SolidPrecip,self).computeValues(wrfdata, const=None) # perform some type checks    
    outdata = wrfdata['RAIN'] * wrfdata['SR'] # compute
    return outdata


class NetPrecip_Hydro(DerivedVariable):
  ''' DerivedVariable child implementing computation of net precipitation for WRF output.
      This version can be computed in hydro files, and is more accurate. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetPrecip_Hydro,self).__init__(name='NetPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SFCEVP'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, avgdata, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(NetPrecip_Hydro,self).computeValues(avgdata, const=None) # perform some type checks    
    outdata = avgdata['RAIN'] - avgdata['SFCEVP'] # compute
    return outdata

class NetPrecip_Srfc(DerivedVariable):
  ''' DerivedVariable child implementing computation of net precipitation for WRF output. 
      This version can be computed in srfc files, but is less accurate. '''  
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetPrecip_Srfc,self).__init__(name='NetPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'QFX'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, avgdata, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(NetPrecip_Srfc,self).computeValues(avgdata, const=None) # perform some type checks    
    outdata = avgdata['RAIN'] - avgdata['QFX'] # compute
    return outdata


class NetWaterFlux(DerivedVariable):
  ''' DerivedVariable child implementing computation of net water flux at the surface for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetWaterFlux,self).__init__(name='NetWaterFlux', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['LiquidPrecip', 'SFCEVP', 'ACSNOM'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, avgdata, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(NetWaterFlux,self).computeValues(avgdata, const=None) # perform some type checks    
    outdata = avgdata['LiquidPrecip'] - avgdata['SFCEVP']  + avgdata['ACSNOM'] # compute
    return outdata


class RunOff(DerivedVariable):
  ''' DerivedVariable child implementing computation of total run off for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(RunOff,self).__init__(name='Runoff', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['SFROFF', 'UDROFF'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) 

  def computeValues(self, wrfdata, const=None):
    ''' Compute total runoff as the sum of surface and underground runoff. '''
    super(RunOff,self).computeValues(wrfdata, const=None) # perform some type checks    
    outdata = wrfdata['SFROFF'] + wrfdata['UDROFF'] # compute
    return outdata


class WaterVapor(DerivedVariable):
  ''' DerivedVariable child implementing computation of water vapor partial pressure for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterVapor,self).__init__(name='WaterVapor', # name of the variable
                              units='Pa', # not accumulated anymore! 
                              prerequisites=['Q2', 'PSFC'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False)
    self.Mratio = 28.96 / 18.02 # g/mol, Molecular mass ratio of dry air over water 

  def computeValues(self, wrfdata, const=None):
    ''' Compute total runoff as the sum of surface and underground runoff. '''
    super(WaterVapor,self).computeValues(wrfdata, const=None) # perform some type checks    
    outdata = wrfdata['Q2'] * wrfdata['PSFC'] * self.Mratio # compute
    return outdata
