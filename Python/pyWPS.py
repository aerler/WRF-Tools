#!/usr/bin/python

'''
Created on 2012-03-20
Revised on 2013-03-19

Script to prepare input data from various sources (including CESM/CCSM) and run the 
WPS/metgrid.exe tool chain, in order to generate input data for WRF/real.exe

@author: Andre R. Erler
'''

##  imports
import socket # recognizing host 
import os # directory operations
import shutil # copy and move
import re # regular expressions
import subprocess # launching external programs
import multiprocessing # parallelization
# my modules
from namelist import time

##  Default Settings (may be overwritten by in meta/namelist.py)
tmp = 'tmp/'
meta = 'meta/'
# metgrid
impfx = 'FILE:'
imform = '%04.0f-%02.0f-%02.0f_%02.0f'
metpfx = 'met_em.d%02.0f.'
metsfx = ':00:00.nc'
geopfx = 'geo_em.d%02.0f'
# parallelization
pname = 'proc%02.0f'
pdir = 'proc%02.0f/'  
# destination folder(s)
ramlnk = 'ram' # automatically generated link to ramdisk (if applicable)
data = 'data/' # data folder in ram
ldata = True # whether or not to keep data in memory  
disk = 'data/' # destination folder on hard disk
Disk = '' # default: Root + disk
ldisk = False # don't write metgrid files to hard disk
## Commands
# metgrid
metgrid_exe = 'metgrid.exe'
metgrid_log = 'metgrid.exe.log'
nmlstwps = 'namelist.wps'
ncext = '.nc' # also used for geogrid files
# dependent variables 
METGRID = './' + metgrid_exe


##  determine if we are on SciNet or my local machine
hostname = socket.gethostname()

if ('gpc' in hostname) or ('p7' in hostname):
  # SciNet
  lscinet = True
else:
  # my local workstation
  lscinet = False
  # use this cmd to mount: sudo mount -t ramfs -o size=100m ramfs /media/tmp/
  # followed by: sudo chown me /media/tmp/
  # sudo mount -t ramfs -o size=100m ramfs /media/tmp/ && sudo chown me /media/tmp/
  # and this to unmount:   sudo umount /media/tmp/

## read environment variables (overrides defaults)
# defaults are set above (some machine specific)
# model root folder (instalation folder of 'WRF Tools'
if os.environ.has_key('MODEL_ROOT'): Model = os.environ['MODEL_ROOT']
# NCARG installation folder (for NCL)
if os.environ.has_key('NCARG_ROOT'): 
  NCARG = os.environ['NCARG_ROOT']
  NCL = NCARG + '/bin/ncl'
# RAM disk
if os.environ.has_key('RAMDISK'): Ram = os.environ['RAMDISK']
# save metgrid data
if os.environ.has_key('PYWPS_MET_DATA'):
  Disk = os.environ['PYWPS_MET_DATA']
  ldisk = True
else: ldisk = False
# number of processes NP 
if os.environ.has_key('PYWPS_THREADS'): NP = int(os.environ['PYWPS_THREADS'])
# dataset specific stuff
if os.environ.has_key('PYWPS_DATA_TYPE'): 
  dataset = os.environ['PYWPS_DATA_TYPE']
else: dataset = None


## dataset manager parent class
class Dataset():
  # a class that encapsulates meta data and operations specific to certain datasets
  # note that this class does not hold any actual data 
  # ungrib
  ungrib_exe = 'ungrib.exe'
  ungrib_log = 'ungrib.exe.log'
  # ungrib input filename is always GRIBFILE.AAA
  def __init__(self):
    # currently no function
    pass
  def dataDir(self):
    # universal wrapper method for folder with "master-filelist"
    pass
  def extractDate(self):
    # method to generate date tuple from date string in filename 
    pass
  def setup(self):
    # method to link dataset specific files and folders
    pass
  def cleanup(self):
    # method to remove dataset specific links
    pass
  def ungrib(self):
    # method that generates the WRF IM file for metgrid.exe
    pass 
  
## CESM
class CESM(Dataset):
  # a class that holds meta data and implements operations specific to CESM data
  # note that this class does not hold any actual data
  # unccsm executables
  unncl_ncl = 'unccsm.ncl'
  unncl_log = 'unccsm.ncl.log'
  unccsm_exe = 'unccsm.exe'
  unccsm_log = 'unccsm.exe.log'
  # unccsm temporary files
  nclfile = 'intermed.nc'
  preimfile = 'FILEOUT' 
  # CESM data source
  prefix = '' # 'cesm19752000v2', 'cesmpdwrf1x1'
  ncext = ncext
  dateform = '\d\d\d\d-\d\d-\d\d-\d\d\d\d\d'
  datestr = '%04i-%02i-%02i-%05i' # year, month, day, seconds
  # atmosphere
  atmdir = 'atm/'
  atmpfx = '.cam2.h1.'
  atmlnk = 'atmfile.nc'
  # land
  lnddir = 'lnd/'
  lndpfx = '.clm2.h1.'
  lndlnk = 'lndfile.nc'
  # ice
  icedir = 'ice/'
  icepfx = '.cice.h1_inst.'
  icelnk = 'icefile.nc'

  def __init__(self, folder=None, prefix=None):
    
    assert folder, 'Warning: need to specify root folder!'
    
    ## CESM specific files and folders (only necessary for file operations)
    self.folder = folder # needs to be set externally for different applicatiosn
    self.AtmDir = os.readlink(folder + self.atmdir[:-1])
    self.LndDir = os.readlink(folder + self.lnddir[:-1])
    self.IceDir = os.readlink(folder + self.icedir[:-1])
    self.NCL_ETA2P = NCL + ' ' + self.unncl_ncl
    self.UNCCSM = './' + self.unccsm_exe
    # set environment variable for NCL (on tmp folder)   
    os.putenv('NCARG_ROOT', NCARG) 
    os.putenv('NCL_POP_REMAP', meta) # NCL is finicky about space characters in the path statement, so relative path is saver
    os.putenv('MODEL_ROOT', Model) # also for NCL (where personal function libs are)
      
    # figure out source file prefix (only needs to be determined once)
    if not prefix: 
      # get file prefix for data files
      # use only atmosphere files
      prergx = re.compile(self.atmpfx+self.dateform+self.ncext+'$')
      # search for first valid filename
      for filename in os.listdir(self.AtmDir):
        match = prergx.search(filename) 
        if match: break
      prefix = filename[0:match.start()] # use everything before the pattern as prefix
      # print prefix
      print('\n No data prefix defined; inferring prefix from valid data files in directory '+self.AtmDir)
      print('  prefix = '+prefix)
    if prefix: self.atmpfx = prefix+self.atmpfx
    if prefix: self.lndpfx = prefix+self.lndpfx
    if prefix: self.icepfx = prefix+self.icepfx
    self.prefix = prefix

    ## compile regular expressions (needed to extract dates)
    # use atmosphere files as master list 
    self.atmrgx = re.compile(self.atmpfx+self.dateform+self.ncext+'$')
    # regex to extract dates from filenames
    self.dateregx = re.compile(self.dateform)
      
  def getDataDir(self):
    # universal wrapper method for folder with "master-filelist"
    if self.folder: return self.AtmDir # use atmosphere folder as master
    else: return None # None if no folder is set
    
  def extractDate(self, filename, zero=2000):
    # method to generate date tuple from date string in filename
    # match valid filenames
    match = self.atmrgx.match(filename) # return match object
    if match is None:
      return None # if the filename doesn't match the regex
    else:
      # extract date string
      datestr = self.dateregx.search(filename).group()
      # split date string into tuple 
      year, month, day, second = datestr.split('-')
#      if year[0] == '0': year = int(year)+zero # start at year 2000 (=0000)
#      else: 
      year = int(year)
      month = int(month); day = int(day)
      hour = int(second)/3600 
      return (year, month, day, hour)
  
  def setup(self, src, dst, lsymlink=False):          
    # method to copy dataset specific files and folders working directory
    # executables   
    if lsymlink:
      cwd = os.getcwd()
      os.chdir(dst)
      # use current directory
      os.symlink(src+self.unccsm_exe, self.unccsm_exe)
      os.symlink(src+self.unncl_ncl, self.unncl_ncl)
      os.chdir(cwd)
    else:
      shutil.copy(src+self.unccsm_exe, dst)
      shutil.copy(src+self.unncl_ncl, dst)

  def cleanup(self, tgt):
    # method to remove dataset specific files and links
    cwd = os.getcwd()
    os.chdir(tgt)
    # use current directory    
    os.remove(self.unccsm_exe)
    os.remove(self.unncl_ncl)
    os.chdir(cwd)

  def ungrib(self, date, mytag):
    # method that generates the WRF IM file for metgrid.exe
    # create formatted date string
    datestr = self.datestr%(date[0],date[1],date[2],date[3]*3600) # not hours, but seconds...
    # create links to relevant source data (requires full path for linked files)
    atmfile = self.atmpfx+datestr+self.ncext
    os.symlink(self.AtmDir+atmfile,self.atmlnk)
    lndfile = self.lndpfx+datestr+self.ncext
    os.symlink(self.LndDir+lndfile,self.lndlnk)
    icefile = self.icepfx+datestr+self.ncext
    if os.path.exists(self.IceDir+icefile):
      os.symlink(self.IceDir+icefile,self.icelnk)
      print('\n '+mytag+' Processing time-step:  '+datestr+'\n    '+atmfile+'\n    '+lndfile+'\n    '+icefile)
    else:
      print('\n '+mytag+' Processing time-step:  '+datestr+'\n    '+atmfile+'\n    '+lndfile)
    
    ##  convert data to intermediate files
    # run unccsm tool chain
    # run NCL script (suppressing output)
    print('\n  * '+mytag+' interpolating to pressure levels (eta2p.ncl)')
    fncl = open(self.unncl_log, 'a') # NCL output and error log
    if lscinet:
      # On SciNet we have to pass this command through the shell, so that the NCL module is loaded.
      subprocess.call(self.NCL_ETA2P, shell=True, stdout=fncl, stderr=fncl)
    else:
      # otherwise we don't need the shell and it's a security risk
      subprocess.call([NCL,self.unncl_ncl], stdout=fncl, stderr=fncl)  
    fncl.close()          
    # run unccsm.exe
    print('\n  * '+mytag+' writing to WRF IM format (unccsm.exe)')
    funccsm = open(self.unccsm_log, 'a') # unccsm.exe output and error log
    subprocess.call([self.UNCCSM], stdout=funccsm, stderr=funccsm)   
    funccsm.close()
    # cleanup
    os.remove(self.atmlnk)
    os.remove(self.lndlnk)
    os.remove(self.icelnk)
    os.remove(self.nclfile)    # temporary file generated by NCL script 
    # renaming happens outside, so we don't have to know about metgrid format
    return self.preimfile
    

## import local settings from file
#sys.path.append(os.getcwd()+'/meta')
#from namelist import *
#print('\n Loading namelist parameters from '+meta+'/namelist.py:')
#import imp # to import namelist variables
#nmlstpy = imp.load_source('namelist_py',meta+'/namelist.py') # avoid conflict with module 'namelist'
#localvars = locals()
## loop over variables defined in module/namelist  
#for var in dir(nmlstpy):
#  if ( var[0:2] != '__' ) and ( var[-2:] != '__' ):
#    # overwrite local variables
#    localvars[var] = nmlstpy.__dict__[var]
#    print('   '+var+' = '+str(localvars[var]))
#print('')


## subroutines

## function to divide a list fairly evenly 
def divideList(genericlist, n):
  nlist = len(genericlist) # total number of items
  items = nlist // n # items per sub-list
  rem = nlist - items*n
  # distribute list items
  listoflists = []; ihi = 0 # initialize
  for i in xrange(n):
    ilo = ihi; ihi += items # next interval
    if i < rem: ihi += 1 # these intervals get one more
    listoflists.append(genericlist[ilo:ihi]) # append interval to list of lists
  # return list of sublists
  return listoflists

## parallel pre-processing function
# N.B.: this function has some shared variables for folder names and regx'
# function to process filenames and check dates
def processFiles(filelist, queue):
#  # some old code with interesting regex handling
#  files = [atmrgx.match(file) for file in filelist] # parse (partial) filelist for atmospheric model (CAM) output  
#  atmfiles = [match.group() for match in files if not match is None] # list of time steps from atmospheric output
#  files = [dateregx.search(atmfile) for atmfile in atmfiles]
#  dates = [match.group() for match in files if not match is None]
  okdates = [] # list of valid dates
  # loop over dates
  for filename in filelist:
    # figure out time and date
    date = dataset.extractDate(filename)
    # collect valid dates
    if date: # i.e. not 'None'
      # check date for validity (only need to check first/master domain)      
      lok = time.checkDate(date, starts[0], ends[0])
      # collect dates within range
      if lok: okdates.append(date)
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
  shutil.copy(nmlstwps, mydir)
  # change working directory to process sub-folder
  os.chdir(mydir)
  # link dataset specific files
  dataset.setup(src=Tmp, dst=MyDir, lsymlink=True)
  # link other source files
  os.symlink(Meta, meta[:-1]) # link to folder
  # link geogrid (data) and metgrid
  os.symlink(Tmp+metgrid_exe, metgrid_exe)
  for i in doms: # loop over all geogrid domains
    geoname = geopfx%(i)+ncext
    os.symlink(Tmp+geoname, geoname)
  
  ## loop over (atmospheric) time steps
  if dates: print('\n '+mytag+' Looping over Time-steps:')
  else: print('\n '+mytag+' Nothing to do!')
  # loop over date-tuples
  for date in dates:
    
    # figure out sub-domains
    ldoms = [True,]*maxdom # first domain is always computed
    for i in xrange(1,maxdom): # check sub-domains
      ldoms[i] = time.checkDate(date, starts[i], ends[i])
    # update date string in namelist.wps
    imdate = imform%date
    imfile = impfx+imdate
    time.writeNamelist(nmlstwps, ldoms, imdate, imd, isd, ied)
    
    # N.B.: in case the stack size limit causes segmentation faults, here are some workarounds
    # subprocess.call(r'ulimit -s unlimited; ./unccsm.exe', shell=True)
    # import resource
    # subprocess.call(['./unccsm.exe'], preexec_fn=resource.setrlimit(resource.RLIMIT_STACK,(-1,-1)))
    # print resource.getrlimit(resource.RLIMIT_STACK)
      
    ## prepare WPS processing 
    # run ungrib.exe or equivalent operation
    preimfile = dataset.ungrib(date, mytag) # need 'mytag' for status messages
    # rename intermediate file according to WPS convention (by date)
    os.rename(preimfile, imfile) # not the same as 'move'
    
    ## run WPS' metgrid.exe on intermediate file
    # run metgrid_exe.exe
    print('\n  * '+mytag+' interpolating to WRF grid (metgrid.exe)')
    fmetgrid = open(metgrid_log, 'a') # metgrid.exe standard out and error log    
    subprocess.call([METGRID], stdout=fmetgrid, stderr=fmetgrid) # metgrid.exe writes a fairly detailed log file
    fmetgrid.close()
    
    ## finish time-step
    os.remove(MyDir+imfile) # remove intermediate file after metgrid.exe completes
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
    
      
  ## clean up after all time-steps
  # link other source files
  os.remove(meta[:-1]) # link to folder
  dataset.cleanup(tgt=MyDir)
  os.remove(metgrid_exe)
  for i in doms: # loop over all geogrid domains
    os.remove(geopfx%(i)+ncext)
    
    
if __name__ == '__main__':
      
        
    ##  prepare environment
    # figure out root folder
    Root = os.getcwd() + '/' # use current directory
    # direct temporary storage
    if Ram:       
      Tmp = Ram + tmp # direct temporary storage to ram disk
      if ldata: Data = Ram + data # temporary data storage (in memory)
#      # provide link to ram disk directory for debugging      
#      if not lscinet and not (os.path.isdir(ramlnk) or os.path.islink(ramlnk[:-1])):
#        os.symlink(Ram, ramlnk)
    else:      
      Tmp = Root + tmp # use local directory
      if ldata: Data = Root + data # temporary data storage (just moves here, no copy)      
    # create temporary storage  (file system or ram disk alike)
    if os.path.isdir(Tmp):       
      shutil.rmtree(Tmp) # clean out entire directory
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
    # parse namelist parameters
    imd, maxdom, isd, startdates, ied, enddates = time.readNamelist(nmlstwps)
    # figure out domains
    starts = [time.splitDateWRF(sd) for sd in startdates]
    ends = [time.splitDateWRF(ed) for ed in enddates]
    doms = range(1,maxdom+1) # list of domain indices
        
    # copy meta data to temporary folder
    shutil.copytree(meta,Meta)
    shutil.copy(metgrid_exe, Tmp)
    shutil.copy(nmlstwps, Tmp)
    for i in doms: # loop over all geogrid domains
      shutil.copy(geopfx%(i)+ncext, Tmp)
    # N.B.: shutil.copy copies the actual file that is linked to, not just the link
    # change working directory to tmp folder
    os.chdir(Tmp)
    
    # create dataset instance
    if dataset  == 'CESM': 
      dataset = CESM(folder=Root)
    else:
      # for backwards compatibility
      dataset = CESM(folder=Root)
    # setup working directory with dataset specific stuff
    dataset.setup(src=Root, dst=Tmp) #
    DataDir = dataset.getDataDir() # should be absolute path
    
    
    ## multiprocessing
    
    # search for files and check dates for validity
    listoffilelists = divideList(os.listdir(DataDir), NP)
    # divide file processing among processes
    procs = []; queues = []
    for pid in xrange(NP):
      q = multiprocessing.Queue()
      queues.append(q)
      p = multiprocessing.Process(name=pname%pid, target=processFiles, args=(listoffilelists[pid], q))
      procs.append(p)
      p.start() 
    # terminate sub-processes and collect results    
    dates = [] # new date list with valid dates only
    for pid in xrange(NP):
      dates += queues[pid].get()
      procs[pid].join()
    
    # divide up dates and process time-steps
    listofdates = divideList(dates, NP)   
    # create processes
    procs = []; ilo = 0; ihi = 0
    for pid in xrange(NP):
      p = multiprocessing.Process(name=pname%pid, target=processTimesteps, args=(pid, listofdates[pid]))
      procs.append(p)
      p.start()     
    # terminate sub-processes
    for p in procs:
      p.join()
      
    # clean up files
    os.chdir(Tmp)
    dataset.cleanup(tgt=Tmp)
    os.remove(metgrid_exe)
    # N.B.: remember to remove *.nc files in meta-folder!
