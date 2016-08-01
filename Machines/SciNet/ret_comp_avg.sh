#!/bin/bash
# script to submit a sequence of jobs to retrieve data from HPSS, compress if necessary, and produce monthly averages

# experiment name
if [ $# -ge 1 ]; then
  EXP="$1"
else # $# name
  EXP=${PWD%/}; EXP=${EXP##/*/}
fi # $# name
# period
if [ $# -ge 3 ]; then
  BEGIN="$2"; END="$3"
else # $# period
  if [[ "$EXP" == *-2100 ]]; then
    BEGIN="2085"; END="2099"
  elif [[ "$EXP" == *-2050 ]]; then
    BEGIN="2045"; END="2059"
  else
    BEGIN="1979"; END="1994"
  fi # period
fi # $# period
# file settings
DIAGS=${DIAGS:-'MISCDIAG'}
FTYPE=${FTYPE:-'srfc,xtrm,plev3d,hydro,lsm,rad'}

echo "Experiment:  $EXP ($BEGIN - $END)"
echo "Files:       $DIAGS / $FTYPE"

# go into experiment folder
[ -e "$EXP" ] && cd "$EXP"

# retrieve
PID=$( qsub ar_wrfout_fineIO.pbs -v MODE=RETRIEVE,DATASET="$DIAGS",TAGS="$(seq -s \  $BEGIN $END)" -l walltime=72:00:00 -N ar_${EXP}_ret -l walltime=72:00:00 )
echo "Retrieval:   $PID"
# compress
PID=$( qsub ~/WRF\ Tools/Machines/GPC/run_compressor.pbs -v MODE=WRF,BEGIN=$BEGIN,END=$END,FILET="$FTYPE" -N comp_${EXP} -W depend=afterok:"$PID" )
echo "Compression: $PID"
# average
PID=$( qsub run_wrf_avg.pbs -l walltime=48:00:00 -v PYAVG_OVERWRITE=OVERWRITE -N g-ctrl-2100_avg_diags -W depend=afterok:"$PID" )
echo "Averaging:   $PID"
