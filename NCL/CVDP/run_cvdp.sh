#!/bin/bash
# script to set up and run NCAR's CVDP for a particular CESM simulations
# 2014/06/20, Andre R. Erler

# environment variables: MODEL_ROOT, CCA
# run using loaded modules

# experiment settings
RUN=$1 # name of experiment
SPRD=$2 # start year of the analysis period
EPRD=$3 # end year of the analysis period
SRC="$CCA/$RUN/cesmavg/" # source folder
DST="$CCA/$RUN/cvdp/" # results folder
DMP="$CCA/$RUN/CVDP_DUMP/" # dump work dir here in case of error 
# general settings
TEST=${TEST:-'False'} # set to True to write namelists only
ROOTDIR='/dev/shm/aerler/cvdp/' # run on RAM disk
WORKDIR="$ROOTDIR/$RUN/" # folder for current experiment
DATADIR="$WORKDIR/input/" # where input data will reside
OUTDIR="$WORKDIR/output/" # where output data is written to
OBSDIR="$ROOTDIR/input_obs/" # folder with observational data
OBSSRC='/reserved1/p/peltier/aerler/CESM/CVDP/obs_input/' # source of obs data
CVDPSRC="$MODEL_ROOT/WRF Tools/NCL/CVDP/"

# setup folders
if [ ! -e "$SRC" ]; then echo "Source folder '$SRC' not found!"; exit 1; fi
mkdir -p "$DST"
mkdir -p "$WORKDIR"
if [ ! -e "$OBSDIR" ]; then cp -r "$OBSSRC" "$OBSDIR"; fi
# copy CVDP files
cp "$CVDPSRC/driver.ncl" "$WORKDIR"
cp -r "$CVDPSRC/ncl_scripts/" "$WORKDIR"

# setup configuration
cp "$CVDPSRC/namelist_obs" "$WORKDIR"
sed -i "/obs_input/ s+$SRC+$DST+" "$WORKDIR/namelist_obs" # change obs data source
echo " $RUN | $DATADIR | $SPRD | $EPRD " > "$WORKDIR/namelist"

# extract necessary variables
for V in TS PSL TREFHT PRECT; do # loop over atmospheric variables
ncks -v $V "$SRC/cesmatm_monthly.nc" "$DATADIR/${V}_${SPRD}01-${EPRD}12.nc"; fi
# snow is from land module
ncks -v $V "$SRC/cesmlnd_monthly.nc" "$DATADIR/${V}_${SPRD}01-${EPRD}12.nc"

## run CVDP
# some influential environment variables
export TEST
export OUTDIR
export TITLE="$RUN ($SPRD-$EPRD)"
# run NCL driver script
cd "$WORKDIR"
ncl driver.ncl
ERR=$?

# copy results, clean up and exit
cp "$OUTDIR/"* "$DST"
echo
if [ $ERR -ne 0 ]; then 
  echo "ERROR: the NCL driver script exited with exit code $ERR - aborting!"
  echo "       (copying working directory to: '$DMP')"
  cp -r "$WORKDIR/" "$DMP" # copy entire directory to disk
elif [[ "$TEST" == 'True' ]]; then 
  echo "   The NCL driver script completed successfully!"
  echo "   (copying working directory to: '$DMP')"
  cp -r "$WORKDIR/" "$DMP" # copy entire directory to disk
else
  echo "   The NCL driver script completed successfully!"
  echo "   (removing working directory: '$WORKDIR')"
fi   
rm -r "$WORKDIR"; fi # only clean, if this is not a test  
echo
# exit
exit $ERR