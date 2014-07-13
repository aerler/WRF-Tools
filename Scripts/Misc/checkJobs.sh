#!/bin/bash
# Andre R. Erler, 06/09/2013, revised 07/04/2014
# script to list status of active experiments on SciNet

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o m:q --long machine:,quiet -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# set argument defaults
LGPC=1; LTCS=1; LP7=1 # check these machines
QUIET=0 # print summary or just return exit code
# parse arguments 
while true; do
  case "$1" in
    -m | --machine )
      # select machine to check (switch off others)
      case "$2" in 
        gpc | GPC ) LTCS=0; LP7=0;;
        tcs | TCS ) LGPC=0; LP7=0;;
        p7 | P7 ) LGPC=0; LTCS=0;;
      esac # case $2 
      shift 2 ;;
    -q | --quiet ) QUIET=1; shift;;
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

# load list of active experiment (separated by machine)
source "${HOME}/running_experiments.sh" # defines: GPC_JOBS, TCS_JOBS, P7_JOBS

# function that does the actual check
function CHECK {
  local JOBS="${1}" # list of running experiments
  local LISTING="${2}" # queue status output
  local MAC="${3}" # machine we are checking
  for E in ${JOBS}
    do
      if [[ -z $( echo ${LISTING} | grep ${E}_WRF ) ]]
	then 
	  echo
	  echo "Experiment ${E} on ${MAC} is not running!"
	  MIA=$(( $MIA + 1 )) # modifies global counter!
      else
	  #echo "Experiment ${E} on ${MAC} is running!"
	  OK=$(( $OK + 1 )) # modifies global counter!
      fi
  done
} # CHECK

# query machine for running jobs
N=0 # total number of jobs (count)
OK=0 # counter for running jobs
MIA=0 # counter for crashed jobs

# GPC
if [ $LGPC == 1 ]; then
  # query queue for my jobs
	GPC_QUEUE=$( ssh gpc01 'qstat -u ${USER} | grep ${USER}' )
  # check showq output against "registered" jobs
	CHECK "${GPC_JOBS}" "${GPC_QUEUE}" 'GPC'
  # count entries in job list
  N=$(( $N + $( echo $GPC_JOBS | wc -w ) ))
fi # if $LGPC

# TCS
if [ $LTCS == 1 ]; then
	TCS_QUEUE=$( ssh tcs01 'llq -l -u ${USER} | grep '\''Job Name'\''' )
	CHECK "${TCS_JOBS}" "${TCS_QUEUE}" 'TCS'
  N=$(( $N + $( echo $TCS_JOBS | wc -w ) ))
fi # if $LTCS

# P7
if [ $LP7 == 1 ]; then
	P7_QUEUE=$( ssh p701 'llq -m -u ${USER} | grep '\''Job Name'\''' )
	CHECK "${P7_JOBS}" "${P7_QUEUE}" 'P7'
  N=$(( $N + $( echo $P7_JOBS | wc -w ) ))
fi # if $LP7

# number of jobs unaccounted for
ERR=$(( $N - $OK - $MIA ))

# report summary
if [ $QUIET != 1 ]; then
	echo 
	if [ ${OK} == ${N} ]; then
	    echo "   <<<   All ${OK} jobs are running!  >>>   "
	elif [ ${MIA} == 0 ]; then
	    echo "   ===   ${OK} jobs are running. ${ERR} errors encountered!   ===   "
	elif [ ${OK} == 0 ] && [ ${ERR} == 0 ]; then
	    echo "   ###   All ${MIA} jobs crashed!!!  ###   "
	elif [ ${OK} == 0 ]; then
	    echo "   ###   ${MIA} jobs crashed! ${ERR} errors encountered!   ###   "
	elif [ ${ERR} == 0 ]; then
	    echo "   ===   ${MIA} jobs crashed; ${OK} still running.   ===   "
	else
	    echo "   ===   ${MIA} jobs crashed; ${OK} still running. ${ERR} errors encountered!   ===   "
	fi # summary
	echo
fi # if not $QUIET

# exit with number of crashed/missing jobs and errors
exit $(( $N - $OK ))
