#!/bin/bash
# Andre R. Erler, 20/12/2013
# script to restart a crashed experiment on SciNet

# default parameters
FORCE=0 # force restart, even if no paramter set was found
SIMPLE=0 # simple restart without increasing stability 
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -f | --force ) FORCE=1; shift;;
    -s | --simple ) SIMPLE=1; shift;;
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

ERR=0
# load job/experiment parameters
INIDIR=${INIDIR:-"${PWD}"}; cd "$INIDIR" # make sure that this is the current directory
EXP="${INIDIR%/}"; EXP="${EXP##*/}" # name of experiment
CURRENTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d | head -n 1 ) # first step folder
WORKDIR=${WORKDIR:-"$INIDIR/$CURRENTSTEP/"}
NEXTSTEP=$( ls [0-9][0-9][0-9][0-9]-[0-9][0-9]* -d | head -n 2 | tail -n 1 ) # second step folder
# determine if WPS has to be run for next step
if [ -f "${INIDIR}/${NEXTSTEP}"/run_*_WPS.* ]; then NOWPS='NOWPS' 
else NOWPS='FALSE'; fi
# N.B.: single brakets are essential, otherwise the globbing expression is not recognized
# determine machine
MAC=${MAC:-''}
if [[ -f 'start_cycle_GPC.sh' ]]; then MAC='GPC'
elif [[ -f 'start_cycle_TCS.sh' ]]; then MAC='TCS'
elif [[ -f 'start_cycle_P7.sh' ]]; then MAC='P7'
elif [[ -z "$MAC" ]]; then 
    echo 'ERROR: unknown machine!'
    exit 1 # abort
fi # if $MAC

# parse current namelist for stability parameters
cd "${WORKDIR}"
CUR_DELT=$(sed -n '/time_step/ s/^\ *time_step\ *=\ *\([0-9]*\).*$/\1/p' namelist.input) # time step
ERR=$(( ${ERR} + $? )) # capture exit code
CUR_EPSS=$(sed -n '/epssm/ s/^\ *epssm\ *=\ *\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # epssm parameter; one or zero times: [0-9]\?.5 -> .5 or 0.5
ERR=$(( ${ERR} + $? )) # capture exit code
CUR_DAMP=$(sed -n '/dampcoef/ s/^\ *dampcoef\ *=\ *\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # dampcoef parameter; one or zero times: [0-9]\?.5 -> .5 or 0.5
ERR=$(( ${ERR} + $? )) # capture exit code
CUR_DIFF=$(sed -n '/diff_6th_factor/ s/^\ *diff_6th_factor\ *=\ *\([0-9]\?.[0-9]*\).*$/\1/p' namelist.input) # diff_6th_factor parameter; one or zero times: [0-9]\?.5 -> .5 or 0.5
ERR=$(( ${ERR} + $? )) # capture exit code
CUR_SNDT=$(sed -n '/time_step_sound/ s/^\ *time_step_sound\ *=\ *\([0-9]*\).*$/\1/p' namelist.input) # time_step_sound parameter; integer
ERR=$(( ${ERR} + $? )) # capture exit code


## define new stability parameters
if [[ "$SIMPLE" == '0' ]]; then
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
  elif [[ $FORCE != 1 ]]; then
    echo 'Error: No applicable set of parameters found!'
    exit 1
  fi # current state
fi # no simple restart

# change namelist
cd "${WORKDIR}"
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

# put in restart links
for DOM in {1..4}; do
  if [ -f ../wrfout/wrfrst_d0${DOM}_${CURRENTSTEP}* ] # check if restart file for DOM exists; don't use [[ ]] here!
    then ln -sf ../wrfout/wrfrst_d0${DOM}_${CURRENTSTEP}*; fi # create link
done # loop over domains

## resubmit job
cd "${INIDIR}"
# Feedback
echo "Restarting Experiment ${EXP} on ${MAC}: NEXTSTEP=${CURRENTSTEP}; NOWPS=${NOWPS}; TIME_STEP=${NEW_DELT}; EPSSM=${NEW_EPSS}"
# launch restart
rm -rf ${CURRENTSTEP}/rsl.* ${CURRENTSTEP}/wrf*.nc
# restart job (this is a bit hackish and not as general as I would like it...)
if [[ "$MAC" == 'GPC' ]]; then 
  ssh gpc01 "cd \"${INIDIR}\"; qsub ./run_cycling_WRF.pbs -v NOWPS=${NOWPS},NEXTSTEP=${CURRENTSTEP}"
  ERR=$(( ${ERR} + $? )) # capture exit code
elif [[ "$MAC" == 'TCS' ]]; then
  ssh tcs02 "cd \"${INIDIR}\"; export NEXTSTEP=${CURRENTSTEP}; export NOWPS=${NOWPS}; llsubmit ./run_cycling_WRF.ll"
  ERR=$(( ${ERR} + $? )) # capture exit code
elif [[ "$MAC" == 'P7' ]]; then
  ssh p701 "cd \"${INIDIR}\"; export NEXTSTEP=${CURRENTSTEP}; export NOWPS=${NOWPS}; llsubmit ./run_cycling_WRF.ll"
  ERR=$(( ${ERR} + $? )) # capture exit code
fi # if MAC
# report errors
if [[ "${ERR}" != '0' ]]; then
  echo "ERROR: $ERR Errors(s) occured!"
  exit 1
else
  exit 0
fi # summary
