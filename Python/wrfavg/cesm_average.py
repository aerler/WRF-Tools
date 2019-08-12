'''
Created on 2012-11-13, revised 2013-12-02

A script to average CESM monthly data to create a monthly climatology. 
This script does not rely on PyGeode but instead uses netCDF4 and numpy directly.

@author: Andre R. Erler
'''

## imports
# numpy
from numpy import arange, array, zeros
import os, re, sys
# import netCDF4-python and added functionality
from netCDF4 import Dataset
from utils.nctools import add_coord, copy_dims, copy_ncatts, copy_vars
#from netcdf import Dataset, copy_ncatts, copy_vars, copy_dims, add_coord


def getDateRegX(period): 
# function to define averaging period based on argument
# use '\d' for any number and [1-3,45] for ranges; '\d\d\d\d-\d\d'
  if period == '1979': prdrgx = '1979-\d\d' # 1 year historical period
  elif period == '1979-1981': prdrgx = '19(79|80)-\d\d' # 2 year historical period
  elif period == '1979-1982': prdrgx = '19(79|8[0-1])-\d\d' # 3 year historical period
  elif period == '1979-1984': prdrgx = '19(79|8[0-3])-\d\d' # 5 year historical period
  elif period == '1979-1989': prdrgx = '19(79|8[0-8])-\d\d' # 10 year historical period
  elif period == '1979-1994': prdrgx = '19(79|8[0-9]|9[0-3])-\d\d' # 15 year historical period
  elif period == '1980-1995': prdrgx = '19(8[0-9]|9[0-4])-\d\d' # 15 year historical period
  elif period == '2045-2048': prdrgx = '204[5-7]-\d\d' # 3 year future period
  elif period == '2045-2050': prdrgx = '204[5-9]-\d\d' # 5 year future period
  elif period == '2045-2055': prdrgx = '20(4[5-9]|5[0-4])-\d\d' # 10 year future period
  elif period == '2045-2060': prdrgx = '20(4[5-9]|5[0-9])-\d\d' # 15 year future period 
  elif period == '2085-2090': prdrgx = '208[5-9]-\d\d' # 5 year future period
  elif period == '2085-2095': prdrgx = '20(8[5-9]|9[0-4])-\d\d' # 10 year future period
  elif period == '2085-2100': prdrgx = '20(8[5-9]|9[0-9])-\d\d' # 15 year future period
  else: #prdrgx = '\d\d\d\d-\d\d'
    raise ValueError('Unknown period definition: \'%s\''%period)
  return prdrgx 

def checkList(varlist, statlist, dimlist, ignorelist):
# function to check or generate or expand variable lists
  # check statlist
  if statlist is None: 
    statlist = []
  else:
    for i in range(len(statlist)-1,-1,-1): # avoid problems with deletions, hence go backwards
      if statlist[i] not in cesmout.variables:
        print(('\nWARNING: variable %s not found in source file!\n'%(statlist[i],)))
        del statlist[i] # remove variable if not present in source file        
  # check varlist
  if varlist is None:
    varlist = []
    for varname,ncvar in cesmout.variables.items():
      if varname not in statlist and varname not in ignorelist and ncvar.dtype != '|S1':
        if 'time' in ncvar.dimensions: varlist.append(varname)
        elif varname not in dimlist: statlist.append(varname) # another static variable
      #varlist = [var for var in cesmout.variables.iterkeys() if var not in statlist]
  else:
    for i in range(len(varlist)-1,-1,-1): # avoid problems with deletions
      if varlist[i] not in cesmout.variables:
        print(('\nWARNING: variable %s not found in source file!\n'%(varlist[i],)))
        del varlist[i] # remove variable if not present in soruce file
      else:
        if varlist[i] in statlist: 
          print(('\nWARNING: variable %s is also statlist!\n'%(varlist[i],)))
          del varlist[i] # remove variable if not present in soruce file  
  # return checked lists
  return varlist, statlist    


## read arguments
# file types to process 
if 'PYAVG_FILETYPE' in os.environ: 
  filetype = os.environ['PYAVG_FILETYPE'] # currently only one at a time
else: filetype = 'atm' # defaults are set below  
# averaging period
if len(sys.argv) > 1:
  period = sys.argv[1]
else: period = None
# source folder (overwrite default)
if len(sys.argv) > 2:
  srcdir = sys.argv[2] + '/' + filetype + '/hist/'
else:
  srcdir = os.getcwd() + '/' + filetype + '/hist/'
# set other variables
dstdir = os.getcwd() + '/cesmavg/'
cesmname = os.getcwd().split('/')[-1] # root folder name

#print period
#print cesmname
#print srcdir
#print dstdir
  
## definitions
# input files and folders
if filetype == 'atm': cesmpfx = cesmname + '.cam2.h0.' # use monthly means
elif filetype == 'lnd': cesmpfx = cesmname + '.clm2.h0.' # use monthly means
elif filetype == 'ice': cesmpfx = cesmname + '.cice.h.' # use monthly means
else: raise ValueError('Unknown filetype \'%s\''%(filetype,))
cesmext = '.nc'
# output files and folders
if period: 
  prdrgx = getDateRegX(period)
  climfile = 'cesm' + filetype + '_clim_' + period + '.nc'
else: 
  prdrgx = '\d\d\d\d-\d\d'
  climfile = 'cesm' + filetype + '_clim.nc'
# variables
tax = 0 # time axis (to average over)
ignorelist = ['time'] #,'date','datesec','time_bnds','date_written','time_written'] # averages would be meaningless...
dimlist = None # copy these dimensions
#dimlist = ['lon', 'lat'] # copy these dimensions
dimmap = dict() # original names of dimensions
varlist = None # include these variables in monthly means
#varlist = ['ps','pmsl','Ts','T2','rainnc','rainc','snownc','rain','rainsh','snowc','rainzm','snow','seaice','evap'] # include these variables in monthly means
statlist = ['LANDFRAC','PHIS'] # static fields (only copied once) 
#statlist = ['zs','lnd'] # static fields (only copied once) 
#varmap = dict(ps='PS',pmsl='PSL',Ts='TS',T2='TREFHT',zs='PHIS',lnd='LANDFRAC',rain='PRECT', # original (CESM) names of variables
#rainnc='PRECL',rainc='PRECC',rainsh='PRECSH',rainzm='PRECCDZM', snownc='PRECSL',snowc='PRECSC', #
#seaice='ICEFRAC',seasnow='SNOWHICE',snow='SNOWHLND',hfx='SHFLX',lhfx='LHFLX',evap='QFLX')
# time constants
months = ['January  ', 'February ', 'March    ', 'April    ', 'May      ', 'June     ',
          'July     ', 'August   ', 'September', 'October  ', 'November ', 'December ']
days = array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31], dtype='int16') # no leap year
mons = arange(1,13, dtype='int16'); nmons = len(mons)

if __name__ == '__main__':
    
  # announcement
  print(('\n\n   ***   Processing CESM %s   ***   '%(cesmname,)))
  print(('Source folder: %s'%(srcdir,)))

  ## setup files and folders
  cesmfiles = cesmpfx + prdrgx + cesmext
  # N.B.: cesmpfx must contain something like %02i to accommodate the domain number
  # assemble input filelist
  #print cesmfiles
  cesmrgx = re.compile(cesmfiles) # compile regular expression
  filelist = [cesmrgx.match(filename) for filename in os.listdir(srcdir)] # list folder and match
  filelist = [match.group() for match in filelist if match is not None] # assemble valid file list
  if len(filelist) == 0:
    print(('\nWARNING: no matching files found for %s   '%(cesmname,)))
    import sys   
    sys.exit(1) # exit if there is no match
  filelist.sort() # sort alphabetically, so that files are in sequence (temporally)
  datergx = re.compile(prdrgx) # compile regular expression, also used to infer month (later)
  begindate = datergx.search(filelist[0]).group()
  enddate = datergx.search(filelist[-1]).group()

  # load first file to copy some meta data
  cesmout = Dataset(srcdir+filelist[0], 'r', format='NETCDF4')
  # create climatology output file  
  if os.path.exists(dstdir+climfile): 
    print((' removing old climatology file \'%s\''%(dstdir+climfile,)))
    os.remove(dstdir+climfile)
  clim = Dataset(dstdir+climfile, 'w', format='NETCDF4')
  add_coord(clim, 'time', data=mons, length=len(mons), dtype='i4', atts=dict(units='month of the year')) # month of the year
  if dimlist is None:
    dimlist = [dim for dim in cesmout.dimensions if dim not in ignorelist]
  copy_dims(clim, cesmout, dimlist=dimlist, namemap=dimmap, copy_coords=True, dtype='f4')
  # variable with proper names of the months
  clim.createDimension('tstrlen', size=9) 
  coord = clim.createVariable('month','S1',('time','tstrlen'))
  for m in range(nmons): 
    for n in range(9): coord[m,n] = months[m][n]
  # global attributes
  copy_ncatts(clim, cesmout, prefix='CESM_') # copy all attributes and save with prefix WRF
  clim.description = 'climatology of CESM monthly means'
  clim.begin_date = begindate; clim.end_date = enddate
  clim.experiment = cesmname
  clim.creator = 'Andre R. Erler'
  
  # check lists
  varlist,statlist = checkList(varlist, statlist, dimlist, ignorelist)
  # copy constant variables (no time dimension)
  if statlist:
    copy_vars(clim, cesmout, varlist=statlist, namemap=None, dimmap=dimmap, remove_dims=['time'], copy_data=True)
  # copy variables to new datasets
  if varlist:
    copy_vars(clim, cesmout, varlist=varlist, namemap=None, dimmap=dimmap, copy_data=False)
  
  # length of time, x, and y dimensions
  nfiles = len(filelist) # number of files
  # monthly means
  climdata = dict()
  for var in varlist:
    ncvar = cesmout.variables[var]
    climdata[var] = zeros((nmons,) + ncvar.shape[1:], dtype=ncvar.dtype) # replace time dimension, keep rest
  xtime = zeros((nfiles,), dtype='int16') # number of month
  xmon = zeros((nmons,), dtype='int16') # counter for number of contributions
  
  # close sample input file
  cesmout.close()
  # loop over input files 
  print(('\n Starting computation: %i iterations (files)\n'%nfiles))
  for n in range(nfiles):
    cesmout = Dataset(srcdir+filelist[n], 'r', format='NETCDF4')
    print(('  processing file #%3i of %3i:'%(n+1,nfiles)))
    print(('    %s\n'%filelist[n]))
    # compute monthly averages
    m = int(datergx.search(filelist[n]).group()[-2:])-1 # infer month from filename (for climatology)
    xtime[n] = n+1 # month since start 
    xmon[m] += 1 # one more item
    for var in varlist:
      #ncvar = varmap.get(var,var)
      # N.B.: these are already monthly means, but for some reason they still have a singleton time dimension
      print(var,climdata[var][m,...].shape, cesmout.variables[var][0,...].shape, cesmout.variables[var].dtype)
      climdata[var][m,...] = climdata[var][m,...] + cesmout.variables[var][0,...] # accumulate climatology
      # N.B.: in-place operations are not possible, otherwise array masks are not preserved
    # close file
    cesmout.close()
  
  # normalize climatology
  if n < nmons: xmon[xmon==0] = 1 # avoid division by zero 
  for var in varlist:
    for i in range(len(xmon)):
      if xmon[i] > 0:
        climdata[var][i,...] = climdata[var][i,...] / xmon[i] # 'None" indicates a singleton dimension
    
  ## finish
  # save to files
  print((' Done. Writing output to:\n  %s'%(dstdir,)))
  for var in varlist:
    clim.variables[var][:] = climdata[var] 
  # close files
  clim.close()
  print(('    %s'%(climfile,)))
