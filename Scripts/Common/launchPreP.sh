#!/bin/bash
# script to perform pre-processing and submit a WPS job before the next job starts
# Andre R. Erler, 28/02/2013

# launch WPS for next step (if $NEXTSTEP is not empty)
if [[ -n "${NEXTSTEP}" ]] && [[ ! $NOWPS == 1 ]]
  then

    # decide to which queue to submit
    #TODO: call to Python script to get estimated wait time

    # this is only for the first instance; unset for next
    echo
    echo "   ***   Launching WPS for next step: ${NEXTSTEP}   ***   "
    echo
    # submitting independent WPS job
    echo "Command: "${SUBMITWPS} # print command
    echo "Variables: INIDIR=${INIDIR}, NEXTSTEP=${NEXTSTEP}, DEPENDENCY=${WPSSCRIPT}"
    eval "${SUBMITWPS}" # using variables: $INIDIR, $DEPENDENCY, $NEXTSTEP

else

    echo
    echo '   >>>   Skipping WPS!   <<<'
    echo

fi # WPS?

# this is only for the first instance; unset for next
unset NOWPS
