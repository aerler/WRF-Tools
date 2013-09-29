'''
Created on 2012-11-10

@author: Andre R. Erler
'''

## imports
import numpy as np
import os, re, sys
import netCDF4 as nc
# my own netcdf stuff
from geodata.nctools import add_coord, copy_dims, copy_ncatts, copy_vars

# date error class
class DateError(Exception):
  ''' Exceptions related to wrfout dats strings, e.g. in file names. '''
  pass


# data root folder
from socket import gethostname
hostname = gethostname()
if hostname=='komputer':
  WRFroot = '/media/data/DATA/WRF/Downscaling/'
  exp = ''
  folder = WRFroot + exp + '/'
elif hostname[0:3] == 'gpc': # i.e. on scinet...
  exproot = os.getcwd()
  exp = exproot.split('/')[-1] # root folder name
  folder = exproot + '/wrfout/' # output folder 
else:
  folder = os.getcwd() # just operate in the current directory
  exp = '' # need to define experiment name...

## read arguments
if len(sys.argv) > 1:
  period = sys.argv[1].split('-') # regular expression identifying 
else: 
  period = [] # means recompute everything
# figure out time interval
yearstr = period[0] if len(period) >= 1 else '\d\d\d\d'
monthstr = period[1] if len(period) >= 2 else '\d\d'
daystr = period[2] if len(period) >= 3 else '\d\d'
# N.B.: the timestr variables are interpreted as strings and support Python regex syntax


## definitions
liniout = True # indicates that the initialization/restart timestep is written to wrfout;
# this means that the last timestep of the previous file is the same as the first of the next 
# input files and folders
filetypes = ['srfc', 'plev3d', 'xtrm', 'hydro']
inputpattern = 'wrf%s_d%02i_%s-%s-%s_\d\d:\d\d:\d\d.nc' # expanded with %(type,domain,year,month) 
outputpattern = 'wrf%s_d%02i_monthly.nc' # expanded with %(type,domain)
# variable attributes
wrftime = 'Time' # time dim inwrfout files
time = 'time' # time dim in monthly mean files
dimlist = ['west_east', 'south_north'] # dimensions we just copy
dimmap = {wrftime:time, 'west_east':'x','south_north':'y'}
acclist = dict(RAINNC=100,RAINC=100,RAINSH=None,SNOWNC=None,GRAUPELNC=None) # dictionary of accumulated variables
# N.B.: keys = variables and values = bucket sizes; value = None or 0 means no bucket  
bktpfx = 'I_' # prefix for bucket variables 
# time constants
months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
          'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
days = np.array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]) # no leap year
mons = np.arange(1,13); nmons = len(mons)

if __name__ == '__main__':
  
  # compile regular expression, used to infer start and end dates and month (later, during computation)
  datestr = '%s-%s-%s'%(yearstr,monthstr,daystr)
  datergx = re.compile(datestr)
    
  # get file list
  wrfrgx = re.compile('wrf.*_d\d\d_%s_\d\d:\d\d:\d\d.nc'%(datestr,))
  # regular expression to match the name pattern of WRF timestep output files
  masterlist = [wrfrgx.match(filename) for filename in os.listdir(folder)] # list folder and match
  masterlist = [match.group() for match in masterlist if match is not None] # assemble valid file list
  if len(masterlist) == 0: raise IOError, 'No matching WRF output files found.'
#   datergx = re.compile(prdrgx) # compile regular expression, also used to infer month (later)
#   begindate = datergx.search(filelist[0]).group()
#   enddate = datergx.search(filelist[-1]).group()
  
  # loop over filetypes
  for filetype in filetypes:
    
    # make list of files
    typelist = []; filelist = []; ndom = 0
    while len(filelist)>0 or ndom == 0:
      ndom += 1
      typergx = re.compile('wrf%s_d%02i_%s_\d\d:\d\d:\d\d.nc'%(filetype, ndom, datestr))
      # regular expression to also match type and domain index
      filelist = [typergx.match(filename) for filename in masterlist] # list folder and match
      filelist = [match.group() for match in typelist if match is not None] # assemble valid file list
      filelist.sort() # now, when the list is shortest, we can sort...
      # N.B.: sort alphabetically, so that files are in temporally sequence
      typelist.append(filelist)
    maxdom = ndom -1 # the last one was always not successful!       
    
    # loop over domains  
    for filelist,ndom in zip(typelist,xrange(1,maxdom+1)): 
      
      # announcement
      print('\n\n   ***   Processing Domain #%02i (of %02i)   ***   '%(ndom,maxdom))
      begindate = datergx.search(filelist[0]).group()
      beginyear, beginmonth, beginday = [int(tmp) for tmp in begindate.split('-')]
      enddate = datergx.search(filelist[-1]).group()
      endyear, endmonth, endday = [int(tmp) for tmp in enddate.split('-')]    
    
      ## setup files and folders
      
      # load first file to copy some meta data
      wrfout = nc.Dataset(folder+filelist[0], 'r', format='NETCDF4')
      # timeless variables            
      timeless = [varname for varname,var in wrfout.variables.iteritems()if 'Time' not in var.dimensions]
      # time-dependent variables            
      varlist = [varname for varname,var in wrfout.variables.iteritems() if 'Time' in var.dimensions]
      
      # open/create monthly mean output file
      meanfile = folder+outputpattern%(filetype,ndom)
      if os.path.exists(meanfile):
        mean = nc.Dataset(meanfile, 'rw', format='NETCDF4')
        t0 = len(mean.dimensions['time']) + 1 # get time index where we start; in month beginning 1979         
      else:        
        mean = nc.Dataset(meanfile, 'w', format='NETCDF4')
        t0 = 1 # time index where we start: first month in 1979
        mean.createDimension('time', size=None) # make time dimension unlimited
        add_coord(mean, 'time', values=None, dtype='i4', atts=dict(units='month since '+begindate)) # unlimited time dimension
        # copy remaining dimensions to new datasets
        copy_dims(mean, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
        # copy time-less variable to new datasets        
        copy_vars(mean, wrfout, varlist=timeless, dimmap=dimmap, copy_data=True) # copy data
        # create time-dependent variable in new datasets
        copy_vars(mean, wrfout, varlist=varlist, dimmap=dimmap, copy_data=False) # do nto copy data - need to average  
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
      times = np.arange(t0,t0+(endyear-beginyear)*12+endmonth-beginmonth)
      mean.variables['time'][t0-1:t0-1+len(times)] = times # extend time array 
      # update current end date
      mean.end_date = enddate
         
      # allocate fields
      data = dict() # temporary data arrays
      for var in varlist:        
        tmpshape = list(wrfout.variables[var].shape)
        del tmpshape[wrfout.variables[var].dimensions.index(wrftime)] # allocated arrays have no time dimension
        assert len(tmpshape) ==  len(wrfout.variables[var].shape) -1
        data[var] = np.zeros(tmpshape) # allocate

          
      ## compute monthly means
      print('\n   ***   Processing wrf%s files for domain %2i.   ***   '%(filetype,ndom))
      print('        (monthly means from %s to %s, incl.)'%(begindate,enddate))
      
      # loop over month and progressively step through input files
      filecounter = 0 # number of wrfout file currently processed 
      wrfstartidx = 0 # output record / time step in current file
      i0 = t0-2 # index position we write to: i = i0 + n
      
      # start loop over month
      for n in xrange(1,len(times)+1):
        meanidx = i0 + n
        # current date
        currentyear = int(n/12)+beginyear 
        currentmonth = n%12+beginmonth
        # sanity checks
        assert meanidx + 1 == mean.variables['time'][meanidx]  
        currentdate = '%04i-%02i'%(currentyear,currentmonth)
        print('\n %s: '%currentdate)
        if '%s-01_00:00:00'%(currentdate,) != str().join(wrfout.variables['Times'][wrfstartidx,:]):
          raise DateError, "Did not find first day of month to compute monthly average."
        
        # prepare summation of output time steps
        lincomplete = True # 
        ntime = 0 # accumulated output time steps/
        xtime = -1 * wrfout.variables['XTIME'][wrfstartidx] # time when accumulation starts (in minutes)
        # N.B.: the first value is saved as negative, so that adding the last value yields a positive interval
        # clear temporary arrays
        for var in varlist:
          data[var] = np.zeros(data[var].shape) # clear/allocate
        
        ## loop over files and average
        while lincomplete:
          
          # determine valid time index range
          wrfendidx = len(wrfout.dimensions[wrftime])-1
          while currentdate < str().join(wrfout.variables['Times'][wrfendidx,0:7]):
            if lincomplete: lincomplete = False # break loop over file if next month is in this file        
            wrfendidx -= 1 # count backwards
          wrfendidx +=1 # reverse last step so that counter sits at fist step of next month 
          assert wrfendidx > wrfstartidx
          
          # compute monthly averages
          for varname in varlist:
            var = wrfout.variables[varname]
            tax = var.dimensions.index(wrftime) # index of time axis
            slices = [slice(None)]*len(var.shape) 
            # decide how to average
            if varname in acclist: # accumulated variables
              # compute mean as difference between end points; normalize by time difference
              if ntime == 0: # first time step of the month
                slices[tax] = wrfstartidx # relevant time interval
                tmp = var.__getitem__(*slices)
                if acclist[varname] != 0: # add bucket level, if applicable
                  bkt = wrfout.variables[bktpfx+varname]
                  tmp += bkt.__getitem__(*slices) * acclist[varname]   
                data[varname] = -1 * tmp # so we can do an in-place operation later  
              elif lincomplete == False: # last step
                slices[tax] = wrfendidx # relevant time interval
                tmp = var.__getitem__(*slices)
                if acclist[varname] != 0: # add bucket level, if applicable 
                  bkt = wrfout.variables[bktpfx+varname]
                  tmp += bkt.__getitem__(*slices) * acclist[varname]   
                data[varname] +=  tmp # the starting data is already negative
            else: # normal variables
              # compute mean via sum over all elements; normalize by number of time steps
              slices[tax] = slice(wrfstartidx,wrfendidx) # relevant time interval
              data[varname] += var.__getitem__(*slices).sum(axis=tax)
          # increment counters
          ntime += wrfendidx - wrfstartidx
          if lincomplete == False: 
            xtime += wrfout.variables['XTIME'][wrfstartidx] # get final time interval (in minutes)
            xtime *=  60. # convert minutes to seconds   
               
          # two ways to leave: month is done or reached end of file
          # if we reached the end of the file, open a new one and go again
          if lincomplete:            
            wrfout.close() # close file...
            filecounter += 1 # move to next file            
            wrfout = nc.Dataset(folder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
            # reset output record / time step counter
            if liniout: wrfstartidx = 1 # skip the initialization step (same as last step in previous file)
            else: wrfstartidx = 0
          elif liniout and wrfendidx == len(wrfout.dimensions[wrftime])-1:
            wrfout.close() # close file...
            filecounter += 1 # move to next file            
            wrfout = nc.Dataset(folder+filelist[filecounter], 'r', format='NETCDF4') # ... and open new one
            wrfstartidx = 0 # use initialization step (same as last step in previous file)
            
             
            
        ## now the loop over files terminated and we need to normalize and save the results
        
        # loop over variable names
        for var in varlist:
          # decide how to normalize
          if var in acclist: data[var] /= xtime 
          else: data[var] /= ntime
          # save variable
          mean.variables[var][meanidx,:] = data[var] # here time is always the outermost index
        # sync data
        mean.sync()
      
      ## here the loop over months finishes and we can close the output file 
      # save to files
      mean.sync()
      print(' Done. Writing output to: %s\n(%s)'%(meanfile,folder))
      # close files      
      mean.close()
