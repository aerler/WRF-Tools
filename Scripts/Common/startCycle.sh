#!/bin/bash
# script to set up a cycling WPS/WRF run: common/machine-independent part
# reads stepfile and sets up run folders 
# created 07/04/2014 by Andre R. Erler, GPL v3

set -e # abort if anything goes wrong

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o r:gsvqkwlmn:t:N:h --long restart:,clean,nogeo,nostat,verbose,quiet,skipwps,nowait,nowps,norst,setrst:,time:,name:,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# default settings
# translate arguments
MODE='' # NOGEO*, RESTART, START, CLEAN, or None (i.e. ''; default)
VERBOSITY=1 # level of output/feedback
NEXTSTEP='' # next step to be processed (argument to --restart)
SKIPWPS=0 # whether or not to run WPS before the first step
NOWPS='FALSE' # passed to WRF
RSTCNT=0 # restart counter
WAITTIME='' # manual override for queue selector (SciNet only; default: 15 min.)
DEFWCT="00:15:00" # another variable is necessary to prevent the setup script from changing the value
# parse arguments 
while true; do
  case "$1" in
    -r | --restart )   MODE='RESTART'; NEXTSTEP="$2"; shift 2 ;; # second argument is restart step
         --clean   )   MODE='CLEAN'; shift;; # delete wrfout/ etc.; short option would be dangerous...
    -g | --nogeo   )   MODE='NOGEO'; shift;; # don't run geogrid
    -s | --nostat  )   MODE='NOSTAT'; shift;; # don't run geogrid and don't archive static data
    -v | --verbose )   VERBOSITY=2; shift;; # print more output
    -q | --quiet   )   VERBOSITY=0; shift;; # don't print output
    -k | --skipwps )   SKIPWPS=1; shift;; # don't run WPS for *this* step
    -w | --nowps   )   NOWPS='NOWPS'; shift;; # don't run WPS for *next* step
    -l | --nowait  )   QWAIT=0; shift;; # don't wait for WPS to finish
    -m | --norst   )   RSTCNT=1000; shift;; # should be enough to prevent restarts...
    -n | --setrst  )   RSTCNT="$2"; shift 2 ;; # (re-)set restart counter
    -t | --time    )   WAITTIME="$2"; shift 2 ;; # WRFWCT crashes for some reason...    
    -N | --name    )   JOBNAME="$2"; shift 2 ;; # set WRF jobname - just for identification
    -h | --help    )   echo -e " \
                          \n\
    -r | --restart     restart cycle at given step \n\
         --clean       delete all WRF output (wrfout/) --- be careful! \n\
    -g | --nogeo       don't run geogrid (has to be run before) \n\
    -s | --nostat      don't run geogrid and don't archive static data \n\
    -v | --verbose     print more output \n\
    -q | --quiet       don't print output \n\
    -k | --skipwps     don't run WPS for *this* step \n\
    -w | --nowps       don't run WPS for *next* step \n\
    -l | --nowait      don't wait for WPS to finish (and skip WPS completion check) \n\
    -m | --norst       suppress restarts \n\
    -n | --setrst      (re-)set restart counter \n\
    -t | --time        maximum wait time for WPS \n\
    -N | --name        set WRF jobname - just for identification \n\
    -h | --help        print this help \n\
                           "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    # break loop
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

# external settings (any of these can be changed from the environment)
export INIDIR=${INIDIR:-"${PWD}"} # current directory
EXP="${INIDIR%/}"; EXP="${EXP##*/}" # guess name of experiment
export JOBNAME=${JOBNAME:-"${EXP}_WRF"} # guess name of job
export STATICTGZ=${STATICTGZ:-'static.tgz'} # file for static data backup
export SCRIPTDIR="${INIDIR}/scripts" # location of the setup-script
export BINDIR="${INIDIR}/bin/"  # location of executables nd scripts (WPS and WRF)
export WRFOUT="${INIDIR}/wrfout/" # output directory
export METDATA='' # folder to collect output data from metgrid
export DATATYPE='' # needed to handle leap years
export WPSSCRIPT='run_cycling_WPS.pbs' # WPS run-scripts
export WRFSCRIPT='run_cycling_WRF.pbs' # WRF run-scripts
export WRFVERSION='' # WRF version; default set in setup_WRF.sh
WRFWCT='00:15:00' # wait time for queue selector; only temporary; default set above ($DEFWCT)
export PYTHONVERSION=3 # pyWPS et al. are now converted to Python 3
export GEOTASKS=4 # Number of geogrid procceses
export WRFENV='2019b' # WRF environment version

# source machine setup
source "${SCRIPTDIR}/setup_WRF.sh" > /dev/null # suppress output (not errors, though)

# previous step in stepfile
if [ -n $NEXTSTEP ]; then
  LASTSTEP=$( grep -B 1 "^${NEXTSTEP}[[:space:]]" stepfile | head -n 1 | cut -d ' ' -f 1 | cut -f 1 )
  # N.B.: use cut twice to catch both, space and tab delimiters
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
export VERBOSITY
export GEOTASKS
export WRFENV 
eval "${SCRIPTDIR}/setup_cycle.sh" # requires geogrid command


## launch jobs
[ $VERBOSITY -gt 0 ] && echo

# submit first WPS instance
if [ $SKIPWPS == 1 ]; then
  [ $VERBOSITY -gt 0 ] && echo 'Skipping WPS!'
else
  
  # launch WPS; waiting for completion is handled below
  # handle waittime for queue selector; $WRFWCT is set above
  if [[ -n "${WAITTIME}" ]]; then 
    WRFWCT="${WAITTIME}" # manual override
  elif [[ "${WRFWCT}" != '00:00:00' ]] && [[ "${WRFWCT}" != '0' ]]; then
    WRFWCT="${DEFWCT}" # default wait time
    # if WRFWCT is 0, leave it: it means the primary queue will always be used
  fi # if waittime should be changed
  # other variables are set above: INIDIR, NEXTSTEP, WPSSCRIPT
	[ $VERBOSITY -gt 0 ] && echo "   Submitting WPS for experiment ${EXP}: NEXTSTEP=${NEXTSTEP}"
  # launch WPS; required vars: INIDIR, NEXTSTEP, WPSSCRIPT, WRFWCT
  if [ -z "$ALTSUBWPS" ] || [[ "$MAC" == "$SYSTEM" ]]
    then eval "${SUBMITWPS}" # on the same machine (default)
    else eval "${ALTSUBWPS}" # alternate/remote command
  fi # if there is an alternative...  

fi # if $SKIPWPS
[ $VERBOSITY -gt 0 ] && echo

# figure out, if we have to wait until WPS job is completed
if [ -z $QWAIT ] && [ -n $QSYS ]; then
  if [[ "$QSYS" == 'LL' ]]; then QWAIT=1
  elif [[ "$QSYS" == 'PBS' ]]; then QWAIT=1 # currently, dependencies don't work...
  elif [[ "$QSYS" == 'SB' ]]; then QWAIT=1 # currently, dependencies don't work...
  elif [[ "$QSYS" == 'SGE' ]]; then QWAIT=1
  else QWAIT=1 # assume the system does not support dependencies
fi; fi # $QWAIT

if [ $QWAIT == 1 ]; then
  # wait until WPS job is completed: check presence of WPS script as signal of completion
  # this is only necessary, if the queue system does not support job dependencies
  # N.B.: use option -l/--nowait to skip the WPS verification step

  if [[ ! -f "${INIDIR}/${NEXTSTEP}/${WPSSCRIPT}" ]]; then
    # start wait cycle
  	[ $VERBOSITY -gt 0 ] && echo
  	[ $VERBOSITY -gt 0 ] && echo "   Waiting for WPS job to complete..."
  	while [[ ! -f "${INIDIR}/${NEXTSTEP}/${WPSSCRIPT}" ]]
  	  do sleep 30
  	done
  	[ $VERBOSITY -gt 0 ] && echo "   ... WPS completed."
  fi # WPS already done?

  # check WPS exit status
  if [ 1 -ne $(grep -c 'SUCCESS COMPLETE REAL_EM INIT' "${INIDIR}/${NEXTSTEP}/real/rsl.error.0000") ]; then
    # do not continue 
    echo
    echo "   ###   WPS for step ${NEXTSTEP} failed --- aborting!   ###   "
    echo
		exit 1
  fi # if WPS failed

fi # job dependency...

[ $VERBOSITY -gt 0 ] && echo

# submit WRF instance to queue
[ $VERBOSITY -gt 0 ] && echo "   Submitting WRF ${EXP} on ${MAC}: NEXTSTEP=${NEXTSTEP}; NOWPS=${NOWPS}"
# launch WRF; required vars: INIDIR, NEXTSTEP, WRFSCRIPT, NOWPS, RSTCNT
if [ -z "$ALTSUBJOB" ] || [[ "$MAC" == "$SYSTEM" ]]
  then eval "${RESUBJOB}" # on the same machine (default)
  else eval "${ALTSUBJOB}" # alternate/remote command
fi # if there is an alternative...
[ $VERBOSITY -gt 0 ] && echo

# exit with 0 exit code: if anything went wrong we would already have aborted
exit 0
