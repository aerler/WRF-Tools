#!/bin/bash
# Andre R. Erler, GPLv3, 23/11/2013
# script to restart crashed experiments on SciNet

# load list of active experiment (separated by machine)
source "${HOME}/running_experiments.sh" # defines: GPC_JOBS, TCS_JOBS, P7_JOBS

# function that does the actual check
function CHECK {
  local JOBS="${1}" # list of running experiments
  local LISTING="${2}" # queue status output
  local MAC="${3}" # machine we are checking
  for E in ${JOBS}
    do
		  echo
      if [[ -z $( echo ${LISTING} | grep ${E}_WRF ) ]]
				then 
				  echo "Restarting ${E} on ${MAC}!"				  
          INIDIR="${DR}/${E}/"
          cd "$INIDIR"
          # figure out next step
          CURRENTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d | head -n 1 ) # first step folder
          NEXTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d | tail -n 1 ) # second/last step folder
          if [[ -f "${INIDIR}/${NEXTSTEP}/run_cycling_WPS.pbs" ]]; then NOWPS='NOWPS' 
          else NOWPS='FALSE'; fi          
          echo "   NEXTSTEP=${CURRENTSTEP}; NOWPS=${NOWPS}"
          # clean up a bit
          if [[ -n "${CURRENTSTEP}" ]] && [[ -f "${INIDIR}/${CURRENTSTEP}/run_cycling_WPS.pbs" ]]; then
            rm -rf ${CURRENTSTEP}/rsl.* ${CURRENTSTEP}/wrf*.nc
	          # restart job (this is a bit hackish and not as general as I would like it...)
	          if [[ "$MAC" == 'GPC' ]]; then 
	            ssh gpc01 "cd \"${INIDIR}\"; qsub ./run_cycling_WRF.pbs -v NOWPS=${NOWPS},NEXTSTEP=${CURRENTSTEP}"
	          elif [[ "$MAC" == 'TCS' ]]; then
	            ssh tcs02 "cd \"${INIDIR}\"; export NEXTSTEP=${CURRENTSTEP}; export NOWPS=${NOWPS}; llsubmit ./run_cycling_WRF.ll"
	          elif [[ "$MAC" == 'P7' ]]; then
	            ssh p701 "cd \"${INIDIR}\"; export NEXTSTEP=${CURRENTSTEP}; export NOWPS=${NOWPS}; llsubmit ./run_cycling_WRF.ll"
	          fi # if MAC
            MIA=$(( $MIA + 1 )) # modifies global counter!
          else
            echo "ERROR: No active run directory found for experiment ${E}!"
          fi # if folder exists (prevent accidential deletion)                                 
			  else
				  echo "Experiment ${E} on ${MAC} is running!"
				  OK=$(( $OK + 1 )) # modifies global counter!
      fi
  done
} # CHECK

# query machine for running jobs
OK=0 # counter for running jobs
MIA=0 # counter for crashed jobs

# GPC
GPC_LIST=$( ssh gpc01 'showq -nu aerler | grep aerler' )
CHECK "${GPC_JOBS}" "${GPC_LIST}" 'GPC'

# TCS
TCS_LIST=$( ssh tcs01 'llq -l | grep -B 3 '\''Owner: aerler'\''' )
CHECK "${TCS_JOBS}" "${TCS_LIST}" 'TCS'

# P7
P7_LIST=$( ssh p701 'llq -m | grep '\''Job Name'\''' )
CHECK "${P7_JOBS}" "${P7_LIST}" 'P7'

# count number of jobs
N=$( echo $GPC_JOBS $TCS_JOBS $P7_JOBS | wc -w )
# number of jobs unaccounted for
ERR=$(( $N - $OK - $MIA ))

# report summary
echo 
if [ ${OK} == ${N} ]; then
    echo "   <<<   All ${OK} jobs were still running!  >>>   "
elif [ ${MIA} == 0 ]; then
    echo "   ===   ${OK} jobs were still running. ${ERR} errors encountered!   ===   "
elif [ ${OK} == 0 ] && [ ${ERR} == 0 ]; then
    echo "   <<<   ${MIA} jobs were restarted!  >>>   "
elif [ ${OK} == 0 ]; then
    echo "   ===   ${MIA} jobs were restarted. ${ERR} errors encountered!   ===   "
elif [ ${ERR} == 0 ]; then
    echo "   <<<   ${MIA} jobs were restarted; ${OK} were still running!   >>>   "
else
    echo "   ===   ${MIA} jobs were restarted; ${OK} were still running. ${ERR} errors encountered!   ===   "
fi # summary
echo

exit $ERR
