'''
Created on 2012-09-19

A Python module to read WRF I/O-config entries (ascii text files) and write the changes 
to I/O streams into the WRF Registry  

@author: Andre R. Erler
'''

# imports
import fileinput # read the I/O config and write the registry file 
import sys # write to stdout (used with fileinput)
import warnings # alert the user of syntax errors
import shutil # copy the original

## settings 
# full path to I/O config file
ioconfigfile = '/home/me/Models/WRF Tools/misc/registry/test/ioconfig.test' 
# full path to WRF registry file (destination)
registryfile = '/home/me/Models/WRF Tools/misc/registry/test/Registry.EM_COMMON'
# full path to WRF registry file (source) 
oldregistry  = '/home/me/Models/WRF/WRFV3/Registry/Registry.EM_COMMON.original'
# more settings 
recurse = False # also apply changes to 'included' registry files (currently not implemented)

# start execution
if __name__ == '__main__':
  
  ## read I/O config file  
  # load file
  ioconfig = fileinput.FileInput([ioconfigfile]) # apparently AIX doesn't like "mode='r'"
  # parse I/O config, define:
  #  addrm     : operation (True: add, False: remove)
  #  iotype    : I/O stream type (i, r, h)
  #  ioid      : I/O stream ID (0-9, {10}-{23})
  #  variables : List of variables affected by the operation
  streamno = 0
  for line in ioconfig:
    # check that this is not a comment line
    if not '#' in line:
      streamno += 1      
      print('\nProcessing Stream # '+str(streamno))
      feedback = ' the following variables ' # tell the user what we are doing
      err = 0
      # split into tokens
      tokens = [token.strip() for token in line.split(':', 3)] # colon delimiter, max 3 splits, remove white spaces 
      # operation: addrm
      if tokens[0] == '+': 
        addrm = True
        feedback = 'Adding' + feedback + 'to '  
      elif tokens[0] == '-': 
        addrm = False
        feedback = 'Removing' + feedback + 'from '
      else: 
        addrm = None
        err += 1
        warnings.warn('WARNING: No legal operation: '+tokens[0]+' \n'+line)
      # stream type: iotype
      if tokens[1] == 'i': 
        iotype = 'i'
        feedback = feedback + 'input' 
      elif tokens[1] == 'r': 
        iotype = 'r'
        feedback = feedback + 'restart' 
      elif tokens[1] == 'h': 
        iotype = 'h'
        feedback = feedback + 'history'
      else:
        iotype = None 
        err += 1
        warnings.warn('WARNING: No legal stream type: '+tokens[1]+' \n'+line)
      # stream id/number: ioid
      try:
        ioid = int(tokens[2])        
      except ValueError:
        ioid = None
        err += 1
        warnings.warn('WARNING: No legal stream ID: '+tokens[3]+' \n'+line)
      feedback = feedback + ' stream # ' + tokens[2]
      # list of variables
      variables = tokens[3].split(',')
      feedback = feedback + ':\n ' + variables[0]
      for variable in variables[1:]:
        feedback += ', ' + variable
      # print feedback (tell user what we are doing)
      if err == 0:
        print(feedback)
        
      # debugging output
      print
      print 'Debugging Info:'
      print addrm
      print iotype
      print ioid
      print variables
      print
            
  # close I/O config file
  fileinput.close()
      
  ## rewrite WRF registry
  # copy the original to the new destination (if given) 
  if oldregistry:
    shutil.copy(oldregistry, registryfile)
  # open with fileinput for editing
  registry = fileinput.FileInput([registryfile], inplace=True) # apparently AIX doesn't like "mode='r'"
  # loop over lines
  oldline = '' # used to reassemble line continuations
  for line in registry:
    line = line.strip() # remove leading/trailing spaces
    # reassemble line continuations
    if oldline:
      line = oldline + line # oldline will be empty is line is self-contained
    # check for more line continuation 
    if line[-1] == "\\": # need to escape backslash
      oldline = line[:-1] # remove backslash
    # if the line is complete, process it  
    else:
      # skip comments and empty lines
      if (line == '') or (line[0] == '#'):
        sys.stdout.write(line+'\n')
      # check for affected variables
      else:
        tokens = line.split(None, 8) # white space delimiter, max 8 splits (to keep names and units intact)
        newline = tokens[0]
        for token in tokens[1:]:
          newline = newline + '    ' + token
        sys.stdout.write(newline+'\n')
      oldline = '' # lines must not grow indefinitely
  # close WRF registry file
  fileinput.close()
  