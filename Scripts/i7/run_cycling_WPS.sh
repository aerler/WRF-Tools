#!/bin/bash
# script to run a WPScycle in Bash (local)
# created 02/03/2013 by Andre R. Erler, GPL v3

set -e # abort if anything goes wrong
# check if $NEXTSTEP is set, and exit, if not
if [[ -z "${NEXTSTEP}" ]]; then
  echo 'Environment variable $NEXTSTEP not set - aborting!'
  exit 1
fi
CURRENTSTEP="${NEXTSTEP}" # $NEXTSTEP will be overwritten


## job settings
export JOBNAME='test' # job name (dummy variable, since there is no queue)
export WRFSCRIPT="run_cycling_WRF.sh" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.sh" # WRF suffix assumed, WPS suffix substituted: # run configuration
export NODES=1 # only one for WPS!
export TASKS=2 # number of MPI task per node (Hpyerthreading?)
export THREADS=1 # number of OpenMP threads
# directory setup
export INIDIR="${PWD}"
export RUNNAME="${CURRENTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/"
export SCRIPTDIR="${INIDIR}/scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="${INIDIR}/bin/" # location of executables (WRF and WPS)
# N.B.: use absolute path for script and bin folders

## WPS settings
# optional arguments $RUNPYWPS, $RUNREAL, $RAMIN, $RAMOUT
export RUNPYWPS=1
export RUNREAL=1
# folders: $METDATA, $REALIN, $REALOUT
export METDATA="" # to output metgrid data set "ldisk = True" in meta/namelist.py
export REALOUT="${WORKDIR}" # this should be default anyway

# setup environment
cd "${INIDIR}"
source "${SCRIPTDIR}/setup_machine.sh" # load machine-specific stuff
# display message from before after setup display
echo
# RAM-disk settings
if [[ -e "${RAMDISK}" ]]; then
  export RAMIN=1
  export RAMOUT=1
  RAMMSG="RAM-disk found at ${RAMDISK} - using RAM disk for input and output."
else
  export RAMIN=0
  export RAMOUT=0
  RAMMSG='No RAM-disk found - using hard disk for input and output.'
fi # RAMDISK
echo


# launch feedback
echo
hostname
uname
echo
echo "   ***   ${JOBNAME}   ***   "
echo
echo "${RAMMSG}"
echo

## run WPS for this step
# start timing
echo
echo "   ***   Launching WPS for current step: ${CURRENTSTEP}   ***   "
date
echo

# run WPS driver script
cd "${INIDIR}"
eval "${SCRIPTDIR}/execWPS.sh"
ERR=$? # capture exit code
# mock input files for testing
# ERR=0
# if [[ -n "${NEXTSTEP}" ]]; then
# 	touch "${WORKDIR}/wrfinput_d01"
# 	touch "${WORKDIR}/wrfinput_d02"
# fi

if [[ $ERR != 0 ]]; then
  # end timing
  echo
  echo "   ###   WARNING: WRF step ${CURRENTSTEP} failed   ###   "
  date
  echo
  exit ${ERR} # abort if error occured!
fi # if error

# end timing
echo
echo "   ***   WPS step ${CURRENTSTEP} completed   ***   "
date
echo

# copy driver script into work dir to signal completion
cp "${INIDIR}/${WPSSCRIPT}" "${WORKDIR}"
