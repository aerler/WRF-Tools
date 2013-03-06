#!/bin/bash
# source script to load i7-specific settings for pyWPS, WPS, and WRF
# created 02/03/2013 by Andre R. Erler, GPL v3

# RAM disk folder (cleared and recreated if needed)
export RAMDISK=${RAMDISK:-'/media/tmp/'}
# check if the RAM=disk is actually there
if [[ ! -e "${RAMDISK}" ]]; then
  echo
  echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - folder does not exist!   <<<"
  echo
fi # no RAMDISK

# RAM-disk settings: infer from queue
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    export RAMIN=${RAMIN:-1}
    export RAMOUT=${RAMOUT:-1}
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

# set up hybrid envionment: OpenMP and OpenMPI
export NODES=${NODES:-1} # there is only on node...
export TASKS=${TASKS:-4} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export OMP_NUM_THREADS=$THREADS
# OpenMPI hybrid (mpi/openmp) job launch command
export HYBRIDRUN=${HYBRIDRUN:-"mpirun -n $((TASKS*NODES))"} # OpenMPI, not Intel

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'cd "${INIDIR}"; export NEXTSTEP=${NEXTSTEP}; ./${WPSSCRIPT}'} # evaluated by launchPreP
# N.B.: do not us '&' to spin off, otherwise output gets mangled and the system overloads

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'echo "cd \"${INIDIR}\"; TAGS=${ARTAG}; export MODE=BACKUP; export INTERVAL=${ARINTERVAL}; ./${ARSCRIPT}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'cd "${INIDIR}"; export NEXTSTEP=${NEXTSTEP}; ./${WRFSCRIPT} &'} # evaluated by resubJob
