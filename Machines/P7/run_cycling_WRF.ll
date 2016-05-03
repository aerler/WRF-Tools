#!/bin/bash
# LoadLeveler submission script for SciNet P7
##=====================================
# @ job_name = test_2x128
# @ wall_clock_limit = 48:00:00
# @ node = 1
# @ tasks_per_node = 128
# @ notification = error
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).out
#@ environment = $NEXTSTEP; $NOWPS; $RSTCNT; MP_INFOLEVEL=1; \
#                MP_USE_BULK_XFER=yes; MP_BULK_MIN_MSG_SIZE=64K; \
#                MP_EAGER_LIMIT=64K; LAPI_DEBUG_ENABLE_AFFINITY=no; \
#                MP_TASK_AFFINITY=CPU:1; MP_BINDPROC=yes
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


## machine specific job settings
# WRF resource requirements (read by setup scripts)
export WRFNODES=1 # $WRFNODES can be inferred from host list, but is needed for setup
# get LoadLeveler names (needed for folder names)
export JOBNAME="${LOADL_JOB_NAME}"
export INIDIR="${LOADL_STEP_INITDIR}" # experiment root (launch directory)
# run scripts
export WRFSCRIPT="run_cycling_WRF.ll" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.pbs" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
# WRF and WPS wallclock  time limits (no way to query from queue system)
export WRFWCT='20:00:00' # WRF wallclock time limit
export WPSWCT='01:00:00' # WPS wallclock time limit


