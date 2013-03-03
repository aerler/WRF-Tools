#!/bin/bash
# script to run a WRF cycle in Bash (local)
# created 02/03/2013 by Andre R. Erler, GPL v3

set -e # abort if anything goes wrong
# check if $NEXTSTEP is set, and exit, if not
if [[ -z "${NEXTSTEP}" ]]; then
  echo 'Environment variable $NEXTSTEP not set - aborting!'
  exit 1
fi
CURRENTSTEP="${NEXTSTEP}" # $NEXTSTEP will be overwritten
export NEXTSTEP
export CURRENTSTEP


## job settings
export JOBNAME='test' # job name (dummy variable, since there is no queue)
export SCRIPTNAME="run_cycling_WRF.sh" # WRF suffix assumed
export DEPENDENCY="run_cycling_WPS.sh" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
export ARSCRIPT="DUMMY" # archive script to be executed after WRF finishes
export ARINTERVAL="" # default: every time
export WAITFORWPS='NO' # stay on compute node until WPS for next step finished, in order to submit next WRF job
# run configuration
export NODES=1 # set in PBS section
export TASKS=4 # number of MPI task per node (Hpyerthreading!)
export THREADS=1 # number of OpenMP threads
# directory setup
export INIDIR="${PWD}" # experiment root (launch directory)
export RUNNAME="${CURRENTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/" # step folder
export SCRIPTDIR="./scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="./bin/" # location of executables (WRF and WPS)
# N.B.: use relative path with './' or absolute path without

## real.exe settings
export RUNREAL=0 # don't run real.exe again (requires metgrid.exe output)
# optional arguments: $RUNREAL, $RAMIN, $RAMOUT
# folders: $REALIN, $REALOUT
# N.B.: RAMIN/OUT only works within a single node!

## WRF settings
# optional arguments: $RUNWRF, $GHG ($RAD, $LSM)
export GHG='' # GHG emission scenario
export RAD='' # radiation scheme
export LSM='' # land surface scheme
# folders: $WRFIN, $WRFOUT, $TABLES
export REALOUT="${WORKDIR}" # this should be default anyway
export WRFIN="${WORKDIR}" # same as $REALOUT
export WRFOUT="${INIDIR}/wrfout/" # output directory
export RSTDIR="${WRFOUT}"

# setup environment
cd "${INIDIR}"
source "${SCRIPTDIR}/setup_i7.sh" # load machine-specific stuff


###                                                                    ##
###   ***   Below this line nothing should be machine-specific   ***   ##
###                                                                    ##


## run WPS/pre-processing for next step
# read next step from stepfile
NEXTSTEP=$(python "${SCRIPTDIR}/cycling.py" "${CURRENTSTEP}")

# launch pre-processing for next step
eval "${SCRIPTDIR}/launchPreP.sh" # primarily for WPS and real.exe


## run WRF for this step
# N.B.: work in existing work dir, created by caller instance;
# i.e. don't remove namelist files in working directory!

# start timing
echo
echo "   ***   Launching WRF for current step: ${CURRENTSTEP}   ***   "
date
echo

# run script
# eval "${SCRIPTDIR}/execWRF.sh"
# ERR=$? # capture exit code
# mock restart files for testing (correct linking)
ERR=0
if [[ -n "${NEXTSTEP}" ]]; then
	touch "${WORKDIR}/wrfrst_d01_${NEXTSTEP}_00"
	touch "${WORKDIR}/wrfrst_d01_${NEXTSTEP}_01"
fi

if [[ $ERR != 0 ]]; then
  # end timing
  echo
  echo "   ###   WARNING: WRF step ${CURRENTSTEP} failed   ###   "
  date
  echo
  exit ${ERR}
fi # if error

# end timing
echo
echo "   ***   WRF step ${CURRENTSTEP} completed   ***   "
date
echo


## launch post-processing
eval "${SCRIPTDIR}/launchPostP.sh" # mainly archiving, but may include actual post-processing


## resubmit job for next step
eval "${SCRIPTDIR}/resubJob.sh" # requires submission command from setup script


# copy driver script into work dir to signal completion
cp "${INIDIR}/${SCRIPTNAME}" "${WORKDIR}"
