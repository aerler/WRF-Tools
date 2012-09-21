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
import re # to parse I/O strings

## settings 
# full path to I/O config file
ioconfigfile = '/home/me/Models/WRF Tools/misc/registry/test/ioconfig.test' 
# full path to WRF registry file (destination)
registryfile = '/home/me/Models/WRF Tools/misc/registry/test/Registry.EM_COMMON'
# full path to WRF registry file (source) 
oldregistry  = '/home/me/Models/WRF/WRFV3/Registry/Registry.EM_COMMON.original'
# more settings 
recurse = False # also apply changes to 'included' registry files (currently not implemented)
debug = True # print all changes to I/O string

## actual editing functions

# globally used regular expressions
dusffct = re.compile(r'[udsf]=\([^()]*\)') # match nesting operations with function specification
dusf = re.compile(r'[udsf]') # match nesting operations without function specification

# fct for pre-conditioning an I/O stream
def processIOstream(oldiostr, addrm, iotype, ioid):
  # regular expression defining the stream we are interested in
  irh = re.compile(iotype+r'[0-9{}]*') # match the required I/O stream
  iostr = oldiostr
  # remove irrelevant fields
  excess = str().join(dusffct.findall(iostr)) # what we don't care about, but need to keep 
  iostr = str().join(dusffct.split(iostr)) # what we are actually interested in
  excess = str().join(dusf.findall(iostr)) + excess
  iostr = str().join(dusf.split(iostr))
  ## process actual I/O streams (and keep order)
  # N.B.: I don't know what happens if multiple instances occur
  # treat '-' as empty field
  if iostr == '-':
    iostrs = ['','']
    iostr = ''
  else:
    iostrs = irh.split(iostr) # list of other I/O streams
    assert len(iostrs) == 2 
    iostr = irh.findall(iostr) # the I/O stream we are operating on 
    assert len(iostr) == 1 
    iostr = iostr[0]
  # string representation of I/O stream
  if ioid > 9:
    assert ioid < 100
    ioidstr = '{%2i}'%ioid
    ddstr = '' # see 'else' below
  else:
    ioidstr = '%1i'%ioid
    # also need to protect double-digit numbers from change
    dd = re.compile(r'{\d\d}')
    ddstr = str().join(dd.findall(iostr))
    iostr = str().join(dd.split(iostr))
  ## add stream
  if addrm:
    # just write stream type and ID if not yet present
    if iostr == '': 
      iostr = iotype + ioidstr
    # if stream type is already present add new ID
    else:
      # add implicit zero
      if iostr == iotype: iostr = iostr + '0' 
      # add new stream is not already present
      if ioidstr not in iostr:
        iostr = iostr + ioidstr
  ## remove stream
  else:
    # remove existing stream (if actually present)
    if ioidstr in iostr:
      iostr = iostr.replace(ioidstr,'')
      # remove stream to avoid implicit zero
      if iostr == iotype: iostr = '' 
  newiostr = str().join([iostrs[0], iostr, ddstr, iostrs[1], excess])
  if newiostr == '': newiostr = '-' # never return empty field
  # return new I/O string
  return newiostr


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
      print('\nProcessing I/O List # '+str(streamno))
      feedback = ' the following variables ' # tell the user what we are doing
      err = 0
      # split into tokens
      tokens = [token.strip() for token in line.lower().split(':', 3)] # colon delimiter, max 3 splits, remove white spaces 
      # operation: addrm
      if tokens[0] == '+': 
        addrm = True
        feedback = '  Adding' + feedback + 'to '  
      elif tokens[0] == '-': 
        addrm = False
        feedback = '  Removing' + feedback + 'from '
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
      variables = tokens[3].lower().split(',')
      feedback = feedback + ':\n   ' + variables[0]
      for variable in variables[1:]:
        feedback += ', ' + variable
      # print feedback (tell user what we are doing)
      if err == 0:
        print(feedback)
        
#      # debugging output
#      if debug:
#        print
#        print 'Debugging Info:'
#        print addrm
#        print iotype
#        print ioid
#        print variables
#        print
            
  # close I/O config file
  fileinput.close()
      
  ## rewrite WRF registry
  # copy the original to the new destination (if given) 
  if oldregistry:
    shutil.copy(oldregistry, registryfile)
  # save list of changes
  if debug: changelog = []
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
    if line[-1:] == '\\': # need to escape backslash
      oldline = line[:-1] # remove backslash
    # if the line is complete, process it  
    else:
      # skip comments and empty lines
      if (line == '') or (line[0] == '#'):
        sys.stdout.write(line+'\n')
      # check for affected variables
      else:
        tokens = line.split(None, 8) # white space delimiter, max 8 splits (to keep names and units intact)
        # N.B.: by limiting the splits to 8, we don't have to deal with the description and unit sections,
        #       which contain white spaces, and would not be easily separable
        ## identify affected variables
        # standard format has 10 entries, but we only split 8 times
        if len(tokens) == 9:
          # loop over variable list
          for var in variables:
            # search for variable name in 3rd field (all lower case)
            if tokens[2].lower() == var.lower():
              oldiostr = tokens[7].lower()
              ## here comes the editing of the actual I/O string
              newiostr = processIOstream(oldiostr, addrm, iotype, ioid)
              # save modifications in string and add to change-log              
              if debug: 
                changelog.append(var+':  '+oldiostr+'  >>>  '+newiostr)                
              tokens[7] = newiostr
          # write modified line into file
          newline = tokens[0]
          for token in tokens[1:]:
            newline = newline + '    ' + token
          sys.stdout.write(newline+'\n')
        # if the line doesn't have 9 tokens, it is something else...
        else:
          sys.stdout.write(line+'\n')
      oldline = '' # lines must not grow indefinitely
  # close WRF registry file
  fileinput.close()
  # print debugging info / change-log
  if debug:
    print('  Log of changes:')
    for line in changelog:
      print('   '+line)
  