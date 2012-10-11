#!/usr/bin/python

'''
Created on 2012-03-20

Script to prepare CCSM/CESM input data and run the WPS/metgrid_exe.exe tool chain, 
in order to generate input data for WRF/real.exe.

@author: Andre R. Erler
'''

##  imports
import socket # recognizing host 
import imp # to import namelist variables
import os # directory operations
import shutil # copy and move
import re # regular expressions
import subprocess # launching external programs
import multiprocessing # parallelization
# my modules
from namelist import time

##  determine if we are on SciNet or my local machine
hostname = socket.gethostname()
if (hostname=='komputer'):
  # my local workstation
  lscinet = False
  Ram = '/media/tmp/' # ramdisk folder to be used for temporary storage
  Root = ''
  # use this cmd to mount: sudo mount -t ramfs -o size=100m ramfs /media/tmp/
  # followed by: sudo chown me /media/tmp/
  # sudo mount -t ramfs -o size=100m ramfs /media/tmp/ && sudo chown me /media/tmp/
  # and this to unmount:   sudo umount /media/tmp/
  Model = '/home/me/Models/'
  NCARG = '/usr/local/ncarg/'
  NCL = '/usr/local/ncarg/bin/ncl'
  NP = 2
elif (hostname=='erlkoenig'):
  # my laptop
  lscinet = False
  Ram = '/media/tmp/' # tmpfs folder to be used for temporary storage
  # (leave Ram directory blank if tmpfs will be in test directory)
  Root = '' # '/media/data/DATA/WRF/test/WPS/'
  # use this cmd to mount: 
  # sudo mount -t tmpfs -o size=200m tmpfs /media/tmp/ && sudo chown me /media/tmp/
  # and this to unmount: sudo umount /media/tmp/
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
  NCARG = '/scinet/p7/Applications/ncl/6.0.0/'
  NCL = '/scinet/p7/Applications/ncl/6.0.0/bin/ncl'
  NP = 32
  
##  Default Settings (may be overwritten by in meta/namelist.py)
prefix = '' # 'cesm19752000v2', 'cesmpdwrf1x1'
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
unncl_ncl = 'unccsm.ncl'
unncl_log = 'unccsm.ncl.log'
unccsm_exe = 'unccsm.exe'
unccsm_log = 'unccsm.exe.log'
metgrid_exe = 'metgrid.exe'
metgrid_log = 'metgrid.exe.log'
nmlstwps = 'namelist.wps'
##  data sources
ncext = '.nc'
dateform = '\d\d\d\d-\d\d-\d\d-\d\d\d\d\d'
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

## import local settings from file
#sys.path.append(os.getcwd()+'/meta')
#from namelist import *
#print('\n Loading namelist parameters from '+meta+'/namelist.py:')
#nmlstpy = imp.load_source('namelist_py',meta+'/namelist.py') # avoid conflict with module 'namelist'
#localvars = locals()
## loop over variables defined in module/namelist  
#for var in dir(nmlstpy):
#  if ( var[0:2] != '__' ) and ( var[-2:] != '__' ):
#    # overwrite local variables
#    localvars[var] = nmlstpy.__dict__[var]
#    print('   '+var+' = '+str(localvars[var]))
#print('')

# dependent variables 
NCL_ETA2P = NCL + ' ' + unncl_ncl
UNCCSM = './' + unccsm_exe
METGRID = './' + metgrid_exe

## subroutines

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
    date = time.splitDateCCSM(datestr)
    # check date for validity (only need to check first/master domain)
    lok = time.checkDate(date, starts[0], ends[0])
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
  shutil.copy(nmlstwps, mydir)
  # change working directory to process sub-folder
  os.chdir(mydir)
  # link other source files
  os.symlink(Meta, meta[:-1]) # link to folder
  os.symlink(Tmp+unccsm_exe, unccsm_exe)
  os.symlink(Tmp+unncl_ncl, unncl_ncl)
  os.symlink(Tmp+metgrid_exe, metgrid_exe)
  for i in doms: # loop over all geogrid domains
    geoname = geopfx%(i)+ncext
    os.symlink(Tmp+geoname, geoname)
  
  ## loop over (atmospheric) time steps
  if dates: print('\n '+mytag+' Looping over Time-steps:')
  else: print('\n '+mytag+' Nothing to do!')

  for datestr in dates:
    
    # convert time and date
    date = time.splitDateCCSM(datestr)
    # figure out sub-domains
    ldoms = [True,]*maxdom # first domain is always computed
    for i in xrange(1,maxdom): # check sub-domains
      ldoms[i] = time.checkDate(date, starts[i], ends[i])
      
    # prepare processing 
    # create links to relevant source data (requires full path for linked files)
    atmfile = atmpfx+datestr+ncext
    os.symlink(AtmDir+atmfile,atmlnk)
    lndfile = lndpfx+datestr+ncext
    os.symlink(LndDir+lndfile,lndlnk)
    icefile = icepfx+datestr+ncext
    if os.path.exists(IceDir+icefile):
      os.symlink(IceDir+icefile,icelnk)
      print('\n '+mytag+' Processing time-step:  '+datestr+'\n    '+atmfile+'\n    '+lndfile+'\n    '+icefile)
    else:
      print('\n '+mytag+' Processing time-step:  '+datestr+'\n    '+atmfile+'\n    '+lndfile)
    
    ##  convert data to intermediate files
    # run NCL script (suppressing output)
    print('\n  * '+mytag+' interpolating to pressure levels (eta2p.ncl)')
    fncl = open(unncl_log, 'a') # NCL output and error log
    if lscinet:
      # On SciNet we have to pass this command through the shell, so that the NCL module is loaded.
      subprocess.call(NCL_ETA2P, shell=True, stdout=fncl, stderr=fncl)
    else:
      # otherwise we don't need the shell and it's a security risk
      subprocess.call([NCL,unncl_ncl], stdout=fncl, stderr=fncl)  
    fncl.close()      
    # run unccsm.exe
    print('\n  * '+mytag+' writing to WRF IM format (unccsm.exe)')
    funccsm = open(unccsm_log, 'a') # unccsm.exe output and error log
    subprocess.call([UNCCSM], stdout=funccsm, stderr=funccsm)   
    funccsm.close()
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
    time.writeNamelist(nmlstwps, ldoms, imdate, imd, isd, ied)
    # run metgrid_exe.exe
    print('\n  * '+mytag+' interpolating to WRF grid (metgrid.exe)')
    fmetgrid = open(metgrid_log, 'a') # metgrid.exe standard out and error log    
    subprocess.call([METGRID], stdout=fmetgrid, stderr=fmetgrid) # metgrid.exe writes a fairly detailed log file
    fmetgrid.close()
    
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
    #clean(MyDir, filelist=[imfile])
      
  ## clean up after all time-steps
  # link other source files
  os.remove(meta[:-1]) # link to folder
  os.remove(unccsm_exe)
  os.remove(unncl_ncl)
  os.remove(metgrid_exe)
  for i in doms: # loop over all geogrid domains
    os.remove(geopfx%(i)+ncext)
    
    
if __name__ == '__main__':
      
        
    ##  prepare environment
    # figure out root folder
    if Root:
      Root = Root + '/' # assume GCM name as subdirectory
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
    imd, maxdom, isd, startdates, ied, enddates = time.readNamelist(nmlstwps)
    # figure out domains
    starts = [time.splitDateWRF(sd) for sd in startdates]
    ends = [time.splitDateWRF(ed) for ed in enddates]
    doms = range(1,maxdom+1) # list of domain indices
        
    # copy meta data to temporary folder
    shutil.copytree(meta,Tmp+meta)
    shutil.copy(unccsm_exe, Tmp)
    shutil.copy(unncl_ncl, Tmp)
    shutil.copy(metgrid_exe, Tmp)
    shutil.copy(nmlstwps, Tmp)
    for i in doms: # loop over all geogrid domains
      shutil.copy(geopfx%(i)+ncext, Tmp)
    # N.B.: shutil.copy copies the actual file that is linked to, not just the link
    # change working directory to tmp folder
    os.chdir(Tmp)
    # set environment variable for NCL (on tmp folder)   
    os.putenv('NCARG_ROOT', NCARG) 
    os.putenv('NCL_POP_REMAP', meta) # NCL is finicky about space characters in the path statement, so relative path is saver
    os.putenv('MODEL_ROOT', Model) # also for NCL (where personal function libs are)
    
    # number of processes NP 
    if os.environ.has_key('PYWPS_THREADS'):
      NP = int(os.environ['PYWPS_THREADS']) # default is set above (machine specific)
    
    # get file prefix for data files
    if not prefix:
#      prefix = 'cesmpdwrf1x1' # or 'tb20trcn1x1' file prefix for CESM output
      # use only atmosphere files
      prergx = re.compile(atmpfx+dateform+ncext+'$')
      # search for first valid filename
      for file in os.listdir(AtmDir):
        match = prergx.search(file) 
        if match: break
      prefix = file[0:match.start()] # use everything before the pattern as prefix
      # print prefix
      print('\n No data prefix defined; inferring prefix from valid data files in directory '+AtmDir)
      print('  prefix = '+prefix)
    
    # compile regular expressions
    dateregx = re.compile(dateform)
    # atmosphere
    if prefix: atmpfx = prefix+atmpfx
    atmrgx = re.compile(atmpfx+dateform+ncext+'$')
    # land
    if prefix: lndpfx = prefix+lndpfx
    lndrgx = re.compile(lndpfx+dateform+ncext+'$')
    # ice
    if prefix: icepfx = prefix+icepfx
    icergx = re.compile(icepfx+dateform+ncext+'$')

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
    os.remove(unncl_ncl)
    os.remove(unccsm_exe)
    os.remove(metgrid_exe)
    # N.B.: remember to remove *.nc files in meta-folder!
