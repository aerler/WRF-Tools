#!/bin/bash
# mock script to launch execWPS.sh on my local system (i.e. without queue system)
# created 08/07/2012 by Andre R. Erler, GPL v3

# check if $STEP is set, and exit, if not
set -e # abort if anything goes wrong
if [[ -z "${NEXTSTEP}" ]]; then exit 1; fi
CURRENTSTEP="${NEXTSTEP}" # $NEXTSTEP will be overwritten

# parallelization
export NODES=1 # only one available
export TASKS=4
export THREADS=1 # ${OMP_NUM_THREADS}
#export OMP_NUM_THREADS=$THREADS
export HYBRIDRUN="mpirun -n $((TASKS*NODES))" # OpenMPI, not Intel
export NOCLOBBER='-n' # don't overwrite existing content

# RAM disk (for real.exe)
export RAMDISK="/media/tmp/" # my local machines
#export RAMDISK="/dev/shm/aerler/" # SciNet (GPC & P7 only)
# working directories
export RUNNAME="${CURRENTSTEP}" # $*STEP is provided by calling instance
export INIDIR="${HOME}/Models/WRF Tools/test" # "$PWD"
export WORKDIR="${INIDIR}/${RUNNAME}/"

# optional arguments
export RUNREAL=0
export RUNWRF=1
# folders: $METDATA, $REALIN, $RAMIN, $REALOUT, $RAMOUT
#export RAMIN=0
#export RAMOUT=0
export REALINMETDATA="${INIDIR}/metgrid/"
export REALOUT="${WORKDIR}"
export WRFIN="${WORKDIR}"
export WRFOUT="${INIDIR}/wrfout/"
# WRF settings
export GHG='A1B' # GHG emission scenario for CAM/ClWRF
#RAD='CAM'
#LSM='Noah'


## start execution
# work in existing work dir, created by caller instance
# N.B.: don't remove namelist files in working directory

# copy driver script into work dir
cp "${INIDIR}/execWRF.sh" "${WORKDIR}"
cp "${INIDIR}/$0" "${WORKDIR}" 

# read next step from stepfile
NEXTSTEP=$(python cycling.py ${CURRENTSTEP})
# N.B.: from here on $STEP is the next step
export NEXTSTEP
# launch WPS for next step (if $NEXTSTEP is not empty)
if [[ -n "${NEXTSTEP}" ]]
 then
	echo "   ***   Launching WPS for next step: ${NEXTSTEP}   ***   "
	echo
	# spawn independent/parallel process
	./run_cycling_WPS.sh &
fi

# run WRF for this step
echo
echo "   ***   Launching WRF for current step: ${CURRENTSTEP}   ***   "
echo
./execWRF.sh
wait # wait for WRF and WPS to finish

# launch WRF for next step (if $NEXTSTEP is not empty)
if [[ -n "${NEXTSTEP}" ]]
 then
	./run_cycling_WRF.sh &
fi
exit