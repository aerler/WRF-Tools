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
#       CODE_ROOT, DATA_ROOT, SCRIPTS, SUBDIR,
#       CLUSTER, CLUSTERSSH, WORKSTN, WORKSTNSSH
# default settings
CODE="${CODE:-${HOME}/Code/}" # code root
SCRIPTS="${SCRIPTS:-${CODE}/WRF-Tools/Scripts/SyncPP/}" # folder with all the scripts
NICENESS=${NICENESS:-10}
# data folders
export WRFDATA="${WRFDATA:-${DATA_ROOT}/WRF/}" # local WRF data root
export CESMDATA="${CESMDATA:-${DATA_ROOT}/CESM/}" # local CESM data root


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
rm -f "${ROOT}"/sync-datasets.log 
if [[ "${NOCLUSTER}" != 'TRUE' ]] && [[ "${NODATASETS}" != 'TRUE' ]]; then
  export RESTORE='RESTORE' # restore datasets from HPC cluster backup
  export HOST="$CLUSTER" # ssh to HPC cluster
  export SSH="$CLUSTERSSH" # ssh settings for HPC cluster 
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh" &>> "${ROOT}"/sync-datasets.log #2> "${ROOT}"/sync-datasets.err # 2>&1
  REPORT $? 'Dataset/Obs Synchronization' 
fi # if not $NOCLUSTER


## synchronize CESM data
rm -f "${CESMDATA}"/sync-cesm.log 
# diagnostics and ensembles from HPC cluster
if [[ "${NOCLUSTER}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export HOST="$CLUSTER" # ssh to HPC cluster
  export SSH="$CLUSTERSSH" # ssh settings for HPC cluster 
  export CESMSRC='/reserved1/p/peltier/aerler//CESM/archive/'
  export INVERT='FALSE' # source has name first then folder type (like on HPC cluster)
  export RESTORE='RESTORE'
  export FILETYPES='NONE'
  export DIAGS='diag cvdp'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &> "${CESMDATA}"/sync-cesm.log #2> "${CESMDATA}"/sync-cesm.err # 2>&1
  REPORT $? 'CESM Diagnostics from HPC cluster' 
fi # if not $NOCLUSTER

## download rest from workstation
export HOST="$WORKSTN" # ssh to workstation
export SSH="$WORKSTNSSH" # ssh settings for workstation
export CESMSRC='/data/CESM/cesmavg/' # archives with my own cesmavg files
export INVERT='INVERT' # invert name/folder order in source (i.e. like in target folder)
export RESTORE='FALSE'
export DIAGS='NONE'
export CVDP='NONE'
# climatologies etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export FILETYPES='cesm*_clim_*.nc'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> "${CESMDATA}"/sync-cesm.log #2>> "${CESMDATA}"/sync-cesm.err # 2>&1
  REPORT $? 'CESM Climatologies' 
fi # if not $NOWORKSTN
# stations etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export FILETYPES='cesm*_ec*_*.nc cesm*_shpavg_*.nc'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> "${CESMDATA}"/sync-cesm.log #2>> "${CESMDATA}"/sync-cesm.err # 2>&1
  REPORT $? 'CESM Stations etc.' 
fi # if not $NOWORKSTN


## synchronize WRF data
rm -f "${WRFDATA}"/sync-wrf.log
# monthly files from HPC cluster
if [[ "${NOCLUSTER}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export HOST="$CLUSTER" # ssh to HPC cluster
  export SSH="$CLUSTERSSH" # ssh settings for HPC cluster 
  export WRFSRC='/reserved1/p/peltier/aerler/'
  export INVERT='FALSE' # source has name first then folder type (like on HPC cluster)  export REX='g-ctrl*'
  export FILETYPES='wrfplev3d_d01_clim_*.nc wrfsrfc_d01_clim_*.nc wrfhydro_d02_clim_*.nc wrfxtrm_d02_clim_*.nc wrflsm_d02_clim_*.nc wrfsrfc_d02_clim_*.nc'
  export STATIC='FALSE'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &> "${WRFDATA}"/sync-wrf.log #2> "${WRFDATA}"/sync-wrf.err # 2>&1
  REPORT $? 'WRF Monthly from HPC cluster' 
fi # if not $NOCLUSTER

## download rest from workstation
export HOST="$WORKSTN" # ssh to workstation
export SSH="$WORKSTNSSH" # ssh settings for workstation
export WRFSRC='/data/WRF/wrfavg/' # archives with my own wrfavg files
export INVERT='INVERT' # invert name/folder order in source (i.e. like in target folder)
# climatologies etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export FILETYPES='wrfplev3d_d01_clim_*.nc wrfsrfc_d01_clim_*.nc wrfhydro_d02_clim_*.nc wrfxtrm_d02_clim_*.nc wrflsm_d02_clim_*.nc wrfsrfc_d02_clim_*.nc'
  export REX='*-ensemble* max-ctrl* max-ens* ctrl-* ctrl-ens* *-3km erai-max erai-ctrl erai-[gt] [gtm]-* [gm][gm]-*'
  export STATIC='STATIC'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &>> "${WRFDATA}"/sync-wrf.log #2> "${WRFDATA}"/sync-wrf.err # 2>&1
  REPORT $? 'WRF Climatologies' 
fi # if not $NOWORKSTN
# stations etc. from workstation
if [[ "${NOWORKSTN}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export FILETYPES='wrf*_ec*_*.nc wrf*_shpavg_*.nc'
  export REX='*-*/'
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
