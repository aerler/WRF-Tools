#!/bin/bash
# script to synchronize parts of the data from a remote cluster environment and remote workstation to a client computer
# 26/12/2014, Andre R. Erler, GPL v3, updated 30/05/2016

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o sn:h --long highspeed,niceness:,config:,from-home,no-cluster,no-workstn,no-datasets,no-cesm,no-wrf,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -s | --highspeed   )   HISPD='HISPD';  shift;;
    -n | --niceness    )   NICENESS=$2; shift 2;;
         --config        )   KCFG="$2"; shift 2;;
         --from-home   )   CODE="${HOME}/Code/"; shift;;
         --no-cluster  )   NOCLUSTER='TRUE'; shift;;
         --no-workstn  )   NOWORKSTN='TRUE'; shift;;
         --no-datasets )   NODATASETS='TRUE'; shift;;
         --no-cesm     )   NOCESM='TRUE'; shift;;
         --no-wrf      )   NOWRF='TRUE'; shift;;
    -h | --help        )   echo -e " \
                            \n\
    -s | --highspeed     whether or not to use the high-speed datamover connection (default: False)\n\
    -n | --niceness      nicesness of the sub-processes (default: +10)\n\
         --config         an alternative configuration file to source instead of kconfig.sh\n\
                          (set to 'NONE' to inherit settings from parent environment)\n\
         --from-home     use code from user $HOME instead of default (/home/data/Code)\n\
         --no-cluster    skip all downloads from remote HPC cluster\n\
         --no-workstn    skip all downloads from remote workstation\n\
         --no-datasets   skip download of observational datasets\n\
         --no-cesm       skip download of CESM data\n\
         --no-wrf        skip download of WRF data\n\
    -h | --help          print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  


## set environment variables
# N.B.: defaults and command line options will be overwritten by custom settings in config file
# load custom configuration from file

if [[ "$KCFG" == "NONE" ]]; then
    echo "Using configuration from parent environment (not sourcing)."
elif [[ -z "$KCFG" ]]; then
    echo "Sourcing configuration from default file: $PWD/lconfig.sh"
    source lconfig.sh # default config file (in local directory)
elif [[ -f "$KCFG" ]]; then 
    echo "Sourcing configuration from alternative file: $KCFG"
    source "$KCFG" # alternative config file
else
    echo "ERROR: no configuration file '$KCFG'"
fi # if config file
export KCFG='NONE' # suppress sourcing in child processes
echo
# N.B.: The following variables need to be set:
#       CODE_ROOT, DATA_ROOT, SCRIPTS, OBSCLSTR, DATASETS,
#       WRFCLSTR, SUBDIR, CESMCLSTR, WRFWRKSTN, CESMWRKSTN,
#       CLUSTER, CLUSTERSSH, WORKSTN, WORKSTNSSH
# default settings
CODE="${CODE:-${HOME}/Code/}" # code root
SCRIPTS="${SCRIPTS:-${CODE}/WRF-Tools/Scripts/SyncPP/}" # folder with all the scripts
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


## synchronize observational datasets
export OBSDATA="${OBSDATA:-${DATA_ROOT}/}" # local datasets root
rm -f "${ROOT}"/sync-datasets.log 
if [[ "${NOCLUSTER}" != 'TRUE' ]] && [[ "${NODATASETS}" != 'TRUE' ]]; then
  export RESTORE='RESTORE' # restore datasets from HPC cluster backup
  export HOST="$CLUSTER" # ssh to HPC cluster
  export SSH="$CLUSTERSSH" # ssh settings for HPC cluster
  export OBSSRC="$OBSCLSTR" # only cluster is used  
  export DATASETS
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh" &>> "${OBSDATA}"/sync-datasets.log #2> "${OBSDATA}"/sync-datasets.err # 2>&1
  REPORT $? 'Dataset/Obs Synchronization' 
fi # if not $NOCLUSTER


## synchronize CESM data
export CESMDATA="${CESMDATA:-${DATA_ROOT}/CESM/}" # local CESM data root
rm -f "${CESMDATA}"/sync-cesm.log 
# diagnostics and ensembles from HPC cluster
if [[ "${NOCLUSTER}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export HOST="$CLUSTER" # ssh to HPC cluster
  export SSH="$CLUSTERSSH" # ssh settings for HPC cluster 
  export CESMSRC="$CESMCLSTR" # remote archive with cesmavg files
  export INVERT='FALSE' # source has name first then folder type (like on HPC cluster)
  export RESTORE='RESTORE'
  export CESMENS='NONE' # ensembles are only for upload
  export CESMREX='*'
  export FILETYPES='NONE'
  export DIAGS='diag cvdp'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &> "${CESMDATA}"/sync-cesm.log #2> "${CESMDATA}"/sync-cesm.err # 2>&1
  REPORT $? 'CESM Diagnostics from HPC cluster' 
fi # if not $NOCLUSTER

## download rest from workstation
export HOST="$WORKSTN" # ssh to workstation
export SSH="$WORKSTNSSH" # ssh settings for workstation
export CESMSRC="$CESMWRKSTN" # archives with my own cesmavg files
export INVERT='INVERT' # invert name/folder order in source (i.e. like in target folder)
export RESTORE='FALSE'
export DIAGS='NONE'
export CVDP='NONE'
export CESMENS='NONE'
# climatologies etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export FILETYPES="${CESMCLIMFT:-'cesmatm*_clim_*.nc cesmlnd*_clim_*.nc'}"
  export CESMREX="${CESMCLIMREX:-'ens*'}" # these files are quite large: only ensembles
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> "${CESMDATA}"/sync-cesm.log #2>> "${CESMDATA}"/sync-cesm.err # 2>&1
  REPORT $? 'CESM Climatologies' 
fi # if not $NOWORKSTN
# stations etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export FILETYPES="${CESMSTNSFT:-'cesm*_ec*_*.nc cesm*_shpavg_*.nc'}"
  export CESMREX="${CESMSTNSREX:-'*'}" # these files are pretty small: all experiments
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> "${CESMDATA}"/sync-cesm.log #2>> "${CESMDATA}"/sync-cesm.err # 2>&1
  REPORT $? 'CESM Stations etc.' 
fi # if not $NOWORKSTN


## synchronize WRF data
export WRFDATA="${WRFDATA:-${DATA_ROOT}/WRF/}" # local WRF data root
rm -f "${WRFDATA}"/sync-wrf.log

# monthly files from HPC cluster
if [[ "${NOCLUSTER}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export HOST="$CLUSTER" # ssh to HPC cluster
  export SSH="$CLUSTERSSH" # ssh settings for HPC cluster 
  export WRFSRC="$WRFCLSTR"
  export INVERT='FALSE' # source has name first then folder type (like on HPC cluster)  export REX='g-ctrl*'
  export FILETYPES="${WRFCLTSFT:-'wrfplev3d_d01_monthly.nc wrfsrfc_d01_monthly.nc wrfhydro_d02_monthly.nc wrfxtrm_d02_monthly.nc wrflsm_d02_monthly.nc wrfsrfc_d02_monthly.nc'}"
  export WRFREX="${WRFCLTSREX:-'NONE'}" # these files are very large! None by default
  export STATIC='FALSE'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &> "${WRFDATA}"/sync-wrf.log #2> "${WRFDATA}"/sync-wrf.err # 2>&1
  REPORT $? 'WRF Monthly from HPC cluster'
fi # if not $NOCLUSTER

## download rest from workstation
export HOST="$WORKSTN" # ssh to workstation
export SSH="$WORKSTNSSH" # ssh settings for workstation
export WRFSRC="$WRFWRKSTN" # archives with my own wrfavg files
export INVERT='INVERT' # invert name/folder order in source (i.e. like in target folder)
# climatologies etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export FILETYPES="${WRFCLIMFT:-'wrfplev3d_d01_clim_*.nc wrfsrfc_d01_clim_*.nc wrfhydro_d02_clim_*.nc wrfxtrm_d02_clim_*.nc wrflsm_d02_clim_*.nc wrfsrfc_d02_clim_*.nc'}"
  export WRFREX="${WRFCLIMREX:-'*-ensemble*'}" # these files are quite large: only ensembles
  export STATIC='STATIC'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &>> "${WRFDATA}"/sync-wrf.log #2> "${WRFDATA}"/sync-wrf.err # 2>&1
  REPORT $? 'WRF Climatologies' 
fi # if not $NOWORKSTN
# stations etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export FILETYPES="${WRFSTNSFT:-'wrf*_ec*_*.nc wrf*_shpavg_*.nc'}"
  export WRFREX="${WRFSTNSREX:-'*-*'}" # these files are pretty small: all experiments
  export STATIC='FALSE'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &>> "${WRFDATA}"/sync-wrf.log #2> "${WRFDATA}"/sync-wrf.err # 2>&1
  REPORT $? 'WRF Stations etc.' 
fi # if not $NOWORKSTN


## report
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
