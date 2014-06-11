#!/bin/bash
# a short script to run averaging operations over a number of CESM archives

#SRCR='/reserved1/p/peltier/marcdo/FromHpss' # Marc's folder on reserved (default)
#SRCR='/scratch/p/peltier/marcdo/archive/' # Marc's folder on scratch
SRCR="$CCA" # my CESM archive folder as source
DSTR="$CCA" # my CESM archive folder as destination (always)

shopt -s extglob
# for tests
RUNS='seaice-3r-hf/'
PERIODS='5' # averaging periods
# historical runs and projections
#RUNS='@(h[abc]|t)b20trcn1x1/ h[abct]brcp85cn1x1/ h[abc]brcp85cn1x1d/ seaice-*-hf/'
#PERIODS='5 10 15' # averaging periods
# cesm_average settings
RECALC='FALSE'
FILETYPES='atm lnd ice'

# feedback
echo ''
echo 'Averaging CESM experiments:'
echo ''
ls -d $RUNS
echo ''
echo "Averaging Periods: ${PERIODS}"
echo "File Types: ${FILETYPES}"
echo "Overwriting Files: ${RECALC}"

# loop over runs
ERRCNT=0
cd "$DSTR"
for RUN in $RUNS
  do
    echo
    # set up folders
    RUN=${RUN%/} # remove trailing slash, if any
    RUNDIR="${SRCR}/${RUN}/" # extract highest order folder name as run name
    AVGDIR="${DSTR}/${RUN}/cesmavg" # subfolder for averages
    mkdir -p "${AVGDIR}" # make sure destination folder exists
    cd "${RUNDIR}"
    ln -sf "${DSTR}/cesm_average.py" # link archiving script
    # determine period from name
    if [[ "$RUN" == *20tr* ]]; then START='1979'
    elif [[ "$RUN" == *rcp*d ]]; then START='2085'
    elif [[ "$RUN" == *rcp* ]]; then START='2045'
    elif [[ "$RUN" == seaice-5r-hf ]]; then START='2045 2085'
    elif [[ "$RUN" == seaice-*-hf ]]; then START='2045'
    fi # if it doesn't match anything, it will be skipped
    # calculate periods
    PRDS='' # clear variable
    for S in $START; do
      for PRD in $PERIODS; do
        PRDS="${PRDS} ${S}-$(( $S + $PRD ))"
    done; done # loop over start dates and periods
    # loop over averaging periods
    #echo $PERIODS
    for PERIOD in $PRDS
      do
        for FILETYPE in $FILETYPES
          do
            ## assemble time-series
            case $FILETYPE in
              atm) FILES="${RUN}.cam2.h0.";; 
              lnd) FILES="${RUN}.clm2.h0.";; 
              ice) FILES="${RUN}.cice.h.";; 
            esac
            # NCO command
            NCOARGS="--netcdf4 --deflate 1" # use NetCDF4 compression
            if [[ ! -e "${AVGDIR}/cesm${FILETYPE}_monthly.nc" ]] || [[ "$RECALC" == 'RECALC' ]]; then
                ncrcat $NCOARGS --output ${AVGDIR}/cesm${FILETYPE}_monthly.nc --overwrite ${RUNDIR}/${FILETYPE}/hist/${FILES}*
                ERR=$?
            else
                echo "   Skipping: The file ${AVGDIR}/cesm${FILETYPE}_monthly.nc already exits!"
                ERR=0 # count as success
            fi # if already file exits
            if [[ $ERR != 0 ]]; then
                echo "   WARNING: CESM Output concatenation failed!!! Exit code: $ERR"
                ERRCNT=$(( ERRCNT + 1 )) # increase error counter
            fi # if $ERR
            ## compute averaged climatologies
            echo "   ***   Averaging $RUN ($PERIOD,$FILETYPE)   ***   "
            echo "   ($RUNDIR)"	
            export PYAVG_FILETYPE=$FILETYPE # set above
            # launch python script, save output in log file
            if [[ ! -e "${AVGDIR}/cesm${FILETYPE}_clim_${PERIOD}.nc" ]] || [[ "$RECALC" == 'RECALC' ]]; then
                python -u cesm_average.py "$PERIOD" > "${AVGDIR}/cesm${FILETYPE}_clim_${PERIOD}.log"
                ERR=$?
            else
                echo "   Skipping: The file cesm${FILETYPE}_clim_${PERIOD}.nc already exits!"
                ERR=0 # count as success
            fi # if already file exits
            # clean up
            if [[ $ERR == 0 ]]; then
                echo "   Averaging successful!!!"
            else
                echo "   WARNING: Averaging failed!!! Exit code: $ERR"
                ERRCNT=$(( ERRCNT + 1 )) # increase error counter
            fi # if $ERR
            #echo "   $AVGDIR"
            echo
        done # for FILETYPES
    done # for $PERIODS
    rm cesm_average.py # remove archiving script
done # for $RUNS

# summary / feedback
echo
if [[ $ERRCNT == 0 ]]
  then
    echo "   All Operations Successful!!!   "
  else
    echo "   WARNING: THERE WERE $ERRCNT ERROR(S)!!!"
fi # if $ERRCNT
echo
