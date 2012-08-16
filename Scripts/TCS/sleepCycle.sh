#!/bin/bash
# script to delay a WRF run start until WPS is finished (for TCS)
# created 15/08/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
export NEXTSTEP='1980-04' # step name/folder 
export INIDIR="${PWD}" # current directory
CASENAME='cycling' # name tag
WPSSCRIPT="run_${CASENAME}_WPS.pbs"

# launch feedback
echo
echo "   ***   Starting Cycle  ***   "
echo
echo "   Next Step: ${NEXTSTEP}"
echo "   Root Dir: ${INIDIR}"
echo 

# submit first independent WPS job to GPC (not TCS!)
echo
echo "   Submitting first WPS job to GPC queue:"
#ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./run_${CASENAME}_WPS.pbs -v NEXTSTEP=${NEXTSTEP}"
echo "   WARNING: WPS disabled!"
echo

# wait until WPS job is completed: check presence of WPS script as signal of completion
echo
echo "   Waiting for WPS job on GPC to complete..."
while [[ ! -e "${INIDIR}/${NEXTSTEP}/${WPSSCRIPT}" ]]
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
