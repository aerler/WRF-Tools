#!/bin/bash
#
# @ environment = MP_INFOLEVEL=0; \
#                 MP_USE_BULK_XFER=yes; \
#                 MP_BULK_MIN_MSG_SIZE=64K;\
#                 MP_EAGER_LIMIT=64K; \
#                 MP_DEBUG_ENABLE_AFFINITY=no; \
#                 MP_SHARED_MEMORY=yes
#
# @ job_name = sleeper-p7n02
# @ job_type = parallel
# @ class = verylong
# @ output = $(job_name).$(jobid).out
# @ error  = $(job_name).$(jobid).out
# @ wall_clock_limit = 48:00:00
#
# @ node = 1
# @ node_usage = not_shared
# @ tasks_per_node = 64
#
# @ requirements = (Machine == "p7n02")
#
# @ queue
#
#===================================

# sleep for 48 hours
sleep 172800
