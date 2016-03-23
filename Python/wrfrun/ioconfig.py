#!/usr/bin/python
'''
Created on 2012-09-19

A Python module to read WRF I/O-config entries (ascii text files) and write the changes 
to I/O streams into WRF Registry files

@author: Andre R. Erler, GPL v3
'''

# imports
import fileinput # read the I/O config and write the registry file 
import sys # write to stdout (used with fileinput)
import warnings # alert the user of syntax errors
import shutil # copy the original
import re # to parse I/O strings
import os # to read environment variables

## settings
#if os.environ.has_key('WRFSRC'):
#  WRFSRC = os.environ['WRFSRC'] # WRF source folder
#elif os.environ.has_key('MODEL_ROOT'):
#  WRFSRC = os.environ['MODEL_ROOT'] + '/WRF/WRFV3/' # WRF source folder
#else:
#  WRFSRC = os.environ['HOME'] + '/WRF/WRFV3/' # WRF source folder
WRFSRC = os.getcwd() # WRF source folder
# full path to I/O config file
if len(sys.argv) > 1:
  ioconfigfile = WRFSRC + '/' + sys.argv[1]
else:
  ioconfigfile = WRFSRC + '/config/registry/ioconfig.fineIO'
# full path to WRF registry file (destination)
newregfolder = WRFSRC + '/Registry/'
newregfiles = ['Registry.EM','Registry.EM_COMMON','registry.diags','registry.flake']
# full path to WRF registry file (source) 
oldregfolder = WRFSRC + '/Registry/original/'
oldregfiles = [] or newregfiles
# more settings
lstate = True # only operate on state-variables (faster) 
ltable = False # search table field instead of variable field (e.g. you can remove all state variables)
lrmall = True # allow keyword 'all' as stream ID to remove all stream IDs for a variable 
lrecurse = False # also apply changes to 'included' registry files
# N.B.: even though the recursion works, due to this option, apparently some files get modified that should not be touched, so that WRF does not build anymore
ldebug = True # print all changes to I/O string

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
    if len(iostrs) == 1: iostrs.append('') 
    assert len(iostrs) == 2 
    iostr = irh.findall(iostr) # the I/O stream we are operating on
    if len(iostr) == 0: iostr.append('') 
    assert len(iostr) == 1 
    iostr = iostr[0]
  # string representation of I/O stream
  if isinstance(ioid, str):
    assert ioid == 'all' # this is the only legal keyword, otherwise only numbers
    ioidstr = ioid
    ddstr = ''
  else:
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
  # add implicit zero before processing further
  if (iostr == iotype) and (ddstr == ''): iostr = iostr + '0' 
  ## add stream
  if addrm:
    # just write stream type and ID if not yet present
    if iostr == '': 
      iostr = iotype + ioidstr
    # if stream type is already present add new ID
    else:
      # add new stream is not already present
      if ioidstr not in iostr:
        iostr = iostr + ioidstr
  ## remove stream
  else:
    # remove all streams
    if lrmall and (ioidstr == 'all'):
      iostr = ''
    # remove an existing stream (if actually present)
    elif ioidstr in iostr:
      iostr = iostr.replace(ioidstr,'')
      # remove stream to avoid implicit zero
      if (iostr == iotype) and (ddstr == ''): iostr = ''
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
  #  line      : line number in ioconfig file
  #  addrm     : operation (True: add, False: remove)
  #  iotype    : I/O stream type (i, r, h)
  #  ioid      : I/O stream ID (0-9, {10}-{23})
  #  variables : List of variables affected by the operation
  #  counts    : Number of operations for each variable
  entryno = 0
  entrylist = []
  lineno = 0
  for line in ioconfig:
    lineno += 1
    # check that this is not a comment line
    if (line != '\n') and ('#' not in line):
      entryno += 1     
      tmpdict = dict() # dictionary of parameters 
      tmpdict['line'] = lineno # with line number as first parameter
      if ldebug:
        print('') 
        print('Reading I/O config Entry # '+str(entryno))
        feedback = ' the following variables ' # tell the user what we are doing
      err = 0
      # split into tokens
      tokens = [token.strip() for token in line.lower().split(':', 3)] # colon delimiter, max 3 splits, remove white spaces 
      # operation: addrm
      if tokens[0] == '+': 
        addrm = True
        if ldebug: feedback = '  Adding' + feedback + 'to '  
      elif tokens[0] == '-': 
        addrm = False
        if ldebug: feedback = '  Removing' + feedback + 'from '
      else: 
        addrm = None
        err += 1
        warnings.warn('WARNING (line #'+str(ioconfig.filelineno())+'): No legal operation: '+tokens[0]+' \n'+line)
      # save in dictionary
      tmpdict['addrm'] = addrm 
      # stream type: iotype
      if tokens[1] == 'i': 
        iotype = 'i'
        if ldebug: iotypetmp = 'input' # used below 
      elif tokens[1] == 'r': 
        iotype = 'r'
        if ldebug: iotypetmp = 'restart' # used below 
      elif tokens[1] == 'h': 
        iotype = 'h'
        if ldebug: iotypetmp = 'history' # used below
      else:
        iotype = None 
        err += 1
        warnings.warn('WARNING: No legal stream type: '+tokens[1]+' \n'+line)
      # save in dictionary
      tmpdict['iotype'] = iotype
      # stream id/number: ioid
      if lrmall and (not addrm) and (tokens[2] == 'all'):
        ioid = 'all'
        if ldebug: feedback = '  Removing the following variables from all ' + iotypetmp + ' streams'      
      else:
        try:
          ioid = int(tokens[2])        
        except ValueError:
          ioid = None
          err += 1
          warnings.warn('WARNING: No legal stream ID: '+tokens[3]+' \n'+line)
        if ldebug: feedback = feedback + iotypetmp + ' stream # ' + tokens[2]
      # save in dictionary
      tmpdict['ioid'] = ioid
      # list of variables
      variables = [var for var in tokens[3].lower().split(',') if len(var) > 0]
      if ldebug: 
        feedback = feedback + ':\n   ' + variables[0]
        for variable in variables[1:]:
          feedback += ', ' + variable
      # save in dictionary
      tmpdict['variables'] = variables
      # dictionary with counters
      counts = {var:0 for var in variables} # initialize with zero
      # save in dictionary
      tmpdict['counts'] = counts
      # print feedback (tell user what we are doing)
      if err == 0:
        if ldebug: print(feedback)
        entrylist.append(tmpdict)
      # or exit, if errors occurred
      else:
        sys.exit('\n   >>>   There were errors processign the I/O config file --- aborting! <<<')
        
  # close I/O config file
  fileinput.close()
  
  print('')
  print('')
  print('      ***   ***   ***   ***   ***   ***   ***   ***   ')
  print('')

  # debugging output
  #if ldebug:
  #  print('')
  #  print('Debugging Info:')
  #  print(lineno)
  #  print(addrm)
  #  print(iotype)
  #  print(ioid)
  #  print(variables)
  #  print(counts)
  #  print('')
  
  ## make backup copy is not already there
  if not os.path.exists(oldregfolder):
    shutil.copytree(newregfolder,oldregfolder)
    # N.B.: this performes in-place manipulation and after creating a backup

  ## loop over and rewrite WRF registry files
  baseno = len(newregfiles) # original number of files
  fileno = 0 # file counter
  while fileno < len(newregfiles):
    # grab files to work on        
    newregfile = newregfiles[fileno]
    oldregfile = oldregfiles[fileno]
    fileno += 1 # move up counter
    if not os.path.exists(oldregfolder+oldregfile):
      print('')
      print('   ***   Registry file '+oldregfile+' not found!  ***   ')
      print('')
    else:
      # announce files
      print('')
      print('   ***   Processing Registry file: '+newregfile+'   ***   ')
      if fileno > baseno: print('            (file was automatically included)')
      print('')
      # copy the original to the new destination (if given) 
      if oldregfolder:
        shutil.copy(oldregfolder+oldregfile, newregfolder+newregfile)
      
      ## loop over I/O config entries
      entryno = 0 # I/O entry counter
      for entry in entrylist:
        entryno += 1
        # open with fileinput for editing
        registry = fileinput.FileInput([newregfolder+newregfile], inplace=True) # apparently AIX doesn't like "mode='r'"
        # regurgitate parameter values
        entryline = entry['line'] # line number of entry, for reference
        addrm = entry['addrm'] # operation (True: add, False: remove)
        iotype = entry['iotype'] # I/O stream type (i, r, h)
        ioid = entry['ioid'] # I/O stream ID (0-9, {10}-{23})
        variables = entry['variables'] # List of variables affected by the operation
        counts = entry['counts'] # dict with counters for variables, initialized to 0
        # save list of changes
        if ldebug: changelog = []
        # loop over lines
        oldline = '' # used to reassemble line continuations
        
        ## loop over lines
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
              if (len(tokens) == 9) and ((not lstate) or (tokens[0].lower() == 'state')):
                # decide which column to go by
                if ltable: mode = 0 # process all of a type
                else: mode = 2 # process by variable name
                # loop over variable list
                for var in variables:
                  # search for variable name in 3rd field (all lower case)
                  if tokens[mode].lower() == var.lower():
                    counts[var] += 1 # count operations per variables
                    oldiostr = tokens[7].lower()
                    ## here comes the editing of the actual I/O string
                    newiostr = processIOstream(oldiostr, addrm, iotype, ioid)
                    # save modifications in string and add to change-log              
                    if ldebug: 
                      if oldiostr != newiostr:
                        changelog.append(tokens[2]+':  '+oldiostr+'  >>>  '+newiostr) # use actual variable name                 
                    tokens[7] = newiostr
                # write modified line into file
                newline = tokens[0]
                for token in tokens[1:]:
                  newline = newline + '    ' + token
                sys.stdout.write(newline+'\n')
              elif lrecurse and (tokens[0].lower() == 'include'):
                newregfiles.append(tokens[1])
                oldregfiles.append(tokens[1])
              # if the line doesn't have 9 tokens, it is something else...
              else:
                sys.stdout.write(line+'\n')
            oldline = '' # lines must not grow indefinitely
  
        # close WRF registry file
        fileinput.close()
        entry['counts'] = counts # save updated counts
      
        # print debugging info / change-log
        if ldebug:
          print('')
          print('Processed I/O config Entry #{:d} (line {:d})'.format(entryno,entryline))
          print('  Log of changes:')
          if len(changelog) == 0:
            print('   no changes')
          else:
            for line in changelog:
              print('   '+line)
          print('')
          for var,cnt in counts.iteritems():
              if cnt == 0: print('    {:s} not found/used'.format(var))
      
  # print summary
  print('')
  entryno = 0 # I/O entry counter
  for entry in entrylist:
    entryno += 1
    #print('')
    if entry['addrm']:
      # loop over variables
      for var,cnt in entry['counts'].iteritems():
          if cnt == 0 : print('\n    {:s} not found/used in entry #{:d}, line {:d}'.format(var,entryno,entry['line']))
  print('')


