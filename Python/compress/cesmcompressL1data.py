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

E.g. usage: cesmcompressL1data.py case_name 1 10 atm
will compress all atm history files of case 'case_name' for years 1 to 10 in
the short term archive. 

NOTE: Mar 28, 2016: Modified to ensure compatibility with pyhton 3

@author: Deepak Chandan
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
from CESMCase import CESMCase

from scinet_cesm_utils import which, secondsToStr
from scinet_cesm_utils import push_notification_to_user
from check_machine import check_machine_is_GPC



# Stuff for comparing two netcdf files >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
def assert_(a, b, msg):
    if (a != b): raise Exception(msg)

def check_files_exist(file1, file2=""):
    """
    Check if one or two files exist. 
    """
    exts1 = False
    exts2 = True
    exts1 = osp.isfile(file1)
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
                assert(np.allclose(var1[Ellipsis], var2[Ellipsis]))
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
    


def job_func(ncfile, comp):
    """
    This is the main worker subroutine. 
    ARGUMENTS
        ncfile - a file on which to operate upon
        comp   - compression level in nccopy
    """
    logger = multiprocessing.get_logger()
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
            compare(ncfile, outfile, False)
            check_passed=True
        except Exception as e:
            logger.critical("Verification failed for file {0}, {1}. Error raised was: {2}".format(ncfile, outfile, e))

        if check_passed: os.rename(outfile, ncfile)
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
  
    parser = argparse.ArgumentParser(prog="cesmcompressL1data.py")
    parser.add_argument('case',  nargs=1, type=str, help='CESM case name')
    parser.add_argument('start', nargs=1, type=int, help='start year')
    parser.add_argument('end',   nargs=1, type=int, help='end year')
    parser.add_argument('model', nargs=1, type=str, choices=["atm", "lnd", "ocn", "ice"], 
                                 help='models component to process')
    parser.add_argument('-n',    nargs=1, type=int, default=[multiprocessing.cpu_count()], 
                                 help='number of parallel processes')
    parser.add_argument('-L1',   type=str, help='Location of the CESM level 1 data, if different from default')
    parser.add_argument('--rundir',   action='store_true', help='Compress files directly in the run directory')
    ncflags = parser.add_argument_group('nccopy flags')
    ncflags.add_argument('-d',   nargs=1, type=int,  default=[6], help="compression level")

    check_machine_is_GPC()

    start_clock = time()  #start clock, used for timing the script

    args        = parser.parse_args()
    casename    = args.case[0]
    start_year  = args.start[0]
    end_year    = args.end[0]
    nprocs      = args.n[0]
    comp        = args.d[0]
    model       = args.model[0]

    if model == "ocn":
        # Override the number of processes for the ocean model. Using more than 8 processes
        # produces problems on GPC.
        nprocs = 8

    case        = CESMCase(casename)
    total_years = end_year - start_year + 1
    years       = list(range(start_year, end_year + 1))


    # Register a function to execute at the end of the program
    atexit.register(endlog, start_clock, total_years, start_year, end_year)

    print("Configuration  >>>>>>>")
    print(("  Case name  : {0}".format(casename)))
    print(("  Model      : {0}".format(model)))
    print(("  Start year : {0}".format(start_year)))
    print(("  End year   : {0}".format(end_year)))
    print(("  Num procs  : {0}".format(nprocs)))
    print(("  Compression: {0}".format(comp)))
    print("<<<<<<<<<<<<<<<<<<<<<<")


    print("Checking for NCCOPY....")
    if (which("nccopy") == None):
        print("ERROR: nccopy is not available on the path")
        sys.exit(-2)
    print("Found!")

    mtypes = {"atm":"cam2", "lnd":"clm2", "ocn":"pop", "ice":"cice"}
    htypes = {"atm":"h0",   "lnd":"h0",   "ocn":"h",   "ice":"h"}

    
    # the multiprocessing module's Pool class function map only operates on
    # functions with a single argument. For this reason, I take the actual
    # worker function here and convert it into a "partial" function first. 
    partial_job_func = partial(job_func, comp=comp)


    if args.L1:
        # If the user has specified the location of level 1 data then use it
        comp_direc = osp.join(args.L1.strip(), model, "hist")
        # comp_direc = args.L1.strip()
    else:
        # otherwise use the standard location
        comp_direc = osp.join(case.DOUT_S_ROOT, model, "hist")
    
    if args.rundir:
        comp_direc = osp.join(case.EXEROOT.strip(), "run")

    os.chdir(comp_direc)

    # Generating the list of files that need to be worked on
    list_of_files = []
    for year in years:
        pattern = "{0}.{1}.{2}.{3:04d}*.nc".format(casename, mtypes[model], htypes[model], year)
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

    ret = push_notification_to_user("L1 compression for {0}/{1} complete!".format(casename, model))

