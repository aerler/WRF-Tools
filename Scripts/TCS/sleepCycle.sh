#!/bin/bash
# script to delay a WRF run start until WPS is finished (for TCS)
# created 15/08/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
NEXTSTEP=$1 # step name/folder as first argument
NOWPS=$2 # to run or not to run WPS
INIDIR="${PWD}" # current directory
WPSSCRIPT="run_cycling_WPS.pbs"
WRFSCRIPT="run_cycling_WRF.ll"

# launch feedback
echo
echo "   Next Step: ${NEXTSTEP}"
# echo "   Root Dir: ${INIDIR}"
echo 

# submit first independent WPS job to GPC (not TCS!)
echo
if [[ "$NOWPS" != 'NOWPS' ]]
  then
    echo "   Submitting first WPS job to GPC queue:"
    ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"
else
  echo "   WARNING: not running WPS! (make sure WPS was started manually)"
fi
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
llsubmit ./${WRFSCRIPT}
echo
