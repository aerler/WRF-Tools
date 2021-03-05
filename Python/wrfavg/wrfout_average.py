'''
Created on 2013-09-28, revised 2014-06-17, added daily output 2020-05-04

A script to average WRF output; the default settings are meant for my 'fineIO' output configuration and 
process the smaller diagnostic files.
The script can run in parallel mode, with each process averaging one filetype and domain, producing 
exactly one output file.  

@author: Andre R. Erler, GPL v3
'''

#TODO: add time-dependent auxiliary files to file processing (use prerequisites from other files)
#TODO: add option to discard prerequisit variables
#TODO: add base variables for correlation and standard deviation (and (co-)variance).
#TODO: more variables: tropopause height, baroclinicity, PV, water flux (require full 3D fields)
#TODO: add shape-averaged output stream (shapes based on a template file)


## imports
import numpy as np
from collections import OrderedDict
#import numpy.ma as ma
import os, re, sys, shutil, gc
import netCDF4 as nc
# my own netcdf stuff
from utils.nctools import add_coord, copy_dims, copy_ncatts, copy_vars
from processing.multiprocess import asyncPoolEC
# import module providing derived variable classes
import wrfavg.derived_variables as dv
# aliases
days_per_month_365 = dv.days_per_month_365
dtype_float = dv.dtype_float 

# thresholds for wet-day variables (from AMS glossary and ETCCDI Climate Change Indices) 
from utils.constants import precip_thresholds
# N.B.: importing from WRF Tools to GeoPy causes a name collision

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
  if prdrgx: print(("\nLoading regular expression for date string: '{:s}'".format(period)))
  return prdrgx 


## read arguments
# number of processes NP 
if 'PYAVG_THREADS' in os.environ: 
  NP = int(os.environ['PYAVG_THREADS'])
else: NP = None
# only compute derived variables 
if 'PYAVG_DERIVEDONLY' in os.environ: 
  lderivedonly =  os.environ['PYAVG_DERIVEDONLY'] == 'DERIVEDONLY' 
else: lderivedonly = False # i.e. all
# # scale dry-day threshold 
# if os.environ.has_key('PYAVG_DRYDAY') and bool(os.environ['PYAVG_DRYDAY']): # i.e. not empty and non-zero
#   dryday_correction =  float(os.environ['PYAVG_DRYDAY']) # relative to WMO recommendation
#   dv.dryday_threshold = dv.dryday_threshold * dryday_correction # precip treshold for a dry day: 2.3e-7 mm/s
#   print("\n   ***   The dry-day threshold was increased by a factor of {:3.2f} relative to WMO recommendation   ***   \n".format(dryday_correction))
# recompute last timestep and continue (usefule after a crash)  
if 'PYAVG_RECOVER' in os.environ: 
  lrecover =  os.environ['PYAVG_RECOVER'] == 'RECOVER' 
else: lrecover = False # i.e. normal operation
# just add new and leave old
if 'PYAVG_ADDNEW' in os.environ: 
  laddnew =  os.environ['PYAVG_ADDNEW'] == 'ADDNEW' 
else: laddnew = False # i.e. recompute all
# recompute specified variables
if 'PYAVG_RECALC' in os.environ:
  if os.environ['PYAVG_RECALC'] == 'DERIVEDONLY':
    # recalculate all derived variables and leave others in place
    lrecalc = True; lderivedonly = True; recalcvars = []
  else:
    recalcvars = os.environ['PYAVG_RECALC'].split() # space separated list (other characters cause problems...)
    if len(recalcvars) > 0 and len(recalcvars[0]) > 0: lrecalc = True # if there is a variable to recompute
    else: lrecalc = False
  # lrecalc uses the same pathway, but they can operate independently
else: lrecalc = False # i.e. recompute all
# overwrite existing data 
if 'PYAVG_OVERWRITE' in os.environ: 
  loverwrite =  os.environ['PYAVG_OVERWRITE'] == 'OVERWRITE'
  if loverwrite: laddnew = False; lrecalc = False 
else: loverwrite = False # i.e. append
# N.B.: when loverwrite is True and and prdarg is empty, the entire file is replaced,
#       otherwise only the selected months are recomputed 
# file types to process 
if 'PYAVG_FILETYPES' in os.environ:
  filetypes = os.environ['PYAVG_FILETYPES'].split() # space separated list (other characters cause problems...)
  if len(filetypes) == 1 and len(filetypes[0]) == 0: filetypes = None # empty string, substitute default 
else: filetypes = None # defaults are set below
# domains to process
if 'PYAVG_DOMAINS' in os.environ:
  domains = os.environ['PYAVG_DOMAINS'].split() # space separated list (other characters cause problems...)
  if len(domains) == 1: domains = [int(i) for i in domains[0]] # string of single-digit indices
  else: domains = [int(i) for i in domains] # semi-colon separated list
else: domains = None # defaults are set below 
# run script in debug mode
if 'PYAVG_DEBUG' in os.environ: 
  ldebug =  os.environ['PYAVG_DEBUG'] == 'DEBUG'
  lderivedonly = ldebug or lderivedonly # usually this is what we are debugging, anyway...
else: ldebug = False # operational mode
# wipe temporary storage after every month (no carry-over)
if 'PYAVG_CARRYOVER' in os.environ: 
  lcarryover =  os.environ['PYAVG_CARRYOVER'] == 'CARRYOVER'
else: lcarryover = True # operational mode
# use simple differences or centered differences for accumulated variables
if 'PYAVG_SMPLDIFF' in os.environ: 
  lsmplDiff = os.environ['PYAVG_SMPLDIFF'] == 'SMPLDIFF'
else: lsmplDiff = False # default mode: centered differences
# generate formatted daily/sub-daily output files for selected variables
if 'PYAVG_DAILY' in os.environ: 
  lglobaldaily =  os.environ['PYAVG_DAILY'] == 'DAILY'
else: lglobaldaily = False # operational mode


# working directories
exproot = os.getcwd()
exp = exproot.split('/')[-1] # root folder name
infolder = exproot + '/wrfout/' # input folder 
outfolder = exproot + '/wrfavg/' # output folder


# figure out time period
# N.B.: values or regex' can be passed for year, month, and day as arguments in this order; alternatively,
#       a single argument with the values/regex separated by commas (',') can be used
if len(sys.argv) == 1 or not any(sys.argv[1:]): # treat empty arguments as no argument
  period = [] # means recompute everything
elif len(sys.argv) == 2:
  period = sys.argv[1].split(',') # regular expression identifying
else: 
  period = sys.argv[1:]
# prdarg = '1979'; period = prdarg.split('-') # for tests
# default time intervals
yearstr = '\d\d\d\d'; monthstr = '\d\d'; daystr = '\d\d'  
# figure out time interval
if len(period) >= 1:
    # first try some common expressions
    yearstr = getDateRegX(period[0])
    if yearstr is None: yearstr = period[0]
if len(period) >= 2: monthstr = period[1]
if len(period) >= 3: daystr = period[2]
# N.B.: the timestr variables are interpreted as strings and support Python regex syntax
if len(period) > 0 or ldebug: print('Date string interpretation:',yearstr,monthstr,daystr)

## definitions
# input files and folders
filetypes = filetypes or ['srfc', 'plev3d', 'xtrm', 'hydro', 'lsm', 'rad', 'snow']
domains = domains or [1,2,3,4] 
# filetypes and domains can also be set in an semi-colon-separated environment variable (see above)
# file pattern (WRF output and averaged files)
# inputpattern = 'wrf{0:s}_d{1:02d}_{2:s}-{3:s}-{4:s}_\d\d:\d\d:\d\d.nc' # expanded with format(type,domain,year,month) 
inputpattern = '^wrf{0:s}_d{1:s}_{2:s}_\d\d[_:]\d\d[_:]\d\d(?:\.nc$|$)' # expanded with format(type,domain,datestring)
#inputpattern = '^wrf{0:s}_d{1:s}_{2:s}_\d\d[_:]\d\d[_:]\d\d.*$' # expanded with format(type,domain,datestring)
# N.B.: the last section (?:\.nc$|$) matches either .nc at the end or just the end of the string;
#       ?: just means that the group defined by () can not be retrieved (it is just to hold "|") 
constpattern = 'wrfconst_d{0:02d}' # expanded with format(domain), also WRF output
# N.B.: file extension is added automatically for constpattern and handled by regex for inputpattern 
monthlypattern = 'wrf{0:s}_d{1:02d}_monthly.nc' # expanded with format(type,domain)
dailypattern = 'wrf{0:s}_d{1:02d}_daily.nc' # expanded with format(type,domain)
# variable attributes
wrftime = 'Time' # time dim in wrfout files
wrfxtime = 'XTIME' # time in minutes since WRF simulation start
wrfaxes = dict(Time='tax', west_east='xax', south_north='yax', num_press_levels_stag='pax')
wrftimestamp = 'Times' # time-stamp variable in WRF
time = 'time' # time dim in monthly mean files
dimlist = ['x','y'] # dimensions we just copy
dimmap = {time:wrftime} #{time:wrftime, 'x':'west_east','y':'south_north'}
midmap = dict(list(zip(list(dimmap.values()),list(dimmap.keys())))) # reverse dimmap
# accumulated variables (only total accumulation since simulation start, not, e.g., daily accumulated)
acclist = dict(RAINNC=100.,RAINC=100.,RAINSH=None,SNOWNC=None,GRAUPELNC=None,SFCEVP=None,POTEVP=None, # srfc vars
               SFROFF=None,UDROFF=None,ACGRDFLX=None,ACSNOW=None,ACSNOM=None,ACHFX=None,ACLHF=None, # lsm vars
               ACSWUPT=1.e9,ACSWUPTC=1.e9,ACSWDNT=1.e9,ACSWDNTC=1.e9,ACSWUPB=1.e9,ACSWUPBC=1.e9,ACSWDNB=1.e9,ACSWDNBC=1.e9, # rad vars
               ACLWUPT=1.e9,ACLWUPTC=1.e9,ACLWDNT=1.e9,ACLWDNTC=1.e9,ACLWUPB=1.e9,ACLWUPBC=1.e9,ACLWDNB=1.e9,ACLWDNBC=1.e9) # rad vars
# N.B.: keys = variables and values = bucket sizes; value = None or 0 means no bucket  
bktpfx = 'I_' # prefix for bucket variables; these are processed together with their accumulated variables

# derived variables
derived_variables = {filetype:[] for filetype in filetypes} # derived variable lists by file type
derived_variables['srfc']   = [dv.Rain(), dv.LiquidPrecipSR(), dv.SolidPrecipSR(), dv.NetPrecip(sfcevp='QFX'),  
                               dv.WaterVapor(), dv.OrographicIndex(), dv.CovOIP(), dv.WindSpeed(),
                               dv.SummerDays(threshold=25., temp='T2'), dv.FrostDays(threshold=0., temp='T2')]
                              # N.B.: measures the fraction of 6-hourly samples above/below the threshold (day and night)
derived_variables['xtrm']   = [dv.RainMean(), dv.TimeOfConvection(),
                               dv.SummerDays(threshold=25., temp='T2MAX'), dv.FrostDays(threshold=0., temp='T2MIN')]
derived_variables['hydro']  = [dv.Rain(), dv.LiquidPrecip(), dv.SolidPrecip(), 
                               dv.NetPrecip(sfcevp='SFCEVP'), dv.NetWaterFlux(), dv.WaterForcing()]
derived_variables['rad']    = [dv.NetRadiation(), dv.NetLWRadiation()]
derived_variables['lsm']    = [dv.RunOff()]
derived_variables['plev3d'] = [dv.OrographicIndexPlev(), dv.Vorticity(), dv.WindSpeed(),
                               dv.WaterDensity(), dv.WaterFlux_U(), dv.WaterFlux_V(), dv.ColumnWater(), 
                               dv.WaterTransport_U(), dv.WaterTransport_V(),
                               dv.HeatFlux_U(), dv.HeatFlux_V(), dv.ColumnHeat(), 
                               dv.HeatTransport_U(),dv.HeatTransport_V(),
                               dv.GHT_Var(), dv.Vorticity_Var()]
# add wet-day variables for different thresholds
wetday_variables = [dv.WetDays, dv.WetDayRain, dv.WetDayPrecip] 
for threshold in precip_thresholds:
  for wetday_var in wetday_variables:
    derived_variables['srfc'].append(wetday_var(threshold=threshold, rain='RAIN'))
    derived_variables['hydro'].append(wetday_var(threshold=threshold, rain='RAIN'))
    derived_variables['xtrm'].append(wetday_var(threshold=threshold, rain='RAINMEAN'))
                               
# N.B.: derived variables need to be listed in order of computation
# Consecutive exceedance variables
consecutive_variables = {filetype:None for filetype in filetypes} # consecutive variable lists by file type
# skip in debug mode (only specific ones for debug)
if ldebug:
    print("Skipping 'Consecutive Days of Exceedance' Variables")
else:
    consecutive_variables['srfc']  = {'CFD'  : ('T2', 'below', 273.14, 'Consecutive Frost Days (< 0C)'),
                                      'CSD'  : ('T2', 'above', 273.14+25., 'Consecutive Summer Days (>25C)'), 
                                      # N.B.: night temperatures >25C will rarely happen... so this will be very short
                                      'CNWD' : ('NetPrecip', 'above', 0., 'Consecutive Net Wet Days'),
                                      'CNDD' : ('NetPrecip', 'below', 0., 'Consecutive Net Dry Days'),}
    consecutive_variables['xtrm']  = {'CFD'  : ('T2MIN', 'below', 273.14, 'Consecutive Frost Days (< 0C)'),
                                      'CSD'  : ('T2MAX', 'above', 273.14+25., 'Consecutive Summer Days (>25C)'),}
    consecutive_variables['hydro'] = {'CNWD' : ('NetPrecip', 'above', 0., 'Consecutive Net Wet Days'),
                                      'CNDD' : ('NetPrecip', 'below', 0., 'Consecutive Net Dry Days'),
                                      'CWGD' : ('NetWaterFlux', 'above', 0., 'Consecutive Water Gain Days'),
                                      'CWLD' : ('NetWaterFlux', 'below', 0., 'Consecutive Water Loss Days'),}
    # add wet-day variables for different thresholds
    for threshold in precip_thresholds:
      for filetype,rain_var in zip(['srfc','hydro','xtrm'],['RAIN','RAIN','RAINMEAN']):
        suffix = '_{:03d}'.format(int(10*threshold)); name_suffix = '{:3.1f} mm/day)'.format(threshold)
        consecutive_variables[filetype]['CWD'+suffix] = (rain_var, 'above', threshold/86400., 
                                                         'Consecutive Wet Days (>'+name_suffix)
        consecutive_variables[filetype]['CDD'+suffix] = (rain_var, 'below', threshold/86400. , 
                                                         'Consecutive Dry Days (<'+name_suffix)
## single- and multi-step Extrema
maximum_variables = {filetype:[] for filetype in filetypes} # maxima variable lists by file type
daymax_variables  = {filetype:[] for filetype in filetypes} # maxima variable lists by file type
daymin_variables  = {filetype:[] for filetype in filetypes} # mininma variable lists by file type
weekmax_variables  = {filetype:[] for filetype in filetypes} # maxima variable lists by file type
minimum_variables = {filetype:[] for filetype in filetypes} # minima variable lists by file type
weekmin_variables  = {filetype:[] for filetype in filetypes} # mininma variable lists by file type
# skip in debug mode (only specific ones for debug)
if ldebug:
    print("Skipping Single- and Multi-step Extrema")
else:
    # Maxima (just list base variables; derived variables will be created later)
    maximum_variables['srfc']   = ['T2', 'U10', 'V10', 'RAIN', 'RAINC', 'RAINNC', 'NetPrecip', 'WindSpeed']
    maximum_variables['xtrm']   = ['T2MEAN', 'T2MAX', 'SPDUV10MEAN', 'SPDUV10MAX', 
                                   'RAINMEAN', 'RAINNCVMAX', 'RAINCVMAX']
    maximum_variables['hydro']  = ['RAIN', 'RAINC', 'RAINNC', 'ACSNOW', 'ACSNOM', 'NetPrecip', 'NetWaterFlux', 'WaterForcing']
    maximum_variables['lsm']    = ['SFROFF', 'Runoff']
    maximum_variables['plev3d'] = ['S_PL', 'GHT_PL', 'Vorticity']
    # daily (smoothed) maxima
    daymax_variables['srfc']  = ['T2','RAIN', 'RAINC', 'RAINNC', 'NetPrecip', 'WindSpeed']
    # daily (smoothed) minima
    daymin_variables['srfc']  = ['T2']
    # weekly (smoothed) maxima
    weekmax_variables['xtrm']   = ['T2MEAN', 'T2MAX', 'SPDUV10MEAN'] 
    weekmax_variables['hydro']  = ['RAIN', 'RAINC', 'RAINNC', 'ACSNOW', 'ACSNOM', 'NetPrecip', 'NetWaterFlux', 'WaterForcing']
    weekmax_variables['lsm']    = ['SFROFF', 'UDROFF', 'Runoff']
    # Maxima (just list base variables; derived variables will be created later)
    minimum_variables['srfc']   = ['T2']
    minimum_variables['xtrm']   = ['T2MEAN', 'T2MIN', 'SPDUV10MEAN']
    minimum_variables['hydro']  = ['RAIN', 'NetPrecip', 'NetWaterFlux', 'WaterForcing']
    minimum_variables['plev3d'] = ['GHT_PL', 'Vorticity']
    # weekly (smoothed) minima
    weekmin_variables['xtrm']   = ['T2MEAN', 'T2MIN', 'SPDUV10MEAN']
    weekmin_variables['hydro']  = ['RAIN', 'NetPrecip', 'NetWaterFlux', 'WaterForcing']
    weekmin_variables['lsm']    = ['SFROFF','UDROFF','Runoff']
# N.B.: it is important that the derived variables are listed in order of dependency! 

# set of pre-requisites
prereq_vars = {key:set() for key in derived_variables.keys()} # pre-requisite variable set by file type
for key in prereq_vars.keys():
  prereq_vars[key].update(*[devar.prerequisites for devar in derived_variables[key] if not devar.linear])    

## daily variables (can also be 6-hourly or hourly, depending on source file)
if lglobaldaily:
    daily_variables = {filetype:[] for filetype in filetypes} # daily variable lists by file type
    daily_variables['srfc']  = ['T2', 'PSFC', 'WaterVapor', 'WindSpeed',] # surface climate
    daily_variables['xtrm']  = ['T2MIN', 'T2MAX'] # min/max T2
    daily_variables['hydro'] = ['RAIN', 'RAINC', 'LiquidPrecip', 'WaterForcing', 'SFCEVP', 'POTEVP'] # water budget
    daily_variables['rad'] = ['NetRadiation','ACSWDNB','ACLWDNB','NetLWRadiation',] # surface radiation budget
    #daily_variables['lsm'] = [] # runoff and soil temperature

## main work function
# N.B.: the loop iterations should be entirely independent, so that they can be run in parallel
def processFileList(filelist, filetype, ndom, lparallel=False, pidstr='', logger=None, ldebug=False):
  ''' This function is doing the main work, and is supposed to be run in a multiprocessing environment. '''  
  
  ## setup files and folders

  # load first file to copy some meta data
  wrfoutfile = infolder+filelist[0]
  logger.debug("\n{0:s} Opening first input file '{1:s}'.".format(pidstr,wrfoutfile))
  wrfout = nc.Dataset(wrfoutfile, 'r', format='NETCDF4')
  # timeless variables (should be empty, since all timeless variables should be in constant files!)        
  timeless = [varname for varname,var in wrfout.variables.items() if 'Time' not in var.dimensions]
  assert len(timeless) == 0 # actually useless, since all WRF variables have a time dimension...
  # time-dependent variables            
  varlist = [] # list of time-dependent variables to be processed
  for varname,var in wrfout.variables.items():
    if ('Time' in var.dimensions) and np.issubdtype(var.dtype, np.number) and varname[0:len(bktpfx)] != bktpfx:
      varlist.append(varname)
  varlist.sort() # alphabetical order...

  ## derived variables, extrema, and dependencies
  # derived variable list
  derived_vars = OrderedDict() # it is important that the derived variables are computed in order:
  # the reason is that derived variables can depend on other derived variables, and the order in 
  # which they are listed, should take this into account
  for devar in derived_variables[filetype]:
    derived_vars[devar.name] = devar
    
  # create consecutive extrema variables
  if consecutive_variables[filetype] is not None:
    for key,value in consecutive_variables[filetype].items():
      if value[0] in derived_vars: 
        derived_vars[key] = dv.ConsecutiveExtrema(derived_vars[value[0]], value[1], threshold=value[2], 
                                                  name=key, long_name=value[3])
      else:
        derived_vars[key] = dv.ConsecutiveExtrema(wrfout.variables[value[0]], value[1], threshold=value[2], 
                                                  name=key, long_name=value[3], dimmap=midmap)
  
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
  # and now add them
  addExtrema(maximum_variables, 'max')
  addExtrema(minimum_variables, 'min')
  addExtrema(daymax_variables, 'max', interval=1)
  addExtrema(daymin_variables, 'min', interval=1)  
  addExtrema(weekmax_variables, 'max', interval=5) # 5 days is the preferred interval, according to
  addExtrema(weekmin_variables, 'min', interval=5) # ETCCDI Climate Change Indices

  ldaily = False
  if lglobaldaily:
      # get varlist (does not include dependencies)
      daily_varlist_full = daily_variables[filetype]
      if len(daily_varlist_full)>0:
          ldaily = True
          daily_varlist = []; daily_derived_vars = [] 
          for varname in daily_varlist_full:
              if varname in wrfout.variables: daily_varlist.append(varname)
              elif varname in derived_vars: daily_derived_vars.append(varname)
              else: 
                raise ArgumentError("Variable '{}' not found in wrfout or derived variables; can only output derived variables that are already being computed for monthly output.".format(varname))
      else:
          logger.info("\n{0:s} Skipping (sub-)daily output for filetype '{1:s}', since variable list is empty.\n".format(pidstr,filetype))

  # if we are only computing derived variables, remove all non-prerequisites 
  prepq = set().union(*[devar.prerequisites for devar in derived_vars.values()])
  if ldaily: prepq |= set(daily_varlist)
  if lderivedonly: varlist = [var for var in varlist if var in prepq]

    
  # get some meta info and construct title string (printed after file creation)
  begindate = str(nc.chartostring(wrfout.variables[wrftimestamp][0,:10])) # first timestamp in first file
  beginyear, beginmonth, beginday = [int(tmp) for tmp in begindate.split('-')]
  # always need to begin on the first of a month (discard incomplete data of first month)
  if beginday != 1:
    beginmonth += 1 # move on to next month
    beginday = 1 # and start at the first (always...)
    begindate = '{0:04d}-{1:02d}-{2:02d}'.format(beginyear, beginmonth, beginday) # rewrite begin date
  # open last file and get last date
  lastoutfile = infolder+filelist[-1]
  logger.debug("{0:s} Opening last input file '{1:s}'.".format(pidstr,lastoutfile))
  lastout = nc.Dataset(lastoutfile, 'r', format='NETCDF4')
  lstidx = lastout.variables[wrftimestamp].shape[0]-1 # netcdf library has problems with negative indexing
  enddate = str(nc.chartostring(lastout.variables[wrftimestamp][lstidx,:10])) # last timestamp in last file
  endyear, endmonth, endday = [int(tmp) for tmp in enddate.split('-')]; del endday # make warning go away...
  # the last timestamp should be the next month (i.e. that month is not included)
  if endmonth == 1: 
    endmonth = 12; endyear -= 1 # previous year 
  else: endmonth -= 1 
  endday = 1 # first day of last month (always 1st..)
  assert 1 <= endday <= 31 and 1 <= endmonth <= 12 # this is kinda trivial...  
  enddate = '{0:04d}-{1:02d}-{2:02d}'.format(endyear, endmonth, endday) # rewrite begin date
      
  ## open/create monthly mean output file
  monthly_file = monthlypattern.format(filetype,ndom)  
  if lparallel: tmppfx = 'tmp_wrfavg_{:s}_'.format(pidstr[1:-1])
  else: tmppfx = 'tmp_wrfavg_' 
  monthly_filepath = outfolder + monthly_file
  tmp_monthly_filepath = outfolder + tmppfx + monthly_file
  if os.path.exists(monthly_filepath):
      if loverwrite or os.path.getsize(monthly_filepath) < 1e6: os.remove(monthly_filepath)
      # N.B.: NetCDF files smaller than 1MB are usually incomplete header fragments from a previous crashed job
  if os.path.exists(tmp_monthly_filepath) and not lrecover: os.remove(tmp_monthly_filepath) # remove old temp files
  if os.path.exists(monthly_filepath):
      # make a temporary copy of the file to work on (except, if we are recovering a broken temp file)
      if not ( lrecover and os.path.exists(tmp_monthly_filepath) ): shutil.copy(monthly_filepath,tmp_monthly_filepath)
      # open (temporary) file
      logger.debug("{0:s} Opening existing output file '{1:s}'.\n".format(pidstr,monthly_filepath))    
      monthly_dataset = nc.Dataset(tmp_monthly_filepath, mode='a', format='NETCDF4') # open to append data (mode='a')
      # infer start index
      meanbeginyear, meanbeginmonth, meanbeginday = [int(tmp) for tmp in monthly_dataset.begin_date.split('-')]
      assert meanbeginday == 1, 'always have to begin on the first of a month'
      t0 = (beginyear-meanbeginyear)*12 + (beginmonth-meanbeginmonth) + 1    
      # check time-stamps in old datasets
      if monthly_dataset.end_date < begindate: assert t0 == len(monthly_dataset.dimensions[time]) + 1 # another check
      else: assert t0 <= len(monthly_dataset.dimensions[time]) + 1 # get time index where we start; in month beginning 1979
##
##  ***  special functions like adding new and recalculating old variables could be added later for daily output  ***    
##
      # checks for new variables
      if laddnew or lrecalc: 
        if t0 != 1: raise DateError("Have to start at the beginning to add new or recompute old variables!") # t0 starts with 1, not 0
        meanendyear, meanendmonth, meanendday = [int(tmp) for tmp in monthly_dataset.end_date.split('-')]
        assert meanendday == 1
        endyear, endmonth = meanendyear, meanendmonth # just adding new, not extending!
        enddate = monthly_dataset.end_date # for printing...
      # check base variables
      if laddnew or lrecalc: newvars = []
      for var in varlist:
        if var not in monthly_dataset.variables:
          if laddnew: newvars.append(var)
          else: varlist.remove(var) 
          #raise IOError, "{0:s} variable '{1:s}' not found in file '{2:s}'".format(pidstr,var.name,monthly_file)
      # add new variables to netcdf file
      if laddnew and len(newvars) > 0:
        # copy remaining dimensions to new datasets
        if midmap is not None:
          dimlist = [midmap.get(dim,dim) for dim in wrfout.dimensions.keys() if dim != wrftime]
        else: dimlist = [dim for dim in wrfout.dimensions.keys() if dim != wrftime]
        dimlist = [dim for dim in dimlist if dim not in monthly_dataset.dimensions] # only the new ones!
        copy_dims(monthly_dataset, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables      
        # create time-dependent variable in new datasets
        copy_vars(monthly_dataset, wrfout, varlist=newvars, dimmap=dimmap, copy_data=False) # do not copy data - need to average
        # change units of accumulated variables (per second)
        for varname in newvars: # only new vars
          assert varname in monthly_dataset.variables
          if varname in acclist:
            meanvar = monthly_dataset.variables[varname]
            meanvar.units = meanvar.units + '/s' # units per second!
      # add variables that should be recalculated    
      if lrecalc:
        for var in recalcvars:
          if var in monthly_dataset.variables and var in wrfout.variables:
            if var not in newvars: newvars.append(var)
          #else: raise ArgumentError, "Variable '{:s}' scheduled for recalculation is not present in output file '{:s}'.".format(var,monthly_filepath)
      # check derived variables
      if laddnew or lrecalc: newdevars = []
      for varname,var in derived_vars.items():
        if varname in monthly_dataset.variables:
          var.checkPrerequisites(monthly_dataset)
          if not var.checked: raise ValueError("Prerequisits for derived variable '{:s}' not found.".format(varname))
          if lrecalc:
            if ( lderivedonly and len(recalcvars) == 0 ) or ( varname in recalcvars ): 
              newdevars.append(varname)
              var.checkPrerequisites(monthly_dataset) # as long as they are sorted correctly...
              #del monthly_dataset.variables[varname]; monthly_dataset.sync()
              #var.createVariable(monthly_dataset) # this does not seem to work...
        else:
          if laddnew: 
            var.checkPrerequisites(monthly_dataset) # as long as they are sorted correctly...
            var.createVariable(monthly_dataset)
            newdevars.append(varname)
          else: del derived_vars[varname] # don't bother
          # N.B.: it is not possible that a previously computed variable depends on a missing variable,
          #       unless it was purposefully deleted, in which case this will crash!
          #raise (dv.DerivedVariableError, "{0:s} Derived variable '{1:s}' not found in file '{2:s}'".format(pidstr,var.name,monthly_file))
      # now figure out effective variable list
      if laddnew or lrecalc:
        varset = set(newvars)
        devarset = set(newdevars)
        ndv = -1
        # check prerequisites
        while ndv != len(devarset):   
          ndv = len(devarset)
          for devar in list(devarset): # normal variables don't have prerequisites
            for pq in derived_vars[devar].prerequisites:
              if pq in derived_vars: devarset.add(pq)
              else: varset.add(pq)
        # N.B.: this algorithm for dependencies relies on the fact that derived_vars is already ordered correctly,
        #       and unused variables can simply be removed (below), without changing the order;
        #       a stand-alone dependency resolution would require soring the derived_vars in order of execution 
        # consolidate lists
        for devar in derived_vars.keys():
          if devar not in devarset: del derived_vars[devar] # don't bother with this one...
        varlist = list(varset) # order doesnt really matter... but whatever...
        varlist.sort() # ... alphabetical order...
  else:
      logger.debug("{0:s} Creating new output file '{1:s}'.\n".format(pidstr,monthly_filepath))
      monthly_dataset = nc.Dataset(tmp_monthly_filepath, 'w', format='NETCDF4') # open to start a new file (mode='w')
      t0 = 1 # time index where we start (first month)
      monthly_dataset.createDimension(time, size=None) # make time dimension unlimited
      add_coord(monthly_dataset, time, data=None, dtype='i4', atts=dict(units='month since '+begindate)) # unlimited time dimension
      # copy remaining dimensions to new datasets
      if midmap is not None:
        dimlist = [midmap.get(dim,dim) for dim in wrfout.dimensions.keys() if dim != wrftime]
      else: dimlist = [dim for dim in wrfout.dimensions.keys() if dim != wrftime]
      copy_dims(monthly_dataset, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
      # copy time-less variable to new datasets
      copy_vars(monthly_dataset, wrfout, varlist=timeless, dimmap=dimmap, copy_data=True) # copy data
      # create time-dependent variable in new datasets
      copy_vars(monthly_dataset, wrfout, varlist=varlist, dimmap=dimmap, copy_data=False) # do not copy data - need to average
      # change units of accumulated variables (per second)
      for varname in acclist:
        if varname in monthly_dataset.variables:
          meanvar = monthly_dataset.variables[varname]
          meanvar.units = meanvar.units + '/s' # units per second!
      # also create variable for time-stamps in new datasets
      if wrftimestamp in wrfout.variables:
        copy_vars(monthly_dataset, wrfout, varlist=[wrftimestamp], dimmap=dimmap, copy_data=False) # do nto copy data - need to average
      # create derived variables
      for var in derived_vars.values(): 
        var.checkPrerequisites(monthly_dataset) # as long as they are sorted correctly...
        var.createVariable(monthly_dataset) # derived variables need to be added in order of computation           
      # copy global attributes
      copy_ncatts(monthly_dataset, wrfout, prefix='') # copy all attributes (no need for prefix; all upper case are original)
      # some new attributes
      monthly_dataset.acc_diff_mode = 'simple' if lsmplDiff else 'centered'
      monthly_dataset.description = 'wrf{0:s}_d{1:02d} monthly means'.format(filetype,ndom)
      monthly_dataset.begin_date = begindate
      monthly_dataset.experiment = exp
      monthly_dataset.creator = 'Andre R. Erler'
  # sync with file
  monthly_dataset.sync()     


  ## open/create daily output file
  if ldaily:
      # get datetime 
      begindatetime = dv.getTimeStamp(wrfout, 0, wrftimestamp)
      # figure out filename
      daily_file = dailypattern.format(filetype,ndom)  
      if lparallel: tmppfx = 'tmp_wrfavg_{:s}_'.format(pidstr[1:-1])
      else: tmppfx = 'tmp_wrfavg_' 
      daily_filepath = outfolder + daily_file
      tmp_daily_filepath = outfolder + tmppfx + daily_file
      if os.path.exists(daily_filepath):
        if loverwrite or os.path.getsize(daily_filepath) < 1e6: os.remove(daily_filepath)
        # N.B.: NetCDF files smaller than 1MB are usually incomplete header fragments from a previous crashed job
      if os.path.exists(tmp_daily_filepath) and not lrecover: os.remove(tmp_daily_filepath) # remove old temp files
      if os.path.exists(daily_filepath):
          raise NotImplementedError("Currently, updating of and appending to (sub-)daily output files is not supported.")
      else:
          logger.debug("{0:s} Creating new (sub-)daily output file '{1:s}'.\n".format(pidstr,daily_filepath))
          daily_dataset = nc.Dataset(tmp_daily_filepath, 'w', format='NETCDF4') # open to start a new file (mode='w')
          timestep_start = 0 # time step where we start (first tiem step)
          daily_dataset.createDimension(time, size=None) # make time dimension unlimited
          add_coord(daily_dataset, time, data=None, dtype='i8', atts=dict(units='seconds since '+begindatetime)) # unlimited time dimension
          # copy remaining dimensions to new datasets
          if midmap is not None:
            dimlist = [midmap.get(dim,dim) for dim in wrfout.dimensions.keys() if dim != wrftime]
          else: dimlist = [dim for dim in wrfout.dimensions.keys() if dim != wrftime]
          copy_dims(daily_dataset, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
          # copy time-less variable to new datasets
          copy_vars(daily_dataset, wrfout, varlist=timeless, dimmap=dimmap, copy_data=True) # copy data
          # create time-dependent variable in new datasets
          copy_vars(daily_dataset, wrfout, varlist=daily_varlist, dimmap=dimmap, copy_data=False) # do not copy data - need to resolve buckets and straighten time
          # change units of accumulated variables (per second)
          for varname in acclist:
            if varname in daily_dataset.variables:
              dayvar = daily_dataset.variables[varname]
              dayvar.units = dayvar.units + '/s' # units per second!
          # also create variable for time-stamps in new datasets
          if wrftimestamp in wrfout.variables:
            copy_vars(daily_dataset, wrfout, varlist=[wrftimestamp], dimmap=dimmap, copy_data=False) # do not copy data - need to straighten out time axis
          if wrfxtime in wrfout.variables:
            copy_vars(daily_dataset, wrfout, varlist=[wrfxtime], dimmap=dimmap, copy_data=False) # do not copy data - need to straighten out time axis
          # create derived variables
          for devarname in daily_derived_vars: 
            # don't need to check for prerequisites, since they are already being checked and computed for monthly output
            derived_vars[devarname].createVariable(daily_dataset) # derived variables need to be added in order of computation           
          # copy global attributes
          copy_ncatts(daily_dataset, wrfout, prefix='') # copy all attributes (no need for prefix; all upper case are original)
          # some new attributes
          daily_dataset.acc_diff_mode = 'simple' if lsmplDiff else 'centered'
          daily_dataset.description = 'wrf{0:s}_d{1:02d} post-processed timestep output'.format(filetype,ndom)
          daily_dataset.begin_date = begindatetime
          daily_dataset.experiment = exp
          daily_dataset.creator = 'Andre R. Erler'
      # sync with file
      daily_dataset.sync()     

  ## construct dependencies
  # update linearity: dependencies of non-linear variables have to be treated as non-linear themselves
  lagain = True
  # parse through dependencies until nothing changes anymore
  while lagain:
    lagain = False
    for dename,devar in derived_vars.items():
      # variables for daily output can be treated as non-linear, so that they are computed at the native timestep
      if ldaily and dename in daily_derived_vars: devar.linear = False
      if not devar.linear:
        # make sure all dependencies are also treated as non-linear
        for pq in devar.prerequisites:
          if pq in derived_vars and derived_vars[pq].linear:
            lagain = True # indicate modification
            derived_vars[pq].linear = False
  # construct dependency set (should include extrema now)
  pqset = set().union(*[devar.prerequisites for devar in derived_vars.values() if not devar.linear])
  if ldaily:
      # daily output variables need to be treated as prerequisites, so that full timestep fields are loaded for bucket variables
      pqset |= set(daily_varlist)
  cset = set().union(*[devar.constants for devar in derived_vars.values() if devar.constants is not None])
  
  # initialize dictionary for temporary storage
  tmpdata = dict() # not allocated - use sparingly
  
  # load constants, if necessary
  const = dict()
  lconst = len(cset) > 0
  if lconst:
    constfile = infolder+constpattern.format(ndom)
    if not os.path.exists(constfile): constfile += '.nc' # try with extension
    if not os.path.exists(constfile): raise IOError("No constants file found! ({:s})".format(constfile))
    logger.debug("\n{0:s} Opening constants file '{1:s}'.\n".format(pidstr,constfile))
    wrfconst = nc.Dataset(constfile, 'r', format='NETCDF4')
    # constant variables
    for cvar in cset:
      if cvar in wrfconst.variables: const[cvar] = wrfconst.variables[cvar][:]
      elif cvar in wrfconst.ncattrs(): const[cvar] = wrfconst.getncattr(cvar)
      else: raise ValueError("Constant variable/attribute '{:s}' not found in constants file '{:s}'.".format(cvar,constfile))             
  else: const = None
    
  # check axes order of prerequisits and constants
  for devar in derived_vars.values():
    for pq in devar.prerequisites:
      # get dimensions of prerequisite
      if pq in varlist: pqax = wrfout.variables[pq].dimensions
      elif lconst and pq in wrfconst.variables: pqax = wrfconst.variables[pq].dimensions
      elif lconst and pq in const: pqax = () # a scalar value, i.e. no axes
      elif pq in derived_vars: pqax = derived_vars[pq].axes
      else: raise ValueError("Prerequisite '{:s} for variable '{:s}' not found!".format(pq,devar.name))
      # check axes for consistent order
      index = -1
      for ax in devar.axes: 
        if ax in pqax:
          idx = pqax.index(ax) 
          if idx > index: index = idx
          else: raise IndexError("The axis order of '{:s}' and '{:s}' is inconsistent - this can lead to unexpected results!".format(devar.name,pq))  
      
  # announcement: format title string and print
  varstr = ''; devarstr = '' # make variable list, also for derived variables
  for var in varlist: varstr += '{}, '.format(var)
  for devar in derived_vars.values(): devarstr += '%s, '%devar.name
  titlestr = '\n\n{0:s}    ***   Processing wrf{1:s} files for domain {2:d}.   ***'.format(pidstr,filetype,ndom)
  titlestr += '\n          (monthly means from {0:s} to {1:s}, incl.)'.format(begindate,enddate)
  if varstr: titlestr += '\n Variable list: {0:s}'.format(str(varstr),)
  else: titlestr += '\n Variable list: None'
  if devarstr: titlestr += '\n Derived variables: {0:s}'.format(str(devarstr),)
  # print meta info (print everything in one chunk, so output from different processes does not get mangled)
  logger.info(titlestr)

  # extend time dimension in monthly average
  if (endyear < beginyear) or (endyear == beginyear and endmonth < beginmonth):
    raise DateError("End date is before begin date: {:04d}-{:02d} < {:04d}-{:02d}".format(endyear,endmonth,beginyear,beginmonth))
  times = np.arange(t0,t0+(endyear-beginyear)*12+endmonth-beginmonth+1)
  # handling of time intervals for accumulated variables
  if wrfxtime in wrfout.variables: 
    lxtime = True # simply compute differences from XTIME (assuming minutes)
    time_desc = wrfout.variables[wrfxtime].description
    assert time_desc.startswith("minutes since "), time_desc 
    assert "simulation start" in time_desc or begindate in time_desc or '**' in time_desc, time_desc 
    # N.B.: the last check (**) is for cases where the date in WRF is garbled...
    if t0 == 1 and not wrfout.variables[wrfxtime][0] == 0:
      raise ValueError( 'XTIME in first input file does not start with 0!\n'+
                        '(this can happen, when the first input file is missing)' )
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
      data[var] = np.zeros(tmpshape, dtype=dtype_float) # allocate
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
          dedata[dename] = np.zeros(tmpshape, dtype=dtype_float) # allocate     
  
      
  # prepare computation of monthly means  
  filecounter = 0 # number of wrfout file currently processed 
  i0 = t0-1 # index position we write to: i = i0 + n (zero-based, of course)
  if ldaily: daily_start_idx = daily_end_idx = timestep_start # for each file cycle, the time index where to write the data
  ## start loop over month
  if lparallel: progressstr = '' # a string printing the processed dates
  else: logger.info('\n Processed dates:')
  

  try:
    
    # loop over month and progressively stepping through input files
    for n,meantime in enumerate(times):
        # meantime: (complete) month since simulation start
       
        lasttimestamp = None # carry over start time, when moving to the next file (defined below)
        # N.B.: when moving to the next file, the script auto-detects and resets this property, no need to change here!
        #       However (!) it is necessary to reset this for every month, because it is not consistent!
  
        # extend time array / month counter
        meanidx = i0 + n
        if meanidx == len(monthly_dataset.variables[time]): 
          lskip = False # append next data point / time step
        elif loverwrite or laddnew or lrecalc: 
          lskip = False # overwrite this step or add data point for new variables
        elif meanidx == len(monthly_dataset.variables[time])-1:
          if lrecover or monthly_dataset.variables[time][meanidx] == -1:
            lskip = False # recompute last step, because it may be incomplete
          else: lskip = True
        else: 
          lskip = True # skip this step, but we still have to verify the timing
        # check if we are overwriting existing data
        if meanidx != len(monthly_dataset.variables[time]):
          assert meanidx < len(monthly_dataset.variables[time])
          assert meantime == monthly_dataset.variables[time][meanidx] or monthly_dataset.variables[time][meanidx] == -1
        # N.B.: writing records is delayed to avoid incomplete records in case of a crash
        # current date
        currentyear, currentmonth = divmod(n+beginmonth-1,12)
        currentyear += beginyear; currentmonth +=1 
        # sanity checks
        assert meanidx + 1 == meantime  
        currentdate = '{0:04d}-{1:02d}'.format(currentyear,currentmonth)
        # determine appropriate start index
        wrfstartidx = 0    
        while currentdate > str(nc.chartostring(wrfout.variables[wrftimestamp][wrfstartidx,0:7])):
          wrfstartidx += 1 # count forward
        if wrfstartidx != 0: logger.debug('\n{0:s} {1:s}: Starting month at index {2:d}.'.format(pidstr, currentdate, wrfstartidx))
        # save WRF time-stamp for beginning of month for the new file, for record
        firsttimestamp_chars = wrfout.variables[wrftimestamp][wrfstartidx,:]
        #logger.debug('\n{0:s}{1:s}-01_00:00:00, {2:s}'.format(pidstr, currentdate, str(nc.chartostring(wrfout.variables[wrftimestamp][wrfstartidx,:])))
        if '{0:s}-01_00:00:00'.format(currentdate,) == str(nc.chartostring(wrfout.variables[wrftimestamp][wrfstartidx,:])): 
            pass # proper start of the month
        elif meanidx == 0 and '{0:s}-01_06:00:00'.format(currentdate,) == str(nc.chartostring(wrfout.variables[wrftimestamp][wrfstartidx,:])): 
            pass # for some reanalysis... but only at start of simulation 
        else: raise DateError("{0:s} Did not find first day of month to compute monthly average.".format(pidstr) +
                                "file: {0:s} date: {1:s}-01_00:00:00".format(monthly_file,currentdate))
        
        # prepare summation of output time steps
        lcomplete = False # 
        ntime = 0 # accumulated output time steps     
        # time when accumulation starts (in minutes)        
        # N.B.: the first value is saved as negative, so that adding the last value yields a positive interval
        if lxtime: xtime = -1 * wrfout.variables[wrfxtime][wrfstartidx] # minutes
        monthlytimestamps = [] # list of timestamps, also used for time period calculation  
        # clear temporary arrays
        for varname,var in data.items(): # base variables
            data[varname] = np.zeros(var.shape, dtype=dtype_float) # reset to zero
        for dename,devar in dedata.items(): # derived variables
            dedata[dename] = np.zeros(devar.shape, dtype=dtype_float) # reset to zero           
  
        ## loop over files and average
        while not lcomplete:
          
            # determine valid end index by checking dates from the end counting backwards
            # N.B.: start index is determined above (if a new file was opened in the same month, 
            #       the start index is automatically set to 0 or 1 when the file is opened, below)
            wrfendidx = len(wrfout.dimensions[wrftime])-1
            while wrfendidx >= 0 and currentdate < str(nc.chartostring(wrfout.variables[wrftimestamp][wrfendidx,0:7])):
                if not lcomplete: lcomplete = True # break loop over file if next month is in this file (critical!)        
                wrfendidx -= 1 # count backwards
            #if wrfendidx < len(wrfout.dimensions[wrftime])-1: # check if count-down actually happened 
            wrfendidx += 1 # reverse last step so that counter sits at first step of next month               
            # N.B.: if this is not the last file, there was no iteration and wrfendidx should be the length of the the file;
            #       in this case, wrfendidx is only used to define Python ranges, which are exclusive to the upper boundary;
            #       if the first date in the file is already the next month, wrfendidx will be 0 and this is the final step;
            assert wrfendidx >= wrfstartidx # i.e. wrfendidx = wrfstartidx = 0 is an empty step to finalize accumulation
            assert lcomplete or wrfendidx == len(wrfout.dimensions[wrftime])
            # if this is the last file and the month is not complete, we have to forcefully terminate
            if filecounter == len(filelist)-1 and not lcomplete: 
                lcomplete = True # end loop
                lskip = True # don't write results for this month!
      
            if not lskip:
              ## compute monthly averages
              # loop over variables
              for varname in varlist:
                  logger.debug('{0:s} {1:s}'.format(pidstr,varname))
                  if varname not in wrfout.variables:
                      logger.info("{:s} Variable {:s} missing in file '{:s}' - filling with NaN!".format(pidstr,varname,filelist[filecounter]))
                      data[varname] *= np.NaN # turn everything into NaN, if variable is missing  
                      # N.B.: this can happen, when an output stream was reconfigured between cycle steps
                  else:
                      var = wrfout.variables[varname]
                      tax = var.dimensions.index(wrftime) # index of time axis
                      slices = [slice(None)]*len(var.shape) 
                      # construct informative IOError message
                      ioerror = "An Error occcured in file '{:s}'; variable: '{:s}'\n('{:s}')".format(filelist[filecounter], varname, infolder)                  
                      # decide how to average
                      ## Accumulated Variables
                      if varname in acclist: 
                          if missing_value is not None: 
                              raise NotImplementedError("Can't handle accumulated variables with missing values yet.")
                          # compute mean as difference between end points; normalize by time difference
                          if ntime == 0: # first time step of the month
                              slices[tax] = wrfstartidx # relevant time interval
                              try: tmp = var.__getitem__(slices) # get array
                              except: raise IOError(ioerror) # informative IO Error 
                              if acclist[varname] is not None: # add bucket level, if applicable
                                bkt = wrfout.variables[bktpfx+varname]
                                tmp += bkt.__getitem__(slices) * acclist[varname]
                              # check that accumulated fields at the beginning of the simulation are zero  
                              if meanidx == 0 and wrfstartidx == 0:
                                # note  that if we are skipping the first step, there is no check
                                if np.max(tmp) != 0 or np.min(tmp) != 0: 
                                  raise ValueError( 'Accumulated fields were not initialized with zero!\n' +
                                                      '(this can happen, when the first input file is missing)' ) 
                              data[varname] = -1 * tmp # so we can do an in-place operation later 
                          # N.B.: both, begin and end, can be in the same file, hence elif is not appropriate! 
                          if lcomplete: # last step
                              slices[tax] = wrfendidx # relevant time interval
                              try: tmp = var.__getitem__(slices) # get array
                              except: raise IOError(ioerror) # informative IO Error 
                              if acclist[varname] is not None: # add bucket level, if applicable 
                                bkt = wrfout.variables[bktpfx+varname]
                                tmp += bkt.__getitem__(slices) * acclist[varname]   
                              data[varname] +=  tmp # the starting data is already negative
                          # if variable is a prerequisit to others, compute instantaneous values
                          if varname in pqset:
                              # compute mean via sum over all elements; normalize by number of time steps
                              if lsmplDiff: slices[tax] = slice(wrfstartidx,wrfendidx+1) # load longer time interval for diff
                              else: slices[tax] = slice(wrfstartidx,wrfendidx) # relevant time interval
                              try: tmp = var.__getitem__(slices) # get array
                              except: raise IOError(ioerror) # informative IO Error 
                              if acclist[varname] is not None: # add bucket level, if applicable
                                bkt = wrfout.variables[bktpfx+varname]
                                tmp = tmp + bkt.__getitem__(slices) * acclist[varname]
                              if lsmplDiff: pqdata[varname] = np.diff(tmp, axis=tax) # simple differences
                              else: pqdata[varname] = dv.ctrDiff(tmp, axis=tax, delta=1) # normalization comes later                   
      ##    
      ##  ***  daily values for bucket variables are generated here,  ***
      ##  ***  but should we really use *centered* differences???     ***
      ##
                      elif varname[0:len(bktpfx)] == bktpfx:
                          pass # do not process buckets
                      ## Normal Variables
                      else: 
                          # skip "empty" steps (only needed to difference accumulated variables)
                          if wrfendidx > wrfstartidx:
                              # compute mean via sum over all elements; normalize by number of time steps
                              slices[tax] = slice(wrfstartidx,wrfendidx) # relevant time interval
                              try: tmp = var.__getitem__(slices) # get array
                              except: raise IOError(ioerror) # informative IO Error 
                              if missing_value is not None:
                                  # N.B.: missing value handling is really only necessary when missing values are time-dependent
                                  tmp = np.where(tmp == missing_value, np.NaN, tmp) # set missing values to NaN
                                  #tmp = ma.masked_equal(tmp, missing_value, copy=False) # mask missing values
                              data[varname] = data[varname] + tmp.sum(axis=tax) # add to sum
                              # N.B.: in-place operations with non-masked array destroy the mask, hence need to use this
                              # keep data in memory if used in computation of derived variables
                              if varname in pqset: pqdata[varname] = tmp
                
              ## compute derived variables
              # but first generate a list of timestamps
              if lcomplete: tmpendidx = wrfendidx
              else: tmpendidx = wrfendidx -1 # end of file
              # assemble list of time stamps                        
              currenttimestamps = [] # relevant timestamps in this file            
              for i in range(wrfstartidx,tmpendidx+1):
                  timestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][i,:]))  
                  currenttimestamps.append(timestamp)
              monthlytimestamps.extend(currenttimestamps) # add to monthly collection
              # write daily timestamps
              if ldaily:
                  nsteps = wrfendidx - wrfstartidx
                  daily_start_idx = daily_end_idx # from previous step
                  daily_end_idx = daily_start_idx + nsteps
                  # set time values to -1, to inticate they are being worked on
                  daily_dataset.variables[time][daily_start_idx:daily_end_idx] = -1
                  ncvar = None; vardata = None # dummies, to prevent crash later on, if varlist is empty 
                  # copy timestamp and xtime data
                  daily_dataset.variables[wrftimestamp][daily_start_idx:daily_end_idx,:] = wrfout.variables[wrftimestamp][wrfstartidx:wrfendidx,:]
                  if lxtime:
                      daily_dataset.variables[wrfxtime][daily_start_idx:daily_end_idx] = wrfout.variables[wrfxtime][wrfstartidx:wrfendidx]
                  daily_dataset.sync()
              # normalize accumulated pqdata with output interval time
              if wrfendidx > wrfstartidx:
                  assert tmpendidx > wrfstartidx, 'There should never be a single value in a file: wrfstartidx={:d}, wrfendidx={:d}, lcomplete={:s}'.format(wrfstartidx,wrfendidx,str(lcomplete))
                  # compute time delta
                  delta = dv.calcTimeDelta(currenttimestamps)
                  if lxtime:
                    xdelta = wrfout.variables[wrfxtime][tmpendidx] - wrfout.variables[wrfxtime][wrfstartidx]
                    xdelta *=  60. # convert minutes to seconds
                    if delta != xdelta: raise ValueError("Time calculation from time stamps and model time are inconsistent: {:f} != {:f}".format(delta,xdelta))                 
                  delta /=  float(tmpendidx - wrfstartidx) # the average interval between output time steps
                  # loop over time-step data
                  for pqname,pqvar in pqdata.items():
                    if pqname in acclist: pqvar /= delta # normalize
                  # write to daily file
                  if ldaily:
                      # loop over variables and save data arrays
                      for varname in daily_varlist:
                          ncvar = daily_dataset.variables[varname] # destination variable in daily output
                          vardata = pqdata[varname] # timestep data
                          if missing_value is not None: # make sure the missing value flag is preserved
                            vardata = np.where(np.isnan(vardata), missing_value, vardata)
                            ncvar.missing_value = missing_value # just to make sure
                          if ncvar.ndim > 1: ncvar[daily_start_idx:daily_end_idx,:] = vardata # here time is always the outermost index
                          else: ncvar[daily_start_idx:daily_end_idx] = vardata 
                      daily_dataset.sync()         
                  # loop over derived variables
                  # special treatment for certain string variables
                  if 'Times' in pqset: pqdata['Times'] = currenttimestamps[:wrfendidx-wrfstartidx] # need same length as actual time dimension 
                  logger.debug('\n{0:s} Available prerequisites: {1:s}'.format(pidstr, str(list(pqdata.keys()))))
                  for dename,devar in derived_vars.items():
                    if not devar.linear: # only non-linear ones here, linear one at the end
                      logger.debug('{0:s} {1:s} {2:s}'.format(pidstr, dename, str(devar.prerequisites)))
                      tmp = devar.computeValues(pqdata, aggax=tax, delta=delta, const=const, tmp=tmpdata) # possibly needed as pre-requisite  
                      dedata[dename] = devar.aggregateValues(tmp, aggdata=dedata[dename], aggax=tax)
                      # N.B.: in-place operations with non-masked array destroy the mask, hence need to use this
                      if dename in pqset: pqdata[dename] = tmp
                      # save to daily output
                      if ldaily:
                          if dename in daily_derived_vars:
                              ncvar = daily_dataset.variables[dename] # destination variable in daily output
                              vardata = tmp
                              if missing_value is not None: # make sure the missing value flag is preserved
                                vardata = np.where(np.isnan(vardata), missing_value, vardata)
                                ncvar.missing_value = missing_value # just to make sure
                              if ncvar.ndim > 1: ncvar[daily_start_idx:daily_end_idx,:] = vardata # here time is always the outermost index
                              else: ncvar[daily_start_idx:daily_end_idx] = vardata
                      # N.B.: missing values should be handled implicitly, following missing values in pre-requisites            
                      del tmp # memory hygiene
                  if ldaily:
                      # add time in seconds, based on index and time delta
                      daily_dataset.variables[time][daily_start_idx:daily_end_idx] = np.arange(daily_start_idx,daily_end_idx, dtype='i8')*int(delta)
                      daily_dataset.end_date = dv.getTimeStamp(wrfout, wrfendidx-1, wrftimestamp) # update current end date
                      # N.B.: adding the time coordinate and attributes finalized this step
                      # sync data and clear memory
                      daily_dataset.sync(); daily_dataset.close() # sync and close dataset
                      del daily_dataset, ncvar, vardata # remove all other references to data
                      gc.collect() # clean up memory
                      # N.B.: the netCDF4 module keeps all data written to a netcdf file in memory; there is no flush command
                      daily_dataset = nc.Dataset(tmp_daily_filepath, mode='a', format='NETCDF4') # re-open to append more data (mode='a')
                      # N.B.: flushing the mean file here prevents repeated close/re-open when no data was written (i.e. 
                      #       the month was skiped); only flush memory when data was actually written. 
                      
                
              # increment counters
              ntime += wrfendidx - wrfstartidx
              if lcomplete: 
                  # N.B.: now wrfendidx should be a valid time step
                  # check time steps for this month
                  laststamp = monthlytimestamps[0]
                  for timestamp in monthlytimestamps[1:]:
                    if laststamp >= timestamp: 
                      raise DateError('Timestamps not in order, or repetition: {:s}'.format(timestamp))
                    laststamp = timestamp
                  # calculate time period and check against model time (if available)
                  timeperiod = dv.calcTimeDelta(monthlytimestamps)
                  if lxtime:
                    xtime += wrfout.variables[wrfxtime][wrfendidx] # get final time interval (in minutes)
                    xtime *=  60. # convert minutes to seconds   
                    if timeperiod != xtime:  
                      logger.info("Time calculation from time stamps and model time are inconsistent: {:f} != {:f}".format(timeperiod,xtime))            
            # two possible ends: month is done or reached end of file
            # if we reached the end of the file, open a new one and go again
            if not lcomplete:            
                # N.B.: here wrfendidx is not a valid time step, but the length of the file, i.e. wrfendidx-1 is the last valid time step
                lasttimestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][wrfendidx-1,:])) # needed to determine, if first timestep is the same as last
                assert lskip or lasttimestamp == monthlytimestamps[-1]
                # lasttimestep is also used for leap-year detection later on
                assert len(wrfout.dimensions[wrftime]) == wrfendidx, (len(wrfout.dimensions[wrftime]),wrfendidx) # wrfendidx should be the length of the file, not the last index!
                ## find first timestep (compare to last of previous file) and (re-)set time step counter
                # initialize search
                tmptimestamp = lasttimestamp; filelen1 = len(wrfout.dimensions[wrftime]) - 1; wrfstartidx = filelen1;
                while tmptimestamp <= lasttimestamp:
                  if wrfstartidx < filelen1:
                    wrfstartidx += 1 # step forward in current file
                  else:
                    # open next file, if we reach the end
                    wrfout.close() # close file
                    #del wrfout; gc.collect() # doesn't seem to work here - strange error
                    # N.B.: filecounter +1 < len(filelist) is already checked above 
                    filecounter += 1 # move to next file
                    if filecounter < len(filelist):    
                      logger.debug("\n{0:s} Opening input file '{1:s}'.\n".format(pidstr,filelist[filecounter]))
                      wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
                      filelen1 = len(wrfout.dimensions[wrftime]) - 1 # length of new file
                      wrfstartidx = 0 # reset index
                      # check consistency of missing value flag
                      assert missing_value is None or missing_value == wrfout.P_LEV_MISSING
                    else: break # this is not really tested...
                  tmptimestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][wrfstartidx,:]))
                # some checks
                firsttimestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][0,:]))
                error_string = "Inconsistent time-stamps between files:\n lasttimestamp='{:s}', firsttimestamp='{:s}', wrfstartidx={:d}"
                if firsttimestamp == lasttimestamp: # skip the initialization step (was already processed in last step)
                    if wrfstartidx != 1: raise DateError(error_string.format(lasttimestamp, firsttimestamp, wrfstartidx))
                if firsttimestamp > lasttimestamp: # no duplicates: first timestep in next file was not present in previous file
                    if wrfstartidx != 0: raise DateError(error_string.format(lasttimestamp, firsttimestamp, wrfstartidx))
                if firsttimestamp < lasttimestamp: # files overlap: count up to next timestamp in sequence
                    #if wrfstartidx == 2: warn(error_string.format(lasttimestamp, firsttimestamp, wrfstartidx))
                    if wrfstartidx == 0: raise DateError(error_string.format(lasttimestamp, firsttimestamp, wrfstartidx))
            else: # month complete
                # print feedback (the current month) to indicate completion
                if lparallel: progressstr += '{0:s}, '.format(currentdate) # bundle output in parallel mode
                else: logger.info('{0:s},'.format(currentdate)) # serial mode
                # clear temporary storage
                if lcarryover:
                    for devar in list(derived_vars.values()):
                      if not (devar.tmpdata is None or devar.carryover):
                        if devar.tmpdata in tmpdata: del tmpdata[devar.tmpdata]
                else: tmpdata = dict() # reset entire temporary storage
                # N.B.: now wrfendidx is a valid timestep, but indicates the first of the next month
                lasttimestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][wrfendidx,:])) # this should be the first timestep of the next month
                assert lskip or lasttimestamp == monthlytimestamps[-1]                
                # open next file (if end of month and file coincide)
                if wrfendidx == len(wrfout.dimensions[wrftime])-1: # reach end of file
                  ## find first timestep (compare to last of previous file) and (re-)set time step counter
                  # initialize search
                  tmptimestamp = lasttimestamp; filelen1 = len(wrfout.dimensions[wrftime]) - 1; wrfstartidx = filelen1;
                  while tmptimestamp <= lasttimestamp:
                      if wrfstartidx < filelen1:
                          wrfstartidx += 1 # step forward in current file
                      else:
                          # open next file, if we reach the end
                          wrfout.close() # close file
                          #del wrfout; gc.collect() # doesn't seem to work here - strange error
                          # N.B.: filecounter +1 < len(filelist) is already checked above 
                          filecounter += 1 # move to next file
                          if filecounter < len(filelist):    
                              logger.debug("\n{0:s} Opening input file '{1:s}'.\n".format(pidstr,filelist[filecounter]))
                              wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
                              filelen1 = len(wrfout.dimensions[wrftime]) - 1 # length of new file
                              wrfstartidx = 0 # reset index
                              # check consistency of missing value flag
                              assert missing_value is None or missing_value == wrfout.P_LEV_MISSING
                          else: break # this is not really tested...
                      tmptimestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][wrfstartidx,:]))
                  # N.B.: same code as in "not complete" section
      #             wrfout.close() # close file
      #             #del wrfout; gc.collect() # doesn't seem to work here - strange error
      #             filecounter += 1 # move to next file
      #             if filecounter < len(filelist):    
      #               logger.debug("\n{0:s} Opening input file '{1:s}'.\n".format(pidstr,filelist[filecounter]))
      #               wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
      #               firsttimestamp = str(nc.chartostring(wrfout.variables[wrftimestamp][0,:])) # check first timestep (compare to last of previous file)
      #               wrfstartidx = 0 # always use initialization step (but is reset above anyway)
      #               if firsttimestamp != lasttimestamp:
      #                 raise NotImplementedError, "If the first timestep of the next month is the last timestep in the file, it has to be duplicated in the next file."
                    
            
        ## now the the loop over files has terminated and we need to normalize and save the results
        
        if not lskip:
          # extend time axis
          monthly_dataset.variables[time][meanidx] = -1 # mark timestep in progress
          ncvar = None; vardata = None # dummies, to prevent crash later on, if varlist is empty 
          # loop over variable names
          for varname in varlist:
              vardata = data[varname]
              # decide how to normalize
              if varname in acclist: vardata /= timeperiod
              else: vardata /= ntime
              # save variable
              ncvar = monthly_dataset.variables[varname] # this time the destination variable
              if missing_value is not None: # make sure the missing value flag is preserved
                vardata = np.where(np.isnan(vardata), missing_value, vardata)
                ncvar.missing_value = missing_value # just to make sure
              if ncvar.ndim > 1: ncvar[meanidx,:] = vardata # here time is always the outermost index
              else: ncvar[meanidx] = vardata
          # compute derived variables
          #logger.debug('\n{0:s}   Derived Variable Stats: (mean/min/max)'.format(pidstr))
          for dename,devar in derived_vars.items():
              if devar.linear:           
                vardata = devar.computeValues(data) # compute derived variable now from averages
              elif devar.normalize: 
                vardata = dedata[dename] / ntime # no accumulated variables here!
              else: vardata = dedata[dename] # just the data...
              # not all variables are normalized (e.g. extrema)
              #if ldebug:
              #  mmm = (float(np.nanmean(vardata)),float(np.nanmin(vardata)),float(np.nanmax(vardata)),)
              #  logger.debug('{0:s} {1:s}, {2:f}, {3:f}, {4:f}'.format(pidstr,dename,*mmm))
              data[dename] = vardata # add to data array, so that it can be used to compute linear variables
              # save variable
              ncvar = monthly_dataset.variables[dename] # this time the destination variable
              if missing_value is not None: # make sure the missing value flag is preserved
                vardata = np.where(np.isnan(vardata), missing_value, vardata)
                ncvar.missing_value = missing_value # just to make sure
              if ncvar.ndim > 1: ncvar[meanidx,:] = vardata # here time is always the outermost index
              else: ncvar[meanidx] = vardata            
              #raise dv.DerivedVariableError, "%s Derived variable '%s' is not linear."%(pidstr,devar.name) 
          # update current end date   
          monthly_dataset.end_date = str(nc.chartostring(firsttimestamp_chars[:10])) # the date of the first day of the last included month
          monthly_dataset.variables[wrftimestamp][meanidx,:] = firsttimestamp_chars
          monthly_dataset.variables[time][meanidx] = meantime # update time axis (last action)
          # sync data and clear memory
          monthly_dataset.sync(); monthly_dataset.close() # sync and close dataset
          del monthly_dataset, ncvar, vardata # remove all other references to data
          gc.collect() # clean up memory
          # N.B.: the netCDF4 module keeps all data written to a netcdf file in memory; there is no flush command
          monthly_dataset = nc.Dataset(tmp_monthly_filepath, mode='a', format='NETCDF4') # re-open to append more data (mode='a')
          # N.B.: flushing the mean file here prevents repeated close/re-open when no data was written (i.e. 
          #       the month was skiped); only flush memory when data was actually written. 
          
    ec = 0 # set zero exit code for this operation
        
  except Exception:
    
      # report error
      logger.exception('\n # {0:s} WARNING: an Error occured while stepping through files! '.format(pidstr)+
                       '\n # Last State: month={0:d}, variable={1:s}, file={2:s}'.format(meanidx,varname,filelist[filecounter])+
                       '\n # Saving current data and exiting\n')
      wrfout.close()
      #logger.exception(pidstr) # print stack trace of last exception and current process ID
      ec = 1 # set non-zero exit code
      # N.B.: this enables us to still close the file!
    
  ## here the loop over months finishes and we can close the output file 
  # print progress
  
  # save to file
  if not lparallel: logger.info('') # terminate the line (of dates) 
  else: logger.info('\n{0:s} Processed dates: {1:s}'.format(pidstr, progressstr))   
  monthly_dataset.sync()
  logger.info("\n{0:s} Writing monthly output to: {1:s}\n('{2:s}')\n".format(pidstr, monthly_file, monthly_filepath))
  if ldaily: 
      daily_dataset.sync()
      logger.info("\n{0:s} Writing (sub-)daily output to: {1:s}\n('{2:s}')\n".format(pidstr, daily_file, daily_filepath))
      
  # Finalize: close files and rename to proper names, clean up
  monthly_dataset.close() # close NetCDF file     
  os.rename(tmp_monthly_filepath,monthly_filepath) # rename file to proper name    
  del monthly_dataset, data # clean up memory
  if ldaily:  
      daily_dataset.close() # close NetCDF file
      os.rename(tmp_daily_filepath,daily_filepath) # rename file to proper name    
      del daily_dataset # clean up memory  
  gc.collect()
  # return exit code
  return ec


## now begin execution    
if __name__ == '__main__':


  # print settings
  print('')
  print(('OVERWRITE: {:s}, RECOVER: {:s}, CARRYOVER: {:s}, SMPLDIFF: {:s}'.format(
        str(loverwrite), str(lrecover), str(lcarryover), str(lsmplDiff))))
  print(('DERIVEDONLY: {:s}, ADDNEW: {:s}, RECALC: {:s}'.format(
        str(lderivedonly), str(laddnew), str(recalcvars) if lrecalc else str(lrecalc))))
  print(('DAILY: {:s}, FILETYPES: {:s}, DOMAINS: {:s}'.format(str(lglobaldaily),str(filetypes),str(domains))))
  print(('THREADS: {:s}, DEBUG: {:s}'.format(str(NP),str(ldebug))))
  print('')
  # compile regular expression, used to infer start and end dates and month (later, during computation)
  datestr = '{0:s}-{1:s}-{2:s}'.format(yearstr,monthstr,daystr)
  datergx = re.compile(datestr)
    
  # get file list
  wrfrgx = re.compile(inputpattern.format('.*','\d\d',datestr,)) # for initial search (all filetypes)
  # regular expression to match the name pattern of WRF timestep output files
  masterlist = [wrfrgx.match(filename) for filename in os.listdir(infolder)] # list folder and match
  masterlist = [match.group() for match in masterlist if match is not None] # assemble valid file list
  if len(masterlist) == 0: 
      raise IOError('No matching WRF output files found for date: {0:s}'.format(datestr))
  
  ## loop over filetypes and domains to construct job list
  args = []
  for filetype in filetypes:    
    # make list of files
    filelist = []
    for domain in domains:
      typergx = re.compile(inputpattern.format(filetype,"{:02d}".format(domain), datestr))
      # N.B.: domain has to be inserted as string, because above it is replaced by a regex
      # regular expression to also match type and domain index
      filelist = [typergx.match(filename) for filename in masterlist] # list folder and match
      filelist = [match.group() for match in filelist if match is not None] # assemble valid file list
      filelist.sort() # now, when the list is shortest, we can sort...
      # N.B.: sort alphabetically, so that files are in temporally sequence
      # now put everything into the lists
      if len(filelist) > 0:
        args.append( (filelist, filetype, domain) )
      else:          
        print(("Can not process filetype '{:s}' (domain {:d}): no source files.".format(filetype,domain)))
  print('\n')
    
  # call parallel execution function
  kwargs = dict() # no keyword arguments
  ec = asyncPoolEC(processFileList, args, kwargs, NP=NP, ldebug=ldebug, ltrialnerror=True)
  # exit with number of failures plus 10 as exit code
  exit(int(10+ec) if ec > 0 else 0)
