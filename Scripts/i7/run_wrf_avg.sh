#!/bin/bash

# load some modules
echo
hostname
uname
echo
date
echo

# general settings
INIDIR="${PWD}"
SCRIPTDIR="${INIDIR}/scripts/" # default location of averaging script
AVGSCRIPT="run_wrf_avg.sh" # name of this script...
PYAVG='wrfout_average.py' # name of Python averaging script

# return to original working directory
cd "${INIDIR}"

# influential enviromentvariables for averaging script
# export PYAVG_THREADS=1
# export PYAVG_OVERWRITE=OVERWRITE
# export PYAVG_FILETYPES='srfc;xtrm;plev3d;hydro'

# launch script
echo
if [[ -n "${PERIOD}" ]]; then
	time -p epd "${SCRIPTDIR}/${PYAVG}" "${PERIOD}" # this alias does not work in scripts...
else
	time -p epd "${SCRIPTDIR}/${PYAVG}"
fi
echo