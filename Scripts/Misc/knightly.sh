#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update climatologies
# this script runs as a cron job at 7am every morning

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
# WRF
"${SCRIPTS}/sync-wrf.sh" 1> ${WRFDATA}/sync-wrf.log 2> ${WRFDATA}/sync-wrf.err # 2>&1
REPORT $? 'WRF Synchronization'  
# CESM
"${SCRIPTS}/sync-cesm.sh" 1> ${CESMDATA}/sync-cesm.log 2> ${CESMDATA}/sync-cesm.err # 2>&1
REPORT $? 'CESM Synchronization' 
# Datasets
"${SCRIPTS}/sync-datasets.sh" 1> ${ROOT}/sync-datasets.log 2> ${ROOT}/sync-datasets.err # 2>&1
REPORT $? 'Dataset/Obs Synchronization' 

## run post-processing (update climatologies)
# WRF
export PYAVG_THREADS=3
export PYAVG_DEBUG=FALSE
export PYAVG_BATCH=BATCH
export PYAVG_OVERWRITE=FALSE
#"${PYTHON}/bin/python" -c "print 'OK'" 1> ${WRFDATA}/wrfavg.log 2> ${WRFDATA}/wrfavg.err # for debugging
"${PYTHON}/bin/python" "${CODE}/PyGeoDat/src/processing/wrfavg.py" 1> ${WRFDATA}/wrfavg.log 2> ${WRFDATA}/wrfavg.err
REPORT $? 'WRF Post-processing'

## compute ensemble averages
# WRF
cd "${WRFDATA}/wrfavg/"
for E in *ensemble*/; do 
   "${SCRIPTS}/ensembleAverage.sh" ${E} 1> ${E}/ensembleAverage.log 2> ${E}/ensembleAverage.err
   REPORT $? "WRF Ensemble Average '${E}'"
done
# CESM
cd "${CESMDATA}/cesmavg/"
for E in ens*/; do 
   "${SCRIPTS}/ensembleAverage.sh" ${E} 1> ${E}/ensembleAverage.log 2> ${E}/ensembleAverage.err
   REPORT $? "CESM Ensemble Average '${E}'"
done

## run regridding (WRF and CESM)
# same settings as wrfavg...
export PYAVG_THREADS=3
export PYAVG_DEBUG=FALSE
export PYAVG_BATCH=BATCH
export PYAVG_OVERWRITE=FALSE
"${PYTHON}/bin/python" "${CODE}/PyGeoDat/src/processing/regrid.py" 1> ${ROOT}/regrid.log 2> ${ROOT}/regrid.err
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
