#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and 
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
export STEPFILE='stepfile' # file in $INIDIR
export INIDIR="${PWD}" # current directory
CASENAME='cycling' # name tag

# launch feedback
echo
echo "   ***   Starting Cycle  ***   "
echo
echo "   Stepfile: ${STEPFILE}"
echo "   Root Dir: ${INIDIR}"
echo 

# clear some folders
cd "${INIDIR}"
export METDATA="${INIDIR}/metgrid/"
export WRFOUT="${INIDIR}/wrfout/"
echo "   Clearing Output Folders:"
echo "${METDATA}"
echo "${WRFOUT}"
rm -rf "${METDATA}" "${WRFOUT}" 

# run geogrid
# clear files
cd "${INIDIR}"
# run with parallel processes
echo
echo "   Running geogrid.exe"
echo
#rm -f geo_em.d??.nc geogrid.log*
#mpiexec -n 8 ./geogrid.exe

# read first entry in stepfile 
NEXTSTEP=$(python cycling.py)
#export NEXTSTEP
echo
echo "   First Step: ${NEXTSTEP}"
echo

# prepare first working directory
# set restart to False for first step
sed -i '/restart\s/ s/restart\s*=\s*\.true\..*$/restart = .false.,/' \
 "${INIDIR}/${NEXTSTEP}/namelist.input"  
# and make sure the rest is on restart
sed -i '/restart\s/ s/restart\s*=\s*\.false\..*$/restart = .true.,/' \
 "${INIDIR}/namelist.input"
echo "   Setting restart option and interval in namelist."
echo

# submit first independent WPS job to GPC (not TCS!)
echo
echo "   Submitting first WPS job to GPC queue:"
ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./run_${CASENAME}_WPS.pbs -v NEXTSTEP=${NEXTSTEP}"
echo

# wait until WPS job is completed: check presence of wrfinput files
echo
echo "   Waiting for WPS job on GPC to complete..."
while [[ ! -e "${INIDIR}/${NEXTSTEP}/wrfinput_d01" ]]
  do
    sleep 30
done
echo "   ... WPS completed. Submitting WRF job to LoadLeveler."
echo

# submit first WRF instance on TCS
echo
echo "   Submitting first WRF job to TCS queue:"
export NEXTSTEP # this is how env vars are passed to LL
llsubmit ./run_${CASENAME}_WRF.ll
echo
