#!/usr/bin/python

'''
Created on 2012-03-20

Script to prepare CCSM/CESM input data and run the WPS/metgrid_exe.exe tool chain, 
in order to generate input data for WRF/real.exe.

@author: Andre R. Erler
'''

##  Imports
import socket 
import os
import subprocess
import re
import shutil
import time
import fileinput
import sys
import multiprocessing

##  determine if we are on SciNet or my local machine
hostname = socket.gethostname()
if (hostname=='komputer'):
  # my local workstation
  lscinet = False
  Ram = '/media/data/tmp/' # ramdisk folder to be used for temporary storage
  Root = '/media/data/DATA/WRF/BC/'
  # use this cmd to mount: sudo mount -t ramfs -o size=100m ramfs /media/data/tmp/
  # followed by: sudo chown me /media/data/tmp/
  # and this to unmount:   sudo umount /media/data/tmp/
  os.putenv('NCARG_ROOT', '/usr/local/ncarg/')
  NCL = '/usr/local/ncarg/bin/ncl'
  NP = 2
elif (hostname=='erlkoenig'):
  # my laptop
  lscinet = False
  Ram = '/home/me/Models/Fortran Tools/test/' # tmpfs folder to be used for temporary storage
  # (leave Ram directory blank if tmpfs will be in test directory)
  Root = '/home/me/Models/Fortran Tools/test/'
  # use this cmd to mount: sudo mount -t tmpfs -o size=100m tmpfs /home/me/Models/Fortran\ Tools/test/tmp/
  # followed by: sudo chown me /home/me/Models/Fortran\ Tools/test/tmp/
  # and this to unmount:   sudo umount /home/me/Models/Fortran\ Tools/test/tmp/
  os.putenv('NCARG_ROOT', '/usr/local/ncarg/')
  NCL = '/usr/local/ncarg/bin/ncl'
  NP = 1
elif ('gpc' in hostname):
  # SciNet
  lscinet = True
  Ram = '/dev/shm/aerler/' # ramdisk/tmpfs folder to be used for temporary storage
  Root = '' # use current directory
  os.putenv('NCARG_ROOT', '/scinet/gpc/Applications/ncl/6.0.0/')
  NCL = '/scinet/gpc/Applications/ncl/6.0.0/bin/ncl'
  NP = 8
  
##  Settings
gcm = 'CESM'
prefix = 'cesmpdwrf1x1'
tmp = 'tmp/'
meta = 'meta/'
nclfile = 'intermed.nc'
preimfile = 'FILEOUT'
impfx = 'FILE:'
imform = '%04.0f-%02.0f-%02.0f_%02.0f'
metpfx = 'met_em.d%02.0f.'
metsfx = ':00:00.nc'
geopfx = 'geo_em.d%02.0f'
data = 'data/' # destination folder
# parallelization
# number of processes NP is set above (machine specific)
pname = 'proc%02.0f'
pdir = 'proc%02.0f/'  
## Commands
eta2p_ncl = 'eta2p.ncl'
eta2p_log = 'eta2p.log'
NCL_ETA2P = 'ncl ' + eta2p_ncl
unccsm_exe = 'unccsm.exe'
unccsm_log = 'unccsm.log'
UNCCSM = './' + unccsm_exe
metgrid_exe = 'metgrid.exe'
metgrid_log = 'metgrid.log'
METGRID = './' + metgrid_exe
namelist = 'namelist.wps'
##  data sources
ncext = '.nc'
dateform = '\d\d\d\d-\d\d-\d\d-\d\d\d\d\d'
dateregx = re.compile(dateform)
# atmosphere
atmdir = 'atm/'
atmpfx = prefix+'.cam2.h1.'
atmrgx = re.compile(atmpfx+dateform+ncext+'$')
atmlnk = 'atmfile.nc'
# land
lnddir = 'lnd/'
lndpfx = prefix+'.clm2.h1.'
lndrgx = re.compile(lndpfx+dateform+ncext+'$')
lndlnk = 'lndfile.nc'
# ice
icedir = 'ice/'
icepfx = prefix+'.cice.h1_inst.'
icergx = re.compile(icepfx+dateform+ncext+'$')
icelnk = 'icefile.nc'

# remove tmp files and links
def clean(folder, filelist=None, all=False):
  if all:
    # clean out entire directory
    for path in os.listdir(folder):
      if os.path.isdir(folder+path):
        shutil.rmtree(folder+path)
      else:
        os.remove(folder+path)
  else:
    # clean out statics
    if os.path.exists(folder+atmlnk): os.remove(folder+atmlnk)
    if os.path.exists(folder+lndlnk): os.remove(folder+lndlnk)
    if os.path.exists(folder+icelnk): os.remove(folder+icelnk)
    if os.path.exists(folder+nclfile): os.remove(folder+nclfile)
#    if os.path.exists(folder+imfile): os.remove(folder+imfile)
    # remove other stuff
    if filelist is not None:
      for file in filelist:
        if os.path.exists(folder+file): os.remove(folder+file)
        
# helper function for readNamelist
def extractValueList(linestring):
  # chunks separated by spaces
  chunks = linestring.split()[2:]
  values = []
  # flatten space and comma separated lists...
  for chunk in chunks:
    # values separated by commas but no spaces
    for value in chunk.split(','):
      if value: values.append(value)
  # return list of values
  return values
  
# function to read namelist
def readNamelist():
  # values to read
  imd = 0 # line index of maxdom
  maxdom = 0 # max number of domains
  isd = 0 # line index of start_date parameter
  startdate = '' # start date of main domain
  substart = '' # start date of sub-domains 
  ied = 0 # line index of end_date parameter
  enddate = '' # start date of main domain
  # open namelist file for reading 
  file = fileinput.FileInput([namelist], mode='r')
  # loop over entries/lines
  for line in file: 
    # search for relevant entries
    if imd==0 and 'max_dom' in line:
      imd = file.filelineno()
      maxdom = int(line.split()[2].strip(','))
    elif isd==0 and 'start_date' in line:
      isd = file.filelineno()
      # extract start time of main and sub-domains
      dates = extractValueList(line)
      startdate = dates[0][1:14] # strip quotes and cut off after hours
      if maxdom > 1: substart = dates[1][1:14] 
    elif ied==0 and 'end_date' in line:
      ied = file.filelineno()
      # extract end time of main domain (sub-domains irrelevant)
      dates = extractValueList(line)
      enddate = dates[0][1:14] # strip quotes and cut off after hours
    if imd>0 and isd>0 and ied>0:
      break # exit as soon as all are found
  # return values
  return imd, maxdom, isd, startdate, substart, ied, enddate
        
# write new namelist file
def writeNamelist(imdate, doms):
  # assemble date string (':00:00' not necessary for hourly output)
  datestr = ''; imdate = "'"+imdate + "',"  # mind the single quotes! 
  for i in doms:
    datestr = datestr + imdate
  # read file and loop over lines
  file = fileinput.FileInput([namelist], inplace=True)
  for line in file:
    if file.filelineno()==imd:
      # write maximum number of domains
      print(' max_dom = %2.0f,'%len(doms))
    elif file.filelineno()==isd:
      # write new start date
      print(' start_date = '+datestr)
    elif file.filelineno()==ied:
      # write new end date
      print(' end_date = '+datestr)
    else:
      # just write original file contents
      sys.stdout.write(line)
#      print line, # also works

# unpack date string from CCSM/CESM
def splitDateCCSM(datestr, zero=2000):
  year, month, day, second = datestr.split('-')
  if year[0] == '0': year = int(year)+zero # start at year 2000 (=0000)
  else: year = int(year)
  month = int(month); day = int(day)
  hour = int(second)/3600 
  return year, month, day, hour

# unpack date string from WRF
def splitDateWRF(datestr, zero=2000):
  year, month, day_hour = datestr.split('-')
  if year[0] == '0': year = int(year)+zero # start at year 2000 (=0000)
  else: year = int(year)
  month = int(month)
  day, hour = day_hour.split('_')
  day = int(day); hour = int(hour[:3]) 
  return year, month, day, hour  

# check if date is within range
def checkDate(year,month,day,hour, startyear,startmonth,startday,starthour, endyear,endmonth,endday,endhour):
  lstart = False; lend = False
  # check lower bound
  lstart = False
  if startyear < year: lstart = True
  elif startyear == year: 
    if startmonth < month: lstart = True
    elif startmonth == month:
      if startday < day: lstart = True
      elif startday == day: 
        if starthour <= hour: lstart = True
  # check upper bound
  lend = False
  if year < endyear: lend = True
  elif year == endyear:
    if month < endmonth: lend = True
    elif month == endmonth:
      if day < endday: lend = True
      elif day == endday: 
        if hour <= endhour: lend = True
  # determine validity of time-step for main domain
  if lstart and lend: lmaindom = True 
  else: lmaindom = False
  return lmaindom

## main processing function: workload for each process
# N.B.: this function has a lot of shared variable for folder and file names etc.
def processTimesteps(myid, dates):
  
  # create process sub-folder
  mydir = pdir%myid
  MyDir = Tmp + mydir
  mytag = '['+pname%myid+']'
  if os.path.exists(mydir): 
    shutil.rmtree(mydir)
  os.mkdir(mydir)
  # copy namelist
  shutil.copy(namelist, mydir)
  # change working directory to process sub-folder
  os.chdir(mydir)
  # link other source files
  os.symlink(Meta, meta[:-1]) # link to folder
  os.symlink(Tmp+unccsm_exe, unccsm_exe)
  os.symlink(Tmp+eta2p_ncl, eta2p_ncl)
  os.symlink(Tmp+metgrid_exe, metgrid_exe)
  for i in maxdoms: # loop over all geogrid domains
    geoname = geopfx%(i)+ncext
    os.symlink(Tmp+geoname, geoname)
  
  ## loop over (atmospheric) time steps
  print('\nLooping over Time-steps:')
  for date in dates:
    
    # figure out time and date
    year, month, day, hour = splitDateCCSM(date)
    # reset switches
    lmaindom = checkDate(year,month,day,hour, startyear,startmonth,startday,starthour, endyear,endmonth,endday,endhour)
    # handle sub-domains
    lsubdoms = False; doms = onedom  
    if maxdom > 1:
      # only generate data for sub-domains at the initial date/time-step
      if subyear==year and submonth==month and subday==day and subhour==hour:
        lsubdoms = True
        doms = maxdoms

    # run processing if any domains are to be computed          
    if lmaindom or lsubdoms:
      
      # prepare processing 
      # create links to relevant source data (requires full path for linked files)
      atmfile = atmpfx+date+ncext
      os.symlink(AtmDir+atmfile,atmlnk)
      lndfile = lndpfx+date+ncext
      os.symlink(LndDir+lndfile,lndlnk)
      icefile = icepfx+date+ncext
      os.symlink(IceDir+icefile,icelnk)
      print('\n '+mytag+' Processing time-step:  '+date+'\n    '+atmfile+'\n    '+lndfile+'\n    '+icefile)
      
      ##  convert data to intermediate files
      # run NCL script (suppressing output)
      print('\n  * '+mytag+' interpolating to pressure levels (eta2p.ncl)')
      if lscinet:
        # On SciNet we have to pass this command through the shell, so that the NCL module is loaded.
        subprocess.call(NCL_ETA2P, shell=True, stdout=open(eta2p_log, 'w'))
      else:
        # otherwise we don't need the shell and it's a security risk
        subprocess.call([NCL,eta2p_ncl], stdout=open(eta2p_log, 'w'))        
      # run unccsm_exe.exe
      print('\n  * '+mytag+' writing to WRF IM format (unccsm.exe)')
      subprocess.call([UNCCSM], stdout=open(unccsm_log, 'w'))   
      # N.B.: in case the stack size limit causes segmentation faults, here are some workarounds
      # subprocess.call(r'ulimit -s unlimited; ./unccsm_exe.exe', shell=True)
      # import resource
      # subprocess.call(['./unccsm_exe.exe'], preexec_fn=resource.setrlimit(resource.RLIMIT_STACK,(-1,-1)))
      # print resource.getrlimit(resource.RLIMIT_STACK)
      
      ## run WPS' metgrid_exe.exe on intermediate file
      # rename intermediate file according to WPS convention (by date)
      imdate = imform%(year,month,day,hour)
      imfile = impfx+imdate
      os.rename(preimfile, imfile) # not the same as 'move'
      # update date string in namelist.wps
      writeNamelist(imdate, doms)
      # run metgrid_exe.exe
      print('\n  * '+mytag+' interpolating to WRF grid (metgrid.exe)')
      subprocess.call([METGRID], stdout=open(os.devnull, 'w')) # metgrid writes a fairly detailed log file
      
      ## finish time-step
      # copy/move data back to disk (one per domain)
      tmpstr = '\n '+mytag+' Writing output to disk: ' # gather output for later display
      for i in doms:
        metfile = metpfx%(i)+imdate+metsfx
        tmpstr += '\n                           '+metfile
        shutil.move(metfile,Data+metfile)      
      tmpstr += '\n\n   ============================== finished '+imdate+' ==============================   \n'
      print(tmpstr)
      # clean up (also renamed intermediate file)
      clean(MyDir, filelist=[imfile])
      
  ## clean up after all time-steps
  # link other source files
  os.remove(meta[:-1]) # link to folder
  os.remove(unccsm_exe)
  os.remove(eta2p_ncl)
  os.remove(metgrid_exe)
  for i in maxdoms: # loop over all geogrid domains
    os.remove(geopfx%(i)+ncext)

if __name__ == '__main__':
      
    ##  prepare environment
    if Root:
      Root = Root + gcm + '/'
      os.chdir(Root)
    else:
      Root = os.getcwd() + '/'    
    # directory shortcuts
    Tmp = Root + tmp
    Meta = Tmp + meta
    Data = Root + data
    AtmDir = Root + atmdir
    LndDir = Root + lnddir
    IceDir = Root + icedir
    # parse namelist parameters
    imd, maxdom, isd, startdate, substart, ied, enddate = readNamelist()
    # figure out main domain
    startyear, startmonth, startday, starthour = splitDateWRF(startdate)
    endyear, endmonth, endday, endhour = splitDateWRF(enddate)
    onedom = [1]
    # figure out sub-domains
    maxdoms = range(1,maxdom+1) # domain list
    if maxdom > 1:
      subyear, submonth, subday, subhour = splitDateWRF(substart)
      
    # create temporary storage    
    if os.path.isdir(tmp) or os.path.islink(tmp[:-1]): # doesn't like the trailing slash
      # clean, if already exists
      clean(Tmp, all=True)
      # also remove meta data
      if os.path.isdir(tmp+meta): 
        shutil.rmtree(tmp+meta)
    else:
      if Ram: 
        # check if (personal) folder is present
        if not os.path.isdir(Ram): 
          os.mkdir(Ram) 
        # use RAM for temporary storage if provided
        os.symlink(Ram, tmp[:-1])
      else:
        # alternatively just use file system
        os.mkdir(tmp)
    # create/clear destination folder
    if not (os.path.isdir(Data) or os.path.islink(Data[:-1])):
      # create destination folder if not there
      os.mkdir(Data)
    else:
      # remove directory if already there
      shutil.rmtree(Data)
      os.mkdir(Data)
        
    # copy meta data to tmp folder
    shutil.copytree(meta,tmp+meta)
    shutil.copy(unccsm_exe, tmp)
    shutil.copy(eta2p_ncl, tmp)
    shutil.copy(metgrid_exe, tmp)
    shutil.copy(namelist, tmp)
    for i in maxdoms: # loop over all geogrid domains
      shutil.copy(geopfx%(i)+ncext, tmp)
    # N.B.: shutil.copy copies the actual file that is linked to, not just the link
    #TODO: parse namelist.wps for correct path
    # change working directory to tmp folder
    os.chdir(Tmp)
    # set environment variable for NCL (on tmp folder)    
    os.putenv('NCL_POP_REMAP', Meta)
    
    files = [atmrgx.match(atmfile) for atmfile in os.listdir(AtmDir)]
    # list of time steps from atmospheric output
    atmfiles = [match.group() for match in files if not match is None]
    files = [dateregx.search(atmfile) for atmfile in atmfiles]
    dates = [match.group() for match in files if not match is None]
    
    ## multiprocessing
    # divide domain
    nd = len(dates) # number of dates
    dpp = nd/NP # dates per process 
    rem = nd - dpp*NP # remainder dates
    # create processes
    procs = []; ilo = 0; ihi = 0
    for id in xrange(NP):
      ilo = ihi # step up to next slice
      if id < rem: ihi = ihi + dpp + 1 # these processes do one more
      else: ihi = ihi + dpp # these processes get off with less work
      mydates = dates[ilo:ihi]
      p = multiprocessing.Process(name=pname%id, target=processTimesteps, args=(id, mydates))
      procs.append(p)
      p.start()
     
    # terminate sub-processes
    for p in procs:
      p.join()
    # clean up files
    os.chdir(Tmp)
    os.remove(eta2p_ncl)
    os.remove(unccsm_exe)
    os.remove(metgrid_exe)
    # N.B.: remember to remove *.nc files in meta-folder!