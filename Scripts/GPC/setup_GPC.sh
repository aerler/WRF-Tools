#!/bin/bash
# source script to load GPC-specific settings for pyWPS, WPS, and WRF
# created 06/07/2012 by Andre R. Erler, GPL v3

# load modules
echo
module purge
module load intel/12.1.3 intelmpi/4.0.3.008 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel
#module load intel/12.1.3 intelmpi/4.0.3.008 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel
# pyWPS.py specific modules
if [[ ${RUNPYWPS} == 1 ]]; then
    module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
    #module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
fi
module list
echo

# RAM-disk settings: infer from queue
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    if [[ "${PBS_QUEUE}" == 'largemem' ]]; then
	export RAMIN=${RAMIN:-1}
	export RAMOUT=${RAMOUT:-1}
    else
	export RAMIN=${RAMIN:-1}
	export RAMOUT=${RAMOUT:-0}
    fi # PBS_QUEUE
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS
echo
echo "Running on ${PBS_QUEUE} queue; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
echo

# unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
ulimit -s unlimited

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# RAM disk folder (cleared and recreated if needed)
export RAMDISK=${RAMDISK:-'/dev/shm/aerler/'}
# check if the RAM=disk is actually there
if [[ ! -e "${RAMDISK}" ]]; then
  echo
  echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - folder does not exist!   <<<"
  echo
fi # no RAMDISK

# set up hybrid envionment: OpenMP and MPI (Intel)
export NODES=${NODES:-${PBS_NUM_NODES}} # set in PBS section
export TASKS=${TASKS:-16} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export KMP_AFFINITY=verbose,granularity=thread,compact
#export I_MPI_PIN_DOMAIN=omp
export I_MPI_DEBUG=1 # less output (currently no problems)
# Intel hybrid (mpi/openmp) job launch command
export HYBRIDRUN=${HYBRIDRUN:-'mpirun -ppn ${TASKS} -np $((NODES*TASKS))'} # evaluated by execWRF and execWPS

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'ssh gpc01 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by launchPreP
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./${ARSCRIPT} -v TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh gpc01 "cd \"${INIDIR}\"; qsub ./${WRFSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by resubJob
