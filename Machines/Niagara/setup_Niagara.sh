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

# default WRF environment version
export WRFENV=${WRFENV:-'2019b'} # need to leave default at old envionrment
# Python Version
export PYTHONVERSION=${PYTHONVERSION:-3} # default Python version is 3 (most scripts are converted now)

if [ -z $SYSTEM ] || [[ "$SYSTEM" == "$MAC" ]]; then 
# N.B.: this script may be sourced from other systems, to set certain variables...
#       basically, everything that would cause errors on another machine, goes here

  # load modules
	echo
	module purge
  # module for WRF
  if [[ ${WRFENV} == '2018a' ]]; then
    module load NiaEnv/2018a intel/2018.2 intelmpi/2018.2 #python/2.7.14-anaconda5.1.0
    module load hdf5/1.8.20 netcdf/4.6.1 #ncl/6.4.0 
    module load pnetcdf/1.9.0
    # modules for PyWPS
    # Anaconda has a different HDF5 version, so if another load-order is required, we need this:
    export HDF5_DISABLE_VERSION_CHECK=1 # has to be set after NCL
    if [ $PYTHONVERSION -eq 2 ]; then module load python/2.7.14-anaconda5.1.0
    elif [ $PYTHONVERSION -eq 3 ]; then module load python/3.6.4-anaconda5.1.0
    else echo "Warning: Python Version '$PYTHONVERSION' not found."
    fi # $PYTHONVERSION
    python --version
    if [[ ${RUNPYWPS} == 1 ]]; then
      # NCL is only necessary for preprocessing CESM
      module load ncl/6.4.0
      source "${PYTHONENV}/bin/activate"
      # NOTE_MM: PYTHONENV is a variable that needs to be set beforehand (possibly in user's
      #   .bashrc or .bash_profile). It contains the path to the folder of a virtual
      #   python environment that has netcdf4 and numexpr installed in it. These 
      #   modules are required within the averaging part of the code and are not
      #   accessible using simple python Niagara modules.
    fi # if RUNPYWPS
  elif [[ ${WRFENV} == '2019b' ]]; then
    module load NiaEnv/2019b openjpeg/2.3.1 jasper/.experimental-2.0.14 
    module load intel/2019u4 intelmpi/2019u4 hdf5/1.8.21 netcdf/4.6.3
    #module load intel/2019u4 openmpi/4.0.1 hdf5/1.8.21 netcdf/4.6.3
    # modules for PyWPS
    if [ $PYTHONVERSION -eq 2 ]; then module load python/2.7.15
    elif [ $PYTHONVERSION -eq 3 ]; then module load python/3.6.8
    else echo "Warning: Python Version '$PYTHONVERSION' not found."
    fi # $PYTHONVERSION
    python --version
    if [[ ${RUNPYWPS} == 1 ]]; then
      # NCL is only necessary for preprocessing CESM
      module load ncl/6.6.2
      source "${PYTHONENV}/bin/activate"
      # NOTE_MM: PYTHONENV is a variable that needs to be set beforehand (possibly in user's
      #   .bashrc or .bash_profile). It contains the path to the folder of a virtual
      #   python environment that has netcdf4 and numexpr installed in it. These 
      #   modules are required within the averaging part of the code and are not
      #   accessible using simple python Niagara modules.
    fi # if RUNPYWPS
  else echo "Warning: WRF Environment Version '$WRFENV' not found."
  fi # if $WRFENV
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


# set Python path for pyWPS.py and cycling.py
if [ -e "${CODE_ROOT}/WRF Tools/Python/" ]; then export PYTHONPATH="${CODE_ROOT}/WRF Tools/Python:${PYTHONPATH}";
elif [ -e "${CODE_ROOT}/WRF-Tools/Python/" ]; then export PYTHONPATH="${CODE_ROOT}/WRF-Tools/Python:${PYTHONPATH}"; fi
# wrfout_average.py depends on some modules from GeoPy (nctools and processing)
if [ -e "${CODE_ROOT}/GeoPy/src/" ]; then export PYTHONPATH="${CODE_ROOT}/GeoPy/src:${PYTHONPATH}"; fi
# show Python path for debugging
echo "PYTHONPATH: $PYTHONPATH"


# RAM-disk settings: infer from queue
echo
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    RAMGB=$(( $(free | grep 'Mem:' | awk '{print $2}') / 1024**2 ))
    echo "Detected ${RAMGB} GB of Memory"
    if [ $RAMGB -gt 90 ]; then
      # apparently Niagara nodes have 93GB, but that should be enough
			export RAMIN=${RAMIN:-1}
			export RAMOUT=${RAMOUT:-1}
    else
			export RAMIN=${RAMIN:-1}
			export RAMOUT=${RAMOUT:-0}
    fi # PBS_QUEUE
    ## don't use hyperthreading for WPS
    #export TASKS=${TASKS:-40} # number of MPI task per node 
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS
echo "Setting RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
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
export TASKS=${TASKS:-40} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export KMP_AFFINITY=verbose,granularity=thread,compact
#export I_MPI_PIN_DOMAIN=omp
export I_MPI_DEBUG=1 # less output (currently no problems)
# Intel hybrid (mpi/openmp) job launch command
export HYBRIDRUN=${HYBRIDRUN:-'mpirun -ppn ${TASKS} -np $((NODES*TASKS))'} # evaluated by execWRF and execWPS
#export HYBRIDRUN=${HYBRIDRUN:-'mpirun --bind-to none'} # evaluated by execWRF and execWPS
#export HYBRIDRUN=${HYBRIDRUN:-'mpiexec '} # evaluated by execWRF and execWPS

# geogrid command (executed during machine-independent setup)
export GEOTASKS=${GEOTASKS:-4} 
#export RUNGEO=${RUNGEO:-"ssh nia-login08 \"cd ${INIDIR}; source ${SCRIPTDIR}/setup_WPS.sh; mpirun -n ${GEOTASKS} ${BINDIR}/geogrid.exe\""} # run on GPC via ssh
export RUNGEO=${RUNGEO:-"mpirun -n ${GEOTASKS} ${BINDIR}/geogrid.exe"}

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'ssh nia-login07 "cd \"${INIDIR}\"; sbatch --export=NEXTSTEP=${NEXTSTEP} ./${WPSSCRIPT}"'} # evaluated by launchPreP
# N.B.: this is a "here document"; variable substitution should happen at the eval stage
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step in the interval)
export SUBMITAR=${SUBMITAR:-'ssh nia-login07 "cd \"${INIDIR}\"; sbatch --export=TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL} ./${ARSCRIPT}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script
# if HPSS is not working or full, log archive backlog
#export SUBMITAR=${SUBMITAR:-'ssh nia-login07 "cd \"${INIDIR}\"; echo \"${ARTAG}\" >> HPSS_backlog.txt"; echo "Logging archive tag \"${ARTAG}\" in 'HPSS_backlog.txt' for later archiving."'} # evaluated by launchPostP
# N.B.: instead of archiving, just log the year to be archived; this is temporarily necessary,  because HPSS is full

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh nia-login07 "cd \"${INIDIR}\"; sbatch --export=PERIOD=${AVGTAG} ./${AVGSCRIPT}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh nia-login07 "cd \"${INIDIR}\"; sbatch --export=NOWPS=${NOWPS},NEXTSTEP=${NEXTSTEP},RSTCNT=${RSTCNT} ./${WRFSCRIPT}"'} # evaluated by resubJob

# sleeper job submission (for next step when WPS is delayed)
export SLEEPERJOB=${SLEEPERJOB-'ssh nia-login07 "cd \"${INIDIR}\"; export NOWPS=${NOWPS}; nohup ./${STARTSCRIPT} --wait=${WAITTIME} --skipwps --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob; relaunches WPS
