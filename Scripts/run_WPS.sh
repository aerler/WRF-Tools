#!/bin/bash
# mock script to launch execWPS.sh on my local system (i.e. without queue system)
# created 25/06/2012 by Andre R. Erler, GPL v3

# parallelization
export THREADS=2 # ${OMP_NUM_THREADS}
export OMP_GET_MAX_THREADS=$THREADS
# OpenMP-only settings
export TASKS=2
export HYBRIDRUN="mpirun -np $TASKS"

# RAM disk (also set in Python script)
export RAMDISK="/media/tmp/" # my local machines
#export RAMDISK="/dev/shm/aerler/" # SciNet (GPC & P7 only)
# working directories
export NAME="test"
export INIDIR="${HOME}/Models/WRF Tools/test" # "$PWD"
export WORKDIR="${INIDIR}/${NAME}/"

# optional arguments
export RUNPYWPS=1
export RUNREAL=1
# folders: $METDATA, $REALIN, $RAMIN, $REALOUT, $RAMOUT
export RAMIN=0
export RAMOUT=0
export METDATA="${INIDIR}/metgrid/"
#export REALOUT="${INIDIR}/wrfinput/"

## start execution
# remove existing work dir and create new
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
# run script
./execWPS.sh

# copy driver script into work dir
cp "${INIDIR}/$0" "${WORKDIR}" 