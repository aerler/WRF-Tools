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
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS
echo
echo "Running on ${PBS_QUEUE} queue; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
echo
# if we are not using RAM disk, we need to output to disk 
export METDATA="${WORKDIR}/metgrid" # output metgrid data to disk; set will set "ldisk = True" in pyWPS.py
export REALTMP="${HOME}/metgrid" # the path names get too long, so we need a shortcut

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
export TASKS=${TASKS:-1} # number of MPI task per processor (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
# OpenMPI job launch command
#export HYBRIDRUN=${HYBRIDRUN:-'mpiexec -n $(( NODES*TASKS ))'} # evaluated by execWRF and execWPS
export HYBRIDRUN=${HYBRIDRUN:-'mpiexec'} # evaluated by execWRF and execWPS

# number of restart files per job step
export RSTINT=${RSTINT:-4} # jobs on Bugaboo run much longer than on other machines
# N.B.: this parameter is set in the setup script, so that startCycle.sh is also aware of it

##TODO: skip hostfile and use normal mpiexec command if not hyperthreading
##TODO: also skip is sourced from devel node shell
#
## create custom hostfile for hyper-threading
#export HOSTFILE="${PBS_O_WORKDIR}/hostfile.${PBS_JOBNAME}"
#for HOST in $( cat "${PBS_NODEFILE}" ); do 
#  for I in $( seq ${TASKS} ); do echo $HOST; done
#done > "${HOSTFILE}"
## OpenMPI job launch command
#export HYBRIDRUN=${HYBRIDRUN:-'mpiexec --mca mpi_paffinity_alone 0 --mca mpi_yield_when_idle 1 -n $(( NODES*TASKS )) -hostfile ${HOSTFILE}'} # evaluated by execWRF and execWPS

# geogrid command (executed during machine-independent setup)
export RUNGEO=${RUNGEO:-"mpirun -n 4 ${BINDIR}/geogrid.exe"}

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'ssh bugaboo "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # use Python script to estimate queue time and choose queue
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'echo "Automatic archiving is currently not available."'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh bugaboo "cd \"${INIDIR}\"; qsub ./${AVGSCRIPT} -v PERIOD=${AVGTAG}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh bugaboo "cd \"${INIDIR}\"; qsub ./${WRFSCRIPT} -v NOWPS=${NOWPS},NEXTSTEP=${NEXTSTEP},RSTCNT=${RSTCNT}"'} # evaluated by resubJob

# sleeper job submission (for next step when WPS is delayed; should run on devel node)
export SLEEPERJOB=${SLEEPERJOB-'ssh bugaboo "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob; relaunches WPS
