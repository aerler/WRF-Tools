#!/usr/bin/bash
# Specifies the name of the shell to use for the job 
# @ shell = /usr/bin/bash
# @ job_name = test_WRF
# @ wall_clock_limit = 01:00:00
# @ node = 1 
# @ tasks_per_node = 64
# @ environment = COPY_ALL; MEMORY_AFFINITY=MCM; MP_SYNC_QP=YES; \
#                MP_RFIFO_SIZE=16777216; MP_SHM_ATTACH_THRESH=500000; \
#                MP_EUIDEVELOP=min; MP_USE_BULK_XFER=yes; \
#                MP_RDMA_MTU=4K; MP_BULK_MIN_MSG_SIZE=64k; MP_RC_MAX_QP=8192; \
#                PSALLOC=early; NODISCLAIM=true
# @ job_type = parallel
# @ class = verylong
# @ node_usage = not_shared
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).err
#=====================================
## this is necessary in order to avoid core dumps for batch files
## which can cause the system to be overloaded
# ulimits
# @ core_limit = 0
#=====================================
## necessary to force use of infiniband network for MPI traffic
# @ network.MPI = sn_all,not_shared,US,HIGH
#=====================================
# @ queue

## job settings
SCRIPTNAME="run_${LOADL_JOB_NAME}.pbs" # WRF suffix assumed
CLEARWDIR=0 # do not clear working director
# run configuration
export NODES=${LOADL_BG_SIZE} # set in LL section
export TASKS=64 # number of MPI task per node (Hpyerthreading!)
export THREADS=1 # number of OpenMP threads
# directory setup
export INIDIR="${LOADL_STEP_INITDIR}" # launch directory
export RUNNAME="${LOADL_JOB_NAME%_*}" # strip WRF suffix
export WORKDIR="${INIDIR}/${RUNNAME}/"
export RAMDISK="" # no RAM disk on TCS!

## real.exe settings
# optional arguments: $RUNREAL, $RAMIN, $RAMOUT
export RAMIN=0 # no RAM disk on TCS!
export RAMOUT=0
# folders: $REALIN, $REALOUT
# N.B.: RAMIN/OUT only works within a single node!

## WRF settings
# optional arguments: $RUNWRF, $GHG ($RAD, $LSM) 
export GHG='A2' # GHG emission scenario
# folders: $WRFIN, $WRFOUT, $TABLES
export WRFIN="${WORKDIR}" 


## setup job environment
echo
hostname
uname
echo
echo "   ***   ${LOADL_JOB_NAME}   ***   "
echo


# load modules
module purge
module load xlf vacpp hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc 
#module load xlf/13.1 vacpp/11.1 hdf5/187-v18-serial-xlc netcdf/4.1.3_hdf5_serial-xlc
module list
# whether or not to clear job folder (default: depends...)
if [[ -z "$CLEARWDIR" ]] && [[ $RUNREAL == 1 || "${WRFIN}" != "${WORKDIR}" ]]; then
	CLEARWDIR=1
fi
# cp-flag to prevent overwriting existing content
export NOCLOBBER='-i --reply=no' 
		

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
export HYBRIDRUN="poe ccsm_launch"

## begin job

# start timing
echo
echo '   ***   Start Time    ***   '
date
echo 

# clear and (re-)create job folder if neccessary
if [[ $CLEARWDIR == 1 ]]; then
	# only delete folder if we are running real.exe or input data is coming from elsewhere
	echo 'Removing old working directory:' 
	rm -rf "${WORKDIR}"
	mkdir -p "${WORKDIR}"
else
	echo 'Using existing working directory:'
	# N.B.: the execWPS-script does not clobber, i.e. config files in the work dir are used
fi
	echo "${WORKDIR}"
	echo
# copy driver script into work dir
cp "${INIDIR}/$SCRIPTNAME" "${WORKDIR}"
cp "${INIDIR}/execWRF.sh" "${WORKDIR}"

# run script
cd "${WORKDIR}"
./execWRF.sh
 
# end timing
echo
echo '    ***    End Time    *** '
date
echo


# # ccsm_launch is a "hybrid program launcher" for MPI-OpenMP programs
# # poe reads from a commands file, where each MPI task is launched
# # with ccsm_launch, which takes care of the processor affinity for the
# # OpenMP threads.  Each line in the poe.cmdfile reads something like:
# #        ccsm_launch ./myCPMD
# # and there must be as many such lines as MPI tasks.  The number of MPI
# # tasks must match the task_geometry statement describing the process placement
# # on the nodes.
