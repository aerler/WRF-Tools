'''
Created on 2013-09-28

A script to average WRF output; the default settings are meant for my 'fineIO' output configuration and 
process the smaller diagnostic files.
The script can run in parallel mode, with each process averaging one filetype and domain, producing 
exactly one output file.  

@author: Andre R. Erler, GPL v3
'''

## imports
import numpy as np
from collections import OrderedDict
from socket import gethostname
#import numpy.ma as ma
import os, re, sys
import netCDF4 as nc
from datetime import datetime
import calendar
# my own netcdf stuff
from geodata.nctools import add_coord, copy_dims, copy_ncatts, copy_vars
from processing.multiprocess import asyncPoolEC
# N.B.: importing from datasets.common causes problems with GDAL, if it is not installed
# days per month without leap days (duplicate from datasets.common) 
days_per_month_365 = np.array([31,28,31,30,31,30,31,31,30,31,30,31])
# import module providing derived variable classes
import average.derived_variables as dv

# date error class
class DateError(Exception):
  ''' Exceptions related to wrfout date strings, e.g. in file names. '''
  pass
# date error class
class ArgumentError(Exception):
  ''' Exceptions related to arguments passed to the script. '''
  pass

def getDateRegX(period):
  ''' function to define averaging period based on argument '''
  # use '\d' for any number and [1-3,45] for ranges; '\d\d\d\d'
  if period == '1979-1980': prdrgx = '19(79|80)' # 2 year historical period
  elif period == '1979-1981': prdrgx = '19(79|8[0-1])' # 3 year historical period
  elif period == '1979-1983': prdrgx = '19(79|8[0-3])' # 5 year historical period
  elif period == '1979-1988': prdrgx = '19(79|8[0-8])' # 10 year historical period
  elif period == '1980-1994': prdrgx = '19(8[0-9]|9[04])' # 15 year historical period
  elif period == '2045-2047': prdrgx = '204[5-7]' # 3 year future period
  elif period == '2045-2049': prdrgx = '204[5-9]' # 5 year future period
  elif period == '2045-2054': prdrgx = '20(4[5-9]|5[0-4])' # 10 year future period
  elif period == '2045-2059': prdrgx = '20(4[5-9]|5[0-9])' # 15 year future period
  elif period == '2085-2087': prdrgx = '208[5-7]' # 3 year future period
  elif period == '2085-2089': prdrgx = '208[5-9]' # 5 year future period
  elif period == '2085-2094': prdrgx = '20(8[5-9]|9[0-4])' # 10 year future period
  elif period == '2085-2099': prdrgx = '20(8[5-9]|9[0-9])' # 15 year future period  
  elif period == '2090-2094': prdrgx = '209[0-4]' # 5 year future period
  else: prdrgx = None
  return prdrgx 


## read arguments
# number of processes NP 
if os.environ.has_key('PYAVG_THREADS'): 
  NP = int(os.environ['PYAVG_THREADS'])
else: NP = None
# only compute whole years 
if os.environ.has_key('PYAVG_OVERWRITE'): 
  loverwrite =  os.environ['PYAVG_OVERWRITE'] == 'OVERWRITE' 
else: loverwrite = False # i.e. append
# N.B.: when loverwrite is True and and prdarg is empty, the entire file is replaced,
#       otherwise only the selected months are recomputed 
# file types to process 
if os.environ.has_key('PYAVG_FILETYPES'): 
  filetypes = os.environ['PYAVG_FILETYPES'].split(';') # semi-colon separated list
else: filetypes = None # defaults are set below
# domains to process
if os.environ.has_key('PYAVG_DOMAINS'): 
  domains = [int(i) for i in os.environ['PYAVG_DOMAINS'].split(';')] # semi-colon separated list
else: domains = None # defaults are set below
# run script in debug mode
if os.environ.has_key('PYAVG_DEBUG'): 
  ldebug =  os.environ['PYAVG_DEBUG'] == 'DEBUG' 
else: ldebug = False # operational mode

# workign directories
exproot = os.getcwd()
exp = exproot.split('/')[-1] # root folder name
infolder = exproot + '/wrfout/' # input folder 
outfolder = exproot + '/wrfavg/' # output folder


# figure out time period
if len(sys.argv) == 1:
  prdarg = ''
  period = [] # means recompute everything
elif len(sys.argv) == 2:
  prdarg = sys.argv[1]
  period = prdarg.split('-') # regular expression identifying 
else: raise ArgumentError
# prdarg = '1979'; period = prdarg.split('-') # for tests
# default time intervals
yearstr = '\d\d\d\d'; monthstr = '\d\d'; daystr = '\d\d'  
# figure out time interval
if len(period) >= 1:
  if len(period[0]) < 4: raise ArgumentError
  yearstr = period[0] 
if len(period) >= 2:
  if len(period[1]) == 4:
    try: 
      tmp = int(period[1])
      yearstr = getDateRegX(prdarg)
      if yearstr is None: raise ArgumentError
    except ValueError: 
      monthstr = period[1]
  elif 2 <= len(period[1]) <= 4:
    monthstr = period[1]
if len(period) >= 3:
  if len(period[2]) != 2: raise ArgumentError
  daystr = period[2]
# N.B.: the timestr variables are interpreted as strings and support Python regex syntax


## definitions
# input files and folders
filetypes = filetypes or ['srfc', 'plev3d', 'xtrm', 'hydro', 'lsm', 'rad']
domains = domains or [1,2,3,4] 
# filetypes and domains can also be set in an semi-colon-separated environment variable (see above)
# inputpattern = 'wrf{0:s}_d{1:02d}_{2:s}-{3:s}-{4:s}_\d\d:\d\d:\d\d.nc' # expanded with format(type,domain,year,month) 
outputpattern = 'wrf{0:s}_d{1:02d}_monthly.nc' # expanded with format(type,domain)
# variable attributes
wrftime = 'Time' # time dim in wrfout files
wrfxtime = 'XTIME' # time in minutes since WRF simulation start
wrftimestamp = 'Times' # time-stamp variable in WRF
time = 'time' # time dim in monthly mean files
dimlist = ['x','y'] # dimensions we just copy
dimmap = {time:wrftime} #{time:wrftime, 'x':'west_east','y':'south_north'}
midmap = dict(zip(dimmap.values(),dimmap.keys())) # reverse dimmap
# accumulated variables (only total accumulation since simulation start, not, e.g., daily accumulated)
acclist = dict(RAINNC=100,RAINC=100,RAINSH=None,SNOWNC=None,GRAUPELNC=None,SFCEVP=None,POTEVP=None, # srfc vars
               SFROFF=None,UDROFF=None,ACGRDFLX=None,ACSNOW=None,ACSNOM=None,ACHFX=None,ACLHF=None, # lsm vars
               ACSWUPT=1.e9,ACSWUPTC=1.e9,ACSWDNT=1.e9,ACSWDNTC=1.e9,ACSWUPB=1.e9,ACSWUPBC=1.e9,ACSWDNB=1.e9,ACSWDNBC=1.e9, # rad vars
               ACLWUPT=1.e9,ACLWUPTC=1.e9,ACLWDNT=1.e9,ACLWDNTC=1.e9,ACLWUPB=1.e9,ACLWUPBC=1.e9,ACLWDNB=1.e9,ACLWDNBC=1.e9) # rad vars
# N.B.: keys = variables and values = bucket sizes; value = None or 0 means no bucket  
bktpfx = 'I_' # prefix for bucket variables; these are processed together with their accumulated variables 

# derived variables
derived_variables = {filetype:[] for filetype in filetypes} # derived variable lists by file type
derived_variables['srfc']  = [dv.Rain(), dv.LiquidPrecipSR(), dv.SolidPrecipSR(), 
                              dv.NetPrecip_Srfc(), dv.WaterVapor()]
derived_variables['xtrm']   = [dv.RainMean(), dv.WetDays(), dv.FrostDays()]
derived_variables['hydro'] = [dv.Rain(), dv.LiquidPrecip(), dv.SolidPrecip(),                            
                              dv.NetPrecip_Hydro(), dv.NetWaterFlux(), ]
derived_variables['lsm']   = [dv.RunOff()]
# Maxima (just list base variables; derived variables will be created later)
maximum_variables = {filetype:[] for filetype in filetypes} # maxima variable lists by file type
maximum_variables['srfc']  = ['T2', 'U10', 'V10', 'RAIN', 'RAINC']
maximum_variables['xtrm']  = ['T2MEAN', 'T2MAX', 'SPDUV10MEAN', 'SPDUV10MAX', 
                              'RAINMEAN', 'RAINNCVMAX', 'RAINCVMAX']
maximum_variables['hydro'] = ['T2MEAN', 'RAIN', 'RAINC', 'NetWaterFlux']
maximum_variables['lsm']   = ['SFROFF']
maximum_variables['plev3d']   = ['S_PL', 'GHT_PL']
# weekly (smoothed) maxima
weekmax_variables  = {filetype:[] for filetype in filetypes} # maxima variable lists by file type
weekmax_variables['hydro'] = ['T2MEAN', 'RAIN', 'ACSNOM', 'NetPrecip', 'NetWaterFlux']
weekmax_variables['lsm']   = ['SFROFF','UDROFF','Runoff']
# Maxima (just list base variables; derived variables will be created later)
minimum_variables = {filetype:[] for filetype in filetypes} # minima variable lists by file type
minimum_variables['srfc']  = ['T2']
minimum_variables['xtrm']  = ['T2MEAN', 'T2MIN']
minimum_variables['hydro'] = ['T2MEAN']
minimum_variables['plev3d']   = ['GHT_PL']
# weekly (smoothed) minima
weekmin_variables  = {filetype:[] for filetype in filetypes} # mininma variable lists by file type
weekmin_variables['hydro'] = ['T2MEAN', 'RAIN', 'ACSNOM', 'NetPrecip', 'NetWaterFlux']
weekmin_variables['lsm']   = ['SFROFF','UDROFF','Runoff']
# N.B.: it is important that the derived variables are listed in order of dependency! 
# set of pre-requisites
prereq_vars = {key:set() for key in derived_variables.keys()} # pre-requisite variable set by file type
for key in prereq_vars.keys():
  prereq_vars[key].update(*[devar.prerequisites for devar in derived_variables[key] if not devar.linear])    

## main work function
# N.B.: the loop iterations should be entirely independent, so that they can be run in parallel
def processFileList(filelist, filetype, ndom, lparallel=False, pidstr='', logger=None):
  ''' This function is doing the main work, and is supposed to be run in a multiprocessing environment. '''  
  
  ## setup files and folders

  # load first file to copy some meta data
  wrfout = nc.Dataset(infolder+filelist[0], 'r', format='NETCDF4')
  # timeless variables (should be empty, since all timeless variables should be in constant files!)        
  timeless = [varname for varname,var in wrfout.variables.iteritems() if 'Time' not in var.dimensions]
  assert len(timeless) == 0
  # time-dependent variables            
  varlist = [varname for varname,var in wrfout.variables.iteritems() if 'Time' in var.dimensions \
             and np.issubdtype(var.dtype, np.number) and not varname[0:len(bktpfx)] == bktpfx]

  ## derived variables, extrema, and dependencies
  # derived variable list
  derived_vars = OrderedDict() # it is important that the derived variables are computed in order:
  # the reason is that derived variables can depend on other derived variables, and the order in 
  # which they are listed, should take this into account
  for devar in derived_variables[filetype]:
    derived_vars[devar.name] = devar 
  pqset = prereq_vars[filetype] # set of pre-requisites for derived variables
  
  
  
  # method to create derived variables for extrema
  def addExtrema(new_variables, mode, interval=0):
    for exvar in new_variables[filetype]:
      # create derived variable instance
      if exvar in derived_vars: 
        if interval == 0: devar = dv.Extrema(derived_vars[exvar],mode)
        else: devar = dv.MeanExtrema(derived_vars[exvar],mode,interval=interval)
      else: 
        if interval == 0: devar = dv.Extrema(wrfout.variables[exvar],mode, dimmap=midmap)
        else: devar = dv.MeanExtrema(wrfout.variables[exvar],mode, interval=interval, dimmap=midmap)
      # append to derived variables
      derived_vars[devar.name] = devar # derived_vars is from the parent scope, not local! 
  # now add them
  addExtrema(maximum_variables, 'max')
  addExtrema(minimum_variables, 'min')
  addExtrema(weekmax_variables, 'max', interval=7)
  addExtrema(weekmin_variables, 'min', interval=7)
    
  # construct dependencies
  # update linearity: dependencies of non-linear variables have to be treated as non-linear themselves
  lagain = True
  # parse through dependencies until nothing changes anymore
  while lagain:
    lagain = False
    for devar in derived_vars.itervalues():
      if not devar.linear:
        # make sure all dependencies are also treated as non-linear
        for pq in devar.prerequisites:
          if pq in derived_vars and derived_vars[pq].linear:
            lagain = True # indicate modification
            derived_vars[pq].linear = False
  # construct dependency set (should include extrema now)
  pqset = set().union(*[devar.prerequisites for devar in derived_vars.itervalues() if not devar.linear])
  laccpq = any([accvar in pqset for accvar in acclist]) # if accumulated variables are among the prerequisites
  
  # get some meta info and construct title string
  begindate = datergx.search(filelist[0]).group()
  beginyear, beginmonth, beginday = [int(tmp) for tmp in begindate.split('-')]
  assert beginday == 1, 'always have to begin on the first of a month'
  enddate = datergx.search(filelist[-1]).group()
  endyear, endmonth, endday = [int(tmp) for tmp in enddate.split('-')]
  assert 1 <= endday <= 31 # this is kinda trivial...  
  varstr = ''; devarstr = '' # make variable list, also for derived variables
  for var in varlist: varstr += '%s, '%var
  for devar in derived_vars.values(): devarstr += '%s, '%devar.name
      
  # announcement: format title string and print
  titlestr = '\n\n{0:s}    ***   Processing wrf{1:s} files for domain {2:d}.   ***'.format(pidstr,filetype,ndom)
  titlestr += '\n          (monthly means from {0:s} to {1:s}, incl.)'.format(begindate,enddate)
  if varstr: titlestr += '\n Variable list: {0:s}'.format(str(varstr),)
  else: titlestr += '\n Variable list: None'
  if devarstr: titlestr += '\n Derived variables: {0:s}'.format(str(devarstr),)
  # print meta info (print everything in one chunk, so output from different processes does not get mangled)
  logger.info(titlestr)
  
  # open/create monthly mean output file
  filename = outputpattern.format(filetype,ndom)   
  meanfile = outfolder+filename
  if os.path.exists(meanfile):
    if loverwrite or os.path.getsize(meanfile) < 1e6: os.remove(meanfile)
    # N.B.: NetCDF files smaller than 1MB are usually incomplete header fragments from a previous crashed
  if os.path.exists(meanfile):
    mean = nc.Dataset(meanfile, mode='a', format='NETCDF4') # open to append data (mode='a')
    # infer start index
    meanbeginyear, meanbeginmonth, meanbeginday = [int(tmp) for tmp in mean.begin_date.split('-')]
    assert meanbeginday == 1, 'always have to begin on the first of a month'
    t0 = (beginyear-meanbeginyear)*12 + (beginmonth-meanbeginmonth) + 1        
    # check time-stamps in old datasets
    if mean.end_date < begindate: assert t0 == len(mean.dimensions[time]) + 1 # another check
    else: assert t0 <= len(mean.dimensions[time]) + 1 # get time index where we start; in month beginning 1979  
    #if not loverwrite: raise DateError, "%s Begindate %s comes before enddate %s in file %s"%(pidstr,begindate,enddate,filename)
    # check derived variables
    for var in derived_vars.values():
      if var.name not in mean.variables: 
        raise (dv.DerivedVariableError, 
               "{0:s} Derived variable '{1:s}' not found in file '{2:s}'".format(pidstr,var.name,filename))
      var.checkPrerequisites(mean)
  else:
    mean = nc.Dataset(meanfile, 'w', format='NETCDF4') # open to start a new file (mode='w')
    t0 = 1 # time index where we start: first month in 1979
    mean.createDimension(time, size=None) # make time dimension unlimited
    add_coord(mean, time, data=None, dtype='i4', atts=dict(units='month since '+begindate)) # unlimited time dimension
    # copy remaining dimensions to new datasets
    if midmap is not None:
      dimlist = [midmap.get(dim,dim) for dim in wrfout.dimensions.keys() if dim != wrftime]
    else: dimlist = [dim for dim in wrfout.dimensions.keys() if dim != wrftime]
    copy_dims(mean, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
    # copy time-less variable to new datasets
    copy_vars(mean, wrfout, varlist=timeless, dimmap=dimmap, copy_data=True) # copy data
    # create time-dependent variable in new datasets
    copy_vars(mean, wrfout, varlist=varlist, dimmap=dimmap, copy_data=False) # do not copy data - need to average
    # change units of accumulated variables (per second)
    for varname in acclist:
      if varname in mean.variables:
        meanvar = mean.variables[varname]
        meanvar.units = meanvar.units + '/s' # units per second!
    # also create variable for time-stamps in new datasets
    if wrftimestamp in wrfout.variables:
      copy_vars(mean, wrfout, varlist=[wrftimestamp], dimmap=dimmap, copy_data=False) # do nto copy data - need to average
    # create derived variables
    for var in derived_vars.values(): 
      var.checkPrerequisites(mean)
      var.createVariable(mean)            
    # copy global attributes
    copy_ncatts(mean, wrfout, prefix='') # copy all attributes (no need for prefix; all upper case are original)
    # some new attributes
    mean.description = 'wrf{0:s}_d{1:02d} monthly means'.format(filetype,ndom)
    mean.begin_date = begindate
    mean.experiment = exp
    mean.creator = 'Andre R. Erler'
    # write to file
    mean.sync()        

  # extend time dimension in monthly average
  if (endyear < beginyear) or (endyear == beginyear and endmonth < beginmonth):
    raise DateError, "End date is before begin date!"
  times = np.arange(t0,t0+(endyear-beginyear)*12+endmonth-beginmonth+1)
  # update current end date
  mean.end_date = enddate # the date-time-stamp of the last included output file
  # handling of time intervals for accumulated variables
  if wrfxtime in wrfout.variables: 
    lxtime = True # simply compute differences from XTIME (assuming minutes)
    assert wrfout.variables[wrfxtime].description == "minutes since simulation start"
  elif wrftimestamp in wrfout.variables: 
    lxtime = False # interpret timestamp in Times using datetime module
  else: raise TypeError
      
  # check if there is a missing_value flag
  if 'P_LEV_MISSING' in wrfout.ncattrs():
    missing_value = wrfout.P_LEV_MISSING # usually -999.
    # N.B.: this is only used in plev3d files, where pressure levels intersect the ground
  else: missing_value = None
  
  # allocate fields
  data = dict() # temporary data arrays
  for var in varlist:        
    tmpshape = list(wrfout.variables[var].shape)
    del tmpshape[wrfout.variables[var].dimensions.index(wrftime)] # allocated arrays have no time dimension
    assert len(tmpshape) ==  len(wrfout.variables[var].shape) -1
    data[var] = np.zeros(tmpshape) # allocate
    #if missing_value is not None:
    #  data[var] += missing_value # initialize with missing value
  # allocate derived data arrays (for non-linear variables)   
  pqdata = {pqvar:None for pqvar in pqset} # temporary data array holding instantaneous values to compute derived variables
  # N.B.: since data is only referenced from existing arrays, allocation is not necessary
  dedata = dict() # non-linear derived variables
  # N.B.: linear derived variables are computed directly from the monthly averages 
  for dename,devar in derived_vars.items():
    if not devar.linear:
      tmpshape = [len(wrfout.dimensions[ax]) for ax in devar.axes if ax != time] # infer shape
      assert len(tmpshape) ==  len(devar.axes) -1 # no time dimension
      dedata[dename] = np.zeros(tmpshape) # allocate     
  
      
  # prepare computation of monthly means  
  filecounter = 0 # number of wrfout file currently processed 
  i0 = t0-1 # index position we write to: i = i0 + n (zero-based, of course)
  ## start loop over month
  if lparallel: progressstr = '' # a string printing the processed dates
  else: logger.info('\n Processed dates:')
  

  try:
    
    # loop over month and progressively stepping through input files
    for n,t in enumerate(times):
     
      liniout = True # determines whether last timestep is the same as first time step in next file
      # N.B.: when moving to the next file, the script auto-detects and resets this property, no need to change here!
      #       However (!) it is necessary to reset this for every month, because it is not consistent!

      # extend time array / month counter
      meanidx = i0 + n
      # check if we are overwriting existing data
      if meanidx == len(mean.variables[time]): 
        lskip = False # append next data point / time step
      elif loverwrite: 
        assert meanidx < len(mean.variables[time])
        lskip = False # overwrite this step
      else: 
        assert meanidx < len(mean.variables[time])
        lskip = True # skip this step, but we still have to verify the timing
      meantime = t # month since simulation start
      # N.B.: writing records is delayed to avoid incomplete records in case of a crash
      # current date
      currentyear, currentmonth = divmod(n+beginmonth-1,12)
      currentyear += beginyear; currentmonth +=1 
      # sanity checks
      assert meanidx + 1 == meantime  
      currentdate = '{0:04d}-{1:02d}'.format(currentyear,currentmonth)
      # determine appropriate start index
      wrfstartidx = 0    
      while currentdate > str().join(wrfout.variables[wrftimestamp][wrfstartidx,0:7]):
        wrfstartidx += 1 # count forward
      # save WRF time-stamp for beginning of month for the new file, for record
      starttimestamp = wrfout.variables[wrftimestamp][wrfstartidx,:] # written to file later
      # print feedback (the current month)
      if not lskip: # but not if we are skipping this step...
        if lparallel: progressstr += '{0:s}, '.format(currentdate) # bundle output in parallel mode
        else: logger.info('{0:s},'.format(currentdate)) # serial mode
      logger.debug('\n{0:s}{1:s}-01_00:00:00, {2:s}'.format(pidstr, currentdate, str().join(wrfout.variables[wrftimestamp][wrfstartidx,:])))
      if '{0:s}-01_00:00:00'.format(currentdate,) == str().join(wrfout.variables[wrftimestamp][wrfstartidx,:]): pass # proper start of the month
      elif '{0:s}-01_06:00:00'.format(currentdate,) == str().join(wrfout.variables[wrftimestamp][wrfstartidx,:]): pass # for some reanalysis...
      else: raise DateError, ("{0:s} Did not find first day of month to compute monthly average.".format(pidstr) +
                              "file: {0:s} date: {1:s}-01_00:00:00".format(filename,currentdate))
      
      # prepare summation of output time steps
      lcomplete = False # 
      ntime = 0 # accumulated output time steps     
      # time when accumulation starts (in minutes)        
      # N.B.: the first value is saved as negative, so that adding the last value yields a positive interval
      if lxtime: xtime = -1 * wrfout.variables[wrfxtime][wrfstartidx] # seconds
      else: xtime = str().join(wrfout.variables[wrftimestamp][wrfstartidx,:]) # datestring of format '%Y-%m-%d_%H:%M:%S'
      # clear temporary arrays
      for varname,var in data.items(): # base variables
        data[varname] = np.zeros(var.shape) # reset to zero
      for dename,devar in dedata.items(): # derived variables
        dedata[dename] = np.zeros(devar.shape) # reset to zero           
      
      ## loop over files and average
      while not lcomplete:
        
        # determine valid end index by checking dates from the end counting backwards
        # N.B.: start index is determined above (if a new file was opened in the same month, 
        #       the start index is automatically set to 0 or 1 when the file is opened, below)
        wrfendidx = len(wrfout.dimensions[wrftime])-1
        while wrfendidx >= 0 and currentdate < str().join(wrfout.variables[wrftimestamp][wrfendidx,0:7]):
          if not lcomplete: lcomplete = True # break loop over file if next month is in this file (critical!)        
          wrfendidx -= 1 # count backwards
        if wrfendidx < len(wrfout.dimensions[wrftime])-1: # check if count-down actually happened 
          wrfendidx += 1 # reverse last step so that counter sits at fist step of next month       
        # N.B.: if this is not the last file, there was no iteration and wrfendidx is the length of the the file;
        # if the first date in the file is already the next month, wrfendidx will be 0 and this is the final step 
        assert wrfendidx >= wrfstartidx
        # if this is the last file and the month is not complete, we have to forcefully terminate
        if filecounter == len(filelist)-1 and not lcomplete: 
          lcomplete = True # end loop
          lskip = True # don't write results for this month!
  
        if not lskip:
          ## compute monthly averages
          for varname in varlist:
            logger.debug('{0:s} {1:s}'.format(pidstr,varname))
            var = wrfout.variables[varname]
            tax = var.dimensions.index(wrftime) # index of time axis
            slices = [slice(None)]*len(var.shape) 
            # decide how to average
            ## Accumulated Variables
            if varname in acclist: 
              if missing_value is not None: 
                raise NotImplementedError, "Can't handle accumulated variables with missing values yet."
              # compute mean as difference between end points; normalize by time difference
              if ntime == 0: # first time step of the month
                slices[tax] = wrfstartidx # relevant time interval
                tmp = var.__getitem__(slices)
                if acclist[varname] is not None: # add bucket level, if applicable
                  bkt = wrfout.variables[bktpfx+varname]
                  tmp += bkt.__getitem__(slices) * acclist[varname]   
                data[varname] = -1 * tmp # so we can do an in-place operation later 
              # N.B.: both, begin and end, can be in the same file, hence elif is not appropriate! 
              if lcomplete: # last step
                slices[tax] = wrfendidx # relevant time interval
                tmp = var.__getitem__(slices)
                if acclist[varname] is not None: # add bucket level, if applicable 
                  bkt = wrfout.variables[bktpfx+varname]
                  tmp += bkt.__getitem__(slices) * acclist[varname]   
                data[varname] +=  tmp # the starting data is already negative
              # if variable is a prerequisit to others, compute instantaneous values
              if varname in pqset:
                # compute mean via sum over all elements; normalize by number of time steps
                slices[tax] = slice(wrfstartidx,wrfendidx) # relevant time interval
                intmp = var.__getitem__(slices)
                if acclist[varname] is not None: # add bucket level, if applicable
                  bkt = wrfout.variables[bktpfx+varname]
                  intmp = intmp + bkt.__getitem__(slices) * acclist[varname]
                outtmp = np.zeros_like(intmp)
                diff = np.diff(intmp, n=1, axis=tax)
                if tax == 0:
                  # compute centered differences, except at the edges, where forward/backward difference are used
                  outtmp[0:-1,:] += diff; outtmp[1:,:] += diff; outtmp[1:-1,:] /= 2
                else: raise NotImplementedError  
                pqdata[varname] = outtmp
            elif varname[0:len(bktpfx)] == bktpfx: pass # do not process buckets
            ## Normal Variables
            else: 
              # compute mean via sum over all elements; normalize by number of time steps
              slices[tax] = slice(wrfstartidx,wrfendidx) # relevant time interval
              tmp = var.__getitem__(slices) # get array
              if missing_value is not None:
                # N.B.: missing value handling is really only necessary when missing values time-dependent
                tmp = np.where(tmp == missing_value, np.NaN, tmp) # set missing values to NaN
                #tmp = ma.masked_equal(tmp, missing_value, copy=False) # mask missing values
              data[varname] = data[varname] + tmp.sum(axis=tax) # add to sum
              # N.B.: in-place operations with non-masked array destroy the mask, hence need to use this
              # keep data in memory if used in computation of derived variables
              if varname in pqset: pqdata[varname] = tmp
          ## compute derived variables
          # But first, normalize accumulated pqdata with output interval time
          if wrfendidx > wrfstartidx:
            if lxtime:
              delta = wrfout.variables[wrfxtime][wrfendidx] - wrfout.variables[wrfxtime][wrfstartidx]
              delta *=  60. # convert minutes to seconds   
            else: 
              dt1 = datetime.strptime(str().join(wrfout.variables[wrftimestamp][wrfstartidx,:]), '%Y-%m-%d_%H:%M:%S')
              dt2 = datetime.strptime(str().join(wrfout.variables[wrftimestamp][wrfendidx,:]), '%Y-%m-%d_%H:%M:%S')
              delta = float( (dt2-dt1).total_seconds() ) # the difference creates a timedelta object
            delta /=  float(wrfendidx - wrfstartidx) # the average interval between output time steps
            # loop over time-step data
            for pqname,pqvar in pqdata.items():
              if pqname in acclist: pqvar /= delta # normalize
          else: delta = 0
	        # N.B.: if wrfendidx == wrfstartidx, just use previous values...
          # loop over derived variables
          logger.debug('\n{0:s} Available prerequisites: {1:s}'.format(pidstr, str(pqdata.keys())))
          for dename,devar in derived_vars.items():
            if not devar.linear: # only non-linear ones here, linear one at the end
              logger.debug('\n{0:s} {1:s} {2:s}'.format(pidstr, dename, str(devar.prerequisites)))
              tmp = devar.computeValues(pqdata, aggax=tax, delta=delta) # possibly needed as pre-requisite  
              dedata[dename] = devar.aggregateValues(dedata[dename], tmp, aggax=tax)
              # N.B.: in-place operations with non-masked array destroy the mask, hence need to use this
              if dename in pqset: pqdata[dename] = tmp
              # N.B.: missing values should be handled implicitly, following missing values in pre-requisites            
            
          # increment counters
          ntime += wrfendidx - wrfstartidx
          if lcomplete: 
            if lxtime:
              xtime += wrfout.variables[wrfxtime][wrfendidx] # get final time interval (in minutes)
              xtime *=  60. # convert minutes to seconds   
            else: 
              dt1 = datetime.strptime(xtime, '%Y-%m-%d_%H:%M:%S')
              dt2 = datetime.strptime(str().join(wrfout.variables[wrftimestamp][wrfendidx,:]), '%Y-%m-%d_%H:%M:%S')
              xtime = (dt2-dt1).total_seconds() # the difference creates a timedelta object
              # N.B.: the datetime module always includes leapdays; the code below is to remove leap days
              #       in order to correctly handle model calendars that don't have leap days
              if liniout:
                assert wrfendidx > 0
                yyyy, mm, dd = str().join(wrfout.variables[wrftimestamp][wrfendidx-1,0:10]).split('-')
              else:
                yyyy, mm, dd = lasttimestamp[0:10].split('-') # gets set below, when moving to the next file
              # also a bit of sanity checking...
              assert yyyy == '{0:04d}'.format(currentyear) and mm == '{0:02d}'.format(currentmonth)
              if calendar.isleap(currentyear) and currentmonth==2:
                if dd == '28':
                  xtime -= 86400. # subtract leap day for calendars without leap day
                  logger.info('\n{0:s} Correcting time interval for {1:s}: current calendar does not have leap-days.'.format(pidstr,currentdate))
                else: assert dd == '29' # if there is a leap day
              else:
                dpm = '{0:02d}'.format(days_per_month_365[currentmonth-1])
                assert dd == dpm, '{0:s}-{1:s}-{2:s}: {2:s} != {3:s}'.format(yyyy,mm,dd,dpm)  # if there is no leap day
             
        # two possible ends: month is done or reached end of file
        # if we reached the end of the file, open a new one and go again
        if not lcomplete:            
	  lasttimestamp = str().join(wrfout.variables[wrftimestamp][wrfendidx,:]) # needed to determine, if first timestep is the same as last
          wrfout.close() # close file...
          # N.B.: filecounter +1 < len(filelist) is already checked above 
          filecounter += 1 # move to next file
          wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
	  firsttimestamp = str().join(wrfout.variables[wrftimestamp][0,:]) # check first timestep (compare to last of previous file)
          if missing_value is not None:
            assert missing_value == wrfout.P_LEV_MISSING
          # reset output record / time step counter
          if firsttimestamp == lasttimestamp: 
            wrfstartidx = 1 # skip the initialization step (same as last step in previous file)
            liniout = True # needed later to detect leapdays
	  else: 
            wrfstartidx = 0 # no duplicates: first timestep in next file was not present in previous file
            liniout = False # needed later to detect leapdays
        else: # month complete
          if wrfendidx == len(wrfout.dimensions[wrftime])-1: # at the end
            wrfout.close() # close file...
            filecounter += 1 # move to next file
            if filecounter < len(filelist):    
              wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
              wrfstartidx = 0 # use initialization step (same as last step in previous file)
          
      ## now the loop over files terminated and we need to normalize and save the results
      
      if not lskip:
        # update time axis
        mean.variables[time][meanidx] = meantime
        mean.variables[wrftimestamp][meanidx,:] = starttimestamp 
        # loop over variable names
        for varname in varlist:
          vardata = data[varname]
          # decide how to normalize
          if varname in acclist: vardata /= xtime 
          else: vardata /= ntime
          # save variable
          ncvar = mean.variables[varname] # this time the destination variable
          if missing_value is not None: # make sure the missing value flag is preserved
            vardata = np.where(np.isnan(vardata), missing_value, vardata)
            ncvar.missing_value = missing_value # just to make sure
          if ncvar.ndim > 1: ncvar[meanidx,:] = vardata # here time is always the outermost index
          else: ncvar[meanidx] = vardata
        # compute derived variables
        logger.debug('\n{0:s}   Derived Variable Stats: (mean/min/max)'.format(pidstr))
        for dename,devar in derived_vars.items():
          if devar.linear:           
            vardata = devar.computeValues(data) # compute derived variable now from averages
          elif devar.normalize: 
            vardata = dedata[dename] / ntime # no accumulated variables here!
          else: vardata = dedata[dename] # just the data...
          # not all variables are normalized (e.g. extrema)
          logger.debug('{0:s} {1:s}, {2:f}, {3:f}, {4:f}'.format(pidstr,dename,float(vardata.mean()),float(vardata.min()),float(vardata.max())))
          data[dename] = vardata # add to data array, so that it can be used to compute linear variables
          # save variable
          ncvar = mean.variables[dename] # this time the destination variable
          if missing_value is not None: # make sure the missing value flag is preserved
            vardata = np.where(np.isnan(vardata), missing_value, vardata)
            ncvar.missing_value = missing_value # just to make sure
          if ncvar.ndim > 1: ncvar[meanidx,:] = vardata # here time is always the outermost index
          else: ncvar[meanidx] = vardata            
          #raise dv.DerivedVariableError, "%s Derived variable '%s' is not linear."%(pidstr,devar.name) 
        # sync data
        mean.sync()
        
    ec = 0 # set zero exit code for this operation
        
  except Exception:
    # report error
    logger.exception('\n # {0:s} WARNING: an Error occured while stepping through files! '.format(pidstr)+
                     '\n # Last State: month={0:d}, variable={1:s}, file={2:s}'.format(meanidx,varname,filename)+
                     '\n # Saving current data and exiting\n')
    logger.exception(pidstr) # print stack trace of last exception and current process ID
    ec = 1 # set non-zero exit code
    # N.B.: this enables us to still close the file!
    
  ## here the loop over months finishes and we can close the output file 
  # print progress
  
  # save to file
  if not lparallel: logger.info('') # terminate the line (of dates) 
  else: logger.info('\n{0:s} Processed dates: {1:s}'.format(pidstr, progressstr))   
  mean.sync()
  logger.info('\n{0:s} Writing output to: {1:s}\n({2:s})\n'.format(pidstr, filename, meanfile))
  # close files        
  mean.close()  
  # return exit code
  return ec

# now begin execution    
if __name__ == '__main__':


  # print settings
  print('\nOVERWRITE: {0:s}\n'.format(str(loverwrite)))
  
  # compile regular expression, used to infer start and end dates and month (later, during computation)
  datestr = '{0:s}-{1:s}-{2:s}'.format(yearstr,monthstr,daystr)
  datergx = re.compile(datestr)
    
  # get file list
  wrfrgx = re.compile('wrf.*_d\d\d_{0:s}_\d\d:\d\d:\d\d.nc'.format(datestr,))
  # regular expression to match the name pattern of WRF timestep output files
  masterlist = [wrfrgx.match(filename) for filename in os.listdir(infolder)] # list folder and match
  masterlist = [match.group() for match in masterlist if match is not None] # assemble valid file list
  if len(masterlist) == 0: raise IOError, 'No matching WRF output files found for date: {0:s}'.format(datestr)
  
  ## loop over filetypes and domains to construct job list
  args = []
  for filetype in filetypes:    
    # make list of files
    filelist = []
    for domain in domains:
      typergx = re.compile('wrf{0:s}_d{1:02d}_{2:s}_\d\d:\d\d:\d\d.nc'.format(filetype, domain, datestr))
      # regular expression to also match type and domain index
      filelist = [typergx.match(filename) for filename in masterlist] # list folder and match
      filelist = [match.group() for match in filelist if match is not None] # assemble valid file list
      filelist.sort() # now, when the list is shortest, we can sort...
      # N.B.: sort alphabetically, so that files are in temporally sequence
      # now put everything into the lists
      if len(filelist) > 0:
        args.append( (filelist, filetype, domain) )
    
  # call parallel execution function
  kwargs = dict() # no keyword arguments
  asyncPoolEC(processFileList, args, kwargs, NP=NP, ldebug=ldebug, ltrialnerror=True)
    
