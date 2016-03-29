#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update and regrid climatologies
# this script runs as a cron job every night
# Andre R. Erler, July 2013, GPL v3

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o e:a:tsrdn:h --long procs-exstns:,procs-avgreg:,test,highspeed,restore,debug,niceness:,from-home,overwrite,no-compute,no-download,no-ensemble,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -e | --procs-exstns )   PYAVG_EXTNP=$2; shift 2;;
    -a | --procs-avgreg )   PYAVG_AVGNP=$2; shift 2;;
    -t | --test         )   PYAVG_BATCH='FALSE'; shift;;    
    -s | --highspeed    )   HISPD='HISPD';  shift;;
    -r | --restore      )   RESTORE='RESTORE'; shift;;
    -d | --debug        )   PYAVG_DEBUG=DEBUG; shift;;
    -n | --niceness     )   NICENESS=$2; shift 2;;
         --from-home    )   CODE="${HOME}/Code/"; shift;;
         --overwrite    )   PYAVG_OVERWRITE='OVERWRITE';  shift;;
         --no-compute   )   NOCOMPUTE='TRUE'; shift;;
         --no-download  )   NODOWNLOAD='TRUE'; shift;;
         --no-ensemble  )   NOENSEMBLE='TRUE'; shift;;
    -h | --help         )   echo -e " \
                            \n\
    -e | --procs-exstns   number of processes to use for station extraction (concurrently to averaging/regridding; default: 2)\n\
    -a | --procs-avgreg   number of processes to use for averaging and regridding (concurrently to stations; default: 2)\n\
    -t | --test           do not run Python modules in batch mode mode (default: Batch)\n\
    -s | --highspeed      whether or not to use the high-speed datamover connection (default: False)\n\
    -r | --restore        inverts local and remote for datasets, so that they are restored\n\
    -d | --debug          print dataset information in Python modules and prefix results with 'test_' (default: False)\n\
    -n | --niceness       nicesness of the sub-processes (default: +5)\n\
         --from-home      use code from user $HOME instead of default (/home/data/Code)\n\
         --overwrite      recompute all averages and regridding (default: False)\n\
         --no-compute     skips the computation steps except the ensemble means (skips all Python scripts)\n\
         --no-download    skips all downloads from SciNet\n\
         --no-ensemble    skips computation of ensemble means\n\
    -h | --help           print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

## check if we are already running
if [ $( ps -A | grep -c ${0##*/} ) -gt 2 ]; then
  echo
  echo "An instance of '${0##*/}' already appears to be running --- aborting!"
  echo
  echo "Running Instances:"
  echo $( ps -A | grep ${0##*/} )
  echo 
  exit 1
fi # if already running, exit

# environment
export GDAL_DATA='/usr/local/share/gdal' # for GDAL API
CODE="${CODE:-/home/data/Code/}" # code root
export PYTHONPATH="${CODE}/GeoPy/src/:${CODE}/WRF Tools/Python/" # my own modules...
# scripts/executables
PYTHON='/home/data/Enthought/EPD/' # path to Python home (do not export!)
SCRIPTS="${CODE}/WRF Tools/Scripts/Misc/" # folder with all the scripts
# data root directories
export ROOT='/data-3/'
export WRFDATA="${ROOT}/WRF/" # local WRF data root
export CESMDATA="${ROOT}/CESM/" # local CESM data root
# general settings
PYAVG_THREADS=${PYAVG_THREADS:-3} # prevent excessive heat...
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

if [[ "${NODOWNLOAD}" != 'TRUE' ]]
  then
    ## synchronize data with SciNet
    export HISPD=${HISPD:-'FALSE'} # whether or not to use the high-speed datamover connection
    # N.B.: the datamover connection needs to be established manually beforehand
    # Datasets
    export RESTORE=${RESTORE:-'FALSE'} # whether or not to invert dataset download
    nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh" &> ${ROOT}/sync-datasets.log #2> ${ROOT}/sync-datasets.err # 2>&1
    REPORT $? 'Dataset/Obs Synchronization' 
    # WRF
    nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &> ${WRFDATA}/sync-wrf.log #2> ${WRFDATA}/sync-wrf.err # 2>&1
    REPORT $? 'WRF Synchronization'  
    # CESM
    nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &> ${CESMDATA}/sync-cesm.log #2> ${CESMDATA}/sync-cesm.err # 2>&1
    REPORT $? 'CESM Synchronization' 
fi # if no-download

if [[ "${NOCOMPUTE}" != 'TRUE' ]]
  then
    
    # N.B.: station extraction runs concurrently with averaging/regridding, because it is I/O limited,
    #       while the other two are CPU limited - easy load balancing
            
    ## extract station data (all datasets)
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_EXTNP:-1} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    nice --adjustment=${NICENESS} "${PYTHON}/bin/python" "${CODE}/GeoPy/src/processing/exstns.py" \
      &> ${ROOT}/exstns.log & # 2> ${ROOT}/exstns.err
    PID=$! # save PID of background process to use with wait 
    
    ## run post-processing (update climatologies)
    # WRF
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_AVGNP:-3} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    #"${PYTHON}/bin/python" -c "print 'OK'" 1> ${WRFDATA}/wrfavg.log 2> ${WRFDATA}/wrfavg.err # for debugging
	  nice --adjustment=${NICENESS} "${PYTHON}/bin/python" "${CODE}/GeoPy/src/processing/wrfavg.py" \
	    &> ${WRFDATA}/wrfavg.log #2> ${WRFDATA}/wrfavg.err
    REPORT $? 'WRF Post-processing'
    
fi # if no-compute

if [[ "${NOENSEMBLE}" != 'TRUE' ]]
  then
    ## compute ensemble averages
    # WRF
    cd "${WRFDATA}/wrfavg/"
    for E in */*ensemble*/; do 
      nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} &> ${E}/ensembleAverage.log #2> ${E}/ensembleAverage.err
      REPORT $? "WRF Ensemble Average '${E}'"
    done
    # CESM
    cd "${CESMDATA}/cesmavg/"
    for E in *ens*/; do 
      nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} &> ${E}/ensembleAverage.log #2> ${E}/ensembleAverage.err
      REPORT $? "CESM Ensemble Average '${E}'"
    done
fi # if no-download

if [[ "${NOCOMPUTE}" != 'TRUE' ]]
  then
    
    # N.B.: station extraction runs concurrently with averaging/regridding, because it is I/O limited,
    #       while the other two are CPU limited - easy load balancing
                
    ## average over regions (all datasets)
    # same settings as wrfavg...
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_AVGNP:-3} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
	  nice --adjustment=${NICENESS} "${PYTHON}/bin/python" "${CODE}/GeoPy/src/processing/shpavg.py" \
	    &> ${ROOT}/shpavg.log #2> ${ROOT}/shpavg.err
    REPORT $? 'Regional/Shape Averaging'
    
    ## run regridding (all datasets)
    # same settings as wrfavg...
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_AVGNP:-3} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    nice --adjustment=${NICENESS} "${PYTHON}/bin/python" "${CODE}/GeoPy/src/processing/regrid.py" \
       &> ${ROOT}/regrid.log #2> ${ROOT}/regrid.err
    REPORT $? 'Dataset Regridding'
    
    wait $PID # wait for station extraction to finish
    REPORT $? 'Station Data Extraction' # wait returns the exit status of the command it waited for
         
fi # if no-compute

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
#exit ${ERR}
