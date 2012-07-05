'''
Created on 2012-07-04

Python module to read and write dates in Fortran namelists.

@author: Andre R. Erler
'''

import fileinput # reading and writing config files
import sys # writing to stdout

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
def readNamelist(nmlstwps):
  # values to read
  imd = 0 # line index of maxdom
  maxdom = 0 # max number of domains
  isd = 0 # line index of start_date parameter
  #startdates = [] # list of start dates for each domain 
  ied = 0 # line index of end_date parameter
  #enddates = [] # list of end dates for each domain
  # open namelist file for reading 
  file = fileinput.FileInput([nmlstwps], mode='r')
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
def writeNamelist(nmlstwps, ldoms, imdate, imd, isd, ied):
  # assemble date string (':00:00' not necessary for hourly output)
  datestr = ''; imdate = "'"+imdate + "',"  # mind the single quotes!
  ndoms = len(ldoms) # (effective) number of domains for this time step
  while not ldoms[ndoms-1]: ndoms -= 1 # cut of unused domains at the end
  datestr = datestr + imdate*ndoms
  # read file and loop over lines
  file = fileinput.FileInput([nmlstwps], inplace=True)
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
