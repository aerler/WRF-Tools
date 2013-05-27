#!/bin/bash
# source script to load Rocks devel node specific settings for pyWPS, WPS
# created 24/05/2013 by Andre R. Erler, GPL v3

# environment variables for "modules"
# export NCARG_ROOT='/usr/local/ncarg/' only needed to interpolate CESM data
export MODEL_ROOT="${HOME}/"

# Stuff we need for WRF
# Intel
source /opt/intel/composer_xe_2013/bin/compilervars.sh intel64 # compiler suite
source /opt/intel/mkl/bin/mklvars.sh intel64 # math kernel library
ulimit -s unlimited
# MPI
export PATH=/usr/mpi/intel/mvapich2-1.7-qlc/bin:$PATH
export LD_LIBRARY_PATH=/usr/mpi/intel/mvapich2-1.7-qlc/lib:$LD_LIBRARY_PATH
# HDF5
export PATH=/pub/rocks_src/hdf_intel_serial/bin:$PATH
export LD_LIBRARY_PATH=/pub/rocks_src/hdf_intel_serial/lib:$LD_LIBRARY_PATH
# netcdf
export PATH=/pub/home_local/wrf/netcdf/bin:$PATH
export LD_LIBRARY_PATH=/pub/home_local/wrf/netcdf/lib:$LD_LIBRARY_PATH
# for Jasper, PNG, and Zlib
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH


# RAM-disk settings: infer from queue
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    export RAMIN=${RAMIN:-1}
    export RAMOUT=${RAMOUT:-0}
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS
echo
echo "Running as local shell script; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
echo

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/dev/shm/${USER}/"
# check if the RAM=disk is actually there
if [[ ${RAMIN}==1 ]] || [[ ${RAMOUT}==1 ]]; then
    # create RAM-disk directory
    mkdir -p "${RAMDISK}"
    # report problems
    if [[ $? != 0 ]]; then
      echo
      echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - folder does not exist!   <<<"
      echo
    fi # no RAMDISK
fi # RAMIN/OUT

# unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
ulimit -s unlimited

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# set up hybrid envionment: OpenMP and OpenMPI
export NODES=${NODES:-1} # there is only on node...
export TASKS=${TASKS:-16} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export OMP_NUM_THREADS=$THREADS
# OpenMPI hybrid (mpi/openmp) job launch command
export HYBRIDRUN=${HYBRIDRUN:-"mpirun -n $((TASKS*NODES)) -ppn ${TASKS}"} # OpenMPI, not Intel

# WPS/preprocessing submission command (for next step)
# export SUBMITWPS=${SUBMITWPS:-'ssh localhost "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; ./${WPSSCRIPT}"'} # evaluated by launchPreP; use for tests on devel node
export SUBMITWPS=${SUBMITWPS:-'ssh rocks "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; ./${WPSSCRIPT} >& ${JOB_NAME%_WRF}_WPS.${JOB_ID}.log" &'} # evaluated by launchPreP; use for production runs on compute nodes
# N.B.: use '&' to spin off, but only on compute nodes, otherwise the system overloads

# archive submission command (for last step)
export SUBMITAR="echo \'No archive script available.\'"
# export SUBMITAR=${SUBMITAR:-'echo "cd \"${INIDIR}\"; TAGS=${ARTAG}; export MODE=BACKUP; export INTERVAL=${ARINTERVAL}; ./${ARSCRIPT}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh rocks "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; qsub ${WRFSCRIPT}"'} # evaluated by resubJob
