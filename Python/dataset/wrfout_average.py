'''
Created on 2012-11-10

@author: Andre R. Erler
'''

## imports
from numpy import array, arange, zeros, diff
import os, re, sys
# netcdf stuff
from netcdf4 import Dataset, MFDataset
from geodata.nctools import add_coord, copy_dims, copy_ncatts, copy_vars

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
# input files and folders
filetypes = ['srfc', 'plev3d', 'xtrm', 'hydro']
inputpattern = 'wrf%s_d%02i_%s-%s-%s_\d\d:\d\d:\d\d.nc' # expanded with %(type,domain,year,month) 
outputpattern = 'wrf%s_d%02i_monthly.nc' # expanded with %(type,domain)
# variable attributes
dimlist = ['Time', 'west_east', 'south_north']
acclist = dict(RAINNC=100,RAINC=100,RAINSH=None,SNOWNC=None,GRAUPELNC=None) # dictionary of accumulated variables
# N.B.: keys = variables and values = bucket sizes; value = None or 0 means no bucket  
bktpfx = 'I_' # prefix for bucket variables 
# time constants
months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
          'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
days = array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]) # no leap year
mons = arange(1,13); nmons = len(mons)

if __name__ == '__main__':
  
  # compile regular expression, used to infer start and end dates and month (later, during computation)
  datergx = re.compile('%s-%s-%s'%(yearstr,monthstr,daystr))
    
  # get file list
  wrfrgx = re.compile('wrf.*_d\d\d_%s-%s-%s_\d\d:\d\d:\d\d.nc'%(yearstr,monthstr,daystr))
  # regular expression to match the name pattern of WRF timestep output files
  masterlist = [wrfrgx.match(filename) for filename in os.listdir(folder)] # list folder and match
  masterlist = [match.group() for match in masterlist if match is not None] # assemble valid file list
  if len(masterlist) == 0: raise IOError, 'no matching wrf output files found'
#   datergx = re.compile(prdrgx) # compile regular expression, also used to infer month (later)
#   begindate = datergx.search(filelist[0]).group()
#   enddate = datergx.search(filelist[-1]).group()
  
  # loop over filetypes
  for filetype in filetypes:
    
    # make list of files
    typelist = []; filelist = []; ndom = 0
    while len(filelist)>0 or ndom == 0:
      ndom += 1
      typergx = re.compile('wrf%s_d%02i_%s-%s-%s_\d\d:\d\d:\d\d.nc'%(filetype, ndom, yearstr,monthstr,daystr))
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
    
      ## setup files and folders
      # load first file to copy some meta data
      wrfout = MFDataset([folder+filename for filename in filelist], check=True, aggdim='Time') # , format='NETCDF4'      
      varlist = wrfout.variables.keys()
      # open/create monthly mean output file
      meanfile = folder+outputpattern%(filetype,ndom)
      if os.path.exists(meanfile):
        mean = Dataset(meanfile, 'rw', format='NETCDF4')
      else:        
        mean = Dataset(meanfile, 'w', format='NETCDF4')
        begindate = datergx.search(filelist[0]).group()
#         begindate = filelist[0].split('_')[2] # should be the date...
        add_coord(mean, 'time', values=None, dtype='i4', atts=dict(units='month since '+begindate)) # unlimited time dimension
        # copy dimensions and variables to new datasets
        copy_dims(mean, wrfout, dimlist=dimlist, copy_coords=False) # don't have coordinate variables
        copy_vars(mean, wrfout, varlist=varlist, copy_data=False)              
        # copy global attributes
        copy_ncatts(mean, wrfout, prefix='') # copy all attributes (no need for prefix; all upper case are original)
        mean.description = 'wrf%s_d%02i monthly means'%(filetype,ndom)
        mean.begin_date = begindate
        mean.experiment = exp
        mean.creator = 'Andre R. Erler'        
        
      # update current end date
      enddate = datergx.search(filelist[-1]).group()    
#       enddate = filelist[-1].split('_')[2] # should be the date...
      mean.end_date = enddate
      
      
#       # create climatology output file
#       clim = Dataset(folder+climfile%ndom, 'w', format='NETCDF4')
#       add_coord(clim, 'time', values=mons, dtype='i4', atts=dict(units='month of the year')) # month of the year
#       copy_dims(clim, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
#       # variable with proper names of the months
#       clim.createDimension('tstrlen', size=9) 
#       coord = clim.createVariable('month','S1',('time','tstrlen'))
#       for m in xrange(nmons): 
#         for n in xrange(9): coord[m,n] = months[m][n]
#       # global attributes
#       copy_ncatts(clim, wrfout, prefix='WRF_') # copy all attributes and save with prefix WRF
#       clim.description = 'climatology of WRF monthly means'
#       clim.begin_date = begindate; clim.end_date = enddate
#       clim.experiment = exp
#       clim.creator = 'Andre R. Erler'
      
          
      # length of time, x, and y dimensions
      nvar = len(varlist)
      nx = len(wrfout.dimensions['west_east'])
      ny = len(wrfout.dimensions['south_north'])
      nfiles = len(filelist) # number of files
      
      
      ## compute monthly means and climatology
      tax = 0 # index of time axis (for averaging)
      time = 'Time' 
      # allocate arrays
      print('\n Computing monthly means from %s to %s (incl);'%(begindate,enddate))
      print ('%3i fields of shape (%i,%i):\n'%(nvar,nx,ny))
      for var in varlist: 
        print('   %s'%(var,))
        assert (ny,nx) == mean.variables[var].shape[1:], \
          '\nWARNING: variable %s does not conform to assumed shape (%i,%i)!\n'%(var,nx,ny)
        
      # monthly means
      meandata = dict()
#       climdata = dict()
      for var in varlist:
        meandata[var] = zeros((nfiles,ny,nx))
#         climdata[var] = zeros((nmons,ny,nx))
      xtime = zeros((nfiles,)) # number of month
      xmon = zeros((nmons,)) # counter for number of contributions
      # loop over input files 
      print('\n Starting computation: %i iterations (files)\n'%nfiles)
      for n in xrange(nfiles):
        wrfout = Dataset(folder+filelist[n], 'r', format='NETCDF4')
        ntime = len(wrfout.dimensions[time]) # length of month
        print('  processing file #%i of %3i (%i time-steps):'%(n+1,nfiles,ntime))
        print('    %s\n'%filelist[n])
        # compute monthly averages
        m = int(datergx.search(filelist[n]).group()[-2:])-1 # infer month from filename (for climatology)
        xtime[n] = n+1 # month since start 
        xmon[m] += 1 # one more item
        for var in varlist:
          tmp = wrfout.variables[var]
          if acclist.has_key(var): # special treatment for accumulated variables
            mtmp = diff(tmp[:].take([0,ntime-1],axis=tax), n=1, axis=tax).squeeze()
            if acclist[var]:
              bktvar = bktpfx + var # guess name of bucket variable 
              if wrfout.variables.has_key(bktvar):
                bkt = wrfout.variables[bktvar]
                mtmp = mtmp + acclist[var] * diff(bkt[:].take([0,ntime-1],axis=tax), n=1, axis=tax).squeeze()
            mtmp /= (days[m]-1) # transform to daily instead of monthly rate
            # N.B.: technically the difference should be taken w.r.t. the last day of the previous month,
            #       not the first day of the current month, hence we loose one day in the accumulation
          else:
            mtmp = tmp[:].mean(axis=tax) # normal variables, normal mean...
          meandata[var][n,:] = mtmp # save monthly mean
#           climdata[var][m,:] += mtmp # accumulate climatology
        # close file
        wrfout.close()
        
      # normalize climatology
      if n < nmons: xmon[xmon==0] = 1 # avoid division by zero 
#       for var in varlist:
#         climdata[var][:,:,:] = climdata[var][:,:,:] / xmon[:,None,None] # 'None" indicates a singleton dimension
      
      ## finish
      # save to files
      print(' Done. Writing output to:\n  %s'%(folder,))
      for var in varlist:
        mean.variables[var][:] = meandata[var]
        mean.variables['time'][:] = xtime
#         clim.variables[var][:] = climdata[var] 
      # close files
      mean.close()
      print('    %s'%(meanfile%ndom,))
#       clim.close()
#       print('    %s'%(climfile%ndom,))
