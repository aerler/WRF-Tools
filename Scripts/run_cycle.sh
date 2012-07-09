#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and 
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
export STEPFILE='stepfile.hourly' # file in $INIDIR
export INIDIR="${PWD}" # current directory

# launch feedback
echo
echo "   ***   Starting Cycle  ***   "
echo
echo "   Stepfile: ${STEPFILE}"
echo "   Root Dir: ${INIDIR}"
echo 

# clear some folders
export METDATA="${INIDIR}/metgrid/"
export WRFOUT="${INIDIR}/wrfout/"
echo "   Clearing Output Folders:"
echo "${METDATA}"
echo "${WRFOUT}"
rm -rf "${METDATA}" "${WRFOUT}" 

# read first entry in stepfile 
NEXTSTEP=$(python cycling.py)
export NEXTSTEP
echo
echo "   First Step: ${NEXTSTEP}"
echo

# launch first WPS instance
./run_cycling_WPS.sh
wait

# launch first WRF instance
./run_cycling_WRF.sh
wait
