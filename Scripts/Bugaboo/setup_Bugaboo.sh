#!/bin/bash
# source script to load Bugaboo-specific settings for pyWPS, WPS, and WRF
# created 11/06/2013 by Andre R. Erler, GPL v3
# revised 09/05/2014 by Andre R. Erler, GPL v3

export MAC='Bugaboo' # machine name
export QSYS='PBS' # queue system

# load modules
echo
module purge
# pyWPS.py specific modules
if [[ ${RUNPYWPS} == 1 ]]; then
    module load python # don't load specific version, or it crashes with next update     
    # N.B.: NCL is only necessary to process CESM output
fi
module list
echo

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
echo "Running on ${PBS_QUEUE} queue; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
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
      echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - Error creating folder!   <<<"
      echo
    fi # no RAMDISK
fi # RAMIN/OUT

# unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
ulimit -s hard

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# set up hybrid envionment: OpenMP and MPI (Intel)
export NODES=${NODES:-${PBS_NP}} # set in PBS section (-l proc=N, but I am not sure if PBS_NP is correct...)
# N.B.: Bugaboo allocates processors and not nodes; $NODES is here used for the number of processors 
export TASKS=${TASKS:-2} # number of MPI task per processor (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
# create custom hostfile for hyper-threading
HOSTFILE="${PBS_O_WORKDIR}/hostfile.${PBS_JOBID}"
for HOST in $( cat "${PBS_NODEFILE}" ); do 
  for I in $( seq ${TASKS} ); do echo $HOST; done
done > "${HOSTFILE}"
# OpenMPI job launch command
export HYBRIDRUN=${HYBRIDRUN:-'mpiexec -n $(( NODES*TASKS )) -hostfile ${HOSTFILE}'} # evaluated by execWRF and execWPS

# geogrid command (executed during machine-independent setup)
export RUNGEO=${RUNGEO:-"mpirun -n 4 ${BINDIR}/geogrid.exe"}

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'cd ${INIDIR} && qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}'} # use Python script to estimate queue time and choose queue
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'echo "Automatic archiving is currently not available."'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'cd \"${INIDIR}\" && qsub ./${AVGSCRIPT} -v PERIOD=${AVGTAG}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'cd ${INIDIR} && qsub ./${WRFSCRIPT} -v NOWPS=${NOWPS},NEXTSTEP=${NEXTSTEP},RSTCNT=${RSTCNT}'} # evaluated by resubJob

# sleeper job submission (for next step when WPS is delayed; should run on devel node)
export SLEEPERJOB=${SLEEPERJOB-'ssh bugaboo "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --skipwps --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob
