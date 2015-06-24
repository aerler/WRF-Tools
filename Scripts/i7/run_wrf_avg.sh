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
AVGSCRIPT='run_wrf_avg.pbs' # name of this script...
PYAVG='wrfout_average.py' # name of Python averaging script
DOMAINS='1234' # string of single-digit domain indices

# return to original working directory
cd "${INIDIR}"

# influential enviromentvariables for averaging script
export PYAVG_THREADS=${PYAVG_THREADS:-8}
export PYAVG_DOMAINS=${PYAVG_DOMAINS:-"$DOMAINS"}
export PYAVG_FILETYPES=${PYAVG_FILETYPES:-''} # use default
# options that would interfere with yearly updates
export PYAVG_OVERWRITE=${PYAVG_OVERWRITE:-'FALSE'}
export PYAVG_ADDNEW=${PYAVG_ADDNEW:-'FALSE'} 
export PYAVG_RECOVER=${PYAVG_RECOVER:-'FALSE'}
export PYAVG_DEBUG=${PYAVG_DEBUG:-'FALSE'} # add more debug output

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