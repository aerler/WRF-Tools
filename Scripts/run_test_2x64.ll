# Specifies the name of the shell to use for the job 
# @ shell = /usr/bin/bash
# @ job_name = test_2x64
# @ job_type = parallel
# @ class = verylong
# @ environment = COPY_ALL; MEMORY_AFFINITY=MCM; MP_SYNC_QP=YES; \
#                MP_RFIFO_SIZE=16777216; MP_SHM_ATTACH_THRESH=500000; \
#                MP_EUIDEVELOP=min; MP_USE_BULK_XFER=yes; \
#                MP_RDMA_MTU=4K; MP_BULK_MIN_MSG_SIZE=64k; MP_RC_MAX_QP=8192; \
#                PSALLOC=early; NODISCLAIM=true
# @ node = 2 
# @ tasks_per_node = 64
# @ node_usage = not_shared
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).err
# @ wall_clock_limit = 01:00:00
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

# *** some settings ***
node=2 # number of nodes
npp=64 # number of MPI processes/tasks per node
np=$( expr $node \* $npp ) # total number of processes
job_name=test_${node}x${npp} # same as $(job_name)

# other stuff...
hostname
export TARGET_CPU_RANGE=-1
# # next variable is for performance, so that memory is allocated as
# # close to the cpu running the task as possible (NUMA architecture)
export MEMORY_AFFINITY=MCM
# # next variable is for OpenMP
export OMP_NUM_THREADS=1
# # next variable is for ccsm_launch
# # note that there is one entry per MPI task, and each of these is then multithreaded
thpt=1; for ((i=1; i<${np}; i++)); do thpt=${thpt}:1; done
export THRDS_PER_TASK=${thpt}

# make new job folder and copy relevant files
mkdir ${job_name}
cp namelist.input GENPARM.TBL LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL ${job_name}
#cp RRTMG_* ${job_name} # RRTMG radiation scheme
cp CAM* ozone* ${job_name} # CAM radiation scheme
cd ${job_name}

# copy links to input/boundary data and executable
for file in ../wrf*
	do cp -P $file .
done

# launch executable (and time)
timex poe ccsm_launch ./wrf.exe
wait

# copy run-script and output files from parent directory
cp ../run_${job_name}.ll .
cp ../${job_name}.* .

# # ccsm_launch is a "hybrid program launcher" for MPI-OpenMP programs
# # poe reads from a commands file, where each MPI task is launched
# # with ccsm_launch, which takes care of the processor affinity for the
# # OpenMP threads.  Each line in the poe.cmdfile reads something like:
# #        ccsm_launch ./myCPMD
# # and there must be as many such lines as MPI tasks.  The number of MPI
# # tasks must match the task_geometry statement describing the process placement
# # on the nodes.
