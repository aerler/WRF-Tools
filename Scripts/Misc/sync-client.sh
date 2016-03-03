#!/bin/bash
# script to synchronize parts of the data with SciNet and komputer
# 26/12/2014

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o sn:h --long highspeed,niceness:,from-home,no-scinet,no-komputer,no-datasets,no-cesm,no-wrf,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -s | --highspeed   )   HISPD='HISPD';  shift;;
    -n | --niceness    )   NICENESS=$2; shift 2;;
         --from-home   )   CODE="${HOME}/Code/"; shift;;
         --no-scinet   )   NOSCINET='TRUE'; shift;;
         --no-komputer )   NOKOMPUTER='TRUE'; shift;;
         --no-datasets )   NODATASETS='TRUE'; shift;;
         --no-cesm     )   NOCESM='TRUE'; shift;;
         --no-wrf      )   NOWRF='TRUE'; shift;;
    -h | --help        )   echo -e " \
                            \n\
    -s | --highspeed     whether or not to use the high-speed datamover connection (default: False)\n\
    -n | --niceness      nicesness of the sub-processes (default: +10)\n\
         --from-home     use code from user $HOME instead of default (/home/data/Code)\n\
         --no-scinet     skip all downloads from SciNet\n\
         --no-komputer   skip all downloads from komputer (workstation)\n\
         --no-datasets   skip download of observational datasets\n\
         --no-cesm       skip download of CESM data\n\
         --no-wrf        skip download of WRF data\n\
    -h | --help          print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  


# settings and environment
# general settings
CODE="${CODE:-${HOME}/Code/}" # code root
SCRIPTS="${CODE}/WRF Tools/Scripts/Misc/" # folder with all the scripts
NICENESS=${NICENESS:-10}
# data root directories
export ROOT='/media/me/data-2/Data/'
export WRFDATA="${ROOT}/WRF/" # local WRF data root
export CESMDATA="${ROOT}/CESM/" # local CESM data root

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


## start synchronization

## synchronize observational datasets
rm -f ${ROOT}/sync-datasets.log 
if [[ "${NOSCINET}" != 'TRUE' ]] && [[ "${NODATASETS}" != 'TRUE' ]]; then
  export RESTORE='RESTORE' # restore datasets from SciNet backup
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-datasets.sh" &>> ${ROOT}/sync-datasets.log #2> ${ROOT}/sync-datasets.err # 2>&1
  REPORT $? 'Dataset/Obs Synchronization' 
fi # if not $NOSCINET


## synchronize CESM data
rm -f ${CESMDATA}/sync-cesm.log 
# diagnostics and ensembles from SciNet
if [[ "${NOSCINET}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export HOST='scinet'
  export RESTORE='RESTORE'
  export FILETYPES='NONE'
  export DIAGS='diag cvdp'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> ${CESMDATA}/sync-cesm.log #2> ${CESMDATA}/sync-cesm.err # 2>&1
  REPORT $? 'CESM Diagnostics from SciNet' 
fi # if not $NOSCINET
# climatologies etc. from komputer
if [[ "${NOKOMPUTER}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export HOST='komputer'
  export RESTORE='FALSE'
  export DIAGS='NONE'
  export CVDP='NONE'
  export FILETYPES='cesm*_clim_*.nc'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> ${CESMDATA}/sync-cesm.log #2>> ${CESMDATA}/sync-cesm.err # 2>&1
  REPORT $? 'CESM Climatologies' 
fi # if not $NOKOMPUTER
# stations etc. from komputer
if [[ "${NOKOMPUTER}" != 'TRUE' ]] && [[ "${NOCESM}" != 'TRUE' ]]; then
  export HOST='komputer'
  export RESTORE='FALSE'
  export DIAGS='NONE'
  export CVDP='NONE'
  export FILETYPES='cesm*_ec*_*.nc cesm*_shpavg_*.nc'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-cesm.sh" &>> ${CESMDATA}/sync-cesm.log #2>> ${CESMDATA}/sync-cesm.err # 2>&1
  REPORT $? 'CESM Stations etc.' 
fi # if not $NOKOMPUTER


## synchronize WRF data
rm -f ${WRFDATA}/sync-wrf.log
# monthly files from SciNet
if [[ "${NOSCINET}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export HOST='scinet' 
  export REX='g-ctrl*'
  export FILETYPES='wrfplev3d_d01_clim_*.nc wrfsrfc_d01_clim_*.nc wrfhydro_d02_clim_*.nc wrfxtrm_d02_clim_*.nc wrflsm_d02_clim_*.nc wrfsrfc_d02_clim_*.nc'
  export STATIC='FALSE'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &>> ${WRFDATA}/sync-wrf.log #2> ${WRFDATA}/sync-wrf.err # 2>&1
  REPORT $? 'WRF Monthly from SciNet' 
fi # if not $NOSCINET
# climatologies etc. from komputer
if [[ "${NOKOMPUTER}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export HOST='komputer'
  export FILETYPES='wrfplev3d_d01_clim_*.nc wrfsrfc_d01_clim_*.nc wrfhydro_d02_clim_*.nc wrfxtrm_d02_clim_*.nc wrflsm_d02_clim_*.nc wrfsrfc_d02_clim_*.nc'
  export REX='*-ensemble* max-ctrl* max-ens* ctrl-* ctrl-ens* *-3km erai-max erai-ctrl erai-[gt] [gtm]-* [gm][gm]-*'
  export STATIC='STATIC'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &>> ${WRFDATA}/sync-wrf.log #2> ${WRFDATA}/sync-wrf.err # 2>&1
  REPORT $? 'WRF Climatologies' 
fi # if not $NOKOMPUTER
# stations etc. from komputer
if [[ "${NOKOMPUTER}" != 'TRUE' ]] && [[ "${NOWRF}" != 'TRUE' ]]; then
  export HOST='komputer'
  export FILETYPES='wrf*_ec*_*.nc wrf*_shpavg_*.nc'
  export REX='*-*'
  export STATIC='FALSE'
  nice --adjustment=${NICENESS} "${SCRIPTS}/sync-wrf.sh" &>> ${WRFDATA}/sync-wrf.log #2> ${WRFDATA}/sync-wrf.err # 2>&1
  REPORT $? 'WRF Stations etc.' 
fi # if not $NOKOMPUTER


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
