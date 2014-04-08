#!/bin/bash
set -e # abort if anything goes wrong
# script to set up a cycling WPS/WRF run: common/machine-independent part
# reads stepfile and sets up run folders 
# created 07/04/2014 by Andre R. Erler, GPL v3

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o r:gscknt:q --long restart:,nogeo,nostat,clean,time:,skipwps,nowps,queue -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# default settings
# translate arguments
MODE='' # NOGEO*, RESTART, START, CLEAN, or None (i.e. ''; default)
NEXTSTEP='' # next step to be processed (argument to --restart)
SKIPWPS=0 # whether or not to run WPS before the first step
NOWPS='FALSE' # passed to WRF
WAITTIME='00:15:00' # wait time for queue selector
QUEUE='SELECTOR' # queue mode: SELECTOR (default), SIMPLE
# parse arguments 
while true; do
  case "$1" in
    -r | --restart ) MODE='RESTART'; NEXTSTEP="$2"; shift 2 ;;
    -c | --clean ) MODE='CLEAN'; shift;; # default anyway...
    -g | --nogeo* ) MODE='NOGEO'; shift;;
    -s | --nostat* ) MODE='NOSTAT'; shift;;
    -k | --skipwps ) SKIPWPS=1; shift;;
    -w | --nowps ) NOWPS=NOWPS; shift;;
    -t | --wait ) WAITTIME="$2"; shift 2 ;;
    -q | --queue ) QUEUE='SIMPLE'; shift;;
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

# external settings (any of these can be changed from the environment)
EXP="${INIDIR%/}"; EXP="${EXP##*/}" # guess name of experiment
export JOBNAME=${JOBNAME:-"${EXP}_WRF"} # guess name of job
export INIDIR=${INIDIR:-"${PWD}"} # current directory
export STATICTGZ=${STATICTGZ:-'static.tgz'} # file for static data backup
export SCRIPTDIR="${INIDIR}/scripts" # location of the setup-script
export WRFOUT="${INIDIR}/wrfout/" # output directory
export METDATA='' # folder to collect output data from metgrid
export WPSSCRIPT='run_cycling_WPS.pbs' # WPS run-scripts
export WRFSCRIPT='run_cycling_WRF.pbs' # WRF run-scripts

# source machine setup
source "${SCRIPTDIR}/setup_WRF.sh"

# previous step in stepfile
if [ -n $NEXTSTEP ]; then
  LASTSTEP=$( grep -B 1 "^${NEXTSTEP}[[:space:]]" stepfile | head -n 1 | cut -d ' ' -f 1 )
  if [[ "$LASTSTEP" == "$NEXTSTEP" ]]; then LASTSTEP=''; fi # i.e. first step!
else
  LASTSTEP='' # first step
fi # if $NEXTSTEP

## start setup
cd "${INIDIR}"

# read first entry in stepfile
NEXTSTEP=$( python "${SCRIPTDIR}/cycling.py" "${LASTSTEP}" )
export NEXTSTEP

# run (machine-independent) setup:
export MODE
eval "${SCRIPTDIR}/setup_cycle.sh" # requires geogrid command


