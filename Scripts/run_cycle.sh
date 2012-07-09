#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and 
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
export STEPFILE='stepfile.daily' # file in $INIDIR
export INIDIR="${PWD}" # current directory 

# read first entry in stepfile 
STEP=$(python cycling.py)
export STEP
echo $STEP

# launch first WPS instance
./run_cycling_WPS.sh
wait

# launch first WRF instance
./run_cycling_WRF.sh
wait
