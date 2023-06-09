 #!/bin/bash
# script to automatically restart job after a crash due to numerical instability
# Andre R. Erler, 21/08/2013, revised 04/03/2014

# The following environment variables have to be set by the caller:
# INIDIR, WORKDIR, SCRIPTDIR, CURRENTSTEP, WRFSCRIPT, RESUBJOB
# optional: AUTORST, MAXRST, DEL_DELT, MUL_EPSS, ENU_SNDT, DEN_SNDT
# N.B.: the variable RSTCNT is set and reused by this script, so it shoudl also be passed on by the caller

# maximum number of restarts
AUTORST=${AUTORST:-'RESTART'} # restart once by default
MAXRST=${MAXRST:--1} # this can be set externally, is ignored the first time...
RSTCNT=${RSTCNT:-0} # need to initialize, incase it is not set
# N.B.: the default settings and behavior is for backward compatibility... 
# stability parameters
DEL_DELT=${DELT:-'30'} # negative time-step increment ($DELT is set in run-script)
MUL_EPSS=${MUL_EPSS:-'0.50'} # epssm factor
ENU_SNDT=${ENU_SNDT:-5} # sound time step enumerator
DEN_SNDT=${DEN_SNDT:-4} # sound time step denominator

# initialize Error counter
ERR=0

# skip if restart is not desired
if [[ "${AUTORST}" == 'RESTART' ]] # && [ ${MAXRST} -gt 0 ] 
  then

## start restart logic

# parse WRF log files (rsl.error.0000) to check if crash occurred during run-time
cd "${WORKDIR}"
if [[ -e 'wrf/rsl.error.0000' ]] && [[ -n $(grep 'Timing for main:' 'wrf/rsl.error.0000') ]]
  then RTERR='RTERR'
  else RTERR='NO'
fi

# Check for known non-run-time errors
if grep -q "Error in \`mpiexec.hydra': corrupted size vs. prev_size:" ${INIDIR}/${SLURM_JOB_NAME}.${SLURM_JOB_ID}.out; then

  # Move into ${INIDIR}
  cd "${INIDIR}"

  # Prompt on screen
  echo
  echo "   The mpiexec.hydra corrupted size error has occured. Restarting."
  echo

  # Export parameters as needed
  export RSTDIR # Set in job script; usually output dir.
  export NEXTSTEP="${CURRENTSTEP}"
  export NOWPS='NOWPS' # Do not submit another WPS job.
  export RSTCNT # Restart counter, set above.

  # Resubmit job for next step
  export WAITTIME=120
  eval "${SLEEPERJOB}" # This requires submission command from setup script.
  ERR=$(( ${ERR} + $? )) # Update exit code.

# Restart if error occurred at run-time, not if it is an initialization error!
elif [[ "${RTERR}" == 'RTERR' ]]
  then

    if [ ${RSTCNT} -ge ${MAXRST} ]; then
    
	    # this happens, if RSTCNT or MAXRST were set incorrectly or not set at all
      echo
      echo "   ###   No auto-restart because restart counter (${RSTCNT}) exceeds maximum number of restarts (${MAXRST})!   ###   "
      echo "         (i.e. RSTCNT and/or MAXRST were set to an invalid value, intentionally or unintentionally)"
      echo
      ERR=$(( ${ERR} + 1 )) # increase exit code
    
    else # i.e. $RSTCNT <= $MAXRST
		            
	    # parse current namelist for stability parameters
	    cd "${WORKDIR}"
	    CUR_DELT=$(sed -n '/time_step/ s/^\s*time_step\s*=\s*\([0-9]*\).*$/\1/p' namelist.input) # time step
	    CUR_EPSS=$(sed -n '/epssm/ s/^\s*epssm\s*=\s*\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # epssm parameter; one ore zero times: [0-9]\?.5 -> .5 or 0.5
	    CUR_SNDT=$(sed -n '/time_step_sound/ s/^\s*time_step_sound\s*=\s*\([0-9]*\).*$/\1/p' namelist.input) # sound time step multiplier
	    # parse default namelist for stability parameters
	    cd "${INIDIR}"
	    INI_DELT=$(sed -n '/time_step/ s/^\s*time_step\s*=\s*\([0-9]*\).*$/\1/p' namelist.input) # time step
	
	    # only restart, if stability parameters have not been changed yet
	    # N.B.: the restart will only be triggered, if 
	    #       1) the timestep has not been changed yet (no previous restart)
	    #       2) the restart counter is set and larger than 0 and smaller than MAXRST
	    #           and the timestep is larger than the DELT increment (i.e. will still be positive)
	    if  [ ${RSTCNT} -gt 0 ] && [ ${CUR_DELT} -gt ${DEL_DELT} ] || [ ${CUR_DELT} -eq ${INI_DELT} ]
	    # N.B.: in single brackets the < > operators act as in shell commands; -lt and -gt have to be used
	      then
		
		      ## increment restart counter 
	        RSTCNT=$(( $RSTCNT + 1 )) # if RSTCNT is not defined, 0 is assumed, and the result is 1
	
				 	## change stability parameters
			    # calculate new parameters (need to use bc for floating-point math)
					NEW_DELT=$( echo "${CUR_DELT} - ${DEL_DELT}" | bc ) # decrease time step by fixed amount
					NEW_EPSS=$( echo "1.00 - ${MUL_EPSS}*(1.00 - ${CUR_EPSS})" | bc ) # increase epssm parameter
	        NEW_SNDT=$( echo "${ENU_SNDT}*${CUR_SNDT}/${DEN_SNDT}" | bc ) # increase epssm parameter
	
			    # Check if new time step is less than or equal to zero
                           if  [ ${NEW_DELT} -le 0 ]
                           then
                           
                             echo
                             echo "   ###   No auto-restart because new time step would become less than or equal to zero. "
                             echo
                             ERR=$(( ${ERR} + 1 )) # increase exit code                          
                           
                           # If new dt is positive
                           else
			    
			      # change namelist
					  cd "${WORKDIR}"
					  sed -i "/time_step/ s/^\s*time_step\s*=\s*[0-9]*.*$/ time_step = ${NEW_DELT}, ! edited by the auto-restart script; previous value: ${CUR_DELT}/" namelist.input
					  sed -i "/epssm/ s/^\s*epssm\s*=\s*[0-9]\?.[0-9]*.*$/ epssm = ${NEW_EPSS}, ${NEW_EPSS}, ${NEW_EPSS}, ${NEW_EPSS}, ! edited by the auto-restart script; previous value: ${CUR_EPSS}/" namelist.input    
					  sed -i "/time_step_sound/ s/^\s*time_step_sound\s*=\s*[0-9]*.*$/ time_step_sound = ${NEW_SNDT}, ${NEW_SNDT}, ${NEW_SNDT}, ${NEW_SNDT}, ! edited by the auto-restart script; previous value: ${CUR_SNDT}/" namelist.input
					
			      ## resubmit job for next step
					  cd "${INIDIR}"
					  echo
					  echo "   ***   Modifying namelist parameters for auto-restart   ***   "    
	          echo "            (this is restart attempt number ${RSTCNT} of ${MAXRST})"
					  echo
					  echo "         TIME_STEP = ${NEW_DELT}"
					  echo "             EPSSM = ${NEW_EPSS}"
	          echo "   TIME_STEP_SOUND = ${NEW_SNDT}"
					  echo
			      # reset job step
	          export RSTDIR # set in job script; usually output dir
					  export NEXTSTEP="${CURRENTSTEP}"
					  export NOWPS='NOWPS' # do not submit another WPS job!
	          export RSTCNT # restart counter, set above
			      # launch restart
					  eval "${SCRIPTDIR}/resubJob.sh" # requires submission command from setup script
					  ERR=$(( ${ERR} + $? )) # capture exit code
					  
					fi  
	      
	    else # stability parameters have been changed
	
			    ## print error message
					echo
	        if [[ 0 == ${MAXRST} ]]; then # maximum restarts exceeded
			        echo "   ###   No auto-restart because maximum number of restarts is set to 0!   ###   "
			        echo "                (one restart may have been performed nevertheless)          "
			    elif [[ ${RSTCNT} == ${MAXRST} ]]; then # maximum restarts exceeded
	            echo "   ###   No auto-restart because maximum number of restarts (${MAXRST}) was exceeded!   ###   "
	            echo "                 (a severe numberical instability is likely!)          "
	        elif [ ${CUR_DELT} -le ${DEL_DELT} ]; then # maximum restarts exceeded
	            echo "   ###   No auto-restart because the time step would become negative!   ###   "
	            echo "              (consider reducing the maximum number of restarts)          "        
	        else
							echo "   ###   No auto-restart because namelist parameters have been modified!   ###   "
					    echo "         (and no restart counter was set; likely due to manual restart)          "
				  fi
					echo
					echo "   TIME_STEP  = ${CUR_DELT};   EPSSM  = ${CUR_EPSS};   TIME_STEP_SOUND  = ${CUR_SNDT}"
					echo
					ERR=$(( ${ERR} + 1 )) # increase exit code
	      
	    fi # if auto-restart

    fi # if $RSTCNT > MAXRST

else # crash did not occur at run time (i.e. not during time-stepping)
    
    ## print error message
    echo
    echo "   ###   No auto-restart because the crash did not occur during run-time!   ###   "
    echo "            (a numerical instability is unlikely)"
    echo
    ERR=$(( ${ERR} + 1 )) # increase exit code

fi # run-time error?

fi # if $AUTORST

exit ${ERR} # exit with number of errors as exit code
