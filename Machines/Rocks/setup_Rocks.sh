#!/bin/bash
# source script to load Rocks devel node specific settings for pyWPS, WPS
# created 24/05/2013 by Andre R. Erler, GPL v3
# revised 09/05/2014 by Andre R. Erler, GPL v3

export MAC='Rocks' # machine name
export QSYS='SGE' # queue system

## environment variables for "modules"
# export NCARG_ROOT='/usr/local/ncarg/' only needed to interpolate CESM data
export IBHOSTS="${HOME}/ibhosts"

# folder that contains WRF Tools (is necessary for some scripts in non-interactive mode)
export CODE_ROOT="$HOME/"

# Python path
export PYTHONPATH=$HOME/WRF\ Tools/Python/:$HOME/PyGeoDat/src/:$PYTHONPATH
# use Anaconda Python distribution
export PATH=/pub/home_local/wrf/anaconda/bin:$PATH

# Intel compiler suite
source /opt/intel/composer_xe_2013/bin/compilervars.sh intel64
source /opt/intel/mkl/bin/mklvars.sh intel64 # math kernel library
ulimit -s unlimited

# Stuff we need for WRF
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
    echo
    echo "Running as local shell script; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
    echo
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS

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
export NODES=${NODES:-8} # number of actual nodes
export TASKS=${TASKS:-32} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export OMP_NUM_THREADS=$THREADS
# OpenMPI hybrid (mpi/openmp) job launch command

#export MPIHOSTS='/pub/home_local/wrf/Runs/Columbia_brian/ibhosts'

#export HYBRIDRUN=${HYBRIDRUN:-"/usr/mpi/gcc/openmpi-1.4.3-qlc/bin/mpirun -np $((TASKS*NODES)) -machinefile ${IBHOSTS} "} 
#export HYBRIDRUN=${HYBRIDRUN:-"/usr/mpi/gcc/mvapich2-1.7-qlc/bin/mpirun -np $((TASKS*NODES)) -machinefile ${IBHOSTS} "} # -machinefile ${MPIHOSTS}"} # OpenMPI, not Intel
export HYBRIDRUN=${HYBRIDRUN:-"/usr/mpi/gcc/mvapich2-1.7-qlc/bin/mpirun -n $((TASKS*NODES)) -ppn ${TASKS} "} #-machinefile ${IBHOSTS} "} # -machinefile ${MPIHOSTS}"} # OpenMPI, not Intel

# geogrid command (executed during machine-independent setup)
export RUNGEO=${RUNGEO:-"mpirun -n 4 ${BINDIR}/geogrid.exe"}

# WPS/preprocessing submission command (for next step)
# export SUBMITWPS=${SUBMITWPS:-'ssh localhost "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; ./${WPSSCRIPT}"'} # evaluated by launchPreP; use for tests on devel node
export JOB_NAME=${JOB_NAME:-'cycling'} # defaults, if these variables are not set
export JOB_ID=${JOB_ID:-0} # this is necessary for the first WPS job, launched by startCycle
export SUBMITWPS=${SUBMITWPS:-'ssh rocks-ib.ib "cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; nohup ./${WPSSCRIPT} >& ${JOB_NAME%_WRF}_WPS.${JOB_ID}.log &"'} # evaluated by launchPreP; use for production runs on compute nodes
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job
#export SUBMITWPS=${SUBMITWPS:-'cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; ./${WPSSCRIPT} >& ${JOB_NAME%_WRF}_WPS.${JOB_ID}.log'} # evaluated by launchPreP; use for production runs on compute nodes
# N.B.: use '&' to spin off, but only on compute nodes, otherwise the system overloads

# number of restart files per job step
export RSTINT=${RSTINT:-3} # write a restart file every day
# N.B.: this parameter is set in the setup script, so that startCycle.sh is also aware of it

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh rocks-ib.ib "cd \"${INIDIR}\"; export PERIOD=${AVGTAG}; nohup ./${AVGSCRIPT} >& ${JOB_NAME%_WRF}_avg.${JOB_ID}.log &"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# archive submission command (for last step)
export SUBMITAR="echo \'No archive script available.\'"
# export SUBMITAR=${SUBMITAR:-'echo "cd \"${INIDIR}\"; TAGS=${ARTAG}; export MODE=BACKUP; export INTERVAL=${ARINTERVAL}; ./${ARSCRIPT}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh rocks-ib.ib "cd \"${INIDIR}\"; export NOWPS=${NOWPS}; export NEXTSTEP=${NEXTSTEP}; export RSTCNT=${RSTCNT}; qsub ${WRFSCRIPT}"'} # evaluated by resubJob
#export RESUBJOB=${RESUBJOB-'cd \"${INIDIR}\"; export NEXTSTEP=${NEXTSTEP}; export NOWPS=${NOWPS}; qsub ${WRFSCRIPT}'} # evaluated by resubJob

# sleeper job submission (for next step when WPS is delayed)
export SLEEPERJOB=${SLEEPERJOB-'ssh rocks-ib.ib "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob
