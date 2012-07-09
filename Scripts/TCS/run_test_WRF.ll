#!/usr/bin/bash
# Specifies the name of the shell to use for the job 
# @ shell = /usr/bin/bash
# @ job_name = test_WRF
# @ wall_clock_limit = 04:00:00
# @ node = 4 
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
export SCRIPTNAME="run_${LOADL_JOB_NAME}.ll" # WRF suffix assumed
export CLEARWDIR=0 # do not clear working director
# run configuration
export NODES=4 # also has to be set in LL section
export TASKS=64 # number of MPI task per node (Hpyerthreading!)
export THREADS=1 # number of OpenMP threads
# directory setup
export INIDIR="${LOADL_STEP_INITDIR}" # launch directory
export RUNNAME="${LOADL_JOB_NAME%_*}" # strip WRF suffix
export WORKDIR="${INIDIR}/${RUNNAME}/"
export RAMDISK="" # no RAM disk on TCS!

## real.exe settings
# optional arguments: $RUNREAL, $RAMIN, $RAMOUT
export RUNREAL=0
export RAMIN=0 # no RAM disk on TCS!
export RAMOUT=0
# folders: $REALIN, $REALOUT
# N.B.: RAMIN/OUT only works within a single node!

## WRF settings
# optional arguments: $RUNWRF, $GHG ($RAD, $LSM) 
export GHG='A2' # GHG emission scenario
# folders: $WRFIN, $WRFOUT, $TABLES
export WRFIN="${INIDIR}/wrfinput/" 

# whether or not to clear job folder (default: depends...)
if [[ -z "$CLEARWDIR" ]] && [[ $RUNREAL == 1 || "${WRFIN}" != "${WORKDIR}" ]]; then
	CLEARWDIR=1
fi


## setup job environment
cd "${INIDIR}"
source setupTCS.sh # load machine-specific stuff


## begin job

# start timing
echo
echo '   ***   Start Time    ***   '
date
echo 

# prepare directory
cd "${INIDIR}"
./prepWorkDir.sh

# run script
cd "${INIDIR}"
./execWRF.sh
 
# end timing
echo
echo '    ***    End Time    *** '
date
echo
