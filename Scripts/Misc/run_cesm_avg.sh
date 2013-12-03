#!/bin/bash
# a short script to run averaging operations over a number of CESM archives

#SRCR='/reserved1/p/peltier/marcdo/FromHpss' # Marc's folder on reserved
#SRCR='/scratch/p/peltier/marcdo/archive/' # Marc's folder on scratch
SRCR="$CCA" # my archive
DSTR="$CCA" # my CESM archive folder

# historical runs
shopt -s extglob
#RUNS='@(h[abc]|t)b20trcn1x1/' # glob expression that identifies CESM archives
#PERIODS='1979-1988' # averaging period; period defined in avgWRF.py
# projections
#RUNS='[abcz]brcp85cn1x1' # glob expression that identifies CESM archives
RUNS='seaice-5r-hf' # glob expression that identifies CESM archives
PERIODS='2045-2055' # averaging period; period defined in avgWRF.py
RECALC='RECALC'
# cesm_average settings
export PYAVG_FILETYPE=${PYAVG_FILETYPE:-'atm'}

# loop over runs
ERRCNT=0
for AR in $SRCR/$RUNS
  do
    echo
    # set up folders
    RUNDIR=${AR%/} # remove trailing slash, if any
    RUN=${RUNDIR##*/} # extract highest order folder name as run name
    AVGDIR="${DSTR}/${RUN}/cesmavg" # subfolder for averages
    mkdir -p "${AVGDIR}" # make sure destination folder exists
    cd "${AVGDIR}"
    #if [[ "${DSTR}" != "${SRCR}" ]]
    #  then
    #    ln -sf "${SRCR}/${RUN}/atm"  # create a link to source archive
    #fi # if $DSTR != $SRCR
    ln -sf "${DSTR}/cesm_average.py" # link archiving script
    # loop over averaging periods
    echo $PERIODS
    for PERIOD in $PERIODS
      do
	## start averaging
	echo "   ***   Averaging $RUN ($PERIOD)   ***   "
	echo "   ($RUNDIR)"	
	# launch python script, save output in log file
	if [[ ! -e "cesmatm_clim_${PERIOD}.nc" ]] || [[ "$RECALC" == 'RECALC' ]]
	  then
	    python cesm_average.py "$PERIOD" "$RUNDIR" > "cesm_average_$PERIOD.log"
	    ERR=$?
	  else
	    echo "WARNING: The file cesmatm_clim_${PERIOD}.nc already exits! Skipping computation!"
	    ERR=0 # count as success
	fi # if already file exits
	# clean up
	if [[ $ERR == 0 ]]
	  then
	    echo "   Averaging successful! Saving data to:"
	    rm cesm_average.py # remove archiving script
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
