#!/bin/bash
# LoadLeveler submission script for SciNet P7

##=====================================
# @ job_name = test_2x128
# @ wall_clock_limit = 18:00:00
# @ node = 1
# @ tasks_per_node = 128
# @ notification = error
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).out
#@ environment = $NEXTSTEP; $NOWPS; MP_INFOLEVEL=1; MP_USE_BULK_XFER=yes; MP_BULK_MIN_MSG_SIZE=64K; \
#                MP_EAGER_LIMIT=64K; LAPI_DEBUG_ENABLE_AFFINITY=no; \
#                MP_RFIFO_SIZE=16777216; MP_EUIDEVELOP=min; \
#                MP_PULSE=0; MP_BUFFER_MEM=256M; MP_EUILIB=us; MP_EUIDEVICE=sn_all;\
#                XLSMPOPTS=parthds=1; MP_TASK_AFFINITY=CPU:1; MP_BINDPROC=yes
# #MP_FIFO_MTU=4K;
##=====================================
# @ job_type = parallel
# @ class = verylong
# @ node_usage = not_shared
# Specifies the name of the shell to use for the job
# @ shell = /bin/bash
##=====================================
## affinity settings
# #@ task_affinity=cpu(1)
# #@ cpus_per_core=4
# @ rset = rset_mcm_affinity
# @ mcm_affinity_options=mcm_distribute mcm_mem_req mcm_sni_none
##=====================================
## this is necessary in order to avoid core dumps for batch files
## which can cause the system to be overloaded
# ulimits
# @ core_limit = 0
#=====================================
## necessary to force use of infiniband network for MPI traffic
# #@ network.mpi = sn_single,not_shared,us,,instances=2
# #@ network.MPI = sn_all,not_shared,us, ,instances=1
# #@ network.MPI = sn_all,not_shared,US,HIGH
##=====================================
# @ queue


## job settings
# get PBS names (needed for folder names)
export JOBNAME="${LOADL_JOB_NAME}"
export INIDIR="${LOADL_STEP_INITDIR}" # experiment root (launch directory)
# directory setup
export RUNNAME="${CURRENTSTEP}" # step name, not job name!
export WORKDIR="${INIDIR}/${RUNNAME}/" # step folder
export WRFOUT="${INIDIR}/wrfout/" # output directory
export SCRIPTDIR="${INIDIR}/scripts/" # location of component scripts (pre/post processing etc.)
export BINDIR="${INIDIR}/bin/" # location of executables (WRF and WPS)
# N.B.: use absolute path for script and bin folders
# important scripts
export WRFSCRIPT="run_cycling_WRF.pbs" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.pbs" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
export ARSCRIPT="" # archive script to be executed after WRF finishes
export ARINTERVAL="" # default: every time
# WRF and WPS wallclock  time limits (no way to query from queue system)
export WRFWCT='' # WRF wallclock  time limit; e.g. '06:00:00'
export WPSWCT='' # WPS wallclock  time limit; e.g. '01:00:00'

## WRF settings
# N.B.: these settings serve as fallback options when inferring from namelist fails
export GHG='' # GHG emission scenario
export RAD='' # radiation scheme
export LSM='' # land surface scheme
