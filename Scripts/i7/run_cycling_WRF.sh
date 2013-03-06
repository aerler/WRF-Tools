#!/bin/bash
# script to run a WRF cycle in Bash (local)
# created 02/03/2013 by Andre R. Erler, GPL v3

## run configuration (otherwise set in queue settings)
export NODES=1 # there is only one...
export TASKS=4 # number of MPI task per node (Hpyerthreading!)
export THREADS=1 # number of OpenMP threads

## job settings
# set names (needed for folder names)
export JOBNAME='test' # job name (dummy variable, since there is no queue)
export INIDIR="${PWD}" # experiment root (launch directory)
# directory setup
export RUNNAME="${CURRENTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/" # step folder
export WRFOUT="${INIDIR}/wrfout/" # output directory
export SCRIPTDIR="${INIDIR}/scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="${INIDIR}/bin/" # location of executables (WRF and WPS)
# N.B.: use absolute path for script and bin folders
# important scripts
export WRFSCRIPT="run_cycling_WRF.pbs" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.pbs" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
export ARSCRIPT="" # archive script to be executed after WRF finishes
export ARINTERVAL="" # default: every time
# WRF and WPS wallclock  time limits (no way to query from queue system)
export WRFWCT='' # WRF wallclock  time limit; e.g. '06:00:00'
export WPSWCT='' # WPS wallclock  time limit; e.g. '01:00:00'

## WRF settings
# N.B.: these settings serve as fallback options when inferring from namelist fails
export GHG='' # GHG emission scenario
export RAD='' # radiation scheme
export LSM='' # land surface scheme


## job settings
export WRFSCRIPT="run_cycling_WRF.sh" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.sh" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
export ARSCRIPT="DUMMY" # archive script to be executed after WRF finishes
export ARINTERVAL="" # default: every time
export WAITFORWPS='NO' # stay on compute node until WPS for next step finished, in order to submit next WRF job
# directory setup
export INIDIR="${PWD}" # experiment root (launch directory)
export RUNNAME="${CURRENTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/" # step folder
export SCRIPTDIR="${INIDIR}/scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="${INIDIR}/bin/" # location of executables (WRF and WPS)
# N.B.: use absolute path for script and bin folders
