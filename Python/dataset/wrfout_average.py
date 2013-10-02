'''
Created on 2013-09-28

A script to average WRF output; the default settings are meant for my 'fineIO' output configuration and 
process the smaller diagnostic files.
The script can run in parallel mode, with each process averaging one filetype and domain, producing 
exactly one output file.  

@author: Andre R. Erler
'''

## imports
import numpy as np
import os, re, sys
import netCDF4 as nc
from datetime import datetime
import calendar
import multiprocessing # parallelization
# my own netcdf stuff
from geodata.nctools import add_coord, copy_dims, copy_ncatts, copy_vars
# N.B.: importing from datasets.common causes problems with GDAL, if it is not installed
# days per month without leap days (duplicate from datasets.common) 
days_per_month_365 = np.array([31,28,31,30,31,30,31,31,30,31,30,31])
# import module providing derived variable classes
import derived_variables as dv

# date error class
class DateError(Exception):
  ''' Exceptions related to wrfout date strings, e.g. in file names. '''
  pass
# date error class
class ArgumentError(Exception):
  ''' Exceptions related to arguments passed to the script. '''
  pass

# data root folder
from socket import gethostname
hostname = gethostname()
if hostname=='komputer':
  WRFroot = '/home/DATA/DATA/WRF/test/'
  exp = 'test'
  infolder = WRFroot + '/wrfout/'
  outfolder = WRFroot + '/wrfavg/'
elif hostname[0:3] == 'gpc': # i.e. on scinet...
  exproot = os.getcwd()
  exp = exproot.split('/')[-1] # root folder name
  infolder = exproot + '/wrfout/' # input folder 
  outfolder = exproot + '/wrfavg/' # output folder
else:
  infolder = os.getcwd() # just operate in the current directory
  outfolder = infolder
  exp = '' # need to define experiment name...
  
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
  elif period == '2090-2094': prdrgx = '209[0-4]' # 5 year future period
  else: prdrgx = None
  return prdrgx 

## read arguments
# number of processes NP 
if os.environ.has_key('PYAVG_THREADS'): 
  NP = int(os.environ['PYAVG_THREADS'])
else: NP = None
# figure out time period
if len(sys.argv) == 1:
  period = [] # means recompute everything
elif len(sys.argv) == 2:
  period = sys.argv[1].split('-') # regular expression identifying 
else: raise ArgumentError
# default time intervals
yearstr = '\d\d\d\d'; monthstr = '\d\d'; daystr = '\d\d'  
# figure out time interval
if len(period) >= 1:
  if len(period[0]) != 4: raise ArgumentError
  yearstr = period[0] 
if len(period) >= 2:
  if len(period[1]) == 4:
    try: 
      tmp = int(period[1])
      yearstr = getDateRegX(sys.argv[1])
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
liniout = True # indicates that the initialization/restart timestep is written to wrfout;
# this means that the last timestep of the previous file is the same as the first of the next 
# input files and folders
# filetypes = ['hydro'] # for testing 
filetypes = ['srfc', 'plev3d', 'xtrm', 'hydro']
inputpattern = 'wrf%s_d%02i_%s-%s-%s_\d\d:\d\d:\d\d.nc' # expanded with %(type,domain,year,month) 
outputpattern = 'wrf%s_d%02i_monthly.nc' # expanded with %(type,domain)
# variable attributes
wrftime = 'Time' # time dim in wrfout files
wrfxtime = 'XTIME' # time in minutes since WRF simulation start
wrftimestamp = 'Times' # time-stamp variable in WRF
time = 'time' # time dim in monthly mean files
dimlist = ['x','y'] # dimensions we just copy
dimmap = {time:wrftime, 'x':'west_east','y':'south_north'}
midmap = dict(zip(dimmap.values(),dimmap.keys())) # reverse dimmap
# accumulated variables (only total accumulation since simulation start, not, e.g., daily accumulated)
acclist = dict(RAINNC=100,RAINC=100,RAINSH=None,SNOWNC=None,GRAUPELNC=None,SFCEVP=None,POTEVP=None,ACSNOM=None) 
# N.B.: keys = variables and values = bucket sizes; value = None or 0 means no bucket  
bktpfx = 'I_' # prefix for bucket variables; these are processed together with their accumulated variables 

# derived variables
derived_variables = {filetype:[] for filetype in filetypes} # derived variable lists by file type
derived_variables['hydro'] = [dv.Rain()]
derived_variables['srfc'] = [dv.Rain()]

## main work function
# N.B.: the loop iterations should be entirely independent, so that they can be run in parallel
def processFileList(pid, filelist, filetype, ndom):
  ''' This function is doing the main work, and is supposed to be run in a multiprocessing environment. '''  
  
  ## setup files and folders
  
  # derived variable list
  derived_vars = derived_variables[filetype]
  
  # load first file to copy some meta data
  wrfout = nc.Dataset(infolder+filelist[0], 'r', format='NETCDF4')
  # timeless variables (should be empty, since all timeless variables should be in constant files!)        
  timeless = [varname for varname,var in wrfout.variables.iteritems() if 'Time' not in var.dimensions]
  assert len(timeless) == 0
  # time-dependent variables            
  varlist = [varname for varname,var in wrfout.variables.iteritems() if 'Time' in var.dimensions \
             and np.issubdtype(var.dtype, np.number) and not varname[0:len(bktpfx)] == bktpfx]
  
  # announcement
  pidstr = '' if pid < 0 else  '[proc%02i]'%pid # pid for parallel mode output
  begindate = datergx.search(filelist[0]).group()
  beginyear, beginmonth, beginday = [int(tmp) for tmp in begindate.split('-')]
  assert beginday == 1, 'always have to begin on the first of a month'
  enddate = datergx.search(filelist[-1]).group()
  endyear, endmonth, endday = [int(tmp) for tmp in enddate.split('-')]
  assert 1 <= endday <= 31 # this is kinda trivial...  
  varstr = ''; devarstr = '' # make variable list, also for derived variables
  for var in varlist: varstr += '%s, '%var
  for devar in derived_vars: devarstr += '%s, '%devar.name
      
  # print meta info (print everything in one chunk, so output from different processes does not get mangled)
  print('\n\n%s    ***   Processing wrf%s files for domain %2i.   ***'%(pidstr,filetype,ndom) +
        '\n          (monthly means from %s to %s, incl.)'%(begindate,enddate) +
        '\n Variable list: %s\n Derived variables: %s'%(varstr,devarstr))
  
  # open/create monthly mean output file
  filename = outputpattern%(filetype,ndom)   
  meanfile = outfolder+filename
  #os.remove(meanfile)
  if os.path.exists(meanfile):
    mean = nc.Dataset(meanfile, mode='a', format='NETCDF4') # open to append data (mode='a')
    t0 = len(mean.dimensions[time]) + 1 # get time index where we start; in month beginning 1979
    # check time-stamps in old datasets
    if mean.end_date >= begindate: 
      raise DateError, "%s Begindate %s comes before enddate %s in file %s"%(pidstr,begindate,enddate,filename)
    # check derived variables
    for var in derived_vars:
      if var.name not in mean.variables: 
        raise dv.DerivedVariableError, "%s Derived variable '%s' not found in file '%s'"%(pidstr,var.name,filename)
      var.checkPrerequisites(mean)
  else:        
    mean = nc.Dataset(meanfile, 'w', format='NETCDF4') # open to start a new file (mode='w')
    t0 = 1 # time index where we start: first month in 1979
    mean.createDimension(time, size=None) # make time dimension unlimited
    add_coord(mean, time, data=None, dtype='i4', atts=dict(units='month since '+begindate)) # unlimited time dimension
    # copy remaining dimensions to new datasets
    dimlist = [midmap.get(dim,dim) for dim in wrfout.dimensions.keys() if dim != wrftime]
    copy_dims(mean, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
    # copy time-less variable to new datasets
    copy_vars(mean, wrfout, varlist=timeless, dimmap=dimmap, copy_data=True) # copy data
    # create time-dependent variable in new datasets
    copy_vars(mean, wrfout, varlist=varlist, dimmap=dimmap, copy_data=False) # do nto copy data - need to average
    # also create variable for time-stamps in new datasets
    if wrftimestamp in wrfout.variables:
      copy_vars(mean, wrfout, varlist=[wrftimestamp], dimmap=dimmap, copy_data=False) # do nto copy data - need to average
    # create derived variables
    for var in derived_vars: 
      var.checkPrerequisites(mean)
      var.createVariable(mean)            
    # copy global attributes
    copy_ncatts(mean, wrfout, prefix='') # copy all attributes (no need for prefix; all upper case are original)
    # some new attributes
    mean.description = 'wrf%s_d%02i monthly means'%(filetype,ndom)
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
  mean.end_date = enddate
  # handling of time intervals for accumulated variables
  if wrfxtime in wrfout.variables: 
    lxtime = True # simply compute differences from XTIME (assuming minutes)
    assert wrfout.variables[wrfxtime].description == "minutes since simulation start"
  elif wrftimestamp in wrfout.variables: 
    lxtime = False # interpret timestamp in Times using datetime module
  else: raise TypeError
      
  # allocate fields
  data = dict() # temporary data arrays
  for var in varlist:        
    tmpshape = list(wrfout.variables[var].shape)
    del tmpshape[wrfout.variables[var].dimensions.index(wrftime)] # allocated arrays have no time dimension
    assert len(tmpshape) ==  len(wrfout.variables[var].shape) -1
    data[var] = np.zeros(tmpshape) # allocate

      
  # prepare computation of monthly means  
  filecounter = 0 # number of wrfout file currently processed 
  wrfstartidx = 0 # output record / time step in current file
  i0 = t0-1 # index position we write to: i = i0 + n
  ## start loop over month
  if pid < 0: print('\n Processed dates:'),
  else: progressstr = '' # a string printing the processed dates
  # loop over month and progressively step through input files
  for n,t in enumerate(times):
    # extend time array / month counter
    meanidx = i0 + n
    mean.variables[time][meanidx] = t # month since simulation start 
    # save WRF time-stamp for beginning of month straight to the new file, for record
    mean.variables[wrftimestamp][meanidx,:] = wrfout.variables[wrftimestamp][wrfstartidx,:] 
    # current date
    currentyear, currentmonth = divmod(n+beginmonth-1,12)
    currentyear += beginyear; currentmonth +=1 
    # sanity checks
    assert meanidx + 1 == mean.variables[time][meanidx]  
    currentdate = '%04i-%02i'%(currentyear,currentmonth)
    # print feedback (the current month)
    if pid < 0: print('%s,'%currentdate), # serial mode
    else: progressstr += '%s, '%currentdate # bundle output in parallel mode
    #print '%s-01_00:00:00'%(currentdate,),str().join(wrfout.variables[wrftimestamp][wrfstartidx,:])
    if '%s-01_00:00:00'%(currentdate,) != str().join(wrfout.variables[wrftimestamp][wrfstartidx,:]):
      raise DateError, ("%s Did not find first day of month to compute monthly average." +
                        "file: %s date: %s-01_00:00:00"%(pidstr,filename,currentdate))
    
    # prepare summation of output time steps
    lincomplete = True # 
    ntime = 0 # accumulated output time steps
    # time when accumulation starts (in minutes)        
    # N.B.: the first value is saved as negative, so that adding the last value yields a positive interval
    if lxtime: xtime = -1 * wrfout.variables[wrfxtime][wrfstartidx] # seconds
    else: xtime = str().join(wrfout.variables[wrftimestamp][wrfstartidx,:]) # datestring of format '%Y-%m-%d_%H:%M:%S'
    # clear temporary arrays
    for var in varlist:
      data[var] = np.zeros(data[var].shape) # clear/allocate
    
    ## loop over files and average
    while lincomplete:
      
      # determine valid time index range
      wrfendidx = len(wrfout.dimensions[wrftime])-1
      while currentdate < str().join(wrfout.variables[wrftimestamp][wrfendidx,0:7]):
        if lincomplete: lincomplete = False # break loop over file if next month is in this file        
        wrfendidx -= 1 # count backwards
      wrfendidx +=1 # reverse last step so that counter sits at fist step of next month 
      assert wrfendidx > wrfstartidx
      
      # compute monthly averages
      for varname in varlist:
        #print(varname+', '),
        var = wrfout.variables[varname]
        tax = var.dimensions.index(wrftime) # index of time axis
        slices = [slice(None)]*len(var.shape) 
        # decide how to average
        if varname in acclist: # accumulated variables
          # compute mean as difference between end points; normalize by time difference
          if ntime == 0: # first time step of the month
            slices[tax] = wrfstartidx # relevant time interval
            tmp = var.__getitem__(slices)
            if acclist[varname] is not None: # add bucket level, if applicable
              bkt = wrfout.variables[bktpfx+varname]
              tmp += bkt.__getitem__(slices) * acclist[varname]   
            data[varname] = -1 * tmp # so we can do an in-place operation later 
          # N.B.: both, begin and end, can be in the same file, hence elif is not appropriate! 
          if lincomplete == False: # last step
            slices[tax] = wrfendidx # relevant time interval
            tmp = var.__getitem__(slices)
            if acclist[varname] is not None: # add bucket level, if applicable 
              bkt = wrfout.variables[bktpfx+varname]
              tmp += bkt.__getitem__(slices) * acclist[varname]   
            data[varname] +=  tmp # the starting data is already negative
        elif varname[0:len(bktpfx)] == bktpfx: pass # do not process buckets
        else: # normal variables
          # compute mean via sum over all elements; normalize by number of time steps
          slices[tax] = slice(wrfstartidx,wrfendidx) # relevant time interval
          data[varname] += var.__getitem__(slices).sum(axis=tax)
      # increment counters
      ntime += wrfendidx - wrfstartidx
      if lincomplete == False: 
        if lxtime:
          xtime += wrfout.variables[wrfxtime][wrfendidx] # get final time interval (in minutes)
          xtime *=  60. # convert minutes to seconds   
        else: 
          dt1 = datetime.strptime(xtime, '%Y-%m-%d_%H:%M:%S')
          dt2 = datetime.strptime(str().join(wrfout.variables[wrftimestamp][wrfendidx,:]), '%Y-%m-%d_%H:%M:%S')
          xtime = (dt2-dt1).total_seconds() # the difference creates a timedelta object
          # N.B.: the datetime module always includes leapdays; the code below is to remove leap days
          #       in order to correctly handle model calendars that don't have leap days
          yyyy, mm, dd = str().join(wrfout.variables[wrftimestamp][wrfendidx-1,0:10]).split('-')
          # also a bit of sanity checking...
          assert yyyy == '%04i'%currentyear and mm == '%02i'%currentmonth
          if calendar.isleap(currentyear) and currentmonth==2:
            if dd == '28':
              xtime -= 86400. # subtract leap day for calendars without leap day
              print('\n%s Correcting time interval for %s: current calendar does not have leap-days.'%(pidstr,currentdate))
            else: assert dd == '29' # if there is a leap day
          else: assert dd == '%02i'%days_per_month_365[currentmonth-1] # if there is no leap day
           
      # two ways to leave: month is done or reached end of file
      # if we reached the end of the file, open a new one and go again
      if lincomplete:            
        wrfout.close() # close file...
        filecounter += 1 # move to next file            
        wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
        # reset output record / time step counter
        if liniout: wrfstartidx = 1 # skip the initialization step (same as last step in previous file)
        else: wrfstartidx = 0
      elif liniout and wrfendidx == len(wrfout.dimensions[wrftime])-1:
        wrfout.close() # close file...
        filecounter += 1 # move to next file    
        if filecounter < len(filelist):        
          wrfout = nc.Dataset(infolder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
          wrfstartidx = 0 # use initialization step (same as last step in previous file)
                       
        
    ## now the loop over files terminated and we need to normalize and save the results
    
    # loop over variable names
    for varname in varlist:
      # decide how to normalize
      if varname in acclist: data[varname] /= xtime 
      else: data[varname] /= ntime
      # save variable
      var = mean.variables[varname] # this time the destination variable
      if var.ndim > 1: var[meanidx,:] = data[varname] # here time is always the outermost index
      else: var[meanidx] = data[varname]
    # compute derived variables
    for devar in derived_vars:
      if not devar.linear: 
        raise dv.DerivedVariableError, "%s Derived variable '%s' is not linear."%(pidstr,devar.name) 
      # save variable
      ncvar = mean.variables[devar.name] # this time the destination variable
      if ncvar.ndim > 1: ncvar[meanidx,:] = devar.computeValues(data) # here time is always the outermost index
      else: ncvar[meanidx] = devar.computeValues(data)            
    # sync data
    mean.sync()
  
  ## here the loop over months finishes and we can close the output file 
  # print progress
  
  # save to file
  if pid < 0: print('') # terminate the line (of dates) 
  else: print('\n%s Processed dates: %s'%(pidstr, progressstr))   
  mean.sync()
  print('\n%s Writing output to: %s\n(%s)\n'%(pidstr, filename, meanfile))
  # close files        
  mean.close()  

# now begin execution    
if __name__ == '__main__':
  
  # compile regular expression, used to infer start and end dates and month (later, during computation)
  datestr = '%s-%s-%s'%(yearstr,monthstr,daystr)
  datergx = re.compile(datestr)
    
  # get file list
  wrfrgx = re.compile('wrf.*_d\d\d_%s_\d\d:\d\d:\d\d.nc'%(datestr,))
  # regular expression to match the name pattern of WRF timestep output files
  masterlist = [wrfrgx.match(filename) for filename in os.listdir(infolder)] # list folder and match
  masterlist = [match.group() for match in masterlist if match is not None] # assemble valid file list
  if len(masterlist) == 0: raise IOError, 'No matching WRF output files found for date: %s'%datestr
  
  ## loop over filetypes and domains to construct job list
  joblist = []; typelist = []; domlist = []
  for filetype in filetypes:    
    # make list of files
    filelist = []; ndom = 0
    while len(filelist)>0 or ndom == 0:
      ndom += 1
      typergx = re.compile('wrf%s_d%02i_%s_\d\d:\d\d:\d\d.nc'%(filetype, ndom, datestr))
      # regular expression to also match type and domain index
      filelist = [typergx.match(filename) for filename in masterlist] # list folder and match
      filelist = [match.group() for match in filelist if match is not None] # assemble valid file list
      filelist.sort() # now, when the list is shortest, we can sort...
      # N.B.: sort alphabetically, so that files are in temporally sequence
      # now put everything into the lists
      if len(filelist) > 0:
        joblist.append(filelist)
        typelist.append(filetype)
        domlist.append(ndom)
    
    
  ## loop over and process all job sets
  if NP is not None and NP == 1:
    # don't parallelize, if there is only one process: just loop over files    
    for filelist,filetype,ndom in zip(joblist, typelist, domlist):
      processFileList(-1, filelist, filetype, ndom) # negative pid means serial mode    
  else:
    if NP is None: pool = multiprocessing.Pool() 
    else: pool = multiprocessing.Pool(processes=NP)
    # distribute tasks to workers
    for pid,filelist,filetype,ndom in zip(xrange(len(joblist)), joblist, typelist, domlist):
      pool.apply_async(processFileList, (pid, filelist, filetype, ndom))
    pool.close()
    pool.join()
  print('')
