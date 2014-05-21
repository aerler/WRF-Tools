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
import numpy as np
# import numpy as np
# my own netcdf stuff
from geodata.nctools import add_var

# class for errors with derived variables
class DerivedVariableError(Exception):
  ''' Exceptions related to derived variables. '''
  pass

# derived variable base class
class DerivedVariable(object):
  '''
    Instances of this class are imported by wrfout_average; it defines methods that the averaging script uses,
    to create the NetCDF variable and compute the values for a given derived variable.
    This is the base class and variable creation etc. is defined here.
    Computation of the values has to be defined in the appropriate child classes, as it depends on the variable.
  '''

  def __init__(self, name=None, units=None, prerequisites=None, constants=None, axes=None, 
               dtype=None, atts=None, linear=False, normalize=True):
    ''' Create and instance of the class, to be imported by wrfout_average. '''
    # set general attributes
    self.prerequisites = prerequisites # a list of variables that this variable depends upon 
    self.constants = constants # similar list of constant fields necessary for computation
    self.linear = linear # only linear computation are supported, i.e. they can be performed after averaging (default=False)
    self.normalize = normalize # whether or not to divide by number or records after aggregation (default=True)
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
      if var not in target.variables:
        check = False # prerequisite variable not found
# N.B.: checking dimensions is potentially too restrictive, if variables are not defined pointwise
#       if var in target.variables:
#         # check if prerequisite variable has compatible dimensions (including broadcasting) 
#         check = all([ax in self.axes for ax in target.variables[var].dimensions])
#       elif const is not None and var in const.variables:
#         check = all([ax in self.axes for ax in const.variables[var].dimensions])         
#       else: 
#         check = False # prerequisite variable not found
    # check constants, too
    if const is not None:
      for var in self.constants:
        if var not in const.variables:
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
    
  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute values for new variable from existing stock; child classes have to overload this method. '''
    # N.B.: this method i called directly for linear and through aggregateValues() for non-linear variables
    if not isinstance(indata,dict): raise TypeError
    if not isinstance(aggax,(int,np.integer)): raise TypeError # the aggregation axis (needed for extrema) 
    if not (const is None or isinstance(const,dict)): raise TypeError # dictionary of constant(s)/fields
    if not (delta is None or isinstance(delta,(float,np.inexact))): raise TypeError # output interval period 
    # N.B.: the const dictionary makes pre-loaded constant fields available for computations 
    if not self.checked: # check prerequisites
      raise DerivedVariableError, "Prerequisites for variable '%s' are not satisfied."%(self.name)
    return NotImplemented
  
  def aggregateValues(self, aggdata, comdata, aggax=0):
    ''' Compute and aggregate values for non-linear over several input periods/files. '''
    # N.B.: linear variables can go through this chain as well, if it is a pre-requisite for non-linear variable
    if not isinstance(aggdata,np.ndarray): raise TypeError # aggregate variable
    if not isinstance(comdata,np.ndarray): raise TypeError # newly computed values
    if not isinstance(aggax,(int,np.integer)): raise TypeError # the aggregation axis (needed for extrema)
    # the default implementation is just a simple sum that will be normalized to an average
    if not self.normalize: raise DerivedVariableError, 'The default aggregation requires normalization.' 
    aggdata = aggdata + np.sum(comdata, axis=aggax)
    # return aggregated value for further treatment
    return aggdata 


## regular derived variables
  
  
class Rain(DerivedVariable):
  ''' DerivedVariable child implementing computation of total precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(Rain,self).__init__(name='RAIN', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAINNC', 'RAINC'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(Rain,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks    
    outdata = indata['RAINNC'] + indata['RAINC'] # compute
    return outdata


class RainMean(DerivedVariable):
  ''' DerivedVariable child implementing computation of total daily precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(RainMean,self).__init__(name='RAINMEAN', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAINNCVMEAN', 'RAINCVMEAN'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(RainMean,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks    
    outdata = indata['RAINNCVMEAN'] + indata['RAINCVMEAN'] # compute
    return outdata

    
class LiquidPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of liquid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(LiquidPrecip,self).__init__(name='LiquidPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAINNC', 'RAINC', 'ACSNOW'], # difference...
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute liquid precipitation as the difference between total and solid precipitation. '''
    super(LiquidPrecip,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks
    outdata = indata['RAINNC'] + indata['RAINC'] - indata['ACSNOW'] # compute
    return outdata


class SolidPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of solid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(SolidPrecip,self).__init__(name='SolidPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['ACSNOW'], # it's identical to this field... 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Just copy the snow accumulation as solid precipitation. '''
    super(SolidPrecip,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks
    outdata = indata['ACSNOW'].copy() # compute
    return outdata


class LiquidPrecipSR(DerivedVariable):
  ''' DerivedVariable child implementing computation of liquid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(LiquidPrecipSR,self).__init__(name='LiquidPrecip_SR', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SR'], # 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute liquid precipitation from total precipitation and the solid fraction. '''
    super(LiquidPrecipSR,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks
    if np.max(indata['SR']) > 1:    
      outdata = indata['RAIN'] * ( 1 - indata['SR'] / 2. ) # compute
    else:
      outdata = indata['RAIN'] * ( 1 - indata['SR'] ) # compute
    return outdata


class SolidPrecipSR(DerivedVariable):
  ''' DerivedVariable child implementing computation of solid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(SolidPrecipSR,self).__init__(name='SolidPrecip_SR', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SR'], # 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute solid precipitation from total precipitation and the solid fraction. '''
    super(SolidPrecipSR,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks
    if np.max(indata['SR']) > 1:
      outdata = indata['RAIN'] * indata['SR'] / 2. # compute (SR ranges from 0 - 2)
    else:
      outdata = indata['RAIN'] * indata['SR'] # compute (SR ranges from 0 - 1)
    return outdata


class NetPrecip_Hydro(DerivedVariable):
  ''' DerivedVariable child implementing computation of net precipitation for WRF output.
      This version can be computed in hydro files, and is more accurate. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetPrecip_Hydro,self).__init__(name='NetPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SFCEVP'], # it's the difference of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute net precipitation as the difference between total precipitation and evapo-transpiration. '''
    super(NetPrecip_Hydro,self).computeValues(indata, const=None) # perform some type checks    
    outdata = indata['RAIN'] - indata['SFCEVP'] # compute
    return outdata

class NetPrecip_Srfc(DerivedVariable):
  ''' DerivedVariable child implementing computation of net precipitation for WRF output. 
      This version can be computed in srfc files, but is less accurate. '''  
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetPrecip_Srfc,self).__init__(name='NetPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'QFX'], # it's the difference of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute net precipitation as the difference between total precipitation and evapo-transpiration. '''
    super(NetPrecip_Srfc,self).computeValues(indata, const=None) # perform some type checks    
    outdata = indata['RAIN'] - indata['QFX'] # compute
    return outdata


class NetWaterFlux(DerivedVariable):
  ''' DerivedVariable child implementing computation of net water flux at the surface for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetWaterFlux,self).__init__(name='NetWaterFlux', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['LiquidPrecip', 'SFCEVP', 'ACSNOM'], #  
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute net water flux as the sum of liquid precipitation and snowmelt minus evapo-transpiration. '''
    super(NetWaterFlux,self).computeValues(indata, const=None) # perform some type checks    
    outdata = indata['LiquidPrecip'] - indata['SFCEVP']  + indata['ACSNOM'] # compute
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

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute total runoff as the sum of surface and underground runoff. '''
    super(RunOff,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks    
    outdata = indata['SFROFF'] + indata['UDROFF'] # compute
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

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute total runoff as the sum of surface and underground runoff. '''
    super(WaterVapor,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks    
    outdata = indata['Q2'] * indata['PSFC'] * self.Mratio # compute
    return outdata
  

class WetDays(DerivedVariable):
  ''' DerivedVariable child for counting the fraction of rainy days for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WetDays,self).__init__(name='WetDays', # name of the variable
                              units='', # fraction of days 
                              prerequisites=['RAINMEAN'], # above threshold 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Count the number of events above a threshold (0 for now) '''
    super(WetDays,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks    
    outdata = indata['RAINMEAN'] > 2.3e-7 # event over threshold (0.02 mm/day, according to AMS Glossary)    
    return outdata

class FrostDays(DerivedVariable):
  ''' DerivedVariable child for counting the fraction of frost days for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(FrostDays,self).__init__(name='FrostDays', # name of the variable
                              units='', # fraction of days 
                              prerequisites=['T2MIN'], # below threshold
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Count the number of events above a threshold (0 for now) '''
    super(FrostDays,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks    
    outdata = indata['T2MIN'] < 273.15 # event below threshold (0 deg. C., according to AMS Glossary)    
    return outdata


class OrographicIndex(DerivedVariable):
  ''' DerivedVariable child for computing the correlation of (surface) winds with the topographic gradient. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(OrographicIndex,self).__init__(name='OrographicIndex', # name of the variable
                              units='', # fraction of days 
                              prerequisites=['U10','V10'], # it's the sum of these two
                              constants=['HGT'], # constant topography field
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype='float', atts=None, linear=False) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Count the number of events above a threshold (0 for now) '''
    super(OrographicIndex,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks
    # compute topographic gradients and save in constants (for later use)
    if 'hgtgrd_sn' not in const:
      if 'HGT' not in const: raise ValueError
      if 'YAX' not in const: raise ValueError
      if 'DY' not in const: raise ValueError
      const['hgtgrd_sn'] = ctrDiff(const['HGT'], axis=const['YAX'], delta=const['DY'])
    if 'hgtgrd_we' not in const:
      if 'HGT' not in const: raise ValueError
      if 'XAX' not in const: raise ValueError
      if 'DX' not in const: raise ValueError
      const['hgtgrd_we'] = ctrDiff(const['HGT'], axis=const['XAX'], delta=const['DX'])
    # compute correlation (projection, scalar product, etc.)    
    outdata = indata['U10']*const['hgtgrd_we'] + indata['V10']*const['hgtgrd_sn'] 
    return outdata


## helper routine: central differences
def ctrDiff(data, axis=0, delta=1):
  if not isinstance(data,np.ndarray): raise TypeError
  if not isinstance(delta,(float,np.inexact,int,np.integer)): raise TypeError
  if not isinstance(axis,(int,np.integer)): raise TypeError
  # if axis is not 0 (innermost), roll axis until it is
  if axis != 0: data = np.rollaxis(data, axis=axis, start=0)
  # prepare calculation
  outdata = np.zeros_like(data) # allocate             
  # compute centered differences, except at the edges, where forward/backward difference are used
  outdata[1:,:] += np.diff(data, n=1, axis=0) # compute differences
  outdata[0:-1,:] += outdata[1:,:] # add differences again, but shifted 
  # N.B.: the order of these two assignments is very important: data must be added before it is modified:
  #       data[i] = data[i] + data[i+1] works; data[i+1] = data[i+1] + data[i] grows cumulatively!   
#   # simple implementation with temporary storage 
#   diff = np.diff(data, n=1, axis=0) # differences             
#   outdata[0:-1,:] += diff; outdata[1:,:] += diff # add differences 
  if delta == 1:
    outdata[1:-1,:] /= 2. # normalize, except boundaries
  else:
    outdata[1:-1,:] /= (2.*delta) # normalize (including "dx"), except boundaries
    outdata[[0,-1],:] /= delta # but aplly the denominator, "dx"
      
  # roll axis back to original position and return
  if axis != 0: outdata = np.rollaxis(outdata, axis=0, start=axis+1)
  return outdata


## extreme values

# base class for extrema
class Extrema(DerivedVariable):
  ''' DerivedVariable child implementing computation of extrema in monthly WRF output. '''
  
  def __init__(self, var, mode, name=None, dimmap=None):
    ''' Constructor; takes variable object as argument and infers meta data. '''
    # construct name with prefix 'Max'/'Min' and camel-case
    if isinstance(var, DerivedVariable):
      varname = var.name; axes = var.axes; atts = var.atts or dict()
    elif isinstance(var, nc.Variable):
      varname = var._name; axes = var.dimensions; atts = dict()
    else: raise TypeError
    # select mode
    if mode.lower() == 'max':      
      atts['Aggregation'] = 'Monthly Maximum'; prefix = 'Max'; exmode = 1
    elif mode.lower() == 'min':      
      atts['Aggregation'] = 'Monthly Minimum'; prefix = 'Min'; exmode = 0
    if isinstance(dimmap,dict): axes = [dimmap[dim] if dim in dimmap else dim for dim in axes]
    if name is None: name = '{0:s}{1:s}'.format(prefix,varname[0].upper() + varname[1:])
    # infer attributes of Maximum variable
    super(Extrema,self).__init__(name=name, units=var.units, prerequisites=[varname], axes=axes, 
                                 dtype=var.dtype, atts=atts, linear=False, normalize=False)
    self.mode = exmode

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute field of maxima '''
    super(Extrema,self).computeValues(indata, aggax=aggax, delta=delta, const=const) # perform some type checks
    # decide, what to do
    if self.mode == 1:
      outdata = np.amax(indata[self.prerequisites[0]], axis=aggax) # compute maximum
    elif self.mode == 0:
      outdata = np.amin(indata[self.prerequisites[0]], axis=aggax) # compute minimum
    # N.B.: already partially aggregating here, saves memory
    return outdata
  
  def aggregateValues(self, aggdata, comdata, aggax=0):
    ''' Compute and aggregate values for non-linear over several input periods/files. '''
    # N.B.: linear variables can go through this chain as well, if it is a pre-requisite for non-linear variable
    if not isinstance(aggdata,np.ndarray): raise TypeError # aggregate variable
    if not isinstance(comdata,np.ndarray): raise TypeError # newly computed values
    if not isinstance(aggax,(int,np.integer)): raise TypeError # the aggregation axis (needed for extrema)
    # the default implementation is just a simple sum that will be normalized to an average
    if self.normalize: raise DerivedVariableError, 'Aggregated extrema should not be normalized!'
    #print self.name, comdata.shape    
    if self.mode == 1: 
      aggdata = np.maximum(aggdata,comdata) # aggregat maxima
    elif self.mode == 0:
      aggdata = np.minimum(aggdata,comdata) # aggregat minima
    # return aggregated value for further treatment
    return aggdata 


# base class for running-mean extrema
class MeanExtrema(Extrema):
  ''' Extrema child implementing extrema of interval-averaged values in monthly WRF output. '''
  
  def __init__(self, var, mode, interval=7, name=None, dimmap=None):
    ''' Constructor; takes variable object as argument and infers meta data. '''
    # infer attributes of Maximum variable
    super(MeanExtrema,self).__init__(var, mode, name=name, dimmap=dimmap)
    self.atts['name'] = self.name = '{0:s}_{1:d}d'.format(self.name,interval)
    print self.name 
    self.atts['Aggregation'] = 'Smoothed ' + self.atts['Aggregation']
    self.atts['SmoothInterval'] = '{0:d} days'.format(interval) # interval in days
    self.interval = interval * 24*60*60 # in seconds, sicne delta will be in seconds, too    

  def computeValues(self, indata, aggax=0, delta=None, const=None):
    ''' Compute field of maxima '''
    if aggax != 0: raise NotImplementedError, 'Currently, smoothing only works on the innermost dimension.'
    if delta == 0: raise ValueError, 'No interval to average over...'
    # determine length of interval
    data = indata[self.prerequisites[0]]
    lt = data.shape[0] # available time steps
    pape = data.shape[1:] # remaining shape (must be preserved)
    ilen = np.round( self.interval / delta )
    nint = np.trunc( lt / ilen ) # number of intervals
    # truncate and reshape data
    data = data[0:ilen*nint,:]
    data = data.reshape((ilen,nint) + pape)
    print self.name, data.shape
    # average interval
    meandata = data.mean(axis=0) # average over interval dimension
    datadict = {self.prerequisites[0]:meandata} # next method expects a dictionary...
    # find extrema as before 
    outdata = super(MeanExtrema,self).computeValues(datadict, aggax=aggax, delta=delta, const=const) # perform some type checks
    # N.B.: already partially aggregating here, saves memory
    return outdata
