'''
Created on 2012-11-10

@author: Andre R. Erler
'''

## imports
from numpy import array, arange, zeros, diff
import os
import re
# netcdf stuff
from netcdf import Dataset, add_coord, copy_dims, copy_ncatts, copy_vars

# data root folder
from socket import gethostname
hostname = gethostname()
if hostname=='komputer':
  WRFroot = '/media/data/DATA/WRF/Downscaling/'
  exp = 'ctrl-2'
  folder = WRFroot + exp + '/'
elif hostname[0:3] == 'gpc': # i.e. on scinet...
  exproot = os.getcwd()
  exp = exproot.split('/')[-1] # root folder name
  folder = exproot + '/wrfout/' # output folder 
else:
  folder = os.getcwd() # just operate in the current directory
  exp = '' # need to define experiment name...

## definitions
# input files and folders
maxdom = 2
wrfpfx = 'wrfsrfc_d%02i_' # %02i is for the domain number
wrfext = '-01_00:00:00.nc'
wrfdate = '\d\d\d\d-\d\d' # use '\d' for any number and [1-3,45] for ranges
# output files and folders
meanfile = 'wrfsrfc_d%02i_monthly.nc' # %02i is for the domain number
climfile = 'wrfsrfc_d%02i_clim.nc' # %02i is for the domain number
# variables
tax = 0 # time axis (to average over)
dimlist = ['x', 'y'] # copy these dimensions
dimmap = dict(time='Time', x='west_east', y='south_north') # original names of dimensions
varlist = ['ps','T2','Ts','rainnc','rainc','snownc','graupelnc','snow'] # include these variables in monthly means 
varmap = dict(ps='PSFC',T2='T2',Ts='TSK',snow='SNOW',snowh='SNOWH', # original (WRF) names of variables
              rainnc='RAINNC',rainc='RAINC',rainsh='RAINSH',snownc='SNOWNC',graupelnc='GRAUPELNC') 
acclist = dict(rainnc=100,rainc=100,rainsh=0,snownc=0,graupelnc=0) # dictionary of accumulated variables
# N.B.: keys = variables and values = bucket sizes; value = None or 0 means no bucket  
bktpfx = 'I_' # prefix for bucket variables 
# time constants
months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
          'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
days = array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]) # no leap year
mons = arange(1,13); nmons = len(mons)

if __name__ == '__main__':
  
  ## loop over domains
  for ndom in xrange(1,maxdom+1): 
    
    # announcement
    print('\n\n   ***   Processing Domain #%02i (of %02i)   ***   '%(ndom,maxdom))
  
    ## setup files and folders
    wrffiles = wrfpfx%ndom + wrfdate + wrfext
    # N.B.: wrfpfx must contain something like %02i to accommodate the domain number  
    # assemble input filelist
    wrfrgx = re.compile(wrffiles) # compile regular expression
    filelist = [wrfrgx.match(filename) for filename in os.listdir(folder)] # list folder and match
    filelist = [match.group() for match in filelist if match is not None] # assemble valid file list
    if len(filelist) == 0:
      print('\nWARNING: no matching files found for domain %02i'%(ndom,))
      break # skip and go to next domain
    filelist.sort() # sort alphabetically, so that files are in sequence (temporally)
    datergx = re.compile(wrfdate) # compile regular expression, also used to infer month (later)
    begindate = datergx.search(filelist[0]).group()
    enddate = datergx.search(filelist[-1]).group()
    # load first file to copy some meta data
    wrfout = Dataset(folder+filelist[0], 'r', format='NETCDF4')
    
    # create monthly mean output file
    mean = Dataset(folder+meanfile%ndom, 'w', format='NETCDF4')
    add_coord(mean, 'time', values=None, dtype='i4', atts=dict(units='month since '+begindate)) # unlimited time dimension
    copy_dims(mean, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
    # global attributes
    copy_ncatts(mean, wrfout, prefix='WRF_') # copy all attributes and save with prefix WRF
    mean.description = 'WRF monthly means'
    mean.begin_date = begindate; mean.end_date = enddate
    mean.experiment = exp
    mean.creator = 'Andre R. Erler'
    
    # create climatology output file
    clim = Dataset(folder+climfile%ndom, 'w', format='NETCDF4')
    add_coord(clim, 'time', values=mons, dtype='i4', atts=dict(units='month of the year')) # month of the year
    copy_dims(clim, wrfout, dimlist=dimlist, namemap=dimmap, copy_coords=False) # don't have coordinate variables
    # variable with proper names of the months
    clim.createDimension('tstrlen', size=9) 
    coord = clim.createVariable('month','S1',('time','tstrlen'))
    for m in xrange(nmons): 
      for n in xrange(9): coord[m,n] = months[m][n]
    # global attributes
    copy_ncatts(clim, wrfout, prefix='WRF_') # copy all attributes and save with prefix WRF
    clim.description = 'climatology of WRF monthly means'
    clim.begin_date = begindate; clim.end_date = enddate
    clim.experiment = exp
    clim.creator = 'Andre R. Erler'
    
    # check variable list
    for var in varlist:
      if not wrfout.variables.has_key(varmap.get(var,var)):
        print('\nWARNING: variable %s not found in source file!\n'%(var,))
        del var # remove variable if not present in soruce file
    # copy variables to new datasets
    copy_vars(mean, wrfout, varlist=varlist, namemap=varmap, dimmap=dimmap, copy_data=False)
    copy_vars(clim, wrfout, varlist=varlist, namemap=varmap, dimmap=dimmap, copy_data=False)
    # length of time, x, and y dimensions
    nvar = len(varlist)
    nx = len(wrfout.dimensions[dimmap['x']])
    ny = len(wrfout.dimensions[dimmap['y']])
    nfiles = len(filelist) # number of files
    # close sample input file
    wrfout.close()
    
    ## compute monthly means and climatology
    # allocate arrays
    print('\n Computing monthly means from %s to %s (incl);'%(begindate,enddate))
    print ('%3i fields of shape (%i,%i):\n'%(nvar,nx,ny))
    for var in varlist: 
      print('   %s (%s)'%(var,varmap.get(var,var)))
      assert (ny,nx) == mean.variables[var].shape[1:], \
        '\nWARNING: variable %s does not conform to assumed shape (%i,%i)!\n'%(var,nx,ny)
      
    # monthly means
    meandata = dict()
    climdata = dict()
    for var in varlist:
      meandata[var] = zeros((nfiles,ny,nx))
      climdata[var] = zeros((nmons,ny,nx))
    xtime = zeros((nfiles,)) # number of month
    xmon = zeros((nmons,)) # counter for number of contributions
    # loop over input files 
    print('\n Starting computation: %i iterations (files)\n'%nfiles)
    for n in xrange(nfiles):
      wrfout = Dataset(folder+filelist[n], 'r', format='NETCDF4')
      ntime = len(wrfout.dimensions[dimmap['time']]) # length of month
      print('  processing file #%i of %3i (%i time-steps):'%(n+1,nfiles,ntime))
      print('    %s\n'%filelist[n])
      # compute monthly averages
      m = int(datergx.search(filelist[n]).group()[-2:])-1 # infer month from filename (for climatology)
      xtime[n] = n+1 # month since start 
      xmon[m] += 1 # one more item
      for var in varlist:
        ncvar = varmap.get(var,var)
        tmp = wrfout.variables[ncvar]
        if acclist.has_key(var): # special treatment for accumulated variables
          mtmp = diff(tmp[:].take([0,ntime-1],axis=tax), n=1, axis=tax).squeeze()
          if acclist[var]:
            bktvar = bktpfx + ncvar # guess name of bucket variable 
            if wrfout.variables.has_key(bktvar):
              bkt = wrfout.variables[bktvar]
              mtmp = mtmp + acclist[var] * diff(bkt[:].take([0,ntime-1],axis=tax), n=1, axis=tax).squeeze()
          mtmp /= (days[m]-1) # transform to daily instead of monthly rate
          # N.B.: technically the difference should be taken w.r.t. the last day of the previous month,
          #       not the first day of the current month, hence we loose one day in the accumulation
        else:
          mtmp = tmp[:].mean(axis=tax) # normal variables, normal mean...
        meandata[var][n,:] = mtmp # save monthly mean
        climdata[var][m,:] += mtmp # accumulate climatology
      # close file
      wrfout.close()
      
    # normalize climatology
    if n < nmons: xmon[xmon==0] = 1 # avoid division by zero 
    for var in varlist:
      climdata[var][:,:,:] = climdata[var][:,:,:] / xmon[:,None,None] # 'None" indicates a singleton dimension
    
    ## finish
    # save to files
    print(' Done. Writing output to:\n  %s'%(folder,))
    for var in varlist:
      mean.variables[var][:] = meandata[var]
      mean.variables['time'][:] = xtime
      clim.variables[var][:] = climdata[var] 
    # close files
    mean.close()
    print('    %s'%(meanfile%ndom,))
    clim.close()
    print('    %s'%(climfile%ndom,))
