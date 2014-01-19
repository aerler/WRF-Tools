#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update climatologies
# this script runs as a cron job at 7am every morning

# environment
export PYTHONHOME='/home/data/EPD/' # New Enthought Canopy Python libraries
#export PYTHONHOME='/opt/epd-7.3-2-rh5-x86_64/' # Enthough Python Interpreter
export GDAL_DATA=/usr/local/share/gdal # for GDAL API
export CODE="${CODE:-/home/data/Code/}" # code root
export PYTHONPATH="${CODE}/PyGeoDat/src/:${CODE}/WRF Tools/Python/"
export ROOT='/data/'
export WRFDATA="${ROOT}/WRF/" # local WRF data root
export CESMDATA="${ROOT}/CESM/" # local CESM data root

## synchronize data with SciNet

${CODE}/WRF\ Tools/Scripts/Misc/sync-wrf.sh 1> ${WRFDATA}/sync-wrf.log 2> ${WRFDATA}/sync-wrf.err # 2>&1 
# CESM
${CODE}/WRF\ Tools/Scripts/Misc/sync-cesm.sh 1> ${CESMDATA}/sync-cesm.log 2> ${CESMDATA}/sync-cesm.err # 2>&1 

## run post-processing (update climatologies)
# WRF
export PYAVG_THREADS=4
export PYAVG_DEBUG=FALSE
export PYAVG_OVERWRITE=FALSE
#${PYTHONHOME}/bin/python ${CODE}/PyGeoDat/src/processing/wrfavg.py 1> ${DATA}/wrfavg.log 2> ${DATA}/wrfavg.err
