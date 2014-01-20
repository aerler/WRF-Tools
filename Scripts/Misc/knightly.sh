#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update climatologies
# this script runs as a cron job at 7am every morning

# environment
export GDAL_DATA=/usr/local/share/gdal # for GDAL API
CODE="${CODE:-/home/data/Code/}" # code root
export PYTHONPATH="${CODE}/PyGeoDat/src/:${CODE}/WRF Tools/Python/" # my own modules...
#export PYTHONHOME='/home/data/EPD/' # New Enthought Canopy Python libraries
#export PYTHONHOME='/opt/epd-7.3-2-rh5-x86_64/' # Enthough Python Interpreter
# scripts/executables
PYTHON='/home/data/EPD/' # path to Python home (do not export!)
SCRIPTS="${CODE}/WRF Tools/Scripts/Misc/" # folder with all the scripts
# data root directories
export ROOT='/data/'
export WRFDATA="${ROOT}/WRF/" # local WRF data root
export CESMDATA="${ROOT}/CESM/" # local CESM data root

## synchronize data with SciNet
# WRF
"${SCRIPTS}/sync-wrf.sh" 1> ${WRFDATA}/sync-wrf.log 2> ${WRFDATA}/sync-wrf.err # 2>&1 
# CESM
"${SCRIPTS}/sync-cesm.sh" 1> ${CESMDATA}/sync-cesm.log 2> ${CESMDATA}/sync-cesm.err # 2>&1 
# Datasets
"${SCRIPTS}/sync-datasets.sh" 1> ${ROOT}/sync-datasets.log 2> ${ROOT}/sync-datasets.err # 2>&1 

## run post-processing (update climatologies)
# WRF
export PYAVG_THREADS=4
export PYAVG_DEBUG=FALSE
export PYAVG_OVERWRITE=FALSE
#"${PYTHON}/bin/python" -c "print 'OK'" 1> ${WRFDATA}/wrfavg.log 2> ${WRFDATA}/wrfavg.err # for debugging
"${PYTHON}/bin/python" "${CODE}/PyGeoDat/src/processing/wrfavg.py" 1> ${WRFDATA}/wrfavg.log 2> ${WRFDATA}/wrfavg.err

## compute ensemble averages
# WRF
cd "${WRFDATA}/wrfavg/"
for E in *ensemble*/; do 
   "${SCRIPTS}/ensembleAverage.sh" ${E} 1> ${E}/ensembleAverage.log 2> ${E}/ensembleAverage.err
done
# CESM
cd "${CESMDATA}/cesmavg/"
for E in ens*/; do 
   "${SCRIPTS}/ensembleAverage.sh" ${E} 1> ${E}/ensembleAverage.log 2> ${E}/ensembleAverage.err
done

