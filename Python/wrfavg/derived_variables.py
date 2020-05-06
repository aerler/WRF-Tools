'''
Created on 2013-10-01, revised 2014-05-20

A module defining a base class and some instances, which provide a mechanism to add derived/secondary variables
to WRF monthly means generated with the wrfout_average module.
The DerivedVariable instances are imported by wrfout_average and its methods are executed at the appropriate 
points during the averaging process.   

@author: Andre R. Erler
'''

## imports
import netCDF4 as nc
import numpy as np
from scipy.integrate import simps # Simpson rule for integration
import calendar
from datetime import datetime
from numexpr import evaluate, set_num_threads, set_vml_num_threads
# numexpr parallelisation: don't parallelize at this point!
set_num_threads(1); set_vml_num_threads(1)
# my own netcdf stuff
from utils.nctools import add_var

# days per month without leap days (duplicate from datasets.common) 
days_per_month_365 = np.array([31,28,31,30,31,30,31,31,30,31,30,31])
# N.B.: importing from datasets.common causes problems with GDAL, if it is not installed
dv_float = np.dtype('float32') # final precision used for derived floating point variables 
dtype_float = dv_float # general floating point precision used for temporary arrays
# dryday_threshold = 0.2/86400. # precip treshold for a dry day 0.2 mm/day


def getTimeStamp(dataset, idx, timestamp_var='Times'):
  ''' read a timestamp and convert to pandas-readable format '''
  # read timestamp
  timestamp = str(nc.chartostring(dataset.variables[timestamp_var][idx,:]))
  # remove underscore
  timestamp = timestamp.split('_') 
  assert len(timestamp)==2, timestamp  
  timestamp = ' '.join(timestamp)
  return timestamp

def calcTimeDelta(timestamps, year=None, month=None):
  ''' function to calculate time deltas and subtract leap-days, if necessary '''
  # check dates
  y1, m1, d1 = tuple( int(i) for i in timestamps[0][:10].split('-') )
  y2, m2, d2 = tuple( int(i) for i in timestamps[-1][:10].split('-') )
  # the first timestamp has to be of this year and month, last can be one ahead
  if year is None: year = y1 
  else: assert year == y1
  assert ( year == y2 or year+1 == y2 )
  if month is None: month = m1 
  else: assert month == m1 
  assert  ( month == m2 or np.mod(month,12)+1 == m2 )                
  # determine interval                
  dt1 = datetime.strptime(timestamps[0], '%Y-%m-%d_%H:%M:%S')
  dt2 = datetime.strptime(timestamps[-1], '%Y-%m-%d_%H:%M:%S')
  delta = float( (dt2-dt1).total_seconds() ) # the difference creates a timedelta object
  n = len(timestamps)
  # check if leap-day is present
  if month == 2 and calendar.isleap(year):
    ld = datetime(year, 2, 29) # datetime of leap day
    # whether to subtract the leap day                  
    if ( d1 == 29 or  d2 == 29 ): 
      lsubld = False  # trivial case; will be handled correctly by datetime
    elif dt1 < ld < dt2:
      # a leap day should be there; if not, then subtract it
      ild = int( ( n - 1 ) * float( ( ld - dt1 ).total_seconds() ) / delta ) # index of leap-day
      lsubld = True # subtract, unless leap day is found, sicne it should be there
      # search through timestamps for leap day
      while lsubld and ild < n:
        yy, mm, dd = tuple( int(i) for i in timestamps[ild][:10].split('-') )
        if mm == 3: break
        assert yy == year and mm == 2
        # check if a leap day is present (if, then don't subtract)
        if dd == 29: lsubld = False
        ild += 1 # increment leap day search
    else: 
      lsubld = False # no leap day in itnerval, no need to correct period 
    if lsubld: delta -= 86400. # subtract leap day from period 
  # return leap-day-checked period
  return delta
              

def ctrDiff(data, axis=0, delta=1):
  ''' helper routine to compute central differences
      N.B.: due to the roll operation, this function is not fully thread-safe '''
  if not isinstance(data,np.ndarray): raise TypeError
  if not isinstance(delta,(float,np.inexact,int,np.integer)): raise TypeError
  if not isinstance(axis,(int,np.integer)): raise TypeError
  # if axis is not 0, roll axis until it is
  # N.B.: eventhough '0' is the outermost axis, the index order does not seem to have any effect  
  if axis != 0: data = np.rollaxis(data, axis=axis, start=0) # changes original - need to undo later
  # prepare calculation
  outdata = np.zeros_like(data, dtype=dtype_float) # allocate             
  # compute centered differences, except at the edges, where forward/backward difference are used
  outdata[1:,:] = np.diff(data, n=1, axis=0) # compute differences
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
  if axis != 0: outdata = np.rollaxis(outdata, axis=0, start=axis+1) # undo roll
  return outdata


def pressureIntegral(var, T, p, RMg):
  ''' helper routine to compute mass-weighted vertical integrals 
      (currently only works on pressure levels) '''
  # allocate extended array with boundary points
  # make sure dimensions fit (pressure is the second dimension)
  assert T.ndim == 4 and p.ndim == 2 
  assert T.shape[:2] == p.shape # tuple comparison doesn't require all()
  # make temporary array (first and last plev are just zero: boundary conditions)
  tmpshape = list(T.shape)
  tmpshape[1] += 2 # add two levels (integral boundaries)
  tmpdata = np.zeros(tmpshape, dtype=dv_float)
  # make extended plev axis
  assert np.all( np.diff(p[0,:]) < 0 ), 'The pressure axis has to decrease monotonically'    
  pax = np.zeros((tmpshape[1],), dtype=dv_float)
  pax[1:-1] = p[0,:]; pax[0] = 1.e5; pax[-1] = 0. # pad with zero-boundaries
  pax = -1 * pax # invert, since we are integrating in the wrong direction
  # compute pressure/mass-weighted flux at each (non-boundary) level       
  p = p.reshape(p.shape+(1,1)) # extend singleton dimensions
  # fill missing values/NaN with zeros to allow integration
  var = np.nan_to_num(var); T = np.nan_to_num(T)
  # compute mass-weighted variable
  tmpdata[:,1:-1,:] = evaluate('RMg * var * T / p') # first and last are zero
  # integrate using Simpson rule
  outdata = simps(tmpdata, pax, axis=1, even='first') # even intervals anyway...
  # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
  return outdata


# class for errors with derived variables
class DerivedVariableError(Exception):
  ''' Exceptions related to derived variables. '''
  pass


# N.B.: this could have been implemented much more efficiently, without the need for separate classes,
#       using a numexpr string and the variable dicts to define the computation 

# derived variable base class
class DerivedVariable(object):
  '''
    Instances of this class are imported by wrfout_average; it defines methods that the averaging script uses,
    to create the NetCDF variable and compute the values for a given derived variable.
    This is the base class and variable creation etc. is defined here.
    Computation of the values has to be defined in the appropriate child classes, as it depends on the variable.
  '''

  def __init__(self, name=None, units=None, prerequisites=None, constants=None, axes=None, 
               dtype=None, atts=None, linear=False, ignoreNaN=False, normalize=True):
    ''' Create and instance of the class, to be imported by wrfout_average. '''
    # set general attributes
    self.prerequisites = prerequisites # a list of variables that this variable depends upon 
    self.constants = constants # similar list of constant fields necessary for computation
    self.linear = linear # only linear computation are supported, i.e. they can be performed after averaging (default=False)
    self.normalize = normalize # whether or not to divide by number or records after aggregation (default=True)
    self.ignoreNaN = ignoreNaN # use NaN-safe aggregation or not (i.e. ignore NaN's in sums etc.)
    self.checked = False # indicates whether prerequisites were checked
    self.tmpdata = None # handle for temporary storage
    self.carryover = False # carry over temporary storage to next month
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
    
  def checkPrerequisites(self, target, const=None, varmap=None):
    ''' Check if all required variables are in the source NetCDF dataset. '''
    if not isinstance(target, nc.Dataset): raise TypeError
    if not (const is None or isinstance(const, nc.Dataset)): raise TypeError
    if not (varmap is None or isinstance(varmap, dict)): raise TypeError
    check = True # any mismatch will set this to False
    # check all prerequisites
    for var in self.prerequisites:
      if varmap: var = varmap.get(var,var)
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
      raise DerivedVariableError("Prerequisites for variable '%s' are not satisfied."%(self.name))
    # create netcdf variable; some parameters were omitted: zlib, fillValue
    ncvar = add_var(target, name=self.name, dims=self.axes, data=None, atts=self.atts, dtype=self.dtype )
    return ncvar
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Compute values for new variable from existing stock; child classes have to overload this method. '''
    # N.B.: this method is called directly for linear and through aggregateValues() for non-linear variables
    if not isinstance(indata,dict): raise TypeError
    if not isinstance(aggax,(int,np.integer)): raise TypeError # the aggregation axis (needed for extrema) 
    if not (const is None or isinstance(const,dict)): raise TypeError # dictionary of constant(s)/fields
    if not (delta is None or isinstance(delta,(float,np.inexact))): raise TypeError # output interval period 
    # N.B.: the const dictionary makes pre-loaded constant fields available for computations 
    if not self.checked: # check prerequisites
      raise DerivedVariableError("Prerequisites for variable '%s' are not satisfied."%(self.name))
    # if this variable requires constants, check that
    if self.constants is not None and len(self.constants) > 0: 
      if const is None or len(const) == 0: 
        raise ValueError('The variable \'{:s}\' requires a constants dictionary!'.format(self.name))
    return NotImplemented
  
  def aggregateValues(self, comdata, aggdata=None, aggax=0):
    ''' Compute and aggregate values for non-linear over several input periods/files. '''
    # N.B.: linear variables can go through this chain as well, if it is a pre-requisite for non-linear variable
    if not isinstance(comdata,np.ndarray): raise TypeError # newly computed values
    if not isinstance(aggax,(int,np.integer)): raise TypeError # the aggregation axis (needed for extrema)
    # the default implementation is just a simple sum that will be normalized to an average
    if comdata is not None and comdata.size > 0:
      if aggdata is None: 
        if self.normalize: raise DerivedVariableError('The one-pass aggregation automatically normalizes.')
        if self.ignoreNaN: aggdata = np.nanmean(comdata, axis=aggax) # ignore NaN's
        else: aggdata = np.mean(comdata, axis=aggax) # don't use in-place addition, because it destroys masks
      else:
        if not self.normalize: raise DerivedVariableError('The default aggregation requires normalization.')
        if not isinstance(aggdata,np.ndarray): raise TypeError # aggregate variable
        if self.ignoreNaN: aggdata = aggdata + np.nansum(comdata, axis=aggax) # ignore NaN's
        else: aggdata = aggdata + np.sum(comdata, axis=aggax) # don't use in-place addition, because it destroys masks
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
                              dtype=dv_float, atts=None, linear=True) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(Rain,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    if delta == 0: raise ValueError('RAIN depends on accumulated variables; differences can not be computed from single time steps. (delta=0)')    
    outdata = evaluate('RAINNC + RAINC', local_dict=indata) # compute
    return outdata


# N.B.: some other DerivedVariable's depend on RAINMEAN, so we are keepign it for now
class RainMean(DerivedVariable):
  ''' DerivedVariable child implementing computation of total daily precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(RainMean,self).__init__(name='RAINMEAN', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAINNCVMEAN', 'RAINCVMEAN'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) 
    # N.B.: this computation is actually linear, but some non-linear computations depend on it

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(RainMean,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks    
    outdata = indata['RAINNCVMEAN'] + indata['RAINCVMEAN'] # compute
    return outdata


class TimeOfConvection(DerivedVariable):
  ''' DerivedVariable child implementing computation of total daily precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(TimeOfConvection,self).__init__(name='TimeOfConvection', # name of the variable
                              units='s', # units in wrfout are actually minutes
                              prerequisites=['TRAINCVMAX', 'Times'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              constants=['XLONG'], # local longitudes
                              dtype=dv_float, atts=None, linear=False, ignoreNaN=True) 
    self.time_offset = 0 # shift clock 6 hours back, to avoid errors from averaging over midnight
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute total precipitation as the sum of convective  and non-convective precipitation. '''
    super(TimeOfConvection,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks    
    times = indata['Times']; tcv = indata['TRAINCVMAX']
    assert len(times) == tcv.shape[0]
    # longitude, to transform to local solar time
    if 'XLONG_360' not in const:
      xlon = const['XLONG']
      # avoid discontinuity at dateline (too close to domain)
      xlon = np.where(xlon < 0, 360.-xlon, xlon)
      const['XLONG_360'] = xlon
    else: xlon = const['XLONG_360']
    # save time of simulation start
    if 'TimeOfSimulationStart' not in const: 
      # this is the first time step
      toss = datetime.strptime(times[0], '%Y-%m-%d_%H:%M:%S')
      # 0-UTC correction, if ToSS is not 0 UTC 
      if times[0][10:] !='_00:00:00':
        dtoss = int( (toss - datetime.strptime(times[0][:10], '%Y-%m-%d')).total_seconds() //60 ) # in minutes
        #raise NotImplementedError, "Simulation has to start at 0 UTC."
      else: dtoss = 0
      # apply time offset
      dtoss += self.time_offset
      # save values for later use
      const['TimeOfSimulationStart'] = toss
      const['DeltaToSS'] = dtoss # ToSS correction for not starting at 0 UTC
      # also correct XLONG
    else: 
      toss = const['TimeOfSimulationStart']
      dtoss = const['DeltaToSS']
    # compute time delta to ToSS
    deltas = np.asarray([(datetime.strptime(time, '%Y-%m-%d_%H:%M:%S') - toss).total_seconds()//60 for time in times], dtype='int')
    deltas = deltas.reshape((len(deltas),1,1)) # add singleton spatial dimensions for broadcasting
    if not np.all( np.diff(deltas) == 1440 ):
      raise NotImplementedError('TimeOfConvection only works with daily output intervals!')
    deltas -= 1440 # go back one day (convection happened during the previous day)
    # isolate time of day and remove days that didn't rain
    tod = tcv - deltas
    tod = np.where(tod <= 0, np.NaN, tod) # NaN if no convection occurred
    # convert to local solar time
    tod += 4*xlon # xlon already has a (singleton) time dimension
    if dtoss > 0: tod += dtoss # apply correction for not starting at 0 UTC & time offset to avoid averaging errors
    tod %= 1440 # correct "overflows"; also necessary, because of time offset 
    # return
    tod *= 60 # convert to seconds
    outdata = np.asarray(tod, dtype=dv_float) 
    return outdata

    
class LiquidPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of liquid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(LiquidPrecip,self).__init__(name='LiquidPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAINNC', 'RAINC', 'ACSNOW'], # difference...
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute liquid precipitation as the difference between total and solid precipitation. '''
    super(LiquidPrecip,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    RAINNC = indata['RAINNC']; RAINC = indata['RAINC']; ACSNOW = indata['ACSNOW']; # for use in expressions
    outdata = evaluate('RAINNC + RAINC - ACSNOW') # compute
    return outdata


class SolidPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of solid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(SolidPrecip,self).__init__(name='SolidPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['ACSNOW'], # it's identical to this field... 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Just copy the snow accumulation as solid precipitation. '''
    super(SolidPrecip,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
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
                              dtype=dv_float, atts=None, linear=False) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute liquid precipitation from total precipitation and the solid fraction. '''
    super(LiquidPrecipSR,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # optimize using expressions
    RAIN = indata['RAIN']; SR = indata['SR'] # for use in expressions
    if np.max(indata['SR']) > 1: outdata = evaluate('RAIN * ( 1 - SR / 2. )') # compute
    else: outdata = evaluate('RAIN * ( 1 - SR )') # compute
    return outdata


class SolidPrecipSR(DerivedVariable):
  ''' DerivedVariable child implementing computation of solid precipitation for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(SolidPrecipSR,self).__init__(name='SolidPrecip_SR', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', 'SR'], # 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute solid precipitation from total precipitation and the solid fraction. '''
    super(SolidPrecipSR,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute
    outdata = indata['RAIN'] * indata['SR'] # compute (SR ranges from 0 - 1)
    if np.max(indata['SR']) > 1: outdata /= 2. # if SR ranges from 0 - 2
    return outdata


class NetPrecip(DerivedVariable):
  ''' DerivedVariable child implementing computation of net precipitation for WRF output. '''  
  
  def __init__(self, sfcevp='SFCEVP'): # 'SFCEVP' for hydro, 'QFC' for srfc files
    ''' Initialize with fixed values and name of surface evaporation variable as argument. '''
    super(NetPrecip,self).__init__(name='NetPrecip', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['RAIN', sfcevp], # it's the difference of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) # this computation is actually linear
    self.sfcevp = sfcevp

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute net precipitation as the difference between total precipitation and evapo-transpiration. '''
    super(NetPrecip,self).computeValues(indata, const=None) # perform some type checks    
    outdata = indata['RAIN'] - indata[self.sfcevp] # compute
    return outdata


class NetWaterFlux(DerivedVariable):
  ''' DerivedVariable child implementing computation of net water flux at the surface for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(NetWaterFlux,self).__init__(name='NetWaterFlux', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['LiquidPrecip', 'SFCEVP', 'ACSNOM'], #  
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute net water flux as the sum of liquid precipitation and snowmelt minus evapo-transpiration. '''
    super(NetWaterFlux,self).computeValues(indata, const=None) # perform some type checks
    outdata = evaluate('LiquidPrecip - SFCEVP + ACSNOM', local_dict=indata)  # compute
    return outdata


class WaterForcing(DerivedVariable):
  ''' DerivedVariable child implementing computation of water flux/forcing at the surface for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterForcing,self).__init__(name='WaterForcing', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['LiquidPrecip', 'ACSNOM'], #  
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) # this computation is actually linear

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute net water flux as the sum of liquid precipitation and snowmelt minus evapo-transpiration. '''
    super(WaterForcing,self).computeValues(indata, const=None) # perform some type checks
    outdata = evaluate('LiquidPrecip + ACSNOM', local_dict=indata)  # compute
    return outdata


class RunOff(DerivedVariable):
  ''' DerivedVariable child implementing computation of total run off for WRF output. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(RunOff,self).__init__(name='Runoff', # name of the variable
                              units='kg/m^2/s', # not accumulated anymore! 
                              prerequisites=['SFROFF', 'UDROFF'], # it's the sum of these two 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=True) 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute total runoff as the sum of surface and underground runoff. '''
    super(RunOff,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks    
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
                              dtype=dv_float, atts=None, linear=False)
    self.Mratio = 28.96 / 18.02 # g/mol, Molecular mass ratio of dry air over water 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute total runoff as the sum of surface and underground runoff. '''
    super(WaterVapor,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    Mratio = self.Mratio; Q2 = indata['Q2']; PSFC = indata['PSFC'] # for use in expression    
    outdata =  evaluate('Mratio * Q2 * PSFC') # compute
    return outdata
  

class WetDays(DerivedVariable):
  ''' DerivedVariable child for counting the fraction of rainy days for WRF output. '''
  
  def __init__(self, threshold=1., rain='RAIN', ignoreNaN=False):
    ''' Initialize with fixed values and selected dry-day threshold (defined by argument in mm/day). '''
    name = 'WetDays_{:03d}'.format(int(10*threshold))
    threshold /= 86400. # convert to SI units (argument assumed mm/day)
    atts = dict(threshold=threshold) # save threshold value in SI/Variable units
    super(WetDays,self).__init__(name=name, # name of the variable
                              units='', # fraction of days 
                              prerequisites=[rain], # above threshold 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=atts, linear=False, ignoreNaN=ignoreNaN)
    self.threshold = threshold # store for computation
    self.rain = rain # name of the rain variable
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Count the number of events above a threshold. '''
    super(WetDays,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # check that delta does not change!
    if tmp is not None:
      if 'WETDAYS_DELTA' in tmp: 
        if delta != tmp['WETDAYS_DELTA']: 
          raise NotImplementedError('Output interval is assumed to be constant for conversion to days. (delta={:f})'.format(delta))
      else: tmp['WETDAYS_DELTA'] = delta # save and check next time
    # sampling does not have to be daily
    if self.ignoreNaN:
      outdata = np.where(indata[self.rain] > self.threshold, 1,0) # comparisons with NaN always yield False
      outdata = np.where(np.isnan(indata[self.rain]), np.NaN,outdata)     
    else:
      outdata = indata[self.rain] > self.threshold # definition according to AMS Glossary: precip > 0.02 mm/day
    # N.B.: this is actually the fraction of wet days in a month (i.e. not really days)      
    return outdata


class WetDayRain(DerivedVariable):
  ''' DerivedVariable child for precipitation amounts exceeding the rainy day threshold. '''
    
  def __init__(self, threshold=1., rain='RAIN', ignoreNaN=False):
    ''' Initialize with fixed values and selected dry-day threshold (defined by argument in mm/day). '''
    name = 'WetDayRain_{:03d}'.format(int(10*threshold))
    wetdays = 'WetDays_{:03d}'.format(int(10*threshold))
    threshold /= 86400. # convert to SI units (argument assumed mm/day)
    atts = dict(threshold=threshold) # save threshold value in SI/Variable units
    super(WetDayRain,self).__init__(name=name, # name of the variable
                              units='kg/m^2/s', # fraction of days 
                              prerequisites=[rain,wetdays], # above threshold 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=atts, linear=False, ignoreNaN=ignoreNaN)
    self.rain = rain # name of the rain variable
    self.wetdays = wetdays 
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Count the number of events above a threshold. '''
    super(WetDayRain,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # just set precip to zero if it is below a threshold 
    outdata = np.where(indata[self.wetdays] == 0, 0., indata[self.rain])
    # N.B.: WetDays is actually the fraction of wet days in a month (i.e. not really days)      
    return outdata


class WetDayPrecip(DerivedVariable):
  ''' DerivedVariable child for precipitation amounts on rainy days for WRF output. '''
  
  def __init__(self, threshold=1., rain='RAIN', ignoreNaN=False):
    ''' Initialize with fixed values and selected dry-day threshold (defined by argument in mm/day). '''
    name = 'WetDayPrecip_{:03d}'.format(int(10*threshold))
    wetdays = 'WetDays_{:03d}'.format(int(10*threshold))
    wetdayrain = 'WetDayRain_{:03d}'.format(int(10*threshold))
    threshold /= 86400. # convert to SI units (argument assumed mm/day)
    atts = dict(threshold=threshold) # save threshold value in SI/Variable units
    super(WetDayPrecip,self).__init__(name=name, # name of the variable
                              units='kg/m^2/s', # fraction of days 
                              prerequisites=[wetdayrain,wetdays], # above threshold 
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=atts, linear=True, ignoreNaN=ignoreNaN)
    self.wetdays = wetdays
    self.wetdayrain = wetdayrain 
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Count the number of events above a threshold. '''
    super(WetDayPrecip,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute monthly wet-day-precip as a quasi-linear operation at the end of each month 
    outdata = np.where(indata[self.wetdays] == 0, 0., indata[self.wetdayrain] / indata[self.wetdays])
    # N.B.: WetDays is actually the fraction of wet days in a month (i.e. not really days)      
    return outdata


class FrostDays(DerivedVariable):
  ''' DerivedVariable child for counting the fraction of frost days for WRF output. '''
  
  def __init__(self, threshold=0., temp='T2MIN', ignoreNaN=False):
    ''' Initialize with fixed values and selected frost-day threshold (defined by argument in Celsius). '''
    name = 'FrostDays_{:+02d}'.format(int(threshold))
    threshold += 273.15 # convert to SI units (argument assumed Celsius)
    atts = dict(threshold=threshold) # save threshold value in SI/Variable units
    super(FrostDays,self).__init__(name=name, # name of the variable
                              units='', # fraction of days 
                              prerequisites=[temp], # below threshold
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=atts, linear=False, ignoreNaN=ignoreNaN)
    self.threshold = threshold 
    self.temp = temp
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Count the number of events below a threshold (0 Celsius) '''
    super(FrostDays,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks    
    if delta != 86400. and self.temp != 'T2': 
      raise ValueError('WRF extreme values are suppposed to be daily; encountered delta={:f}'.format(delta))
    if self.ignoreNaN:
      outdata = np.where(indata[self.temp] < self.threshold, 1,0) # comparisons with NaN always yield False
      outdata = np.where(np.isnan(indata[self.temp]), np.NaN,outdata)     
    else:
      outdata = indata[self.temp] < self.threshold # event below threshold (default 0 deg. Celsius)    
    return outdata


class SummerDays(DerivedVariable):
  ''' DerivedVariable child for counting the fraction of summer days for WRF output. '''
  
  def __init__(self, threshold=25., temp='T2MAX', ignoreNaN=False):
    ''' Initialize with fixed values and selected frost-day threshold (defined by argument in Celsius). '''
    name = 'SummerDays_{:+02d}'.format(int(threshold))
    threshold += 273.15 # convert to SI units (argument assumed Celsius)
    atts = dict(threshold=threshold) # save threshold value in SI/Variable units
    super(SummerDays,self).__init__(name=name, # name of the variable
                              units='', # fraction of days 
                              prerequisites=[temp], # below threshold
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=atts, linear=False, ignoreNaN=ignoreNaN)
    self.threshold = threshold 
    self.temp = temp

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Count the number of events above a threshold (25 Celsius) '''
    super(SummerDays,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks    
    if delta != 86400. and self.temp != 'T2': 
      raise ValueError('WRF extreme values are suppposed to be daily; encountered delta={:f}'.format(delta))
    if self.ignoreNaN:
      outdata = np.where(indata[self.temp] > self.threshold, 1,0) # comparisons with NaN always yield False
      outdata = np.where(np.isnan(indata[self.temp]), np.NaN,outdata)     
    else:
      outdata = indata[self.temp] > self.threshold # event below threshold (default 0 deg. Celsius)    
    return outdata


class OrographicIndex(DerivedVariable):
  ''' DerivedVariable child for computing the correlation of (surface) winds with the topographic gradient. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(OrographicIndex,self).__init__(name='OrographicIndex', # name of the variable
                              units='', # fraction of days 
                              prerequisites=['U10','V10'], # it's the sum of these two
                              constants=['HGT','DY','DX'], # constant topography field
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Project surface winds onto topographic gradient. '''
    super(OrographicIndex,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute topographic gradients and save in constants (for later use)
    if 'hgtgrd_sn' not in const:
      if 'HGT' not in const: raise ValueError
      if 'DY' not in const: raise ValueError
      hgtgrd_sn = ctrDiff(const['HGT'], axis=1, delta=const['DY'])
      const['hgtgrd_sn'] = hgtgrd_sn
    else: hgtgrd_sn = const['hgtgrd_sn']  
    if 'hgtgrd_we' not in const:
      if 'HGT' not in const: raise ValueError
      if 'DX' not in const: raise ValueError
      hgtgrd_we = ctrDiff(const['HGT'], axis=2, delta=const['DX'])
      const['hgtgrd_we'] = hgtgrd_we
    else: hgtgrd_we = const['hgtgrd_we']
    U = indata['U10']; V = indata['V10']
    # compute covariance (projection, scalar product, etc.)    
    outdata = evaluate('U * hgtgrd_we + V * hgtgrd_sn')
    # N.B.: outer dimensions (i.e. the first) are broadcast automatically, which is what we want here 
    return outdata


class CovOIP(DerivedVariable):
  ''' DerivedVariable child for computing the correlation of the orographic index with precipitation. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(CovOIP,self).__init__(name='OIPX', # name of the variable
                              units='', # fraction of days 
                              prerequisites=['OrographicIndex', 'RAIN'], # it's the sum of these two
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Covariance of Origraphic Index and Precipitation (needed to calculate correlation coefficient). '''
    super(CovOIP,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute covariance
    outdata = evaluate('OrographicIndex * RAIN', local_dict=indata) 
    return outdata


class OrographicIndexPlev(DerivedVariable):
  ''' DerivedVariable child for computing the correlation of (surface) winds with the topographic gradient. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(OrographicIndexPlev,self).__init__(name='OrographicIndex', # name of the variable
                              units='', # fraction of days 
                              prerequisites=['U_PL','V_PL'], # it's the sum of these two
                              constants=['HGT','DY','DX'], # constant topography field
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Project atmospheric winds onto underlying topographic gradient. '''
    super(OrographicIndexPlev,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute topographic gradients and save in constants (for later use)
    if 'hgtgrd_sn' not in const:
      if 'HGT' not in const: raise ValueError
      if 'DY' not in const: raise ValueError
      hgtgrd_sn = ctrDiff(const['HGT'], axis=1, delta=const['DY'])
      const['hgtgrd_sn'] = hgtgrd_sn
    else: hgtgrd_sn = const['hgtgrd_sn']  
    if 'hgtgrd_we' not in const:
      if 'HGT' not in const: raise ValueError
      if 'DX' not in const: raise ValueError
      hgtgrd_we = ctrDiff(const['HGT'], axis=2, delta=const['DX'])
      const['hgtgrd_we'] = hgtgrd_we
    else: hgtgrd_we = const['hgtgrd_we']
    U = indata['U_PL']; V = indata['V_PL']
    # compute covariance (projection, scalar product, etc.)    
    outdata = evaluate('U * hgtgrd_we + V * hgtgrd_sn')
    # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
    return outdata


class WaterDensity(DerivedVariable):
  ''' DerivedVariable child for computing water vapor density at a pressure level. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterDensity,self).__init__(name='WaterDensity', # name of the variable
                              units='kg/m^3', # "density" 
                              prerequisites=['TD_PL','T_PL'], # it's the sum of these two
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False)
    self.MR = np.asarray( 0.01802 / 8.3144621, dtype=dv_float) # Mh2o / R; from AMS Glossary
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute mass denisty of water vapor using the Magnus formula. '''
    super(WaterDensity,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute water vapor content from dew point (using magnus formula)
    MR = self.MR; Td = indata['TD_PL']; T = indata['T_PL'] # for use in expression
    # compute partial pressure using Magnus formula (Wikipedia) and mass per volume "density"
    # based on: pV = m T (R/M) -> m/V = M/R * p/T
    outdata = evaluate('MR * 100. * 6.1094 * exp( 17.625 * (Td - 273.15) / (Td - 273.15 + 243.04) ) / T')
    # N.B.: the Magnus formula uses Celsius and returns hecto-Pascale: need to convert to/from SI
    # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
    return outdata


class ColumnWater(DerivedVariable):
  ''' DerivedVariable child for computing the column-integrated atmospheric water vapor content. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(ColumnWater,self).__init__(name='ColumnWater', # name of the variable
                              units='kg/m^2', # flux 
                              prerequisites=['T_PL','P_PL','WaterDensity'], # west-east direction: U
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.RMg = np.asarray( 8.3144621 / ( 0.01802 *  9.80616 ), dtype=dv_float) # R / (Mh2o g); from AMS Glossary (g at 45 lat)
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(ColumnWater,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    outdata = pressureIntegral(var=indata['WaterDensity'], T=indata['T_PL'], 
                               p=indata['P_PL'], RMg=self.RMg)
    return outdata


class WaterFlux_U(DerivedVariable):
  ''' DerivedVariable child for computing the atmospheric transport of water vapor (West-East). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterFlux_U,self).__init__(name='WaterFlux_U', # name of the variable
                              units='kg/m^2/s', # flux 
                              prerequisites=['U_PL','WaterDensity'], # west-east direction: U
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(WaterFlux_U,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute covariance (projection, scalar product, etc.)    
    outdata = indata['U_PL']*indata['WaterDensity']
    # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
    return outdata


class WaterFlux_V(DerivedVariable):
  ''' DerivedVariable child for computing the atmospheric transport of water vapor (South-North). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterFlux_V,self).__init__(name='WaterFlux_V', # name of the variable
                              units='kg/m^2/s', # flux 
                              prerequisites=['V_PL','WaterDensity'], # south-north direction: V
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute South-North atmospheric water vapor transport. '''
    super(WaterFlux_V,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute covariance (projection, scalar product, etc.)    
    outdata = indata['V_PL']*indata['WaterDensity']
    # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
    return outdata


class WaterTransport_U(DerivedVariable):
  ''' DerivedVariable child for computing the column-integrated atmospheric transport of water vapor (West-East). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterTransport_U,self).__init__(name='WaterTransport_U', # name of the variable
                              units='kg/m/s', # flux 
                              prerequisites=['T_PL','P_PL','WaterFlux_U'], # west-east direction: U
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.RMg = np.asarray( 8.3144621 / ( 0.01802 *  9.80616 ), dtype=dv_float) # R / (M g); from AMS Glossary (g at 45 lat)
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(WaterTransport_U,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    outdata = pressureIntegral(var=indata['WaterFlux_U'], T=indata['T_PL'], 
                               p=indata['P_PL'], RMg=self.RMg)
    return outdata


class WaterTransport_V(DerivedVariable):
  ''' DerivedVariable child for computing the column-integrated atmospheric transport of water vapor (West-East). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(WaterTransport_V,self).__init__(name='WaterTransport_V', # name of the variable
                              units='kg/m/s', # flux 
                              prerequisites=['T_PL','P_PL','WaterFlux_V'], # west-east direction: U
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.RMg = np.asarray( 8.3144621 / ( 0.01802 *  9.80616 ), dtype=dv_float)  # R / (M g); from AMS Glossary (g at 45 lat)
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute South-North atmospheric water vapor transport. '''
    super(WaterTransport_V,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    outdata = pressureIntegral(var=indata['WaterFlux_V'], T=indata['T_PL'], 
                               p=indata['P_PL'], RMg=self.RMg)
    return outdata


class ColumnHeat(DerivedVariable):
  ''' DerivedVariable child for computing the column-integrated atmospheric water vapor content. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(ColumnHeat,self).__init__(name='ColumnHeat', # name of the variable
                              units='J/m', # flux 
                              prerequisites=['T_PL','P_PL'], # west-east direction: U
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.RMg = np.asarray( 8.3144621 / ( 0.01802 *  9.80616 ), dtype=dv_float) # R / (M g); from AMS Glossary (g at 45 lat)
    self.cp = np.asarray( 1005.7, dtype=dv_float) # J/(kg K), specific heat of dry air per mass (AMS Glossary)
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(ColumnHeat,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    outdata = pressureIntegral(var=indata['T_PL'], T=indata['T_PL'], 
                               p=indata['P_PL'], RMg=self.RMg)
    outdata *= self.cp # since integration is linear
    return outdata


class HeatFlux_U(DerivedVariable):
  ''' DerivedVariable child for computing the atmospheric (sensible) heat transport (West-East). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(HeatFlux_U,self).__init__(name='HeatFlux_U', # name of the variable
                              units='J/m^2/s', # flux 
                              prerequisites=['U_PL','P_PL'], # west-east direction: U
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.cpMR = np.asarray( 1005.7 * 0.0289644 / 8.3144621, dtype=dv_float) # cp * Mair / R (AMS Glossary)
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(HeatFlux_U,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute covariance (projection, scalar product, etc.)    
    # N.B.: u * T*cp * rho; rho = p / (R/M * T) => u * p * (cp * M / R)
    p=indata['P_PL']; u = indata['U_PL']; cpMR = self.cpMR
    p = p.reshape(p.shape+(1,1)) # extend singleton dimensions
    outdata = evaluate('u * p * cpMR')
    # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
    return outdata

class HeatFlux_V(DerivedVariable):
  ''' DerivedVariable child for computing the atmospheric (sensible) heat transport (South-North). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(HeatFlux_V,self).__init__(name='HeatFlux_V', # name of the variable
                              units='J/m^2/s', # flux 
                              prerequisites=['V_PL','P_PL'], # west-east direction: U
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.cpMR = np.asarray( 1005.7 * 0.0289644 / 8.3144621, dtype=dv_float) # cp * Mair / R (AMS Glossary)
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(HeatFlux_V,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute covariance (projection, scalar product, etc.)    
    # N.B.: u * T*cp * rho; rho = p / (R/M * T) => u * p * (cp * M / R)
    p=indata['P_PL']; v = indata['V_PL']; cpMR = self.cpMR
    p = p.reshape(p.shape+(1,1)) # extend singleton dimensions
    outdata = evaluate('v * p * cpMR')
    # N.B.: outer dimensions (i.e. the first and second) are broadcast automatically, which is what we want here 
    return outdata


class HeatTransport_U(DerivedVariable):
  ''' DerivedVariable child for computing the column-integrated atmospheric heat transport (West-East). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(HeatTransport_U,self).__init__(name='HeatTransport_U', # name of the variable
                              units='J/m/s', # flux 
                              prerequisites=['T_PL','P_PL','HeatFlux_U'], # west-east direction: U
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.RMg = np.asarray( 8.3144621 / ( 0.01802 *  9.80616 ), dtype=dv_float) # R / (M g); from AMS Glossary (g at 45 lat)
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(HeatTransport_U,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    outdata = pressureIntegral(var=indata['HeatFlux_U'], T=indata['T_PL'], 
                               p=indata['P_PL'], RMg=self.RMg)
    return outdata


class HeatTransport_V(DerivedVariable):
  ''' DerivedVariable child for computing the column-integrated atmospheric heat transport (South-North). '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(HeatTransport_V,self).__init__(name='HeatTransport_V', # name of the variable
                              units='J/m/s', # flux 
                              prerequisites=['T_PL','P_PL','HeatFlux_V'], # west-east direction: U
                              axes=('time','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 
    self.RMg = np.asarray( 8.3144621 / ( 0.01802 *  9.80616 ), dtype=dv_float) # R / (M g); from AMS Glossary (g at 45 lat)
    # N.B.: it is necessary to enforce the type of scalars, otherwise numexpr casts everything as doubles
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Compute West-East atmospheric water vapor transport. '''
    super(HeatTransport_V,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    outdata = pressureIntegral(var=indata['HeatFlux_V'], T=indata['T_PL'], 
                               p=indata['P_PL'], RMg=self.RMg)
    return outdata


class Vorticity(DerivedVariable):
  ''' DerivedVariable child for computing relative vorticity. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(Vorticity,self).__init__(name='Vorticity', # name of the variable
                              units='1/s', 
                              prerequisites=['U_PL','V_PL'],
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Project surface winds onto topographic gradient. '''
    super(Vorticity,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute relative vorticity on pressure levels
    # zeta = dv/dx - du/dy
    outdata = ( ctrDiff(indata['V_PL'], axis=3, delta=const['DX']) # order of dimensions: t,p,y,x
                -  ctrDiff(indata['U_PL'], axis=2, delta=const['DY']) )
    # N.B.: metric factors are not computed
    return outdata


class Vorticity_Var(DerivedVariable):
  ''' DerivedVariable child for computing the variance of relative vorticity. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(Vorticity_Var,self).__init__(name='Vorticity_Var', # name of the variable
                              units='1/s^2', 
                              prerequisites=['Vorticity'],
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Project surface winds onto topographic gradient. '''
    super(Vorticity_Var,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute variance without subtracting the mean
    outdata = indata['Vorticity']**2
    # N.B.: to get actual variance, the square of the mean has to be subtracted after the final stage of aggregation
    return outdata


class GHT_Var(DerivedVariable):
  ''' DerivedVariable child for computing the variance of geopotential height on pressure levels. '''
  
  def __init__(self):
    ''' Initialize with fixed values; constructor takes no arguments. '''
    super(GHT_Var,self).__init__(name='GHT_Var', # name of the variable
                              units='m^2', 
                              prerequisites=['GHT_PL'],
                              axes=('time','num_press_levels_stag','south_north','west_east'), # dimensions of NetCDF variable 
                              dtype=dv_float, atts=None, linear=False) 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None, ignoreNaN=False):
    ''' Project surface winds onto topographic gradient. '''
    super(GHT_Var,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # compute variance without subtracting the mean
    outdata = indata['GHT_PL']**2
    # N.B.: to get actual variance, the square of the mean has to be subtracted after the final stage of aggregation
    return outdata



## extreme values

# base class for extrema
class Extrema(DerivedVariable):
  ''' DerivedVariable child implementing computation of extrema in monthly WRF output. '''
  
  def __init__(self, var, mode, name=None, long_name=None, dimmap=None, ignoreNaN=False):
    ''' Constructor; takes variable object as argument and infers meta data. '''
    # construct name with prefix 'Max'/'Min' and camel-case
    if isinstance(var, DerivedVariable):
      varname = var.name; axes = var.axes; atts = var.atts.copy() or dict()
    elif isinstance(var, nc.Variable):
      varname = var._name; axes = var.dimensions; atts = dict()
    else: raise TypeError
    # select mode
    if mode.lower() == 'max':      
      atts['Aggregation'] = 'Monthly Maximum'; prefix = 'Max'; exmode = 1
    elif mode.lower() == 'min':      
      atts['Aggregation'] = 'Monthly Minimum'; prefix = 'Min'; exmode = 0
    if long_name is not None: atts['long_name'] = long_name
    if isinstance(dimmap,dict): axes = [dimmap[dim] if dim in dimmap else dim for dim in axes]
    if name is None: name = '{0:s}{1:s}'.format(prefix,varname[0].upper() + varname[1:])
    # infer attributes of extreme variable
    super(Extrema,self).__init__(name=name, units=var.units, prerequisites=[varname], axes=axes, 
                                 dtype=var.dtype, atts=atts, linear=False, normalize=False, ignoreNaN=ignoreNaN)
    self.mode = exmode
    self.tmpdata = None # don't need temporary storage 

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Compute field of maxima '''
    super(Extrema,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # decide, what to do
    if self.mode == 1:
      if self.ignoreNaN: outdata = np.nanmax(indata[self.prerequisites[0]], axis=aggax) # ignore NaNs
      else: outdata = np.max(indata[self.prerequisites[0]], axis=aggax) # compute maximum
    elif self.mode == 0:
      if self.ignoreNaN: outdata = np.nanmin(indata[self.prerequisites[0]], axis=aggax) # ignore NaNs
      else: outdata = np.min(indata[self.prerequisites[0]], axis=aggax) # compute minimum
    # N.B.: already partially aggregating here, saves memory
    return outdata
  
  def aggregateValues(self, comdata, aggdata=None, aggax=0):
    ''' Compute and aggregate values for non-linear over several input periods/files. '''
    # N.B.: linear variables can go through this chain as well, if it is a pre-requisite for non-linear variable
    if not isinstance(aggdata,np.ndarray) and aggdata is not None: raise TypeError # aggregate variable
    if not isinstance(comdata,np.ndarray) and comdata is not None: raise TypeError # newly computed values
    if not isinstance(aggax,(int,np.integer)): raise TypeError # the aggregation axis (needed for extrema)
    # the default implementation is just a simple sum that will be normalized to an average
    if self.normalize: raise DerivedVariableError('Aggregated extrema should not be normalized!')
    #print self.name, comdata.shape
    if comdata is not None and comdata.size > 0:
      # N.B.: comdata can be None if the record was not long enough to compute this variable
      if aggdata is None:
        aggdata = comdata # i.e. no intermediate accumulation step (already monthly data)
      else:
        if self.mode == 1: 
          if self.ignoreNaN: aggdata = np.fmax(aggdata,comdata)
          else: aggdata = np.maximum(aggdata,comdata) # aggregate maxima
        elif self.mode == 0:
          if self.ignoreNaN: aggdata = np.fmin(aggdata,comdata)
          else: aggdata = np.minimum(aggdata,comdata) # aggregate minima
    # return aggregated value for further treatment
    return aggdata
  
  
# base class for 'period over threshold'-type extrema 
class ConsecutiveExtrema(Extrema):
  ''' Class of variables that tracks the period of exceedance of a threshold. '''

  def __init__(self, var, mode, threshold=0, name=None, long_name=None, dimmap=None, ignoreNaN=False):
    ''' Constructor; takes variable object as argument and infers meta data. '''
    # construct name with prefix 'Max'/'Min' and camel-case
    if isinstance(var, DerivedVariable):
      varname = var.name; axes = var.axes; atts = var.atts.copy() or dict()
    elif isinstance(var, nc.Variable):
      varname = var._name; axes = var.dimensions; atts = dict()
    else: raise TypeError
    # select mode
    if mode.lower() == 'above':      
      atts['Aggregation'] = 'Maximum Monthly Consecutive Days Above Threshold'
      name_prefix = 'ConAb'; exmode = 1; prefix = '>'
    elif mode.lower() == 'below':      
      atts['Aggregation'] = 'Maximum Monthly Consecutive Days Below Threshold'
      name_prefix = 'ConBe'; exmode = 0; prefix = '<'
    else: raise ValueError("Only 'above' and 'below' are valid modes.")
    atts['Variable'] = '{0:s} {1:s} {2:s} {3:s}'.format(varname,prefix,str(threshold),var.units) 
    atts['ThresholdValue'] = str(threshold); atts['ThresholdVariable'] = varname 
    if long_name is not None: atts['long_name'] = long_name 
    if isinstance(dimmap,dict): axes = [dimmap[dim] if dim in dimmap else dim for dim in axes]
    if name is None: name = '{0:s}{1:f}{2:s}'.format(prefix,threshold,varname[0].upper() + varname[1:])
    # infer attributes of consecutive extreme variable
    super(Extrema,self).__init__(name=name, units='days', prerequisites=[varname], axes=axes, ignoreNaN=ignoreNaN, 
                                 dtype=np.dtype('int16'), atts=atts, linear=False, normalize=False)    
    self.lengthofday = 86400. # delta's are in units of seconds (24 * 60 * 60)
    self.period = 0. # will be set later
    self.thresmode = exmode # above (=1) or below (=0) 
    self.threshold = threshold # threshold value
    self.mode = 1 # aggregation method is always maximum (longest period)
    self.tmpdata = 'COX_'+self.name # don't need temporary storage 
    self.carryover = True # don't stop counting - this is vital    
    
  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Count consecutive above/below threshold days '''
    super(Extrema,self).computeValues(indata, aggax=aggax, delta=delta, const=const, tmp=tmp) # perform some type checks
    # check that delta does not change!
    if 'COX_DELTA' in tmp: 
      if delta != tmp['COX_DELTA']: 
        raise NotImplementedError('Consecutive extrema currently only work, if the output interval is constant.')
    else: 
      tmp['COX_DELTA'] = delta # save and check next time
    if self.period == 0.: 
      self.period = delta / self.lengthofday 
    # get data
    data = indata[self.prerequisites[0]]
    # if axis is not 0 (outermost), roll axis until it is
    if aggax != 0: data = np.rollaxis(data, axis=aggax, start=0).copy() # should make a copy
    tlen = data.shape[0] # aggregation axis
    xshape = data.shape[1:] # rest of the map
    # initialize counter of consecutive exceedances
    if self.tmpdata in tmp: xcnt = tmp[self.tmpdata] # carry over from previous period 
    else: xcnt = np.zeros(xshape, dtype='int16')# initialize as zero
    # initialize output array
    maxdata = np.zeros(xshape, dtype=np.dtype('int16')) # record of maximum consecutive days in computation period 
    # march along aggregation axis
    for t in range(tlen):
      # detect threshold changes
      if self.thresmode == 1: xmask = ( data[t,:] > self.threshold ) # above
      elif self.thresmode == 0: xmask = ( data[t,:] < self.threshold ) # below
      # N.B.: comparisons with NaN always yield False, i.e. non-exceedance
      # update maxima of exceedances
      xnew = np.where(xmask,0,xcnt) * self.period # extract periods before reset
      maxdata = np.maximum(maxdata,xnew) #       
      # set counter for all non-exceedances to zero
      xcnt[np.invert(xmask)] = 0
      # increment exceedance counter
      xcnt[xmask] += 1      
    # carry over current counter to next period or month
    tmp[self.tmpdata] = xcnt
    # return output for further aggregation
    if self.ignoreNaN:
      maxdata = np.ma.masked_where(np.isnan(data).sum(axis=0) > 0, maxdata)
    return maxdata
  

# base class for interval-averaged extrema (sort of similar to running mean)
class MeanExtrema(Extrema):
  ''' Extrema child implementing extrema of interval-averaged values in monthly WRF output. '''
  
  def __init__(self, var, mode, interval=5, name=None, long_name=None, dimmap=None, ignoreNaN=False):
    ''' Constructor; takes variable object as argument and infers meta data. '''
    # infer attributes of Maximum variable
    super(MeanExtrema,self).__init__(var, mode, name=name, long_name=long_name, dimmap=dimmap, ignoreNaN=ignoreNaN)
    if len(self.prerequisites) > 1: raise ValueError("Extrema can only have one Prerquisite")
    self.atts['name'] = self.name = '{0:s}_{1:d}d'.format(self.name,interval)
    self.atts['Aggregation'] = 'Averaged ' + self.atts['Aggregation']
    self.atts['AverageInterval'] = '{0:d} days'.format(interval) # interval in days
    self.interval = interval * 24*60*60 # in seconds, sicne delta will be in seconds, too
    self.tmpdata = 'MEX_'+self.name # handle for temporary storage
    self.carryover = True # don't drop data    

  def computeValues(self, indata, aggax=0, delta=None, const=None, tmp=None):
    ''' Compute field of maxima '''
    #if aggax != 0: raise NotImplementedError, 'Currently, interval averaging only works on the innermost dimension.'
    if delta == 0: raise ValueError('No interval to average over...')
    # assemble data
    data = indata[self.prerequisites[0]]
    # if axis is not 0 (outermost), roll axis until it is
    if aggax != 0: data = np.rollaxis(data, axis=aggax, start=0).copy() # rollaxis just provides a view
    if self.tmpdata in tmp:
      data = np.concatenate((tmp[self.tmpdata], data), axis=0)
    # determine length of interval
    lt = data.shape[0] # available time steps
    pape = data.shape[1:] # remaining shape (must be preserved)
    ilen = int( self.interval / delta )
    nint = int( lt / ilen ) # number of intervals
    if nint > 0:
      # truncate and reshape data
      ui = ilen*nint # usable interval: split data here
      data = data[:ui,:] # use this portion
      rest = data[ui:,:] # save the rest for next iteration
      data = data.reshape((nint,ilen) + pape)
      # average interval
      meandata = data.mean(axis=1) # average over interval dimension
      datadict = {self.prerequisites[0]:meandata} # next method expects a dictionary...
      # find extrema as before (but aggregation axis was shifted to 0)
      outdata = super(MeanExtrema,self).computeValues(datadict, aggax=0, delta=delta, const=const, 
                                                      tmp=None) # perform some type checks
    else:
      rest = data # carry over everything
      outdata = None # nothing to return (handled in aggregation)
    # add remaining data to temporary storage
    tmp[self.tmpdata] = rest
       
    # N.B.: already partially aggregating here, saves memory
    return outdata
