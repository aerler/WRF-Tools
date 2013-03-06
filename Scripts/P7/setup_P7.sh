#!/bin/bash
# source script to load P7-specific settings for pyWPS, WPS, and WRF
# created 06/07/2012 by Andre R. Erler, GPL v3

echo
echo "Host list: ${LOADL_PROCESSOR_LIST}"
echo
# load modules
module purge
module load xlf/14.1 vacpp/12.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc pe/1.2.0.7
#module load xlf/13.1 vacpp/11.1 pe/1.2.0.7 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
# pyWPS.py specific modules
if [[ ${RUNPYWPS} == 1 ]]; then
    module load ncl/6.0.0 python/2.7.2
    #module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
fi
module list
echo

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
echo "Running on P7 Linux; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
echo

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/dev/shm/aerler/"
# check if the RAM=disk is actually there
if [[ ! -e "${RAMDISK}" ]]; then
  echo
  echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - folder does not exist!   <<<"
  echo
fi # no RAMDISK

# launch executable
export NODES=${NODES:-$( echo "${LOADL_PROCESSOR_LIST}" | wc -w )} # infer from host list; set in LL section
export TASKS=${TASKS:-128} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
export HYBRIDRUN=${HYBRIDRUN:-'poe'} # evaluated by execWRF and execWPS

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'ssh gpc-f102n084 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by launchPreP
export WAITFORWPS=${WAITFORWPS:-'WAIT'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./${ARSCRIPT} -v TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh p7n01 "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; llsubmit ./${WRFSCRIPT}"'} # evaluated by resubJob
