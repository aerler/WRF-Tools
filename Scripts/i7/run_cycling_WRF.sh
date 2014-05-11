#!/bin/bash
# script to run a WRF cycle in Bash (local)
# created 02/03/2013 by Andre R. Erler, GPL v3

## run configuration (otherwise set in queue settings)
#export NODES=1 # there can be only one...
export TASKS=4 # number of MPI task per node (Hpyerthreading!)
export THREADS=1 # number of OpenMP threads

## job settings
# set names (needed for folder names)
export JOBNAME='' # job name (dummy variable, since there is no queue)
export INIDIR="${PWD}" # experiment root (launch directory)
# important scripts
export WRFSCRIPT="run_cycling_WRF.sh" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.sh" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
# WRF and WPS wallclock  time limits (no way to query from queue system)
export WRFWCT='10:00:00' # WRF wallclock time limit
export WPSWCT='01:00:00' # WPS wallclock time limit
# WRF resource requirements (read by setup scripts)
export WRFNODES=4 # number of threads used by WRF