#!/bin/bash
# script to resubmit next job after current job completed
# Andre R. Erler, 28/02/2013

# The following environment variables have to be set by the caller:
# INIDIR, RSTDIR, WRFSCRIPT, RESUBJOB, NEXTSTEP, NOWPS

# set default for $NOWPS and $RSTCNT, to avoid problems when passing variable to next job
NOWPS=${NOWPS:-'WPS'} # i.e. launch WPS, unless instructed otherwise
RSTCNT=${RSTCNT:-0} # assume no restart by default
# $NEXTSTEP is handled below

## launch WRF for next step (if $NEXTSTEP is not empty)
if [[ -n "${NEXTSTEP}" ]]
  then

   # read date string for restart file
    RSTDATE=$(sed -n "/${NEXTSTEP}/ s/${NEXTSTEP}[[:space:]]\+'\([-_\:0-9]\{19\}\)'[[:space:]]\+'[-_\:0-9]\{19\}'$/\1/p" stepfile)
    # N.B.: '[[:space:]]' also matches tabs; '\ ' only matches one space; '\+' means one or more
    # some code to catch sed errors on TCS
    if [[ -z "${RSTDATE}" ]]
      then 
        echo '   ###   ERROR: cannot read step file - aborting!   ###   '
        # print some diagnostics
        echo
        echo 'Current PATH variable:'
        echo "${PATH}"
        echo
        echo 'sed executable:'
        which sed
        echo
        echo 'Stepfile line:'
        grep "${NEXTSTEP}" stepfile        
        echo
        echo 'stepfile stat:'
        stat stepfile
        echo
        exit 1
    fi # RSTDATE
#    while [[ -z "${RSTDATE}" ]] 
#      do # loop appears to be necessary to prevent random read errors on TCS
#       	echo ' Error: could not read stepfile - trying again!'
#        RSTDATE=$(sed -n "/${NEXTSTEP}/ s/${NEXTSTEP}[[:space:]].\(.*\).[[:space:]].*$/\1/p" stepfile)
#      	sleep 600 # prevent too much file access
#    done
    NEXTDIR="${INIDIR}/${NEXTSTEP}" # next $WORKDIR
    cd "${NEXTDIR}"
    # link restart files
    echo
    echo "Linking restart files to next working directory:"
    echo "${NEXTDIR}"
    for RESTART in "${RSTDIR}"/wrfrst_d??_"${RSTDATE//:/[_:]}"; do # match hh:mm:ss and hh_mm_ss
      ln -sf "${RESTART}"; done  
    
    # check for WRF input files (in next working directory)
    # N.B.: this option can potentially waste a lot of walltime and should be used with caution
    if [[ "${WAITFORWPS}" == 'WAIT' ]] &&  [[ ! -f "${WPSSCRIPT}" ]]
		  then
		    echo
		    echo "   ***   Waiting for WPS to complete...   ***"
		    echo
		    while [[ ! -f "${WPSSCRIPT}" ]]; do
		       sleep 30 # need faster turnover to submit next step
		    done
		fi # $WAITFORWPS

    
    # go back to initial directory
    cd "${INIDIR}"            
                        
    # now, decide what to do...
    if [[ -f "${NEXTDIR}/${WPSSCRIPT}" ]]
      then
        
        if [ 0 -lt $(grep -c 'SUCCESS COMPLETE REAL_EM INIT' "${NEXTDIR}/real/rsl.error.0000") ]
          then
            
				    # submit next job (start next cycle)
				    echo
				    echo "   ***   Launching WRF for next step: ${NEXTSTEP}   ***   "
				    echo
				    # execute submission command (set in setup-script; machine-specific)
				    #eval "echo ${RESUBJOB}" # print command; now done with set -x
				    set -x
				    eval "${RESUBJOB}" # execute command
            ERR=$? # capture exit status
				    set +x
				    exit $? # exit with exit status from reSubJob
				    
		    else # WPS crashed

            # do not continue 
            echo
            echo "   ###   WPS for next step (${NEXTSTEP}) failed --- aborting!   ###   "
            echo
			  	  exit 1
		    
	      fi # if WPS successful
		
    else # WPS not finished (yet)
	    
		    # start a sleeper job, if available
        if [[ -n "{SLEEPERJOB}" ]]
          then
            
		        # submit next job (start next cycle)
            echo
            echo "   ---      WPS for next step (${NEXTSTEP}) has not finished yet     ---   "
            echo "   +++   Launching sleeper job to restart WRF when WPS finished   +++   "
            echo "            (see log file below for details and job status)   "
            echo
            # submit sleeper script (set in setup-script; machine-specific)
            set -x
            eval "${SLEEPERJOB}" # execute command
            ERR=$? # capture exit status
            set +x
            exit $? # exit with exit status from reSubJob
		    
        else # WPS did not run - abort

            # do not continue 
            echo
            echo "   ###   WPS for next step (${NEXTSTEP}) failed --- aborting!   ###   "
            echo
            exit 1
                        
        fi # if sleeper job
		    		  
    fi # if WPS finished...
    
else
  
	  echo
	  echo '   ===   No $NEXTSTEP --- cycle terminated.   ===   '
	  echo '         (no more jobs have been submitted)   '
	  echo
	  exit 0 # most likely this is OK

fi # $NEXTSTEP
