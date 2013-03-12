#!/bin/bash
# script to run a WPScycle in Bash (local)
# created 02/03/2013 by Andre R. Erler, GPL v3

## run configuration (otherwise set in queue settings)
export NODES=1 # only one for WPS!
export TASKS=2 # number of MPI task per node (Hpyerthreading?)
export THREADS=1 # number of OpenMP threads

## job settings
# get PBS names (needed for folder names)
export JOBNAME='test' # job name (dummy variable, since there is no queue)
export INIDIR="${PWD}" # experiment root (launch directory)
# directory setup
export RUNNAME="${NEXTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/" # step folder
export SCRIPTDIR="${INIDIR}/scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="${INIDIR}/bin/" # location of executables (WRF and WPS)
# N.B.: use absolute path for script and bin folders
export WPSSCRIPT="run_cycling_WPS.pbs" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
# WPS wallclock  time limits (no way to query from queue system)
export WPSWCT='01:00:00' # WPS wallclock  time limit; dummy variable
