'''
Created on 2013-02-08

Short script to estimate expected queue wait times. 

@author: Andre R. Erler
'''

# imports
import socket # recognizing host 
import subprocess
# maybe imports ...
import os # directory operations
import fileinput # reading and writing config files
import shutil # file operations
import sys # writing to stdout
import datetime # to compute run time
import calendar # to locate leap years

##  determine if we are on SciNet or my local machine
hostname = socket.gethostname()
if (hostname=='komputer') or (hostname=='erlkoenig'):
  showq = 'cat queue-test.txt' # test dummy
elif ('gpc' in hostname):
  showq = 'showq -w class=largemem'

if __name__ == '__main__':
  
  ## parse queue query output
  running = []
  idle = []
  # query queue
  cmd = subprocess.Popen(showq, shell=True, stdout=subprocess.PIPE)
  # parse output
  for line in cmd.stdout:
    lrun = lidl = False # reset
    if "Running" in line: lrun = True 
    elif "Idle" in line: lidl = True
    # process time
    if lrun or lidl: 
      time = line.split()[4]
      # convert time format... 
      if lrun: print 'Running: %s'%time  
      elif lidl: print 'Idle: %s'%time
      
  
  ## estimate total wait time
  pass