##===============================================================================
# Specifies the name of the shell to use for the job 
## @ shell = /usr/bin/ksh
##
#@ environment = MP_INFOLEVEL=1; MP_USE_BULK_XFER=yes; MP_BULK_MIN_MSG_SIZE=64K; \
#                MP_EAGER_LIMIT=64K; LAPI_DEBUG_ENABLE_AFFINITY=no; \
#                MP_RFIFO_SIZE=16777216; MP_EUIDEVELOP=min; \
#                MP_PULSE=0; MP_BUFFER_MEM=256M; MP_EUILIB=us; MP_EUIDEVICE=sn_all;\
#                XLSMPOPTS=parthds=1; MP_TASK_AFFINITY=CPU:1; MP_BINDPROC=yes
# #MP_FIFO_MTU=4K; 
# @ job_name = test_4x32x4
# @ job_type = parallel
# @ class = verylong
# @ node = 4
# @ tasks_per_node = 32
# @ output = $(job_name).$(jobid).out
# @ error = $(job_name).$(jobid).err
# @ wall_clock_limit = 2:00:00
# @ node_usage = not_shared
##
## affinity settings
# #@ task_affinity=cpu(1)
# #@ cpus_per_core=4
# @ rset = rset_mcm_affinity
# @ mcm_affinity_options=mcm_distribute mcm_mem_req mcm_sni_none
##
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

hostname

# OpenMP threads (4 per core is optimal)
export OMP_NUM_THREADS=4

# job name (tag _ nodes x MPI tasks x OMP threads)
job_name=test_4x32x${OMP_NUM_THREADS} # same as $(job_name)

# make new job folder and copy relevant files
mkdir ${job_name}
cp namelist.input wrf.exe wrfinput_d01 ${job_name}
cd ${job_name}

# launch executable (and time)
time -p poe ./wrf.exe
wait

# copy run-script and output files from parent directory
cp ../run_${job_name}.ll .
cp ../${job_name}.* .

