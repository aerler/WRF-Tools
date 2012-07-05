#!/bin/bash
# mock script to launch execWPS.sh on my local system (i.e. without queue system)
# created 25/06/2012 by Andre R. Erler, GPL v3

# parallelization
export NODES=1
export TASKS=4
export THREADS=1 # ${OMP_NUM_THREADS}
#export OMP_NUM_THREADS=$THREADS
export HYBRIDRUN="mpirun -ppn $TASKS -np $((TASKS*NODES))"
export TIMING="time -p"

# RAM disk (for real.exe)
export RAMDISK="/media/tmp/" # my local machines
#export RAMDISK="/dev/shm/aerler/" # SciNet (GPC & P7 only)
# working directories
export RUNNAME="test"
export INIDIR="${HOME}/Models/WRF Tools/test" # "$PWD"
export WORKDIR="${INIDIR}/${JOBNAME}/"

# optional arguments
export RUNREAL=1
export RUNWRF=1
# folders: $METDATA, $REALIN, $RAMIN, $REALOUT, $RAMOUT
#export RAMIN=0
#export RAMOUT=0
export METDATA="${INIDIR}/metgrid/"
#export REALOUT="${INIDIR}/wrfinput/"
#export WRFIN="${INIDIR}/wrfinput/"
export WRFOUT="${INIDIR}/wrfout/"
# WRF settings
export GHG='A1B' # GHG emission scenario for CAM/ClWRF
#RAD='CAM'
#LSM='Noah'

## start execution
export NOCLOBBER='' # overwrite existing content
# remove existing work dir and create new
#rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}" # but make sure it exists
# N.B.: do not remove existing work dir if input data is stored there!
# run script
./execWRF.sh

# copy driver script into work dir
cp "${INIDIR}/execWRF.sh" "${WORKDIR}"
cp "${INIDIR}/$0" "${WORKDIR}" 