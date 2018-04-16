#!/bin/bash
set -e # abort if anything goes wrong
# script to set up a cycling WPS/WRF run: machine-specific part (GPC)
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3, adapted 07/04/2014

# machine-specific defaults
WAITTIME=${WAITTIME:-'00:15:00'} # wait time for queue selector
QUEUE=${QUEUE:-'SELECTOR'} # queue mode: SELECTOR (default), SIMPLE

## launch jobs on GPC

# submit first WPS instance
if [ $SKIPWPS == 1 ]; then
  echo 'Skipping WPS!'
else
sbatch ./${WPSSCRIPT} --export=NEXTSTEP="${NEXTSTEP}"
fi # if $SKIPWPS

# submit first WRF instance
echo
echo "Starting Experiment ${EXP} on ${MAC}: NEXTSTEP=${NEXTSTEP}; NOWPS=${NOWPS}"
sbatch ./${WRFSCRIPT} --export=NEXTSTEP="${NEXTSTEP}",NOWPS="${NOWPS}"

# exit with 0 exit code: if anything went wrong we would already have aborted
echo
exit 0
