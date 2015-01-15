#!/bin/bash
# Andre R. Erler, 20/12/2013
# script to restart a crashed experiment on SciNet

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o rdse:nwtqh --long restart,reset,no-clean,simple,step:,nowps,wps,test,quiet,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# default parameters
RESET=0 # regenerate fresh namelist
CLEAN=1 # clean folder before restart
SIMPLE=0 # simple restart without increasing stability
TEST=0 # do not actually restart, just print parameters
QUIET=0 # suppress output 
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -s | --simple   )   SIMPLE=1; shift;;
    -d | --no-clean )   CLEAN=0; shift;;
    -r | --restart  )   CLEAN=0; SIMPLE=1; shift;;
         --reset    )   RESET=1; SIMPLE=1; shift;;
    -e | --step     )   CURRENTSTEP="$2"; shift 2;;
    -n | --nowps    )   NOWPS='NOWPS'; shift;;
    -w | --wps      )   NOWPS='FALSE'; shift;;
    -t | --test     )   TEST=1;   shift;;
    -q | --quiet    )   QUIET=1;  shift;;
    -h | --help     )   echo -e " \
                            \n\
    -s | --simple       do not change stability parameters \n\
    -d | --no-clean     don't clean run folder before restart \n\
    -r | --restart      restart a simulation without changes or clean-up (use when restart date was changed manually) \n\
         --reset        reset all namelist parameters \n\
    -e | --step         restart at this step \n\
    -n | --nowps        don't run WPS for next step \n\
    -w | --wps          (re-)run WPS for next step \n\
    -t | --test         dry-run for tests; just print parameters \n\
    -q | --quiet        do not print launch feedback \n\
    -h | --help         print this help \n\

    Note: don't use this script to restart from a different restart point; the restart date has to be changed manually, \n\
          real.exe (or WPS) needs to be rerun, and the previous WRF output files must not be deleted. \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

ERR=0
# load job/experiment parameters
INIDIR=${INIDIR:-"${PWD}"}; cd "$INIDIR" # make sure that this is the current directory
SCRIPTDIR="${INIDIR}/scripts" # location of the setup-script
EXP="${INIDIR%/}"; EXP="${EXP##*/}" # name of experiment
if [ -z $CURRENTSTEP ]; then 
  CURRENTSTEP=$( for W in `awk '{print $1}' stepfile`; do [ -e $W/ ] && break; done; echo $W ) # first step folder
  if [ ! -e "$INIDIR/$CURRENTSTEP/" ]; then 
    echo 'Error: no active step folder found!'
    exit 1
  fi # check step folder
elif [ ! -e "$INIDIR/$CURRENTSTEP/" ]; then
  echo 'Error: current step folder does not exist:'
  echo "$INIDIR/$CURRENTSTEP/" 
  exit 1
fi # default step
WORKDIR=${WORKDIR:-"$INIDIR/$CURRENTSTEP/"}
# determin next step, based on current step
NEXTSTEP=$( awk '{print $1}' stepfile | grep -A 1 "$CURRENTSTEP" | tail -n 1 )
#NEXTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d | head -n 2 | tail -n 1 ) # second step folder

# determine if WPS has to be run for next step
if [[ -n "$NOWPS" ]]; then
  NOWPS="$NOWPS" # redundant...
elif [ -f "${INIDIR}/${NEXTSTEP}"/run_*_WPS.* ] && [[ "${NEXTSTEP}" != "${CURRENTSTEP}" ]]; then
  # N.B. if there is only one folder, $NEXTSTEP will be equal to $CURRENTSTEP, but we need to run WPS
  NOWPS='NOWPS' 
else 
  NOWPS='FALSE'
fi
# N.B.: single brackets are essential, otherwise the globbing expression is not recognized

# source machine setup
source "${SCRIPTDIR}/setup_WRF.sh" > /dev/null # suppress output (not errors, though)
# needed to define $MAC, $QSYS, and $RESUBJOB
# guess run script name, bases on queue system
WRFSCRIPT="run_cycling_WRF.$(echo $QSYS | tr '[:upper:]' '[:lower:]')" # lower case file name extension

# move into working directory (step folder)
cd "${WORKDIR}"


# parse current namelist for stability parameters
# N.B.: the parameters here are also used for display, in any case
CUR_DELT=$(sed -n '/time_step/ s/^\ *time_step\ *=\ *\([0-9]*\).*$/\1/p' namelist.input) # time step
ERR=$(( ${ERR} + $? )) # capture exit code
CUR_EPSS=$(sed -n '/epssm/ s/^\ *epssm\ *=\ *\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # epssm parameter; one or zero times: [0-9]\?.5 -> .5 or 0.5
ERR=$(( ${ERR} + $? )) # capture exit code

## change stability parameters
if [[ "$SIMPLE" == '1' ]]; then
  
  # just read current values for display
  NEW_DELT="${CUR_DELT}"; NEW_EPSS="${CUR_EPSS}"
  
else # $SIMPLE != 1, i.e. change stability parameters
  
  # read some more parameters that are not needed just for display
	CUR_DAMP=$(sed -n '/dampcoef/ s/^\ *dampcoef\ *=\ *\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # dampcoef parameter; one or zero times: [0-9]\?.5 -> .5 or 0.5
	ERR=$(( ${ERR} + $? )) # capture exit code
	CUR_DIFF=$(sed -n '/diff_6th_factor/ s/^\ *diff_6th_factor\ *=\ *\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # diff_6th_factor parameter; one or zero times: [0-9]\?.5 -> .5 or 0.5
	ERR=$(( ${ERR} + $? )) # capture exit code
	CUR_SNDT=$(sed -n '/time_step_sound/ s/^\ *time_step_sound\ *=\ *\([0-9]*\).*$/\1/p' namelist.input) # time_step_sound parameter; integer
	ERR=$(( ${ERR} + $? )) # capture exit code

  ## define new stability parameters
  if [[ "$CUR_DELT" == '150' ]]; then #  && [[ "$CUR_EPSS" == *'.55' ]]
    NEW_DELT='120'; NEW_EPSS='0.75'; NEW_SNDT='5'
  elif [[ "$CUR_DELT" == '120' ]]; then #  && [[ "$CUR_EPSS" == *'.75' ]]
    NEW_DELT='90'; NEW_EPSS='0.85'; NEW_DAMP='0.06'; NEW_SNDT='6'
  elif [[ "$CUR_DELT" == '90' ]]; then #  && [[ "$CUR_EPSS" == *'.85' ]]
    NEW_DELT='60'; NEW_EPSS='0.95'; NEW_DIFF='0.09'; NEW_DAMP='0.09'; NEW_SNDT='7'
  elif [[ "$CUR_DELT" == '60' ]]; then #  && [[ "$CUR_EPSS" == *'.95' ]]
    NEW_DELT='45'; NEW_EPSS='0.97'; NEW_DIFF='0.12'; NEW_DAMP='0.12'; NEW_SNDT='8'
  elif [[ "$CUR_DELT" == '40' ]] || [[ "$CUR_DELT" == '45' ]]; then #  && [[ "$CUR_EPSS" == *'.95' ]]
    NEW_DELT='30'; NEW_EPSS='0.99'; NEW_DIFF='0.15'; NEW_DAMP='0.15'; NEW_SNDT='8'
  else #if [[ $FORCE != 1 ]]; then
    echo 'Error: No applicable set of parameters found!'
    exit 1
  fi # current state

  # change namelist (only if this is not a test!)
  if [ $TEST == 0 ]; then
	  if [[ -n "${NEW_DELT}" ]]; then
	    sed -i "/time_step/ s/^\ *time_step\ *=\ *[0-9]*.*$/ time_step = ${NEW_DELT}, ! edited by restart script; original value: ${CUR_DELT}/" namelist.input
	    ERR=$(( ${ERR} + $? )) # capture exit code
	  fi; if [[ -n "${NEW_EPSS}" ]]; then
	    sed -i "/epssm/ s/^\ *epssm\ *=\ *[0-9]\?.[0-9]*.*$/ epssm = ${NEW_EPSS}, ${NEW_EPSS}, ${NEW_EPSS}, ${NEW_EPSS}, ! edited by restart script; original value: ${CUR_EPSS}/" namelist.input    
	    ERR=$(( ${ERR} + $? )) # capture exit code
	  fi; if [[ -n "${NEW_DAMP}" ]]; then
	    sed -i "/dampcoef/ s/^\ *dampcoef\ *=\ *[0-9]\?.[0-9]*.*$/ dampcoef = ${NEW_DAMP}, ${NEW_DAMP}, ${NEW_DAMP}, ${NEW_DAMP}, ! edited by restart script; original value: ${CUR_DAMP}/" namelist.input    
	    ERR=$(( ${ERR} + $? )) # capture exit code
	  fi; if [[ -n "${NEW_DIFF}" ]]; then
	    sed -i "/diff_6th_factor/ s/^\ *diff_6th_factor\ *=\ *[0-9]\?.[0-9]*.*$/ diff_6th_factor = ${NEW_DIFF}, ${NEW_DIFF}, ${NEW_DIFF}, ${NEW_DIFF}, ! edited by restart script; original value: ${CUR_DIFF}/" namelist.input    
	    ERR=$(( ${ERR} + $? )) # capture exit code
	  fi; if [[ -n "${NEW_SNDT}" ]]; then
	    sed -i "/time_step_sound/ s/^\ *time_step_sound\ *=\ *[0-9]\?.[0-9]*.*$/ time_step_sound = ${NEW_SNDT}, ${NEW_SNDT}, ${NEW_SNDT}, ${NEW_SNDT}, ! edited by restart script; original value: ${CUR_SNDT}/" namelist.input    
	    ERR=$(( ${ERR} + $? )) # capture exit code
    fi 
  fi # if $TEST
  
fi # no simple restart

# put in restart links
for DOM in {1..4}; do
  ls ../wrfout/wrfrst_d0${DOM}_${CURRENTSTEP}* &> /dev/null
  if [ $? == 0 ] # check if restart file for DOM exists
  then ln -sf $( ls ../wrfout/wrfrst_d0${DOM}_${CURRENTSTEP}* | head -n 1 ); fi # create link to first
done # loop over domains

# change back into initial directory (experiment root)
cd "${INIDIR}"

# regenerate fresh namelist
if [ $RESET -eq 1 ]; then
  # re-run folder setup for current step (hide output)
  python scripts/cycling.py next $CURRENTSTEP > /dev/null
  ERR=$(( ${ERR} + $? )) # capture exit code
fi # if $RESET

## resubmit job
# Feedback
if [ $QUIET == 0 ]; then
  if [ $TEST == 1 ]; 
    then echo "Testing Restart of Experiment ${EXP}: NEXTSTEP=${CURRENTSTEP}; NOWPS=${NOWPS}; TIME_STEP=${NEW_DELT}; EPSSM=${NEW_EPSS}"
    else echo "Restarting Experiment ${EXP} on ${MAC}: NEXTSTEP=${CURRENTSTEP}; NOWPS=${NOWPS}; TIME_STEP=${NEW_DELT}; EPSSM=${NEW_EPSS}"
fi; fi # reporting level
# launch restart
[ $CLEAN == 1 ] && rm -rf ${CURRENTSTEP}/rsl.* ${CURRENTSTEP}/wrf*.nc
## restart job (using the machine setup)
export NEXTSTEP="${CURRENTSTEP}"
export NOWPS
if [ $TEST == 0 ]; then
  # launch WRF; required vars: INIDIR, NEXTSTEP, WRFSCRIPT, NOWPS, RSTCNT
  export NEXTSTEP="${CURRENTSTEP}" # $CURRENTSTEP corresponds to $NEXTSTEP in RESUBJOB!
  export NOWPS
  if [ -z "$ALTSUBJOB" ] || [[ "$MAC" == "$SYSTEM" ]]; then 
    eval "${RESUBJOB}" # on the same machine (default)
    ERR=$(( ${ERR} + $? )) # capture exit code
  else 
    eval "${ALTSUBJOB}" # alternate/remote command
    ERR=$(( ${ERR} + $? )) # capture exit code
  fi # if there is an alternative...
fi # if $TEST
# report errors
if [[ "${ERR}" != '0' ]]; then
  [ $QUIET == 0 ] && echo "ERROR: $ERR Errors(s) occured!"
  exit 1
else
  exit 0
fi # summary
