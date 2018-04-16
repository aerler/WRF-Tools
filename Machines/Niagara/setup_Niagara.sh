#!/bin/bash
# source script to load GPC-specific settings for pyWPS, WPS, and WRF
# created 16/04/2018 by Andre R. Erler, GPL v3

# some code to make seamless machine transitions work on SciNet
if [[ -n "$QSYS" ]] && [[ -n "$WRFSCRIPT" ]] && [[ "$QSYS" != 'SB' ]]; then
  # since the run-script defined before, is not for this machine, we need to change the extension
  export WRFSCRIPT="${WRFSCRIPT%.*}.sb"
fi # if previously not PBS
# this machine
export MAC='Niagara' # machine name
export QSYS='SB' # queue system

if [ -z $SYSTEM ] || [[ "$SYSTEM" == "$MAC" ]]; then 
# N.B.: this script may be sourced from other systems, to set certain variables...
#       basically, everything that would cause errors on another machine, goes here

  # load modules
	echo
	module purge
  module load NiaEnv/2018a intel/2018.2 intelmpi/2018.2 hdf5/1.8.20 netcdf/4.6.1 python/2.7.14-anaconda5.1.0
	module list
	echo

  # unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
  ulimit -s unlimited
  
  # set the functions that are used in CMIP5 cases
  # TODO: wrapper code for the following functions may have to be added (see GPC-file for examples)
  # ncks
  # cdo
  # cdb_query_6hr
  # cdb_query_day
  # cdb_query_month
  
  
fi # if on Niagara

# RAM-disk settings: infer from queue
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    #if [[ "${PBS_QUEUE}" == 'largemem' ]]; then
    if [ $(( $(free | grep 'Mem:' | awk '{print $2}') / 1024**2 )) -gt 100 ]; then
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
echo "RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
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
	
# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# set up hybrid envionment: OpenMP and MPI (Intel)
export NODES=${NODES:-${SLURM_JOB_NUM_NODES}} # set in PBS section
export TASKS=${TASKS:-80} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export KMP_AFFINITY=verbose,granularity=thread,compact
#export I_MPI_PIN_DOMAIN=omp
export I_MPI_DEBUG=1 # less output (currently no problems)
# Intel hybrid (mpi/openmp) job launch command
export HYBRIDRUN=${HYBRIDRUN:-'mpirun -ppn ${TASKS} -np $((NODES*TASKS))'} # evaluated by execWRF and execWPS

# geogrid command (executed during machine-independent setup)
export RUNGEO=${RUNGEO:-"ssh nia-login08 \"cd ${INIDIR}; source ${SCRIPTDIR}/setup_WPS.sh; mpirun -n 4 ${BINDIR}/geogrid.exe\""} # run on GPC via ssh
#export RUNGEO=${RUNGEO:-"mpirun -n 4 ${BINDIR}/geogrid.exe"}

# WPS/preprocessing submission command (for next step)
# export SUBMITWPS=${SUBMITWPS:-'ssh gpc01 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by launchPreP
#export SUBMITWPS=${SUBMITWPS:-'bash -c "cd \"${INIDIR}\"; export WRFWCT=${WRFWCT}; export WPSWCT=${WPSWCT}; export NEXTSTEP=${NEXTSTEP}; export WPSSCRIPT=${WPSSCRIPT}; python ${SCRIPTDIR}/selectWPSqueue.py"'} # use Python script to estimate queue time and choose queue
# N.B.: the 'bash -c' command is necessary in order to remain consistent with the ssh commands used from other machines
export SUBMITWPS=${SUBMITWPS:-'cd "${INIDIR}"; sbatch ./${WPSSCRIPT} --export=NEXTSTEP=${NEXTSTEP}'} # no queue selector here
# N.B.: this is a "here document"; variable substitution should happen at the eval stage
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step in the interval)
export SUBMITAR=${SUBMITAR:-'ssh nia-login08 "cd \"${INIDIR}\"; sbatch ./${ARSCRIPT} --export=TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh nia-login08 "cd \"${INIDIR}\"; sbatch ./${AVGSCRIPT} --export=PERIOD=${AVGTAG}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh nia-login08 "cd \"${INIDIR}\"; sbatch ./${WRFSCRIPT} --export=NOWPS=${NOWPS},NEXTSTEP=${NEXTSTEP},RSTCNT=${RSTCNT}"'} # evaluated by resubJob

# sleeper job submission (for next step when WPS is delayed)
export SLEEPERJOB=${SLEEPERJOB-'ssh nia-login08 "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob; relaunches WPS
# N.B.: all sleeper jobs should be submitted to P7
