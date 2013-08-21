#!/bin/bash -l
# LoadLeveler submission script for SciNet TCS
##=====================================
# @ job_name = test_4x64
# @ wall_clock_limit = 06:00:00
# @ node = 4
# @ tasks_per_node = 64
# @ notification = error
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).out
# @ environment = $NEXTSTEP; $NOWPS; MEMORY_AFFINITY=MCM; MP_SYNC_QP=YES; \
#                MP_RFIFO_SIZE=16777216; MP_SHM_ATTACH_THRESH=500000; \
#                MP_EUIDEVELOP=min; MP_USE_BULK_XFER=yes; \
#                MP_RDMA_MTU=4K; MP_BULK_MIN_MSG_SIZE=64k; MP_RC_MAX_QP=8192; \
#                PSALLOC=early; NODISCLAIM=true
##=====================================
# @ job_type = parallel
# @ class = verylong
# @ node_usage = not_shared
# Specifies the name of the shell to use for the job
# @ shell = /bin/bash -l
##=====================================
## this is necessary in order to avoid core dumps for batch files
## which can cause the system to be overloaded
# ulimits
# @ core_limit = 0
## necessary to force use of infiniband network for MPI traffic
# @ network.MPI = sn_all,not_shared,US,HIGH
##=====================================
# @ queue


## machine specific job settings
export NODES=4 # number of nodes (necessary for TCS threading setup)
export WAITFORWPS='WAIT' # stay on compute node until WPS for next step finished, in order to submit next WRF job
# get LoadLeveler names (needed for folder names)
export JOBNAME="${LOADL_JOB_NAME}"
export INIDIR="${LOADL_STEP_INITDIR}" # experiment root (launch directory)
# important scripts
export WRFSCRIPT="run_cycling_WRF.ll" # WRF suffix assumed
export WPSSCRIPT="run_cycling_WPS.pbs" # WRF suffix assumed, WPS suffix substituted: ${JOBNAME%_WRF}_WPS
