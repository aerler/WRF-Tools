#!/bin/bash
set -e # abort if anything goes wrong
# script to set up a cycling WPS/WRF run: machine-specific part (i7)
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3, adapted 07/04/2014

## launch jobs on i7

# submit first WPS instance
if [ $SKIPWPS == 1 ]; then
  echo 'Skipping WPS!'
else
	echo
	echo "Starting WPS for Experiment ${EXP} on ${MAC}: NEXTSTEP=${NEXTSTEP}"
	./${WPSSCRIPT}
fi # if $SKIPWPS

# submit first WRF instance
echo
echo "Starting WRF Experiment ${EXP} on ${MAC}: NEXTSTEP=${NEXTSTEP}; NOWPS=${NOWPS}"
export NEXTSTEP
export NOWPS
./${WRFSCRIPT}

# exit with 0 exit code: if anything went wrong we would already have aborted
echo
exit 0
