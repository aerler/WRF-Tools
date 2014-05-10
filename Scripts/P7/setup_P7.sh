#!/bin/bash
# source script to load P7-specific settings for pyWPS, WPS, and WRF
# created 06/07/2012 by Andre R. Erler, GPL v3
# revised 09/05/2014 by Andre R. Erler, GPL v3

export MAC='P7' # machine name
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
	module load xlf pe vacpp hdf5 netcdf
  #module load xlf/14.1.0.2 vacpp/12.1.0.2 pe/1.2.0.9 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
  #module load xlf/14.1 vacpp/12.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc pe/1.2.0.9
  #module load xlf/13.1 vacpp/11.1 pe/1.2.0.7 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
  # pyWPS.py specific modules
	if [[ ${RUNPYWPS} == 1 ]]; then
	    module load ncl/6.0.0 python/2.7.2
	    #module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
	fi
	module list
	echo
	
fi # if on P7

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

# launch executable
export NODES=${NODES:-$( echo "${HOSTLIST}" | wc -w )} # infer from host list; set in LL section
export TASKS=${TASKS:-128} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
export HYBRIDRUN=${HYBRIDRUN:-'poe'} # evaluated by execWRF and execWPS

# geogrid command (executed during machine-independent setup)
export RUNGEO=${RUNGEO:-"ssh gpc-f102n084-ib0 \"cd ${INIDIR}; source ${SCRIPTDIR}/setup_WPS.sh; mpirun -n 4 ${BINDIR}/geogrid.exe\""} # run on GPC via ssh
# export RUNGEO=${RUNGEO:-"mpiexec -n 8 ${BINDIR}/geogrid.exe"} # run locally

# WPS/preprocessing submission command (for next step)
# export SUBMITWPS=${SUBMITWPS:-'ssh gpc-f102n084 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by launchPreP
export SUBMITWPS=${SUBMITWPS:-'ssh gpc-f102n084-ib0 "cd \"${INIDIR}\"; export WRFWCT=${WRFWCT}; export WPSWCT=${WPSWCT}; export NEXTSTEP=${NEXTSTEP}; export WPSSCRIPT=${WPSSCRIPT}; python ${SCRIPTDIR}/selectWPSqueue.py"'} # use Python script to estimate queue time and choose queue
export WAITFORWPS=${WAITFORWPS:-'WAIT'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'ssh gpc-f102n084-ib0 "cd \"${INIDIR}\"; qsub ./${ARSCRIPT} -v TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh gpc-f102n084-ib0 "cd \"${INIDIR}\"; qsub ./${AVGSCRIPT} -v PERIOD=${AVGTAG}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh p7n01-ib0 "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; export NOWPS=${NOWPS}; export RSTCNT=${RSTCNT}; llsubmit ./${WRFSCRIPT}"'} # evaluated by resubJob
export ALTSUBJOB=${ALTSUBJOB-'ssh p7n01-ib0 "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; export NOWPS=${NOWPS}; export RSTCNT=${RSTCNT}; llsubmit ./${WRFSCRIPT}"'} # for start_cycle from different machines

# sleeper job submission (for next step when WPS is delayed)
export SLEEPERJOB=${SLEEPERJOB-'ssh p7n01-ib0 "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --skipwps --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob
# N.B.: all sleeper jobs should be submitted to P7