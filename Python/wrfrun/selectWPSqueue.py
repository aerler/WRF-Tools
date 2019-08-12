'''
Created on 2013-02-08

Short script to estimate expected queue wait times.

@author: Andre R. Erler
'''

# imports
import subprocess
import warnings
import math
#import numpy
import os # directory operations
#import fileinput # reading and writing config files
#import shutil # file operations
import sys # writing to stdout and exit with exit code
#import datetime # to compute run time
#import calendar # to locate leap years

## Settings
# environment variables (set by caller instance)
WRFWCT = os.getenv('WRFWCT','00:00:00')
WPSWCT = os.getenv('WPSWCT','00:00:00')
NEXTSTEP = os.getenv('NEXTSTEP')
DEBUG = os.getenv('DEBUG')
# machine-specific setup: read from environment (except debug mode)
if DEBUG == 'DEBUG':
  # this is for test purpose only; read file 'queue-test.txt' in same directory
  nodes = 2 # number of nodes
  ppn = (16,20) # possible processes per node
  ppm = max(ppn) # maximum (assuming all are similar)
  showq = 'cat queue-test.txt' # test dummy
  submitPrimary = 'echo qsub WPS_script.pbs -v NEXTSTEP={0:s} -l nodes=1:m128g:ppn=16 -q largemem'.format(NEXTSTEP)
  submitSecondary = 'echo qsub WPS_script.pbs -v NEXTSTEP={0:s} -l nodes=1:m32g:ppn=8 -q batch'.format(NEXTSTEP)
else:
  # we need to know something about the queue system...
  nodes = int(os.getenv('QNDS')) # number of nodes
  ppn = tuple(int(np) for np in os.getenv('QPPN').split(',')) # possible processes per node
  ppm = int(os.getenv('QPPM',max(ppn))) # maximum (assuming all are similar)
  showq = os.getenv('QSHOW') # queue query command
  submitPrimary = os.getenv('QONE').format(NEXTSTEP)
  submitSecondary = os.getenv('QTWO').format(NEXTSTEP)  
  # use only sandy (old form)
  #nodes = 76 # number of nodes
  #ppm = 16 # processes per node
  #showq = 'showq -w class=sandy' # queue query command
  #submitPrimary = 'qsub {:s} -v NEXTSTEP={:s} -l nodes=1:m128g:ppn=16 -q sandy '.format(WPSSCRIPT,NEXTSTEP)
  #submitSecondary = 'qsub {:s} -v NEXTSTEP={:s} -l nodes=1:m128g:ppn=16 -q sandy'.format(WPSSCRIPT,NEXTSTEP)
  # use largemem as primary, 32G as secondary (sandy takes too long, old form)
  # nodes = 4 # number of nodes
  # ppn = (16,20) # possible processes per node
  # ppm = max(ppn) # maximum (assuming all are similar)
  # showq = 'showq -w class=largemem' # queue query command
  # submitPrimary = 'qsub {:s} -v NEXTSTEP={:s} -l nodes=1 -q largemem '.format(WPSSCRIPT,NEXTSTEP)
  # submitSecondary = 'qsub {:s} -v NEXTSTEP={:s} -l nodes=1:m32g:ppn=8 -q batch'.format(WPSSCRIPT,NEXTSTEP)
  #submitPrimary = submitSecondary # temporarily disabled

## functions

# convert time format...
def convertTime(timeString):
  # split into components, delimited by ':'
  tmp = timeString.split(':')
  # determine format
  if len(tmp) == 3: # hours:minutes:seconds
    time = int(tmp[0])*3600 + int(tmp[1])*60 + int(tmp[2])
  elif len(tmp) == 4: # days:hours:minutes:seconds
    time = int(tmp[0])*86400 + int(tmp[1])*3600 + int(tmp[2])*60 + int(tmp[3])
  else: # unknown
    warnings.warn('WARNING: invalid time format encountered: {0:s}'.format(time))
    time = 0
  # return value in seconds (integer)
  return time

# function to find minimum and minimum index in a list
def findMinimum(values):
  # initialize
  jmin = 0
  vmin = values[jmin]
  # search list
  for j in range(1,len(values)):
    if values[j] < vmin:
      vmin = values[j] # save smallest value
      jmin = j # index of smallest value
  # return results
  return vmin, jmin


if __name__ == '__main__':

  ## parse queue query output
  running = []
  idle = []
  # query queue
  cmd = subprocess.Popen(showq, shell=True, stdout=subprocess.PIPE)
  # parse output
  for line in cmd.stdout:
    lrun = lidl = False # reset
    linesplit = line.split()
    if len(linesplit) == 9:
      if "Running" == linesplit[2]: lrun = True
      elif "Idle" == linesplit[2]: lidl = True
    # process time
    if lrun or lidl:
      np =  float(linesplit[3]) # ensure floating point division below: np / ppm
      if np == 1 and lidl: np = 20 # if no specific number is requested, idle jobs just show '1'
      if np not in ppn: print(('WARNING: large number of processes: {0:d} --- possibly multi-node jobs.'.format(int(np))))
      nn = math.ceil(np / ppm) # next full multiple of ppm: number of nodes
      time = linesplit[4]
#      # print times
#      if lrun: print 'Running: {:s}'.format(time)
#      elif lidl: print 'Idle: {:s}'.format(time)
      # convert time string to integer seconds
      time = convertTime(time)
      # save timings
      while nn > 0:
        if lrun: running.append(time)
        elif lidl: idle.append(time)
        nn = nn - 1

  ## estimate total wait time
  # one time slot for each running process
  #slots = numpy.zeros(nodes,dtype=int) # integer seconds
  slots = [int(0) for x in range(nodes)]
  # distribute running jobs to nodes
  if len(running) > len(slots): warnings.warn('WARNING: number of nodes and number of running jobs not equal: {0:s} jobs on {1:d} nodes.'.format(len(running),nodes))
  for i in range(min(len(running),len(slots))):
    slots[i] = running[i]
#  print slots
  # distribute idle jobs to nodes
  for i in range(len(idle)):
    # find smallest slots
    vmin, jmin = findMinimum(slots)
    # assign to smallest slot
    slots[jmin] = vmin + idle[i]
    #slots[slots.argmin()] += idle[i]
#  print slots

  ## launch WPS according to estimated wait time
  vmin, jmin = findMinimum(slots)
  waittime = vmin
  #waittime = slots.min()
  #  print waittime
  print(('\nEstimated queue wait time is {0:3.2f} hours\n'.format(waittime/3600)))
  # determine acceptable wait time
  if WRFWCT:
    timelimit = convertTime(WRFWCT) # basic time limit from WRF execution time
    if WPSWCT: timelimit -= convertTime(WPSWCT) # subtract execution time for WPS
    # launch WPS
    if timelimit <= 0 or waittime < timelimit:    
      print('   >>> submitting to primary queue system:')
      print(submitPrimary)
      subproc=subprocess.Popen(submitPrimary, shell=True)
      exitcode=subproc.wait() # wait for completion and capture exit code
    else:
      print('   >>> submitting to secondary queue system:')
      print(submitSecondary)
      subproc=subprocess.Popen(submitSecondary, shell=True)
      exitcode=subproc.wait() # wait for completion and capture exit code
  else:
    # just launch on primary queue	
    print('WARNING: invalid timelimit!')
    print('   >>> submitting to primary queue system:')
    print(submitPrimary)
    subproc=subprocess.Popen(submitPrimary, shell=True)
    exitcode=subproc.wait() # wait for completion and capture exit code

# N.B.: could capture stdout/stderr with the stdout=subprocess.PIPE and stderr=subprocess.STDOUT
# option and retrieving the string with subproc.communicate()

sys.exit(exitcode) # use exit code from submit command
