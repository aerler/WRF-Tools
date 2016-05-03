#!/bin/bash
# a short script to run averaging operations over a number of CESM archives

#SRCR='/reserved1/p/peltier/marcdo/FromHpss' # Marc's folder on reserved (default)
#SRCR='/scratch/p/peltier/marcdo/archive/' # Marc's folder on scratch
SRCR="$CCA" # my CESM archive folder as source
DSTR="$CCA" # my CESM archive folder as destination (always)

shopt -s extglob
# for tests
RUNS='htbrcp85cn1x1d'
#PERIODS='5' # averaging periods
# historical runs and projections
#RUNS='@(h[abc]|t)b20trcn1x1/ h[abct]brcp85cn1x1/ h[abc]brcp85cn1x1d/ seaice-*-hf/'
PERIODS='5 10 15' # averaging periods
# cesm_average settings
OVERWRITE='OVERWRITE'
FILETYPES='atm lnd ice'

# feedback
echo ''
echo 'Averaging CESM experiments:'
echo ''
ls -d $RUNS
echo ''
echo "Averaging Periods: ${PERIODS}"
echo "File Types: ${FILETYPES}"
echo "Overwriting Files: ${OVERWRITE}"

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
    echo "   ***   Processing $RUN   ***   "
    echo "   ($RUNDIR)"	
    mkdir -p "${AVGDIR}" # make sure destination folder exists
    cd "${RUNDIR}"
    ln -sf "${CODE_ROOT}/WRF Tools/Python/wrfavg/cesm_average.py" # link archiving script
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
    # loop over file types
    #echo $PERIODS
		for FILETYPE in $FILETYPES
      do
		    ## assemble time-series
		    case $FILETYPE in
		      atm) FILES="${RUNDIR}/${FILETYPE}/hist/${RUN}.cam2.h0.";; 
		      lnd) FILES="${RUNDIR}/${FILETYPE}/hist/${RUN}.clm2.h0.";; 
		      ice) FILES="${RUNDIR}/${FILETYPE}/hist/${RUN}.cice.h.";; 
		    esac
		    # NCO command
		    NCOARGS="--netcdf4 --deflate 1" # use NetCDF4 compression
        NCOOUT="${AVGDIR}/cesm${FILETYPE}_monthly.nc"
		    if [[ ! -e "${NCOOUT}" ]] || [[ "$OVERWRITE" == 'OVERWRITE' ]]; then
		      echo "   Concatenating: ${NCOOUT}"
          ncrcat $NCOARGS --output "${NCOOUT}" --overwrite "${FILES}"* > "${NCOOUT%.nc}.log"
		      ERR=$?		      
		    else
		      echo "   Skipping: ${NCOOUT}"
		      ERR=0 # count as success
		    fi # if already file exits
		    if [[ $ERR != 0 ]]; then
		      echo "   WARNING: CESM Output concatenation failed!!! Exit code: $ERR"
		      ERRCNT=$(( ERRCNT + 1 )) # increase error counter
		    fi # if $ERR
        # loop over averaging periods
        for PERIOD in $PRDS
          do
            ## compute averaged climatologies
            export PYAVG_FILETYPE=$FILETYPE # set above
            # launch python script, save output in log file
            PYAVGOUT="${AVGDIR}/cesm${FILETYPE}_clim_${PERIOD}.nc"
            if [[ ! -e "$PYAVGOUT" ]] || [[ "$OVERWRITE" == 'OVERWRITE' ]]; then
              echo "   Averaging: ${PYAVGOUT}"
              python -u cesm_average.py "$PERIOD" > "${PYAVGOUT%.nc}.log"
              ERR=$?
            else
              echo "   Skipping: ${PYAVGOUT}"
              ERR=0 # count as success
            fi # if already file exits
            # clean up
            if [[ $ERR == 0 ]]; then
              echo "   Averaging successful!!!"
            else
              echo "   WARNING: Averaging failed!!! Exit code: $ERR"
              ERRCNT=$(( ERRCNT + 1 )) # increase error counter
            fi # if $ERR
            echo
        done # for $PERIODS
    done # for $FILETYPES
    rm cesm_average.py # remove link to averaging script
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
