#!/usr/bin/env python

"""
This program is used to compress the netcdf history data files in the CESM L1
output. I.e. the raw output files stored under short-term archive.

By "compression", I mean it converts the format of the netCDF file from the classic
format, which does not support compression, to the netCDF4 format with variable
compression. The external nccopy utility is employed for this conversion.

The CLI interface this program provides allows for the specification of the files
to compress by four parameters - the casename, the component name and the start
and end years.

E.g. usage: netCDFcompressor.py case_name 1 10 atm
will compress all atm history files of case 'case_name' for years 1 to 10 in
the short term archive. 

NOTE: Mar 28, 2016: Modified to ensure compatibility with pyhton 3

NOTE: Jun 09, 2016: Adapted for use with WRF output by Fengyi Xie

NOTE: Jun 12, 2016: Updated and adapted for use with 6-hourly CESM output by Andre R. Erler
"""


# Python standard library imports ==============================================
import os
import sys
import glob
import atexit
import logging
import argparse
import subprocess
import multiprocessing
from netCDF4 import Dataset
import numpy as np
from collections import namedtuple
from multiprocessing import Pool, Lock
import os.path as osp
from time import time
from functools import partial

# User library imports =========================================================

from scinet_cesm_utils import which, secondsToStr


# Stuff for comparing two netcdf files >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
def assert_(a, b, msg):
    if (a != b): raise Exception(msg)

def check_files_exist(file1, file2=""):
    """
    Check if one or two files exist. 
    """
    exts1 = osp.isfile(file1)
    exts2 = True
    if file2 != "": exts2 = osp.isfile(file2)

    if (exts1 and exts2):
        return True
    else:
        raise IOError("One or more input files don't exist")


def compare_dimensions(dim1, dim2, verbose):
    assert_(len(dim1), len(dim2), "Number of dimensions different in files")
    assert_(list(dim1.keys()), list(dim2.keys()), "Dimensions in files different")
    if verbose: 
        print("Comparing Dimensions")
        print(("  Both files have {0} dimensions".format(len(dim1))))
        
    for k in list(dim1.keys()):
        assert_(len(dim1[k]), len(dim2[k]), "Lengths not same for dimension {0}".format(k))
        if verbose: print(("  Dimension {0} same".format(k)))


def compare_variables(vars1, vars2, verbose):
    if verbose: print("Comparing Dimensions")
    assert_(len(vars1), len(vars2), "Number of variables different in files")
    assert_(list(vars1.keys()), list(vars2.keys()), "Variables different in files")

    failed_vars = []

    all_okay = True

    for var in list(vars1.keys()):
        if verbose:
            print(("  {0}".format(var)))
        var1 = vars1[var]
        var2 = vars2[var]

        var_dtype = var1.dtype

        # Checking 'non-string' variables only
        if (var_dtype != np.dtype('S1')):
            try:
                assert(np.allclose(var1[Ellipsis], var2[Ellipsis], equal_nan=True))
                if verbose: print ("    Variable same")
            except AssertionError:
                # Maybe it failed because its a masked array...
                try:
                    assert(np.allclose(var1[Ellipsis].data, var2[Ellipsis].data))
                    assert(np.allclose(var1[Ellipsis].mask, var2[Ellipsis].mask))
                except AssertionError:
                    all_okay = False
                    failed_vars.append(var)
                    if verbose: print ("    Variable not same")
                except:
                    all_okay = False
                    failed_vars.append(var)
                    if verbose: print ("    Variable not same")

        else:
            if verbose: print ("    Skipping check for this variable")

    if not all_okay:
        print(failed_vars)
        raise Exception("Variable verification failed")



def compare_attributes(ncf1, ncf2, verbose):
    att1 = ncf1.ncattrs()
    att2 = ncf2.ncattrs()
    assert_(len(att1), len(att2), "Number of attributes different")
    assert_(att1, att2, "Attributes different in files")
    if verbose: 
        print("Comparing Attributes")
        print(("  Both files have {0} attributes".format(len(att1))))

    for att in att1:
        assert_(getattr(ncf1, att), getattr(ncf2, att), "Attribute {0} different in files".format(att))
        if verbose: print(("  Attribute {0} same".format(att)))


def compare(file1, file2, verbose):
    check_files_exist(file1, file2)
    ncf1 = Dataset(file1, "r")
    ncf2 = Dataset(file2, "r")

    dims1 = ncf1.dimensions
    dims2 = ncf2.dimensions

    vars1 = ncf1.variables
    vars2 = ncf2.variables

    compare_dimensions(dims1, dims2, verbose)
    compare_attributes(ncf1, ncf2, verbose)
    compare_variables(vars1, vars2, verbose)

    ncf1.close()
    ncf2.close()

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Stuff for comparing two netcdf files


ReturnData = namedtuple("ReturnData", ['fname', 'pass1', 'pass2'])

def endlog(start, total_years, sty, edy):
    """
    This is called at the end of the run to finish the logging with 
    information about the number of years convereted and the total time
    taken.
    ARGUMENTS
        start - an object of type time.time containing the start time of
                the program
        total_years - The total number of years converted
    """
    end     = time()
    elapsed = end - start
    print(("+" + "-"*78 + "+"))
    print(("|" + ("Finished converting {0} years ({1}-{2})".format(total_years, sty, edy)).center(78) + "|" ))
    print(("|" + ("Total time: {0}".format(secondsToStr(elapsed))).center(78) + "|" ))
    print(("+" + "-"*78 + "+"))
    


def job_func(ncfile, comp, debug=False, skip_NC4=True):
    """
    This is the main worker subroutine. 
    ARGUMENTS
        ncfile   - a file on which to operate upon
        comp     - compression level in nccopy
        skip_NC4 - skip NetCDF-4 files
    """
    
    logger = multiprocessing.get_logger()

    # check format of file
    if skip_NC4:
        # open file and check format version (skip NetCDF-4)
        lskip = ( Dataset(ncfile).data_model == 'NETCDF4' )
    else: lskip = False # never skip
    
    # decide what to do based on format information
    if lskip:
      
        # skip file (print message)
        logger.info('Skipping NetCDF-4 file {0}'.format(ncfile))
        success = True; check_passed = True # pretend everything is alright
      
    else:
      
        # proceed as ususal
        outfile = ncfile[:ncfile.rfind(".")] + "_new.nc"
        command = "nccopy -s -d {0} {1} {2}".format(comp, ncfile, outfile)
        logger.info(command)
        command = command.strip().split()
        assert(len(command) == 6)  # Checking to make sure the strip().split() command worked as intended
    
        success = False
        ctr = 0
        
        # Sometimes scinet file system acts weird and nccopy commands fail. But running
        # the nccopy command again usually works. This loop will make multiple attempts 
        # to call nccopy and convert the file. 
        while (not success) and (ctr < 5):
            try:
              if debug:
                if not osp.exists(ncfile): 
                  success = False
                  logger.critical('DEBUG: source file missing: {:s}'.format(ncfile))
                else: success = True
              else:
                subprocess.check_call(command)
                success = True
            except subprocess.CalledProcessError as e:
                logger.critical("nccopy: errorcode [{0}] file [{1}] message [{2}]; Retrying.....".format(e.returncode, ncfile, e.output))
            except Exception as e:
                logger.critical("An exception was raised: {0}".format(str(e)))
            ctr += 1
    
        if success:
            # Now we verify the coversion using the cprnc tool. 
            check_passed = False
            try:
              if not debug: compare(ncfile, outfile, False)
              check_passed=True
            except Exception as e:
                logger.critical("Verification failed for file {0}, {1}. Error raised was: {2}".format(ncfile, outfile, e))
    
            if check_passed and not debug: os.rename(outfile, ncfile)
        else:
            check_passed = False
            logger.critical("nccopy FAILED to convert {0}".format(ncfile))

    return ReturnData(ncfile, int(success), int(check_passed))


def print_diagnostics(diag):
    print(("-"*80))
    print("SUMMARY")
    print(("-"*80))

    num_failed_nccopy = 0
    num_failed_verification = 0
    for item in diag:
        if not item.pass1: num_failed_nccopy += 1
        if (item.pass1 and (not item.pass2)): num_failed_verification += 1

    total_failed = num_failed_verification + num_failed_nccopy
    print("")
    print(("Total number of files for work     : {0:4d}".format(len(diag))))
    print(("Total number of files that failed  : {0:4d}".format(total_failed)))
    print(("Number of files that failed nccopy : {0:4d}".format(num_failed_nccopy)))
    print(("Number of files that failed check  : {0:4d}".format(num_failed_verification)))
    if total_failed > 0:
        print("ERRORS encountered during conversion")
        print("Files that failed nccopy:")
        for item in diag:
            if not item.pass1: print(("    {0}".format(item)))
        print("Files that failed verification:")
        for item in diag:
            if (item.pass1 and (not item.pass2)): print(("    {0}".format(item)))
    else:
        print("All files converted SUCCESSFULLY!!")
    print(("-"*80))
    print(("-"*80))


def init(l):
    global lock
    lock = l


if __name__ == "__main__":

    parser = argparse.ArgumentParser(prog="netCDFcompressor.py")
    parser.add_argument('start',        nargs=1, type=int, help='start year')
    parser.add_argument('end',          nargs=1, type=int, help='end year')
    parser.add_argument('--case',       nargs=1, type=str, help='CESM case name (use \'WRF\' or omit for WRF)')
    parser.add_argument('--mode',       nargs=1, type=str, choices=['WRF','CESM','CESM1'], 
                                        help='WRF or CESM mode (default: \'CESM\' if \'case\' is specified, otherwise \'WRF\')')
    parser.add_argument('--filetypes',  nargs=1, type=str, default=['all'], help='filetypes to process')
    parser.add_argument('--domain',     nargs=1, type=int, help='WRF domain number')
    parser.add_argument('-h0',          action='store_true', help='CESM history stream 0 (usually monthly; default)')
    parser.add_argument('-h1',          action='store_true', help='CESM history stream 1 (usually 6-hourly output)')
    #parser.add_argument('-L1',          type=str, help='Location of the CESM level 1 data, if different from default')
    parser.add_argument('--folder',     type=str, help='Case root folder (default: current directory; alias for -L1)')
    parser.add_argument('--noskip',     action='store_true', help='Also compress files already in NetCDF-4 format')
    parser.add_argument('-n',           nargs=1, type=int, default=[int(multiprocessing.cpu_count()/4)], 
                                        help='number of parallel processes (default: CPU_count/4')
    parser.add_argument('--debug',      action='store_true', help='Debug mode: only list files and operations (no conversion)')
    
    ncflags = parser.add_argument_group('nccopy flags')
    ncflags.add_argument('-d',   nargs=1, type=int,  default=[1], help="compression level")
    
    start_clock = time()  #start clock, used for timing the script

    args        = parser.parse_args()
    # general arguments
    start_year  = args.start[0]
    end_year    = args.end[0]
    nprocs      = args.n[0]
    comp        = args.d[0]
    debug       = args.debug
    skip_NC4    = not args.noskip
    
    # figure out what the data folder is
    if args.folder and args.L1: raise ValueError("'L1' and 'folder' arguments are aliases; can only use one.")
    elif args.folder:
      comp_direc = args.folder.strip()
      if not osp.exists(comp_direc): raise IOError(comp_direc)
    elif args.L1:
      comp_direc = args.folder.strip()
      if not osp.exists(comp_direc): raise IOError(comp_direc)
    else:
      comp_direc = os.getcwd()
    # remove trailing slashes etc. and check
    comp_direc = osp.normpath(comp_direc) 
    if not osp.isdir(comp_direc): raise IOError("'{0}' is not a directory.".format(comp_direc))
    
    # infer mode or casename
    casename    = args.case[0] if args.case else None
    mode        = args.mode[0] if args.mode else None
    if mode is None:
        if casename is None: mode = 'WRF'
        else: mode = 'CESM'
    elif mode == 'CESM' or mode == 'CESM1':
        mode = 'CESM' # standardize
        # infer casename from last component of folder name 
        if casename is None: casename = comp_direc.split('/')[-1]
        
    # set/check filetypes based on mode
    if mode == "WRF":
        if args.domain: domain = 'd{:02d}'.format(args.domain[0])
        else: domain = 'd[0-9][0-9]' # match all domains
        filetype_list = ["fdda", "drydyn3d", "hydro", "lsm", "moist3d", "plev3d", "rad", "srfc", "xtrm"]
    elif mode == 'CESM':
        mode = 'CESM'
        # different history streams are processed slightly differently 
        if args.h0 and args.h1: raise ValueError('Can only process one history stream!')
        elif args.h1: 
          hs = 1
          filetype_list = ["atm", "lnd", "ice"]
        else: 
          hs = 0
          filetype_list = ["atm", "lnd", "ocn", "ice"]
    
    # infer filetypes    
    filetype_arg   = args.filetypes[0]
    if filetype_arg.lower() == 'all': filetypes = filetype_list
    else: filetypes = filetype_arg.split(',')
    # check filetypes
    for filetype in filetypes:
        if filetype not in filetype_list:
            raise ValueError('Unsupported filetype: {:s}'.format(filetype))
        if filetype == "ocn":
            if hs == 1:
                raise ValueError("h1 output for ocn files is not supported")
            else:
                # Override the number of processes for the ocean filetype. Using more than 8 processes
                # produces problems on GPC.
                nprocs = min(8,nprocs)
        
    total_years = end_year - start_year + 1
    years       = list(range(start_year, end_year + 1))


    # Register a function to execute at the end of the program
    atexit.register(endlog, start_clock, total_years, start_year, end_year)

    print("Configuration  >>>>>>>")
    print(("  Start year     : {0}".format(start_year)))
    print(("  End year       : {0}".format(end_year)))
    if mode == 'WRF': 
      print(("  Domain(s)      : {0}".format('{:02d}'.format(args.domain[0]) if args.domain else 'all')))
    elif mode == 'CESM': 
      print(("  Case name      : {0}".format(casename)))
      print(("  History stream : {0:d}".format(hs)))
    print(("  Filetype(s)    : {0}".format(filetype_arg)))
    print(("  Num procs      : {0}".format(nprocs)))
    print(("  Compression    : {0}".format(comp)))
    print(("  Skip NetCDF-4  : {0}".format(skip_NC4)))
    if args.debug: print("     DEBUG MODE   ")
    print("<<<<<<<<<<<<<<<<<<<<<<")


    print("Checking for NCCOPY....")
    if (which("nccopy") == None):
        print("ERROR: nccopy is not available on the path")
        sys.exit(-2)
    print("Found!")

    if mode == "CESM":
        mtypes = {"atm":"cam2", "lnd":"clm2", "ocn":"pop", "ice":"cice"}
        if hs == 1: htypes = {"atm":"h1",   "lnd":"h1",   "ice":"h1_inst"}
        elif hs == 0: htypes = {"atm":"h0",   "lnd":"h0",   "ocn":"h",   "ice":"h"}
        else: raise ValueError('Unsupported history steam: '.format(hs))
#     elif modename == "WRF":
#         mtypes = {} # not used with WRF files
#         htypes = {}

    
    # the multiprocessing module's Pool class function map only operates on
    # functions with a single argument. For this reason, i take the actual
    # worker function here and convert it into a "partial" function first. 
    partial_job_func = partial(job_func, comp=comp, debug=debug, skip_NC4=skip_NC4)


    if mode == "WRF":
        # if this is the case root, we have to add the default filetype structure (e.g. wrfout/)
        tmp = osp.join(comp_direc,'wrfout')
        if osp.exists(tmp): comp_direc = tmp # if sub-folder exists, we are in root
        
    os.chdir(comp_direc) # use relative path from here
    if debug: print('DEBUG: working directory: {:s}'.format(comp_direc))

    # Generating the list of files that need to be worked on
    list_of_files = []
    if mode == "WRF":
        for filetype in filetypes:
            for year in years:
                pattern = "wrf{0}_{1}_{2}*".format(filetype, domain, year)
                if debug: print('DEBUG: globbing pattern: {:s}'.format(pattern))
                list_of_files.extend(glob.glob(pattern))
    elif mode == "CESM":
        for filetype in filetypes:
            tmp = osp.join(comp_direc,filetype,'hist')
            if not osp.exists(tmp): IOError(tmp)
            for year in years:
                pattern = "{0}.{1}.{2}.{3:04d}*.nc".format(casename, mtypes[filetype], htypes[filetype], year)
                if hs == 1 and osp.exists('{0:s}/hist/{1:04d}'.format(filetype,year)): # auto-detect yearly sub-folder
                    pattern = '{0:04d}/{1:s}'.format(year,pattern)
                pattern = '{0:s}/hist/{1:s}'.format(filetype,pattern)
                if debug: print('DEBUG: globbing pattern: {:s}'.format(pattern))
                list_of_files.extend(glob.glob(pattern))
    
    
    if (len(list_of_files)) == 0:
        print("ERROR: No files were found matching the specification criteria")
        sys.exit(-1)

    print(("+" + "-"*78 + "+"))
    print(("|" + ("Number of files to operate upon: {0:3d}".format(len(list_of_files))).center(78) + "|" ))
    print(("+" + "-"*78 + "+"))

    # Launching processes
    lock = Lock() # Acquiring a lock

    # logging in multiprocessing to a single file is hard. So we are just going to
    # log to standard output, which is supported by the multiprocessing module.
    logger = multiprocessing.log_to_stderr()
    logger.setLevel(logging.INFO)

    # Launching a pool of processes. The initializer is passed the lock object
    # so that the pool processes can share it.
    pool = Pool(processes=nprocs, initializer=init, initargs=(lock,))

    returneddata = pool.map(partial_job_func, list_of_files)

    pool.close()

    print_diagnostics(returneddata)
