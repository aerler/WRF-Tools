#~/bin/bash
# a short script to run averaging operations over a number of CESM archives

SRCR='/reserved1/p/peltier/marcdo/FromHpss' # Marc's folder
DSTR="$CCA" # my CESM archive folder

RUNS='h*' # glob expression that identifies CESM archives
RUNS='hcb20trcn1x1'
PERIOD='1979-1988' # averaging period; period defined in avgWRF.py

ERRCNT=0
# loop over runs
for AR in $SRCR/$RUNS
  do
    echo
    # set up folders
    RUNDIR=${AR%/} # remove trailing slash, if any
    RUN=${AR##*/} # extract highest order folder name as run name
    AVGDIR="$DSTR/$RUN/cesmavg" # subfolder for averages
    mkdir -p "$AVGDIR" # make sure destination folder exists    
    ## start averaging
    echo "   ***   Averaging $RUN ($PERIOD)   ***   "
    echo "   ($RUNDIR)"
    cd "$RUNDIR"
    ln -s "$DSTR/avgCESM.py" # link archiving script
    # launch python script, save output in log file
    python avgCESM.py "$PERIOD" > "avgCESM_$PERIOD.log"
    ERR=$?
    # clean up
    if [[ ERR == 0 ]]
      then
	echo "   Averaging successful! Moving data to:"
	echo "   $AVGDIR"
	mv cesm*_clim.nc "$AVGDIR"
	mv "avgCESM_$PERIOD.log" "$AVGDIR"
	rm 'avgCESM.py' # remove archiving script
      else
	echo "   WARNING: averaging failed!!! Exit code: $ERR"
	ERRCNT=$(( ERRCNT + 1 )) # increase error counter
    fi # if $ERR
    echo
done # for $RUNS

# summary / feedback

echo
if [[ ERR == 0 ]]
  then
    echo "   All Operations Successful!!!   "
  else
    echo "   WARNING: THERE WERE $ERRCNT ERROR(S)!!!"
fi # if $ERRCNT
echo