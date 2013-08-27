# #!/bin/bash
# # script to perform post-processing and submit an archive job after the main job completed
# # Andre R. Erler, 28/02/2013

# The following environment variables have to be set by the caller:
# INIDIR, ARSCRIPT, SUBMITAR, CURRENTSTEP
# Optional: ARINTERVAL

function INTERVALERROR () { # using global namespace - no arguments
  echo
  echo "   ###   Archive Error: step name does not conform   ###   "
  echo "   ###   to naming convention for archive interval   ###   "
  echo
  echo "             Step name: ${CURRENTSTEP}"
  echo "      Archive interval: ${ARINTERVAL}"
  echo
  exit 1 # exit immediately with error
} # function INTERVALERROR

# launch archive script if specified
if [[ -n "${ARSCRIPT}" ]]
  then

    # decide to launch or not and determine archive parameters
    # N.B.: this mechanism assumes that step names represent dates in the format YYYY-MM-DD
    ARTAG=''
    if [[ "${ARINTERVAL}" == 'YEARLY' ]]; then
	CY=$( echo "${CURRENTSTEP}" | cut -d '-' -f 1 )
	if [[ -z "${CY}" ]]; then INTERVALERROR; fi # parsing error
	NY=$( echo "${NEXTSTEP}" | cut -d '-' -f 1 )
    	if [[ "${CY}" != "${NY}" ]]
	  then ARTAG="${CY}"; fi # just the current year
    elif [[ "${ARINTERVAL}" == 'MONTHLY' ]]; then
	CY=$( echo "${CURRENTSTEP}" | cut -d '-' -f 1 )
	CM=$( echo "${CURRENTSTEP}" | cut -d '-' -f 2 )
	if [[ -z "${CM}" ]]; then INTERVALERROR; fi # parsing error
	NM=$( echo "${NEXTSTEP}" | cut -d '-' -f 2 )
    	if [[ "${CM}" != "${NM}" ]]
	  then ARTAG="${CY}-${CM}"; fi # current year and month
    elif [[ "${ARINTERVAL}" == 'DAILY' ]]; then
	CY=$( echo "${CURRENTSTEP}" | cut -d '-' -f 1 )
	CM=$( echo "${CURRENTSTEP}" | cut -d '-' -f 2 )
	CD=$( echo "${CURRENTSTEP}" | cut -d '-' -f 3 )
	if [[ -z "${CD}" ]]; then INTERVALERROR; fi # parsing error
	ND=$( echo "${NEXTSTEP}" | cut -d '-' -f 3 )
    	if [[ "${CD}" != "${ND}" ]]
	  then ARTAG="${CY}-${CM}-${CD}"; fi # current year, month, and day
    else
      ARTAG="${CURRENTSTEP}"
    fi # $ARINTERVAL

    # collect logs and launch archive job
    if [[ -n "${ARTAG}" ]]
      then
	# collect and archive logs
	echo
	echo "Cleaning up and archiving log files in ${ARTAG}_logs.tgz "
	cd "${INIDIR}"
	tar czf "${WRFOUT}/${ARTAG}_logs.tgz" *.out # all logfiles
	mkdir -p "${INIDIR}/logs" # make sure log folder exists
	mv *.out "${INIDIR}/logs" # move log files to log folder
	# launch archive job
	echo
	echo "   ***   Launching archive script for WRF output: ${CURRENTSTEP}   ***   "
	echo
	#eval "echo ${SUBMITAR}" # print command; now done with set -x
	set -x
	eval "${SUBMITAR}" # using variables: $ARTAG, $ARINTERVAL
	set +x
	# using these default options: TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}
	# additional default options set in archive script: RMSRC, VERIFY, DATASET, DST, SRC
    fi # $ARTAG
    
    # also launch another archive job, if this is the final step
    # N.B.: if this action triggers, a regular archive job for the last interval should
    #       already have been submitted. This should also be the case, when the archive 
    #       interval does not coincide with the last step. ($CURRENTSTEP will be
    #       different from $NEXTSTEP, because $NEXTSTEP will be empty.)
    if [[ -n "${CURRENTSTEP}" ]] && [[ -z "${NEXTSTEP}" ]]
      then
	echo
	echo "   ***   Launching FINAL archive job for WRF experiment clean-up   ***   "
	echo
	if [[ -z "${ARTAG}" ]] # just a precaution
	  then echo "WARNING: no regular archive job was submitted for the final stage!"; fi
	# set $TAGS environment variable to communicate command
	ARTAG='FINAL'
	set -x
	eval "${SUBMITAR}" # using variables: $ARTAG, $ARINTERVAL
	set +x
	# using these default options: TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}
	# additional default options set in archive script: RMSRC, VERIFY, DATASET, DST, SRC
    fi # if final step

fi # $ARSCRIPT
