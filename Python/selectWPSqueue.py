'''
Created on 2013-02-08

Short script to estimate expected queue wait times.

@author: Andre R. Erler
'''

# imports
import socket # recognizing host
import subprocess
import warnings
import numpy
# maybe imports ...
import os # directory operations
#import fileinput # reading and writing config files
#import shutil # file operations
#import sys # writing to stdout
#import datetime # to compute run time
#import calendar # to locate leap years

## Settings
# environment variables (set by caller instance)
WRFWCT = os.getenv('WRFWCT')
WPSWCT = os.getenv('WPSWCT')
WPSSCRIPT = os.getenv('WPSSCRIPT')
NEXTSTEP = os.getenv('NEXTSTEP')
# machine-specific setup
hostname = socket.gethostname()
if (hostname=='komputer') or (hostname=='erlkoenig'):
  # this is for test purpose only
  nodes = 2 # number of nodes
  ppn = 16 # processes per node
  showq = 'cat queue-test.txt' # test dummy
  submitPrimary = 'echo qsub %s -v NEXTSTEP=%s -l nodes=1:m128g:ppn=16 -q largemem'%(WPSSCRIPT,NEXTSTEP)
  submitSecondary = 'echo qsub %s -v NEXTSTEP=%s -l nodes=1:m32g:ppn=8 -q batch'%(WPSSCRIPT,NEXTSTEP)
elif ('gpc' in hostname):
  # we need to know something about the queue system...
  nodes = 2 # number of nodes
  ppn = 16 # processes per node
  showq = 'showq -w class=largemem' # queue query command
  submitPrimary = 'qsub %s -v NEXTSTEP=%s -l nodes=1:m128g:ppn=16 -q largemem'%(WPSSCRIPT,NEXTSTEP)
  submitSecondary = 'qsub %s -v NEXTSTEP=%s -l nodes=1:m32g:ppn=8 -q batch'%(WPSSCRIPT,NEXTSTEP)

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
    warnings.warn('WARNING: invalid time format encountered: %s'%time)
    time = 0
  # return value in seconds (integer)
  return time

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
      np =  int(linesplit[3])
      if np != 16 and np != 32: print('WARNING: strange number of processes: %i'%np)
      np = np / ppn
      time = linesplit[4]
#      # print times
#      if lrun: print 'Running: %s'%time
#      elif lidl: print 'Idle: %s'%time
      # convert time string to integer seconds
      time = convertTime(time)
      # save timings
      while np > 0:
        if lrun: running.append(time)
        elif lidl: idle.append(time)
        np = np - 1

  ## estimate total wait time
  # one time slot for each running process
  slots = numpy.zeros(nodes,dtype=int) # integer seconds
  # distribute running jobs to nodes
  assert len(running) <= len(slots), warnings.warn('WARNING: number of nodes and number of running jobs inconsistent: %s'%len(running))
  for i in xrange(len(running)):
    slots[i] = running[i]
#  print slots
  # distribute idle jobs to nodes
  for i in xrange(len(idle)):
    slots[slots.argmin()] += idle[i]
#  print slots

  ## launch WPS according to estimated wait time
  waittime = slots.min()
  #  print waittime
  print('\nEstimated queue wait time is %3.2f hours\n'%(waittime/3600))
  # determine acceptable wait time
  timelimit = 0
  if WPSWCT: timelimit += convertTime(WPSWCT)
  if WRFWCT: timelimit += convertTime(WRFWCT)
  # launch WPS
  if timelimit <= 0:
    print('WARNING: invalid timelimit: %i'%len(timelimit))
    print('   >>> submitting to primary queue system:')
    print(submitPrimary)
    subprocess.Popen(submitPrimary, shell=True)
  elif waittime < timelimit:    
    print('   >>> submitting to primary queue system:')
    print(submitPrimary)
    subprocess.Popen(submitPrimary, shell=True)
  else:
    print('   >>> submitting to secondary queue system:')
    print(submitSecondary)
    subprocess.Popen(submitSecondary, shell=True)


