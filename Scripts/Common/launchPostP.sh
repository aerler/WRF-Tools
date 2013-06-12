# #!/bin/bash
# # script to perform post-processing and submit an archive job after the main job completed
# # Andre R. Erler, 28/02/2013

# The following environment variables have to be set by the caller:
# INIDIR, ARSCRIPT, SUBMITAR, CURRENTSTEP
# Optional: ARINTERVAL


# launch archive script if specified
if [[ -n "${ARSCRIPT}" ]]
  then

    # check trigger interval
    ARTAG=''
    if [[ "${ARINTERVAL}" == 'YEARLY' ]]; then
    	if [[ "${CURRENTSTEP}" == ????-12 ]]; then
			ARTAG="${CURRENTSTEP%'-12'}"; fi # isolate interval, cut off rest
    elif [[ "${ARINTERVAL}" == 'MONTHLY' ]]; then
		if [[ "${CURRENTSTEP}" == ????-?? ]]; then
			ARTAG="${CURRENTSTEP}"; fi # just the step tag
    else
      ARTAG="${CURRENTSTEP}"
    fi # $ARINTERVAL

    # decide to launch or not
    if [[ -n "${ARTAG}" ]]
      then
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

fi # $ARSCRIPT
