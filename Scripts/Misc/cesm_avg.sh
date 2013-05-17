#~/bin/bash
# a short script to run averaging operations over a number of CESM archives

SRCR='/reserved1/p/peltier/marcdo/FromHpss' # Marc's folder
DSTR="$CCA" # my CESM archive folder

RUNS='*20tr*' # glob expression that identifies CESM archives
PERIODS='1979-1983 1979-1988' # averaging period; period defined in avgWRF.py

RECALC='FALSE'
ERRCNT=0
# loop over runs
for AR in $SRCR/$RUNS
  do
    for PERIOD in $PERIODS
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
	cd "$AVGDIR"
	ln -sf "$DSTR/avgCESM.py" # link archiving script
	# launch python script, save output in log file
	if [[ ! -e "cesmsrfc_clim_${PERIOD}.nc" ]] || [[ "$RECALC" == 'TRUE' ]]
	  then
	    python avgCESM.py "$PERIOD" "$RUNDIR" > "avgCESM_$PERIOD.log"
	    ERR=$?
	  else
	    echo "WARNING: The file cesmsrfc_clim_${PERIOD}.nc already exits! Skipping computation!"
	    ERR=0 # count as success
	fi # if already file exits
	# clean up
	if [[ $ERR == 0 ]]
	  then
	    echo "   Averaging successful! Saving data to:"
	    rm 'avgCESM.py' # remove archiving script
	  else
	    echo "   WARNING: averaging failed!!! Exit code: $ERR"
	    ERRCNT=$(( ERRCNT + 1 )) # increase error counter
	fi # if $ERR
	echo "   $AVGDIR"
	echo
    done # for $PERIODS
done # for $RUNS

# summary / feedback
echo
if [[ $ERR == 0 ]]
  then
    echo "   All Operations Successful!!!   "
  else
    echo "   WARNING: THERE WERE $ERRCNT ERROR(S)!!!"
fi # if $ERRCNT
echo
