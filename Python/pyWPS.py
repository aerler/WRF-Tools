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
  Model = '/home/me/Models/'
  NCARG = '/usr/local/ncarg/'
  NCL = '/usr/local/ncarg/bin/ncl'
  NP = 2
elif (hostname=='erlkoenig'):
  # my laptop
  lscinet = False
  Ram = '/home/me/Models/Fortran Tools/test/tmp/' # tmpfs folder to be used for temporary storage
  # (leave Ram directory blank if tmpfs will be in test directory)
  Root = '/home/me/Models/Fortran Tools/test/'
  # use this cmd to mount: sudo mount -t tmpfs -o size=200m tmpfs /home/me/Models/Fortran\ Tools/test/tmp/
  # followed by: sudo chown me /home/me/Models/Fortran\ Tools/test/tmp/
  # and this to unmount: sudo umount /home/me/Models/Fortran\ Tools/test/tmp/
  Model = '/home/me/Models/'
  NCARG = '/usr/local/ncarg/'
  NCL = '/usr/local/ncarg/bin/ncl'
  NP = 1
elif ('gpc' in hostname):
  # SciNet
  lscinet = True
  Ram = '/dev/shm/aerler/' # ramdisk/tmpfs folder to be used for temporary storage
  Root = '' # use current directory
  Model = '/home/p/peltier/aerler/'
  NCARG = '/scinet/gpc/Applications/ncl/6.0.0/'
  NCL = '/scinet/gpc/Applications/ncl/6.0.0/bin/ncl'
  NP = 16 # either hyperthreading or largemem nodes
elif ('p7' in hostname):
  # SciNet
  lscinet = True
  Ram = '/dev/shm/aerler/' # ramdisk/tmpfs folder to be used for temporary storage
  Root = '' # use current directory
  Model = '/home/p/peltier/aerler/'
  NCARG = ''
  NCL = ''
  NP = 32
  
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
# parallelization
# number of processes NP is set above (machine specific)
pname = 'proc%02.0f'
pdir = 'proc%02.0f/'  
# destination folder(s)
ramlnk = 'ram' # automatically generated link to ramdisk (if applicable)
data = 'data/' # data folder in ram
ldata = True # whether or not to keep data in memory  
disk = 'data/' # destination folder on hard disk
Disk = '' # default: Root + disk
ldisk = True # whether or not to store data on hard disk
## Commands
eta2p_ncl = 'eta2p.ncl'
eta2p_log = 'eta2p.log'
NCL_ETA2P = NCL + ' ' + eta2p_ncl
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
  #startdates = [] # list of start dates for each domain 
  ied = 0 # line index of end_date parameter
  #enddates = [] # list of end dates for each domain
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
      startdates = [date[1:14] for date in dates] # strip quotes and cut off after hours 
    elif ied==0 and 'end_date' in line:
      ied = file.filelineno()
      # extract end time of main domain (sub-domains irrelevant)
      dates = extractValueList(line)
      enddates = [date[1:14] for date in dates] # strip quotes and cut off after hours
    if imd>0 and isd>0 and ied>0:
      break # exit as soon as all are found
  # trim date lists to number of domains and cast into tuples
  # N.B.: do after loop, so that order doesn't matter
  startdates = tuple(startdates[:maxdom])
  enddates = tuple(enddates[:maxdom])
  # return values
  return imd, maxdom, isd, startdates, ied, enddates
        
# write new namelist file
def writeNamelist(imdate, ldoms):
  # assemble date string (':00:00' not necessary for hourly output)
  datestr = ''; imdate = "'"+imdate + "',"  # mind the single quotes!
  ndoms = len(ldoms) # (effective) number of domains for this time step
  while not ldoms[ndoms-1]: ndoms -= 1 # cut of unused domains at the end
  datestr = datestr + imdate*ndoms
  # read file and loop over lines
  file = fileinput.FileInput([namelist], inplace=True)
  for line in file:
    if file.filelineno()==imd:
      # write maximum number of domains
      print(' max_dom = %2.0f,'%ndoms)
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
  return (year, month, day, hour)

# unpack date string from WRF
def splitDateWRF(datestr, zero=2000):
  year, month, day_hour = datestr.split('-')
  if year[0] == '0': year = int(year)+zero # start at year 2000 (=0000)
  else: year = int(year)
  month = int(month)
  day, hour = day_hour.split('_')
  day = int(day); hour = int(hour[:3]) 
  return (year, month, day, hour)  

# check if date is within range
def checkDate(current, start, end):
  # unpack and initialize
  year, month, day, hour = current
  startyear, startmonth, startday, starthour = start
  endyear, endmonth, endday, endhour = end
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

# function to divide a list fairly evenly 
def divideList(list, n):
  nlist = len(list) # total number of items
  items = nlist // n # items per sub-list
  rem = nlist - items*n
  # distribute list items
  listoflists = []; ihi = 0 # initialize
  for i in xrange(n):
    ilo = ihi; ihi += items # next interval
    if i < rem: ihi += 1 # these intervals get one more
    listoflists.append(list[ilo:ihi]) # append interval to list of lists
  # return list of sublists
  return listoflists

## parallel pre-processing function
# N.B.: this function has some shared variables for folder names and regx'
# function to process filenames and check dates
def processFiles(id, filelist, queue):
  # parse (partial) filelist for atmospheric model (CAM) output
  files = [atmrgx.match(file) for file in filelist]
  # list of time steps from atmospheric output
  atmfiles = [match.group() for match in files if not match is None]
  files = [dateregx.search(atmfile) for atmfile in atmfiles]
  dates = [match.group() for match in files if not match is None]
  okdates = [] # list of valid dates
  # loop over dates
  for datestr in dates:
    # figure out time and date
    date = splitDateCCSM(datestr)
    # check date for validity (only need to check first/master domain)
    lok = checkDate(date, starts[0], ends[0])
    # collect valid dates
    if lok: 
      okdates.append(datestr)
  # return list of valid datestrs
  queue.put(okdates)


## primary parallel processing function: workload for each process
# N.B.: this function has a lot of shared variable for folder and file names etc.
# this is the actual processing pipeline
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
  for i in doms: # loop over all geogrid domains
    geoname = geopfx%(i)+ncext
    os.symlink(Tmp+geoname, geoname)
  
  ## loop over (atmospheric) time steps
  if dates: print('\n '+mytag+' Looping over Time-steps:')
  else: print('\n '+mytag+' Nothing to do!')

  for datestr in dates:
    
    # convert time and date
    date = splitDateCCSM(datestr)
    # figure out sub-domains
    ldoms = [True,]*maxdom # first domain is always computed
    for i in xrange(1,maxdom): # check sub-domains
      ldoms[i] = checkDate(date, starts[i], ends[i])
      
    # prepare processing 
    # create links to relevant source data (requires full path for linked files)
    atmfile = atmpfx+datestr+ncext
    os.symlink(AtmDir+atmfile,atmlnk)
    lndfile = lndpfx+datestr+ncext
    os.symlink(LndDir+lndfile,lndlnk)
    icefile = icepfx+datestr+ncext
    os.symlink(IceDir+icefile,icelnk)
    print('\n '+mytag+' Processing time-step:  '+datestr+'\n    '+atmfile+'\n    '+lndfile+'\n    '+icefile)
    
    ##  convert data to intermediate files
    # run NCL script (suppressing output)
    print('\n  * '+mytag+' interpolating to pressure levels (eta2p.ncl)')
    if lscinet:
      # On SciNet we have to pass this command through the shell, so that the NCL module is loaded.
      subprocess.call(NCL_ETA2P, shell=True, stdout=open(eta2p_log, 'w'))
    else:
      # otherwise we don't need the shell and it's a security risk
      subprocess.call([NCL,eta2p_ncl], stdout=open(eta2p_log, 'w'))        
    # run unccsm.exe
    print('\n  * '+mytag+' writing to WRF IM format (unccsm.exe)')
    subprocess.call([UNCCSM], stdout=open(unccsm_log, 'w'))   
    # N.B.: in case the stack size limit causes segmentation faults, here are some workarounds
    # subprocess.call(r'ulimit -s unlimited; ./unccsm.exe', shell=True)
    # import resource
    # subprocess.call(['./unccsm.exe'], preexec_fn=resource.setrlimit(resource.RLIMIT_STACK,(-1,-1)))
    # print resource.getrlimit(resource.RLIMIT_STACK)
    
    ## run WPS' metgrid.exe on intermediate file
    # rename intermediate file according to WPS convention (by date)
    imdate = imform%date
    imfile = impfx+imdate
    os.rename(preimfile, imfile) # not the same as 'move'
    # update date string in namelist.wps
    writeNamelist(imdate, ldoms)
    # run metgrid_exe.exe
    print('\n  * '+mytag+' interpolating to WRF grid (metgrid.exe)')
    subprocess.call([METGRID], stdout=open(os.devnull, 'w')) # metgrid.exe writes a fairly detailed log file
    
    ## finish time-step
    # copy/move data back to disk (one per domain) and/or keep in memory
    tmpstr = '\n '+mytag+' Writing output to disk: ' # gather output for later display
    for i in xrange(maxdom):
      metfile = metpfx%(i+1)+imdate+metsfx
      if ldoms[i]:
        tmpstr += '\n                           '+metfile
        if ldisk: 
          shutil.copy(metfile,Disk+metfile)
        if ldata:
          shutil.move(metfile,Data+metfile)      
        else:
          os.remove(metfile)
      else:
        if os.path.exists(metfile): 
          os.remove(metfile) # metgrid.exe may create more files than needed
    # finish time-step
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
  for i in doms: # loop over all geogrid domains
    os.remove(geopfx%(i)+ncext)
    
    
if __name__ == '__main__':
      
    ##  prepare environment
    # figure out root folder
    if Root:
      Root = Root + gcm + '/' # assume GCM name as subdirectory
      os.chdir(Root) # change to Root directory
    else:
      Root = os.getcwd() + '/' # use current directory
    # direct temporary storage
    if Ram:       
      Tmp = Ram + tmp # direct temporary storage to ram disk
      if ldata: Data = Ram + data # temporary data storage (in memory)
      # provide link to ram disk directory for convenience (unless on SciNet)      
      if not lscinet and not (os.path.isdir(ramlnk) or os.path.islink(ramlnk[:-1])):
        os.symlink(Ram, ramlnk)
    else:      
      Tmp = Root + tmp # use local directory
      if ldata: Data = Root + data # temporary data storage (just moves here, no copy)      
    # create temporary storage  (file system or ram disk alike)
    if os.path.isdir(Tmp):        
      clean(Tmp, all=True) # if folder already there, clean
    else:                 
      os.mkdir(Tmp) # otherwise create folder 
    # create temporary data collection folder
    if ldata:
      if os.path.isdir(Data) or os.path.islink(Data[:-1]):
        # remove directory if already there
        shutil.rmtree(Data)
      os.mkdir(Data) # create data folder in temporary storage
    # create/clear destination folder
    if ldisk:
      if not Disk: 
        Disk = Root + disk
      if os.path.isdir(Disk) or os.path.islink(Disk[:-1]):
        # remove directory if already there
        shutil.rmtree(Disk)
      # create new destination folder
      os.mkdir(Disk)
      
    # directory shortcuts
    Meta = Tmp + meta
    AtmDir = Root + atmdir
    LndDir = Root + lnddir
    IceDir = Root + icedir
    # parse namelist parameters
    imd, maxdom, isd, startdates, ied, enddates = readNamelist()
    # figure out domains
    starts = [splitDateWRF(sd) for sd in startdates]
    ends = [splitDateWRF(ed) for ed in enddates]
    doms = range(1,maxdom+1) # list of domain indices
        
    # copy meta data to temporary folder
    shutil.copytree(meta,Tmp+meta)
    shutil.copy(unccsm_exe, Tmp)
    shutil.copy(eta2p_ncl, Tmp)
    shutil.copy(metgrid_exe, Tmp)
    shutil.copy(namelist, Tmp)
    for i in doms: # loop over all geogrid domains
      shutil.copy(geopfx%(i)+ncext, Tmp)
    # N.B.: shutil.copy copies the actual file that is linked to, not just the link
    # change working directory to tmp folder
    os.chdir(Tmp)
    # set environment variable for NCL (on tmp folder)   
    os.putenv('NCARG_ROOT', NCARG) 
    os.putenv('NCL_POP_REMAP', meta) # NCL is finicky about space characters in the path statement, so relative path is saver
    os.putenv('MODEL_ROOT', Model) # also for NCL (where personal function libs are)
    
    ## multiprocessing
    
    # search for files and check dates for validity
    listoffilelists = divideList(os.listdir(AtmDir), NP)
    # divide file processing among processes
    procs = []; queues = []
    for id in xrange(NP):
      q = multiprocessing.Queue()
      queues.append(q)
      p = multiprocessing.Process(name=pname%id, target=processFiles, args=(id, listoffilelists[id], q))
      procs.append(p)
      p.start() 
    # terminate sub-processes and collect results    
    dates = [] # new date list with valid dates only
    for id in xrange(NP):
      dates += queues[id].get()
      procs[id].join()
    
    # divide up dates and process time-steps
    listofdates = divideList(dates, NP)    
    # create processes
    procs = []; ilo = 0; ihi = 0
    for id in xrange(NP):
      p = multiprocessing.Process(name=pname%id, target=processTimesteps, args=(id, listofdates[id]))
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
