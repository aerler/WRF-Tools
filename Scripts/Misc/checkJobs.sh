#!/bin/bash
# Andre R. Erler, 06/09/2013
# script to list status of active experiments on SciNet

# load list of active experiment (separated by machine)
source "${HOME}/running_experiments.sh" # defines: GPC_JOBS, TCS_JOBS, P7_JOBS

# function that does the actual check
function CHECK {
  local JOBS="${1}" # list of running experiments
  local LISTING="${2}" # queue status output
  local MAC="${3}" # machine we are checking
  for E in ${JOBS}
    do
      if [[ -z $( echo ${LISTING} | grep ${E}_WRF ) ]]
	then 
	  echo
	  echo "Experiment ${E} on ${MAC} is not running!"
	  MIA=$(( $MIA + 1 )) # modifies global counter!
      else
	  #echo "Experiment ${E} on ${MAC} is running!"
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
    echo "   <<<   All ${OK} jobs are running!  >>>   "
elif [ ${MIA} == 0 ]; then
    echo "   ===   ${OK} jobs are running. ${ERR} errors encountered!   ===   "
elif [ ${OK} == 0 ] && [ ${ERR} == 0 ]; then
    echo "   ###   All ${MIA} jobs crashed!!!  ###   "
elif [ ${OK} == 0 ]; then
    echo "   ###   ${MIA} jobs crashed! ${ERR} errors encountered!   ###   "
elif [ ${ERR} == 0 ]; then
    echo "   ===   ${MIA} jobs crashed; ${OK} still running.   ===   "
else
    echo "   ===   ${MIA} jobs crashed; ${OK} still running. ${ERR} errors encountered!   ===   "
fi # summary
echo

# exit with number of crashed/missing jobs and errors
exit $(( $N - $OK ))
