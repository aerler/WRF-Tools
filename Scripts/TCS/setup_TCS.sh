#!/bin/bash -l
# source script to load TCS-specific settings for WRF
# created 06/07/2012 by Andre R. Erler, GPL v3
# revised 09/05/2014 by Andre R. Erler, GPL v3

# some code to make seamless machine transitions work on SciNet
if [[ -n "$QSYS" ]] && [[ -n "$WRFSCRIPT" ]] && [[ "$QSYS" != 'LL' ]]; then
  # since the run-script defined before, is not for LL, we need to change the extension
  export WRFSCRIPT="${WRFSCRIPT%.*}.ll"
fi # if previously not LL
# this machine
export MAC='TCS' # machine name
export QSYS='LL' # queue system

if [ -z $SYSTEM ] || [[ "$SYSTEM" == "$MAC" ]]; then 
# N.B.: this script may be sourced from other systems, to set certain variables...
#       basically, everything that would cause errors on another machine, goes here

  # generate list of nodes (without repetition)
	HOSTLIST=''; LH='';
	for H in ${LOADL_PROCESSOR_LIST};
	  do
	    if [[ "${H}" != "${LH}" ]];
		then HOSTLIST="${HOSTLIST} ${H}"; fi;
	    LH="${H}";
	done # processor list
	
	echo
	echo "Host list: ${HOSTLIST}"
	echo
  # load modules
	module purge
	module load xlf/14.1 vacpp/12.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc python/2.3.4
  #module load xlf/13.1 vacpp/11.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
	module list
	echo

fi # if on TCS

# no RAM disk on TCS!
export RAMIN=0
export RAMOUT=0

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-i --reply=no'

# run configuration
export NODES=${NODES:-$( echo "${HOSTLIST}" | wc -w )} # inferring from host list doesn't work on TCS - set in run-script
export TASKS=${TASKS:-64} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
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
export HYBRIDRUN=${HYBRIDRUN:-'poe ccsm_launch'} # evaluated by execWRF and execWPS

# ccsm_launch is a "hybrid program launcher" for MPI-OpenMP programs
# poe reads from a commands file, where each MPI task is launched
# with ccsm_launch, which takes care of the processor affinity for the
# OpenMP threads.  Each line in the poe.cmdfile reads something like:
#        ccsm_launch ./myCPMD
# and there must be as many such lines as MPI tasks.  The number of MPI
# tasks must match the task_geometry statement describing the process placement
# on the nodes.

# geogrid command (executed during machine-independent setup)
#export RUNGEO=${RUNGEO:-"mpiexec -n 8 ${BINDIR}/geogrid.exe"} # hide stdout
export RUNGEO=${RUNGEO:-"ssh gpc-f102n084-ib0 \"cd ${INIDIR}; source ${SCRIPTDIR}/setup_WPS.sh; mpirun -n 4 ${BINDIR}/geogrid.exe\""} # run on GPC via ssh

# WPS/preprocessing submission command (for next step)
# export SUBMITWPS=${SUBMITWPS:-'ssh gpc-f102n084 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by launchPreP
export SUBMITWPS=${SUBMITWPS:-'ssh gpc-f102n084-ib0 "cd \"${INIDIR}\"; export WRFWCT=${WRFWCT}; export WPSWCT=${WPSWCT}; export NEXTSTEP=${NEXTSTEP}; export WPSSCRIPT=${WPSSCRIPT}; python ${SCRIPTDIR}/selectWPSqueue.py"'} # use Python script to estimate queue time and choose queue
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; echo \"${ARTAG}\" >> HPSS_backlog.txt"; echo "Logging archive tag \"${ARTAG}\" in 'HPSS_backlog.txt' for later archiving."'} # evaluated by launchPostP
# N.B.: instead of archviing, just log the year to be archived; this is temporarily necessary,  because HPSS is full
#export SUBMITAR=${SUBMITAR:-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; qsub ./${ARSCRIPT} -v TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; qsub ./${AVGSCRIPT} -v PERIOD=${AVGTAG}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh tcs-f11n06-ib0 "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; export NOWPS=${NOWPS}; export RSTCNT=${RSTCNT}; llsubmit ./${WRFSCRIPT}"'} # evaluated by resubJob
export ALTSUBJOB=${ALTSUBJOB-'ssh tcs-f11n06-ib0 "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; export NOWPS=${NOWPS}; export RSTCNT=${RSTCNT}; llsubmit ./${WRFSCRIPT}"'} # for start_cycle from different machines

# sleeper job submission (for next step when WPS is delayed)
export SLEEPERJOB=${SLEEPERJOB-'ssh p7n01-ib0 "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob; relaunches WPS
# N.B.: all sleeper jobs should be submitted to P7
