#!/bin/bash
# mock script to launch execWPS.sh on my local system (i.e. without queue system)
# created 08/07/2012 by Andre R. Erler, GPL v3

# check if $STEP is set, and exit, if not
if [[ -z "$STEP" ]]; then exit 1; fi

# parallelization
export NODES=1 # only one available
export TASKS=4
export THREADS=1 # ${OMP_NUM_THREADS}
#export OMP_NUM_THREADS=$THREADS
export HYBRIDRUN="mpirun -n $((TASKS*NODES))" # OpenMPI, not Intel
export NOCLOBBER='-n' # don't overwrite existing content

# RAM disk (also set in Python script)
export RAMDISK="/media/tmp/" # my local machines
#export RAMDISK="/dev/shm/aerler/" # SciNet (GPC & P7 only)
# working directories
export RUNNAME="${STEP}" # $STEP is provided by calling instance
export INIDIR="${HOME}/Models/WRF Tools/test" # "$PWD"
export WORKDIR="${INIDIR}/${RUNNAME}/"

# optional arguments
export RUNPYWPS=1
export RUNREAL=1
# folders: $METDATA, $REALIN, $RAMIN, $REALOUT, $RAMOUT
export RAMIN=1
export RAMOUT=1
export METDATA="${INIDIR}/metgrid/"
export REALOUT="${WORKDIR}"

## start execution
# work in existing work dir, created by caller instance
# N.B.: don't remove namelist files in working directory
# run script
./execWPS.sh

# copy driver script into work dir
cp "${INIDIR}/execWPS.sh" "${WORKDIR}"
cp "${INIDIR}/$0" "${WORKDIR}" 