#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update and regrid climatologies
# this script runs as a cron job every night
# Andre R. Erler, July 2013, GPL v3

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o p:tsdn:h --long processes:,test,highspeed,debug,niceness:,overwrite,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -p | --processes )   PYAVG_THREADS=$2; shift 2;;
    -t | --test      )   PYAVG_BATCH='FALSE'; shift;;    
    -s | --highspeed )   HISPD='HISPD';  shift;;
    -d | --debug     )   PYAVG_DEBUG=DEBUG; shift;;
    -n | --niceness  )   NICENESS=$2; shift 2;;
         --overwrite )   PYAVG_OVERWRITE='OVERWRITE';  shift;;
    -h | --help     )   echo -e " \
                            \n\
    -p | --processes    number of processes to use by Python multi-processing (default: 4)\n\
    -t | --test         do not run Python modules in batch mode mode (default: Batch)\n\
    -s | --highspeed    whether or not to use the high-speed datamover connection (default: False)\n\
    -d | --debug        print dataset information in Python modules and prefix results with 'test_' (default: False)\n\
    -n | --niceness     nicesness of the sub-processes (default: +5)\n\
         --overwrite    recompute all averages and regridding (default: False)\n\
    -h | --help         print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

# environment
export GDAL_DATA='/usr/local/share/gdal' # for GDAL API
CODE="${CODE:-/home/data/Code/}" # code root
export PYTHONPATH="${CODE}/PyGeoDat/src/:${CODE}/WRF Tools/Python/" # my own modules...
# scripts/executables
PYTHON='/home/data/Enthought/EPD/' # path to Python home (do not export!)
SCRIPTS="${CODE}/WRF Tools/Scripts/Misc/" # folder with all the scripts
# data root directories
export ROOT='/data/'
export WRFDATA="${ROOT}/WRF/" # local WRF data root
export CESMDATA="${ROOT}/CESM/" # local CESM data root
# general settings
NICENESS=${NICENESS:-10}

## error reporting
ERR=0 # error counter
# reporting function
function REPORT {
  # function to record the number of errors and print feedback, 
  # including exit codes when errors occured 
  EC=$1 # reported exit code
  CMD=$2 # command/operation that was executed
  # print feedback, depending on exit code
  echo 
  if [ $EC -eq 0 ]; then
    echo "${CMD} successfull!" 
  else
    echo "ERROR in ${CMD}; exit code ${EC}"
    ERR=$(( $ERR + 1 )) 
  fi # if $EC == 0
} # function REPORT 

# start
echo
date
echo

## synchronize data with SciNet
export HISPD=${HISPD:-'FALSE'} # whether or not to use the high-speed datamover connection
# N.B.: the datamover connection needs to be established manually beforehand
# WRF
nice --adjustment=${NICENESS} ${NICESNESS} "${SCRIPTS}/sync-wrf.sh" &> ${WRFDATA}/sync-wrf.log #2> ${WRFDATA}/sync-wrf.err # 2>&1
REPORT $? 'WRF Synchronization'  
# CESM
nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &> ${CESMDATA}/sync-cesm.log #2> ${CESMDATA}/sync-cesm.err # 2>&1
REPORT $? 'CESM Synchronization' 
# Datasets
nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh" &> ${ROOT}/sync-datasets.log #2> ${ROOT}/sync-datasets.err # 2>&1
REPORT $? 'Dataset/Obs Synchronization' 

## run post-processing (update climatologies)
# WRF
export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
export PYAVG_THREADS=${PYAVG_THREADS:-4} # parallel execution
export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
#"${PYTHON}/bin/python" -c "print 'OK'" 1> ${WRFDATA}/wrfavg.log 2> ${WRFDATA}/wrfavg.err # for debugging
nice --adjustment=${NICENESS} "${PYTHON}/bin/python" "${CODE}/PyGeoDat/src/processing/wrfavg.py" &> ${WRFDATA}/wrfavg.log #2> ${WRFDATA}/wrfavg.err
REPORT $? 'WRF Post-processing'

## compute ensemble averages
# WRF
cd "${WRFDATA}/wrfavg/"
for E in *ensemble*/; do 
  nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} &> ${E}/ensembleAverage.log #2> ${E}/ensembleAverage.err
  REPORT $? "WRF Ensemble Average '${E}'"
done
# CESM
cd "${CESMDATA}/cesmavg/"
for E in ens*/; do 
  nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} &> ${E}/ensembleAverage.log #2> ${E}/ensembleAverage.err
  REPORT $? "CESM Ensemble Average '${E}'"
done

## run regridding (WRF and CESM)
# same settings as wrfavg...
export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
export PYAVG_THREADS=${PYAVG_THREADS:-4} # parallel execution
export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
nice --adjustment=${NICENESS} "${PYTHON}/bin/python" "${CODE}/PyGeoDat/src/processing/regrid.py" &> ${ROOT}/regrid.log #2> ${ROOT}/regrid.err
REPORT $? 'CESM & WRF regridding'

# report
echo
echo
if [ $ERR -eq 0 ]
  then
    echo "   <<<   All Transfers/Post-Processing Completed Successfully!   >>>   "
  else
    echo "   ###   Transfers/Post-Processing Completed - there were ${ERR} Errors!   ###   "
fi
echo
date
echo

# exit with error code
exit ${ERR}
