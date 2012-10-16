#!/bin/bash
# source script to load TCS-specific settings for WRF
# created 06/07/2012 by Andre R. Erler, GPL v3

# launch feedback etc.
echo
hostname
uname
echo
echo "   ***   ${LOADL_JOB_NAME}   ***   "
echo


# load modules
module purge
module load xlf/14.1 vacpp/12.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc python/2.3.4
#module load xlf/13.1 vacpp/11.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
module list
echo

# no RAM disk on TCS!
export RAMIN=0 
export RAMOUT=0

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-i --reply=no'
		
# set up hybrid envionment: OpenMP and MPI (Intel)
export TARGET_CPU_RANGE=-1

# next variable is for performance, so that memory is allocated as
# close to the cpu running the task as possible (NUMA architecture)
export MEMORY_AFFINITY=MCM

# next variable is for ccsm_launch
# note that there is one entry per MPI task, and each of these is then potentially multithreaded
THPT=1
for ((i=1; i<$((NODES*TASKS)); i++)); do 
	THPT="${THPT}:${THREADS}"; 
done
export THRDS_PER_TASK="${THPT}"

# launch executable
export HYBRIDRUN="poe ccsm_launch"

# # ccsm_launch is a "hybrid program launcher" for MPI-OpenMP programs
# # poe reads from a commands file, where each MPI task is launched
# # with ccsm_launch, which takes care of the processor affinity for the
# # OpenMP threads.  Each line in the poe.cmdfile reads something like:
# #        ccsm_launch ./myCPMD
# # and there must be as many such lines as MPI tasks.  The number of MPI
# # tasks must match the task_geometry statement describing the process placement
# # on the nodes.
