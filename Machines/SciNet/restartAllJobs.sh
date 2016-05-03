#!/bin/bash
# Andre R. Erler, GPLv3, 23/11/2013
# script to restart crashed experiments on SciNet

# load list of active experiment (separated by machine)
source "${HOME}/running_experiments.sh" # defines: GPC_JOBS, TCS_JOBS, P7_JOBS

# root folder for experiments
DR="${1:-$PWD}"

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
          INIDIR="${DR}/${E}/"
          if [[ ! -e "${INIDIR}" ]]; then # check if folder actually exists, else complain
              echo "Folder '${INIDIR}' not found."
              MIA=$(( $MIA + 1 )) # modifies global counter!
          else
            cd "$INIDIR"
            # figure out next step
            CURRENTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d 2> /dev/null | head -n 1 ) # first step folder
            NEXTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d 2> /dev/null | tail -n 1 ) # second/last step folder
            if [[ -f "${INIDIR}/${NEXTSTEP}/run_cycling_WPS.pbs" ]]; then NOWPS='NOWPS' 
            else NOWPS='FALSE'; fi          
            # check, if experiment is active (if some run folder exist)
            if [[ ! -f "${MAC}" ]]; then
              echo "Experiment ${E} in this folder does not appear to run on machine ${MAC} - not restarting."
            elif [[ -n "${CURRENTSTEP}" ]]; then
              # check, if we need to run WPS and start sleeper job
              if [[ -f "${INIDIR}/${CURRENTSTEP}/run_cycling_WPS.pbs" ]]; then
                # put in restart links
                for DOM in {1..9}; do
                  RST="${INIDIR}/wrfout/wrfrst_d0${DOM}_${CURRENTSTEP}"
                  ls "${RST}"*  &> /dev/null
                  if [ $? == 0 ] # check if restart file for DOM exists
                  then ln -sf $( ls "${RST}"* | head -n 1 ) "${INIDIR}/${CURRENTSTEP}/"; fi
                  # N.B.: creates a link to the first restart file that matches
                done # loop over domains
				        echo "Restarting ${E} on ${MAC}!"				  
                echo "   NEXTSTEP=${CURRENTSTEP}; NOWPS=${NOWPS}"
                # clean up a bit
                rm -rf ${CURRENTSTEP}/rsl.* ${CURRENTSTEP}/wrf*.nc
  	            # restart job (this is a bit hackish and not as general as I would like it...)
  	            if [[ "$MAC" == 'GPC' ]]; then 
  	              ssh gpc-f102n084-ib0 "cd \"${INIDIR}\"; qsub ./run_cycling_WRF.pbs -v NOWPS=${NOWPS},NEXTSTEP=${CURRENTSTEP}"
  	            elif [[ "$MAC" == 'TCS' ]]; then
  	              ssh tcs-f11n06-ib0 "cd \"${INIDIR}\"; export NEXTSTEP=${CURRENTSTEP}; export NOWPS=${NOWPS}; llsubmit ./run_cycling_WRF.ll"
  	            elif [[ "$MAC" == 'P7' ]]; then
  	              ssh p7n01-ib0 "cd \"${INIDIR}\"; export NEXTSTEP=${CURRENTSTEP}; export NOWPS=${NOWPS}; llsubmit ./run_cycling_WRF.ll"
  	            fi # if MAC
                KIA=$(( $KIA + 1 )) # modifies global counter!
              else
                # This means, WPS did not complete and we need to run it first
                SCLOG="${INIDIR}/startCycle_${E}_WRF_${CURRENTSTEP}.log"
                if [[ -f "$SCLOG"  ]] && [ 0 -lt $(tail -n 1 "$SCLOG" | grep -c 'Waiting for WPS job to complete' ) ]; then
                  # This means, the sleeper job is waiting for WPS to complete - just restart WPS
                  if [[ "${WRFWCT}" != '00:00:00' ]] && [[ "${WRFWCT}" != '0' ]]; then WRFWCT='00:45:00'; fi
                  ssh gpc-f102n084-ib0 "cd '${INIDIR}'; export WRFWCT=${WRFWCT}; export WPSWCT='00:15:00'; export NEXTSTEP=${CURRENTSTEP}; export WPSSCRIPT='run_cycling_WPS.pbs'; python scripts/selectWPSqueue.py; sleep 3" # give command some time to complete
                  #ssh gpc04 "cd \"${INIDIR}\"; qsub ./run_cycling_WPS.pbs -v NEXTSTEP=${CURRENTSTEP}"
                else
                  # start new sleeper job (which will start WPS)
                  ssh p7n01-ib0 "cd '${INIDIR}'; nohup ./startCycle.sh --restart=${NEXTSTEP} --name=${JOBNAME} &> '$SCLOG' &"
                  #echo "ERROR: No active run directory found for experiment ${E}!"
                fi # handle incomplete/missing WPS
                KIA=$(( $KIA + 1 )) # modifies global counter!
              fi # if folder exists (prevent accidential deletion)                                 
            else
              echo "Experiment ${E} on ${MAC} appears to be inactive/completed - not restarting."
            fi # if $CURRENTSTEP
          fi # if folder exists
			  else
				  echo "Experiment ${E} on ${MAC} is running!"
				  OK=$(( $OK + 1 )) # modifies global counter!
      fi
  done
} # CHECK

# query machine for running jobs
OK=0 # counter for running jobs
KIA=0 # counter for crashed jobs
MIA=0 # counter for missing folders

# GPC
GPC_LIST=$( ssh gpc01 'showq -nu aerler | grep aerler' )
CHECK "${GPC_JOBS}" "${GPC_LIST}" 'GPC'

# TCS
TCS_LIST=$( ssh tcs-f11n06-ib0 'llq -l | grep -B 3 '\''Owner: aerler'\''' )
CHECK "${TCS_JOBS}" "${TCS_LIST}" 'TCS'

# P7
P7_LIST=$( ssh p701 'llq -m | grep '\''Job Name'\''' )
CHECK "${P7_JOBS}" "${P7_LIST}" 'P7'

# count number of jobs
N=$( echo $GPC_JOBS $TCS_JOBS $P7_JOBS | wc -w )
# number of jobs unaccounted for
ERR=$(( $N - $OK - $KIA -$MIA ))

# report summary
echo 
if [ ${OK} == ${N} ]; then
    echo "   <<<   All ${OK} jobs were still running!  >>>   "
elif [ ${KIA} == 0 ]; then
    echo "   ===   ${OK} jobs were still running. ${ERR} errors encountered!   ===   "
elif [ ${OK} == 0 ] && [ ${ERR} == 0 ]; then
    echo "   <<<   ${KIA} jobs were restarted!  >>>   "
elif [ ${OK} == 0 ]; then
    echo "   ===   ${KIA} jobs were restarted. ${ERR} errors encountered!   ===   "
elif [ ${ERR} == 0 ]; then
    echo "   <<<   ${KIA} jobs were restarted; ${OK} were still running!   >>>   "
else
    echo "   ===   ${KIA} jobs were restarted; ${OK} were still running. ${ERR} errors encountered!   ===   "
fi # summary
if [ ${MIA} > 0 ]; then
    echo " ${MIA} job folders were not found in root folder '${DR}'"; fi
echo

exit $ERR
