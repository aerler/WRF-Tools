 #!/bin/bash
# script to automatically restart job after a crash due to numerical instability
# Andre R. Erler, 21/08/2013

# The following environment variables have to be set by the caller:
# INIDIR, RSTDIR, WRFSCRIPT, WRFSCRIPT, RESUBJOB, NEXTSTEP
# optional: DEL_DELT, DEL_EPSS

DEL_DELT=${DEL_DELT:-'30'} # positive time-step increment
DEL_EPSS=${DEL_EPSS:-'0.25'} # positive epssm increment

# initialize Error counter
ERR=0

# skip if restart is not desired
if [[ "${AUTORST}" == 'RESTART' ]]
  then

## start restart logic

# parse WRF log files (rsl.error.0000) to check if crash occurred during run-time
cd "${WORKDIR}"
if [[ -e 'wrf/rsl.error.0000' ]] && [[ -n $(grep 'Timing for main:' 'wrf/rsl.error.0000') ]]
  then RTERR='RTERR'
  else RTERR='NO'
fi

# only restart if error occurred at run-time, not if it is an initialization error!
if [[ "${RTERR}" == 'RTERR' ]]
  then

    # parse current namelist for stability parameters
    cd "${WORKDIR}"
    CUR_DELT=$(sed -n '/time_step/ s/^\s*time_step\s*=\s*\([0-9]*\).*$/\1/p' namelist.input) # time step
    CUR_EPSS=$(sed -n '/epssm/ s/^\s*epssm\s*=\s*\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # epssm parameter; one ore zero times: [0-9]\?.5 -> .5 or 0.5

    # parse default namelist for stability parameters
    cd "${INIDIR}"
    INI_DELT=$(sed -n '/time_step/ s/^\s*time_step\s*=\s*\([0-9]*\).*$/\1/p' namelist.input) # time step
    INI_EPSS=$(sed -n '/epssm/ s/^\s*epssm\s*=\s*\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # epssm parameter

    # only restart, if stability parameters have not been changed yet
    if [[ "${CUR_DELT}" == "${INI_DELT}" ]] && [[ "${CUR_EPSS}" == "${INI_EPSS}" ]]
      then
	
	## change stability parameters
	# calculate new parameters (need to use bc for floating-point math)
	NEW_DELT=$( echo "${CUR_DELT} - ${DEL_DELT}" | bc ) # decrease time step
	NEW_EPSS=$( echo "${CUR_EPSS} + ${DEL_EPSS}" | bc ) # increase epssm parameter
	# change namelist
	cd "${WORKDIR}"
	sed -i "/time_step/ s/^\s*time_step\s*=\s*[0-9]*.*$/ time_step = ${NEW_DELT}, ! edited by the auto-restart script; original value: ${CUR_DELT}/" namelist.input
	sed -i "/epssm/ s/^\s*epssm\s*=\s*[0-9]\?.[0-9]*.*$/ epssm = ${NEW_EPSS}, ${NEW_EPSS}, ${NEW_EPSS}, ${NEW_EPSS}, ! edited by the auto-restart script; original value: ${CUR_EPSS}/" namelist.input    
	
	## resubmit job for next step
	cd "${INIDIR}"
	echo
	echo "   ***   Modifying namelist parameters for auto-restart   ***   "    
	echo
	echo "   TIME_STEP = ${NEW_DELT}"
	echo "   EPSSM     = ${NEW_EPSS}"
	echo
	# reset job step
	export NEXTSTEP="${CURRENTSTEP}"
	export NOWPS='NOWPS' # do not submit another WPS job!
	# launch restart
	eval "${SCRIPTDIR}/resubJob.sh" # requires submission command from setup script
	ERR=$(( ${ERR} + $? )) # capture exit code

    else # stability parameters have been changed

	## print error message
	echo
	echo "   ###   No auto-restart because namelist parameters have been modified!   ###   "
	echo "            (a severe numerical instability is likely!)"
	echo
	echo "   TIME_STEP  = ${CUR_DELT};   EPSSM  = ${CUR_EPSS}"
	echo
	ERR=$(( ${ERR} + 1 )) # increase exit code
      
    fi # if first auto-restart

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