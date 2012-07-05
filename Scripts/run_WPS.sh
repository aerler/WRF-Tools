#!/bin/bash
# mock script to launch execWPS.sh on my local system (i.e. without queue system)
# created 25/06/2012 by Andre R. Erler, GPL v3

# parallelization
export NODES=1
export TASKS=4
export THREADS=1 # ${OMP_NUM_THREADS}
export HYBRIDRUN="mpirun -np $TASKS"

# RAM disk (also set in Python script)
export RAMDISK="/media/tmp/" # my local machines
#export RAMDISK="/dev/shm/aerler/" # SciNet (GPC & P7 only)
# working directories
export RUNNAME="test"
export INIDIR="${HOME}/Models/WRF Tools/test" # "$PWD"
export WORKDIR="${INIDIR}/${RUNNAME}/"

# optional arguments
export RUNPYWPS=1
export RUNREAL=1
# folders: $METDATA, $REALIN, $RAMIN, $REALOUT, $RAMOUT
export RAMIN=1
export RAMOUT=1
export METDATA="${INIDIR}/metgrid/"
#export REALOUT="${INIDIR}/wrfinput/"

## start execution
export NOCLOBBER='-n' # overwrite existing content
# remove existing work dir and create new
#rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
# N.B.: don't remove namelist files in working directory
# run script
./execWPS.sh

# copy driver script into work dir
cp "${INIDIR}/execWPS.sh" "${WORKDIR}"
cp "${INIDIR}/$0" "${WORKDIR}" 