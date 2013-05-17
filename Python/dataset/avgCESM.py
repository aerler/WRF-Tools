'''
Created on 2012-11-13

A script to average CESM monthly data to create a monthly climatology. 
This script does not rely on PyGeode but instead uses netCDF4 and numpy directly.

@author: Andre R. Erler
'''

## imports
# numpy
from numpy import arange, array, zeros
import os, re, sys
# import netCDF4-python and added functionality
from netcdf import Dataset, copy_ncatts, copy_vars, copy_dims, add_coord
from avgWRF import getDateRegX # this is for date formats

## names of CESM experiments
cesmexp = dict()
cesmexp['tb20trcn1x1'] = 'ctrl-1'

# data root folder
from socket import gethostname
hostname = gethostname()
if hostname=='komputer':
  CESMroot = '/home/DATA/DATA/CESM/'
  cesmname = 'tb20trcn1x1' 
  exp = cesmexp[cesmname]
  folder = CESMroot + exp + '/'
elif hostname[0:3] == 'gpc': # i.e. on scinet...
  exproot = os.getcwd()
  cesmname = exproot.split('/')[-3] # root folder name
  exp = cesmname
  folder = exproot + '/' # assuming we are in the atm/hist folder...
else:
  folder = os.getcwd() + '/' # just operate in the current directory
  exp = '' # need to define experiment name...

## read arguments
if len(sys.argv) > 1:
  period = sys.argv[1]
else: period = ''

## definitions
prdrgx = getDateRegX(period)
# input files and folders
cesmpfx = cesmname + '.cam2.h0.' # use monthly means
cesmext = '.nc'
# output files and folders
if period: climfile = 'cesmsrfc_clim_' + period + '.nc'
else: climfile = 'cesmsrfc_clim.nc'
# variables
tax = 0 # time axis (to average over)
dimlist = ['lon', 'lat'] # copy these dimensions
dimmap = dict() # original names of dimensions
varlist = ['ps','pmsl','Ts','T2','rainnc','rainc','snownc','rain','rainsh','snowc','rainzm','snow','seaice'] # include these variables in monthly means
statlist = ['zs','lnd'] # static fields (only copied once) 
varmap = dict(ps='PS',pmsl='PSL',Ts='TS',T2='TREFHT',zs='PHIS',lnd='LANDFRAC',rain='PRECT', # original (CESM) names of variables
              rainnc='PRECL',rainc='PRECC',rainsh='PRECSH',rainzm='PRECCDZM', #
              snownc='PRECSL',snowc='PRECSC', seaice='ICEFRAC',seasnow='SNOWHICE',snow='SNOWHICE')
# time constants
months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ', #
          'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
days = array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]) # no leap year
mons = arange(1,13); nmons = len(mons)

if __name__ == '__main__':
    
  # announcement
  print('\n\n   ***   Processing CESM %s (%s)  ***   '%(exp,cesmname))
  
  ## setup files and folders
  cesmfiles = cesmpfx + prdrgx + cesmext
  # N.B.: cesmpfx must contain something like %02i to accommodate the domain number  
  # assemble input filelist
  cesmrgx = re.compile(cesmfiles) # compile regular expression
  filelist = [cesmrgx.match(filename) for filename in os.listdir(folder)] # list folder and match
  filelist = [match.group() for match in filelist if match is not None] # assemble valid file list
  if len(filelist) == 0:
    print('\nWARNING: no matching files found for %s (%s)'%(exp,cesmname,)) 
    import sys   
    sys.exit(1) # exit if there is no match
  filelist.sort() # sort alphabetically, so that files are in sequence (temporally)
  datergx = re.compile(prdrgx) # compile regular expression, also used to infer month (later)
  begindate = datergx.search(filelist[0]).group()
  enddate = datergx.search(filelist[-1]).group()

  # load first file to copy some meta data
  cesmout = Dataset(folder+filelist[0], 'r', format='NETCDF4')    
  # create climatology output file  
  clim = Dataset(folder+climfile, 'w', format='NETCDF4')
  add_coord(clim, 'time', values=mons, dtype='i4', atts=dict(units='month of the year')) # month of the year
  copy_dims(clim, cesmout, dimlist=dimlist, namemap=dimmap, copy_coords=True, dtype='f4') # don't have coordinate variables
  # variable with proper names of the months
  clim.createDimension('tstrlen', size=9) 
  coord = clim.createVariable('month','S1',('time','tstrlen'))
  for m in xrange(nmons): 
    for n in xrange(9): coord[m,n] = months[m][n]
  # global attributes
  copy_ncatts(clim, cesmout, prefix='CESM_') # copy all attributes and save with prefix WRF
  clim.description = 'climatology of CESM monthly means'
  clim.begin_date = begindate; clim.end_date = enddate
  clim.experiment = exp
  clim.creator = 'Andre R. Erler'
  # copy constant variables (no time dimension)
  copy_vars(clim, cesmout, varlist=statlist, namemap=varmap, dimmap=dimmap, remove_dims=['time'], copy_data=True)
  
  # check variable list
  for var in varlist:
    if not cesmout.variables.has_key(varmap.get(var,var)):
      print('\nWARNING: variable %s not found in source file!\n'%(var,))
      del var # remove variable if not present in soruce file
  # copy variables to new datasets
  copy_vars(clim, cesmout, varlist=varlist, namemap=varmap, dimmap=dimmap, copy_data=False)
  # length of time, x, and y dimensions
  nvar = len(varlist)
  nlon = len(cesmout.dimensions['lon'])
  nlat = len(cesmout.dimensions['lat'])
  nfiles = len(filelist) # number of files
  # close sample input file
  cesmout.close()

  # monthly means
  climdata = dict()
  for var in varlist:
    climdata[var] = zeros((nmons,nlat,nlon))
  xtime = zeros((nfiles,)) # number of month
  xmon = zeros((nmons,)) # counter for number of contributions
  # loop over input files 
  print('\n Starting computation: %i iterations (files)\n'%nfiles)
  for n in xrange(nfiles):
    cesmout = Dataset(folder+filelist[n], 'r', format='NETCDF4')
    print('  processing file #%3i of %3i:'%(n+1,nfiles))
    print('    %s\n'%filelist[n])
    # compute monthly averages
    m = int(datergx.search(filelist[n]).group()[-2:])-1 # infer month from filename (for climatology)
    xtime[n] = n+1 # month since start 
    xmon[m] += 1 # one more item
    for var in varlist:
      ncvar = varmap.get(var,var)
      climdata[var][m,:] += cesmout.variables[ncvar][0,:] # accumulate climatology
    # close file
    cesmout.close()
  
  # normalize climatology
  if n < nmons: xmon[xmon==0] = 1 # avoid division by zero 
  for var in varlist:
    climdata[var][:,:,:] = climdata[var][:,:,:] / xmon[:,None,None] # 'None" indicates a singleton dimension
    
  ## finish
  # save to files
  print(' Done. Writing output to:\n  %s'%(folder,))
  for var in varlist:
    clim.variables[var][:] = climdata[var] 
  # close files
  clim.close()
  print('    %s'%(climfile,))
