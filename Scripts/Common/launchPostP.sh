# #!/bin/bash
# # script to perform post-processing and submit an archive job after the main job completed
# # Andre R. Erler, 28/02/2013

# The following environment variables have to be set by the caller:
# INIDIR, SUBMITAR, CURRENTSTEP, NEXTSTEP, ARSCRIPT, AVGSCRIPT
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

function CHECKINTERVAL () {
  # decide to launch or not and determine date parameter/tag
  # N.B.: this mechanism assumes that step names represent dates in the format YYYY-MM-DD
  local INTERVAL="${1}" # the string identifying the interval
  local CURRENT="${2}" # the current step
  local NEXT="${3}" # the next step
  TAG='' # the return parameter 
  if [[ "${INTERVAL}" == 'YEARLY' ]]; then
    CY=$( echo "${CURRENT}" | cut -d '-' -f 1 )
    if [[ -z "${CY}" ]]; then INTERVALERROR; fi # parsing error
    NY=$( echo "${NEXT}" | cut -d '-' -f 1 )
    if [[ "${CY}" != "${NY}" ]]; then TAG="${CY}"; fi # just the current year
  elif [[ "${INTERVAL}" == 'MONTHLY' ]]; then
	  CY=$( echo "${CURRENT}" | cut -d '-' -f 1 )
	  CM=$( echo "${CURRENT}" | cut -d '-' -f 2 )
	  if [[ -z "${CM}" ]]; then INTERVALERROR; fi # parsing error
	  NM=$( echo "${NEXT}" | cut -d '-' -f 2 )
	  if [[ "${CM}" != "${NM}" ]]; then TAG="${CY}-${CM}"; fi # current year and month
  elif [[ "${INTERVAL}" == 'DAILY' ]]; then
	  CY=$( echo "${CURRENT}" | cut -d '-' -f 1 )
	  CM=$( echo "${CURRENT}" | cut -d '-' -f 2 )
	  CD=$( echo "${CURRENT}" | cut -d '-' -f 3 )
	  if [[ -z "${CD}" ]]; then INTERVALERROR; fi # parsing error
	  ND=$( echo "${NEXT}" | cut -d '-' -f 3 )
		if [[ "${CD}" != "${ND}" ]]; then TAG="${CY}-${CM}-${CD}"; fi # current year, month, and day
  else
    TAG="${CURRENT}"
  fi # $INTERVAL
  # return TAG string
  echo "${TAG}" # return only takes exit codes - strings have to be returned via echo!
} # function CHECKINTERVAL


# launch archive script if specified
if [[ -n "${ARSCRIPT}" ]]
  then

    # test interval and date parameter
    ARTAG=$( CHECKINTERVAL "${ARINTERVAL}" "${CURRENTSTEP}" "${NEXTSTEP}" )
    
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
				echo "   ***   Launching archive script for WRF output: ${ARTAG}   ***   "
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

# launch averaging script if specified
if [[ -n "${AVGSCRIPT}" ]]
  then

    # test interval and date parameter
    AVGTAG=$( CHECKINTERVAL "${AVGINTERVAL}" "${CURRENTSTEP}" "${NEXTSTEP}" )
    
    # collect logs and launch archive job
    if [[ -n "${AVGTAG}" ]]
      then
        # launch averaging job
        echo
        echo "   ***   Launching averaging script for WRF output: ${AVGTAG}   ***   "
        echo
        #eval "echo ${SUBMITAVG}" # print command; now done with set -x
        set -x
        eval "${SUBMITAVG}" # using variables: $AVGTAG, $AVGINTERVAL
        set +x        
    fi # $AVGTAG

fi # $AVGSCRIPT
