#!/bin/bash
# script to perform pre-processing and submit a WPS job before the next job starts
# Andre R. Erler, 28/02/2013

# The following environment variables have to be set by the caller:
# INIDIR, WRFSCRIPT, SUBMITWPS, NEXTSTEP
# Optional: NOWPS


# launch WPS for next step (if $NEXTSTEP is not empty)
if [[ -n "${NEXTSTEP}" ]] && [[ ! $NOWPS == 1 ]]
  then

    # this is only for the first instance; unset for next
    echo
    echo "   ***   Launching WPS for next step: ${NEXTSTEP}   ***   "
    echo
    # submitting independent WPS job
    eval "echo ${SUBMITWPS}" # print command
    eval "${SUBMITWPS}" # using variables: $INIDIR, $DEPENDENCY, $NEXTSTEP

    # N.B.: the queue selection process happens in the launch command ($SUBMITWPS),
    #       which is set in the setup-script
    
else

    echo
    echo '   >>>   Skipping WPS!   <<<'
    echo

fi # WPS?

# this is only for the first instance; unset for next
unset NOWPS
