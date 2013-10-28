#!/bin/bash
# script to run nightly updates on komputer:
# - download/update monthly means from SciNet
# - compute/update climatologies
# this script runs as a cron job at 7am every morning

# environment
EPD='/opt/epd-7.3-2-rh5-x86_64/bin/python'
export CODE='/home/data/Code/' # code root
export PYTHONPATH="${CODE}/PyGeoDat/src/:${CODE}/WRF Tools/Python/"
export DATA='/data/WRF/wrfavg/' # local WRF data root

# synchronize data with SciNet
#${CODE}/WRF\ Tools/Scripts/Misc/sync-monthly.sh 2>&1 1> ${DATA}/sync-monthly.log
${CODE}/WRF\ Tools/Scripts/Misc/sync-monthly.sh 1> ${DATA}/sync-monthly.log 2> ${DATA}/sync-monthly.err 

# run post-processing (update climatologies)
export PYAVG_THREADS=4
export PYAVG_TEST=FALSE
export PYAVG_OVERWRITE=FALSE
$EPD ${CODE}/PyGeoDat/src/datasets/wrfavg.py 1> ${DATA}/wrfavg.log 2> ${DATA}/wrfavg.err
