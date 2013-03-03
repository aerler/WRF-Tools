#!/bin/bash
# source script to load i7-specific settings for pyWPS, WPS, and WRF
# created 02/03/2013 by Andre R. Erler, GPL v3

# launch feedback etc.
echo
hostname
uname
echo
echo "   ***   ${JOBNAME}   ***   "
echo

# unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
ulimit -s unlimited

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/media/tmp/"

# set up hybrid envionment: OpenMP and OpenMPI
# OpenMPI hybrid (mpi/openmp) job launch command
#export OMP_NUM_THREADS=$THREADS
export HYBRIDRUN="mpirun -n $((TASKS*NODES))" # OpenMPI, not Intel

# job submission command (for next step)
export RESUBJOB='cd ${INIDIR}; export NEXTSTEP=${NEXTSTEP}; ./${SCRIPTNAME} &' # evaluated by resubJob
