#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3
# revised 02/03/2013 by Andre R. Erler, GPL v3

set -e # abort if anything goes wrong
# settings
export STEPFILE=${STEPFILE:-'stepfile'} # file in $INIDIR
export INIDIR=${INIDIR:-"${PWD}"} # current directory
export SCRIPTDIR=${SCRIPTDIR:-"./scripts"} # location of the setup-script
export BINDIR=${BINDIR:-"./bin/"} # location of geogrid.exe
export METDATA=${METDATA:-''} # don't save metgrid output
export WRFOUT=${WRFOUT:-"${INIDIR}/wrfout/"} # WRF output folder
export WPSSCRIPT=${WPSSCRIPT:-'run_cycling_WPS.ll'} # WPS run-scripts
export WRFSCRIPT=${WRFSCRIPT:-'run_cycling_WRF.ll'} # WRF run-scripts
export STATICTGZ=${STATICTGZ:-'static.tgz'} # file for static data backup
# geogrid command (executed during machine-independent setup)
export GEOGRID=${GEOGRID:-"mpiexec -n 8 ${BINDIR}/geogrid.exe > /dev/null"} # hide stdout
# export GEOGRID=${GEOGRID:-"ssh gpc04 \"cd ${INIDIR}; source setup_GPC.sh; mpirun -n 4 ${BINDIR}/geogrid.exe\" > /dev/null"} # hide stdout; run on GPC via ssh

# translate arguments
export MODE="${1}" # NOGEO*, RESTART, START
export LASTSTEP="${2}" # previous step in stepfile (leave blank if this is the first step)


## start setup
cd "${INIDIR}"

# read first entry in stepfile
NEXTSTEP=$( python "${SCRIPTDIR}/cycling.py" "${LASTSTEP}" )
export NEXTSTEP

# run (machine-independent) setup:
eval "${SCRIPTDIR}/setup_cycle.sh" # requires geogrid command


## launch jobs

# use sleeper script to to launch WPS and WRF
./sleepCycle.sh "${NEXTSTEP}" # should be present in the root folder

# exit with 0 exit code: if anything went wrong we would already have aborted
exit 0
