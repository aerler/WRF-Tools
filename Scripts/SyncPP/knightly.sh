#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update and regrid climatologies
# this script runs as a cron job every night
# Andre R. Erler, July 2013, GPL v3
# revised by Fengyi Xie and Andre R. Erler, March 2016, GPL v3

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o e:a:tsrdn:h --long procs-exstns:,procs-avgreg:,test,highspeed,restore,debug,niceness:,config:,code-root:,data-root:,from-home,python:,overwrite,no-compute,no-download,no-ensemble,help -n "$0" -- "$@" ) # pre-process arguments
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
         --config       )   KCFG="$2"; shift 2;;
         --code-root    )   CODE="$2"; shift 2;;
         --data-root    )   DATA="$2"; shift 2;;
         --from-home    )   CODE="${HOME}/Code/"; shift;;
         --python       )   PYTHON="$2"; shift 2;;
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
         --config         an alternative configuration file to source instead of kconfig.sh\n\
                          (set to 'NONE' to inherit settings from parent environment)\n\
         --code-root      alternative root folder for code base (WRF Tools & GeoPy)\n\
         --data-root      root folder for data repository\n\
         --from-home      use home directory as code root\n\
         --python         use alternative Python executable\n\
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
echo
date
echo
if [ $( ps -A | grep -c ${0##*/} ) -gt 2 ]; then
  echo
  echo "An instance of '${0##*/}' already appears to be running --- aborting!"
  echo
  echo "Running Instances:"
  echo $( ps -A | grep ${0##*/} )
  echo 
  exit 1
fi # if already running, exit

## error reporting
ERR=0 # error counter
# reporting function
function REPORT {
  # function to record the number of errors and print feedback, 
  # including exit codes when errors occurred 
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


## set environment variables
# N.B.: defaults and command line options will be overwritten by custom settings in config file
# load custom configuration from file

if [[ "$KCFG" == "NONE" ]]; then
    echo "Using configuration from parent environment (not sourcing)."
elif [[ -z "$KCFG" ]]; then
    echo "Sourcing configuration from default file: $PWD/kconfig.sh"
    source kconfig.sh # default config file (in local directory)
elif [[ -f "$KCFG" ]]; then 
    echo "Sourcing configuration from alternative file: $KCFG"
    source "$KCFG" # alternative config file
else
    echo "ERROR: no configuration file '$KCFG'"
fi # if config file
export KCFG='NONE' # suppress sourcing in child processes
echo
# N.B.: The following variables need to be set:
#       CODE, DATA, GDAL_DATA, SCRIPTS, PYTHON, PYTHONPATH, 
#       PYYAML_EXSTNS, PYYAML_WRFAVG, PYYAML_SHPAVG, PYYAML_REGRID
#       SSHMASTER, SSH, HOST, SRC, SUBDIR
# some defaults for optional variables
export WRFDATA="${WRFDATA:-"${DATA}/WRF/"}" # local WRF data root
export CESMDATA="${CESMDATA:-"${DATA}/CESM/"}" # local CESM data root
export HISPD="${HISPD:-'FALSE'}" # whether or not to use the high-speed datamover connection
# N.B.: the datamover connection needs to be established manually beforehand
export SSH="${SSH:-"-o BatchMode=yes -o ControlPath=${HOME}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"}" # default SSH options
export STATIC="${STATIC:-'STATIC'}" # download static/const data 
export INVERT="${INVERT:-'FALSE'}" # source has experiment name first then folder type
export RESTORE="${RESTORE:-'FALSE'}" # restore CESM data and other datasets from local repository (currently not implemented for WRF)
export CODE DATA GDAL_DATA PYTHONPATH SSHMASTER HOST SRC SUBDIR # make sure remaining environment variables are passed to sub-processes
NICENESS=${NICENESS:-10} # low priority, but not lowest

if [[ "${NODOWNLOAD}" != 'TRUE' ]]
  then
    ## synchronize data with SciNet
    # Datasets
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh" &> "${DATA}"/sync-datasets.log #2> "${DATA}"/sync-datasets.err # 2>&1
      else
        nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh"
    fi # if logging
    REPORT $? 'Dataset/Obs Synchronization' 
    # WRF
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &> "${WRFDATA}"/sync-wrf.log #2> "${WRFDATA}"/sync-wrf.err # 2>&1
      else
        nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh"
    fi # if logging
    REPORT $? 'WRF Synchronization'  
    # CESM
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &> "${CESMDATA}"/sync-cesm.log #2> "${CESMDATA}"/sync-cesm.err # 2>&1
      else
        nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh"
    fi # if logging
    REPORT $? 'CESM Synchronization' 
fi # if no-download

if [[ "${NOCOMPUTE}" != 'TRUE' ]]
  then
    # N.B.: station extraction runs concurrently with averaging/regridding, because it is I/O limited,
    #       while the other two are CPU limited - easy load balancing
            
    # extract station data (all datasets)
    export PYAVG_YAML="${PYYAML_EXSTNS}" # YAML configuration file
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_EXTNP:-1} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/exstns.py" \
          &> "${DATA}"/exstns.log & # 2> "${DATA}"/exstns.err
      else
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/exstns.py"
    fi # if logging
    #PID=$! # save PID of background process to use with wait 
    
    # run post-processing (update climatologies)
    # WRF
    export PYAVG_YAML="${PYYAML_WRFAVG}" # YAML configuration file
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_AVGNP:-3} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    #"${PYTHON}" -c "print 'OK'" 1> "${WRFDATA}"/wrfavg.log 2> "${WRFDATA}"/wrfavg.err # for debugging
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/wrfavg.py" \
          &> "${WRFDATA}"/wrfavg/wrfavg.log #2> "${WRFDATA}"/wrfavg.err
      else
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/wrfavg.py"
    fi # if logging
    REPORT $? 'WRF Post-processing'
    
fi # if no-compute

if [[ "${NOENSEMBLE}" != 'TRUE' ]]
  then
    ## compute ensemble averages
    # WRF
    cd "${WRFDATA}/wrfavg/"
    for E in */*ensemble*/; do 
      if [ -w "$E" ]; then
        if [[ "${NOLOGGING}" != 'TRUE' ]]; then
            nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} &> ${E}/ensembleAverage.log #2> ${E}/ensembleAverage.err
        else
            nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} 
        fi # if logging
        REPORT $? "WRF Ensemble Average '${E}'"
      fi # if writable
    done
    # CESM
    cd "${CESMDATA}/cesmavg/"
    for E in *ens*/; do 
      if [ -w "$E" ]; then
        if [[ "${NOLOGGING}" != 'TRUE' ]]; then
            nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} &> ${E}/ensembleAverage.log #2> ${E}/ensembleAverage.err
          else
            nice --adjustment=${NICENESS} "${SCRIPTS}/ensembleAverage.sh" ${E} 
        fi # if logging      
        REPORT $? "CESM Ensemble Average '${E}'"
      fi # if writable
    done
fi # if no-download

if [[ "${NOCOMPUTE}" != 'TRUE' ]]
  then
    
    # N.B.: station extraction runs concurrently with averaging/regridding, because it is I/O limited,
    #       while the other two are CPU limited - easy load balancing
                
    ## average over regions (all datasets)
    # same settings as wrfavg...
    export PYAVG_YAML="${PYYAML_SHPAVG}" # YAML configuration file
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_AVGNP:-3} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/shpavg.py" \
        &> "${DATA}"/shpavg.log #2> "${DATA}"/shpavg.err
      else
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/shpavg.py" 
    fi
    REPORT $? 'Regional/Shape Averaging'
    
    # run regridding (all datasets)
    # same settings as wrfavg...
    export PYAVG_YAML="${PYYAML_REGRID}" # YAML configuration file
    export PYAVG_BATCH=${PYAVG_BATCH:-'BATCH'} # run in batch mode - this should not be changed
    export PYAVG_THREADS=${PYAVG_AVGNP:-3} # parallel execution
    export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output
    export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'} # append (default) or recompute everything
    if [[ "${NOLOGGING}" != 'TRUE' ]]
      then
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/regrid.py" \
        &> "${DATA}"/regrid.log #2> "${DATA}"/regrid.err
      else
        nice --adjustment=${NICENESS} "${PYTHON}" "${CODE}/GeoPy/src/processing/regrid.py"
    fi
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
