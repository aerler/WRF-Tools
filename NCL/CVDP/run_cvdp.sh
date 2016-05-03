#!/bin/bash
# script to set up and run NCAR's CVDP for a particular CESM simulations
# 2014/06/20, Andre R. Erler

# load modules (we need to load the netcdf module in order to use it in Python)
echo
module purge
module load intel/13.1.1 gcc/4.8.1 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel 
module load ncl/6.2.0 gsl/1.13-intel udunits/2.1.11 nco/4.3.2-intel 
module load Xlibraries/X11-64 ImageMagick/6.6.7
module list
echo

# environment variables: CODE_ROOT, CCA
# run using loaded modules
set -e # abort, if anything goes wrong
# experiment settings
RUN=$1 # name of experiment
SPRD=$2 # start year of the analysis period
EPRD=$3 # end year of the analysis period
CLIM_FILE=$4 # climatology used to remove annual cycle
SRC="$CCA" # source folder
DST="$CCA/$RUN/cvdp/" # results folder
DMP="$CCA/$RUN/CVDP_DUMP/" # dump work dir here in case of error 
# general settings
TEST=${TEST:-'FALSE'} # set to True to write namelists only
ROOTDIR='/dev/shm/aerler/cvdp/' # run on RAM disk
WORKDIR="$ROOTDIR/$RUN/" # folder for current experiment
DATADIR="$WORKDIR/input/" # where input data will reside
OUTDIR="$WORKDIR/output/" # where output data is written to
OBSDIR="$ROOTDIR/input_obs/" # folder with observational data
OBSSRC='/reserved1/p/peltier/aerler/CESM/CVDP/obs_input/' # source of obs data
CVDPSRC="$CODE_ROOT/WRF Tools/NCL/CVDP/"

[[ -n "$PARALLEL_SEQ" ]] && sleep $PARALLEL_SEQ # disentangle processes... to avoid race conditions

# figure out ensemble
if [ ! -e "$SRC/$RUN/" ]; then echo "ERROR: Source folder '$SRC' not found!"; exit 1; fi
if [ -e "$SRC/$RUN/members.txt" ]; then
  ENSNO=0; ENSMEM=''
  for M in $( cat "$SRC/$RUN/members.txt" ); do
    ENSNO=$(( $ENSNO + 1 ))
    ENSMEM="$ENSMEM $M"
  done # for members
else
  ENSNO=1
  ENSMEM="$RUN"
fi # if ensemble

# CVDP settings
if [[ "$TEST" == 'NAMELISTS_ONLY' ]]; then NAMELISTS_ONLY='True'
else NAMELISTS_ONLY='False'; fi # translate to NCL-True; used in NCL driver script
OBS=${OBS:-'True'} # whether to perform analysis for observations
if [[ -n "$CLIM_FILE" ]]; then OPT_CLIMO='External'
#elif [[ -n "$SPRD" ]] && [[ -n "$EPRD" ]]; then OPT_CLIMO='Custom'
else OPT_CLIMO='Full'; fi

# announcement
echo
echo "   ***   $RUN ($SPRD-$EPRD)   ***   "
echo
if [ $ENSNO -gt 1 ]; then
  echo "    Root Folder: $SRC/$RUN"
  echo "    Members: $ENSMEM"
else
  echo "    Run Folder: $SRC/$RUN"
fi
echo "    Work Directory: $WORKDIR"
echo

# setup folders
rm -fr "$WORKDIR" # make sure we are clean
mkdir -p "$DST" "$WORKDIR" "$DATADIR"
if [ ! -e "$OBSDIR" ]; then echo "   Copying observational data from $OBSSRC to $OBSDIR"; cp -r "$OBSSRC" "$OBSDIR"
else echo "   Observational data already present: $OBSDIR"; mkdir -p "$OBSDIR"; fi
if [[ "$TEST" != 'FALSE' ]]; then 
  ls "$OBSDIR"; echo ''
fi
# copy climfile, if necessary
if [[ -n "$CLIM_FILE" ]]; then 
  echo "External climatology file '${CLIM_FILE}'"
  ncks -v TS,PSL,TREFHT,PRECT "$CLIM_FILE" "$DATADIR/clim_file.nc" # avoid excessive file sizes
  # N.B. clim_file's for land variables are currently not supported
  CLIM_FILE="$DATADIR/clim_file.nc"
fi

# copy CVDP files
if [[ "$TEST" == 'TEST' ]]; then cp "$CVDPSRC/driver_test.ncl" "$WORKDIR" # use test script
else cp "$CVDPSRC/driver.ncl" "$WORKDIR"; fi # use full driver script
cp -r "$CVDPSRC/ncl_scripts/" "$WORKDIR"

# period length
PRDLEN=$(( $EPRD - $SPRD +1 )) # length of time period to extract (in years)
DIMLEN=$(( $PRDLEN * 12 )) # length of time dimension to extract
PRDAYS=$(( $PRDLEN * 365 )) # length of period in days (CESM time coordinate)
ENSLEN=$(( $PRDLEN * $ENSNO )) # length of the total record
ENSPRD=$(( $SPRD + $ENSLEN -1 )) # fake end date of concatenated ensemble record

# setup configuration
cp "$CVDPSRC/namelist_obs" "$WORKDIR"
sed -i "/obs_input/ s+$OBSSRC+$OBSDIR+" "$WORKDIR/namelist_obs" # change obs data source
echo " $RUN | $DATADIR | $SPRD | $ENSPRD " > "$WORKDIR/namelist"

## function to handle ensemlbe concatenation for all variables
function CONCAT {
  # inputs
  VAR=$1
  if [[ "$VAR" == 'SNOWDP' ]]; then SRCNC="cesmlnd_monthly.nc"
  else SRCNC="cesmatm_monthly.nc"; fi # otherwise all atmosphere
  # target file name
  VARNC="$DATADIR/${V}_${SPRD}01-${ENSPRD}12.nc" # with fake end of period
  # loop over ensemble members
  cd "$WORKDIR" # make sure we are on RAM disk, for temporary files
  Z=0
  for M in $ENSMEM; do
    if [ $Z -eq 0 ]; then
      ncks -v $VAR -F -d time,1,$DIMLEN "$SRC/$M/cesmavg/$SRCNC" "$VARNC"
    else
      ncks -v $VAR -F -d time,1,$DIMLEN "$SRC/$M/cesmavg/$SRCNC" TMP.nc # copy to temporary file
      ncap2 -O -s "time = time + $PRDAYS * $Z" TMP.nc TMP.nc # increase time coordinate to ensure monotonicity
      ncrcat -O "$VARNC" TMP.nc "$VARNC" # append to file
      rm TMP.nc
    fi
    Z=$(( Z + 1 ))
  done # for $ENSMEM
} # fct CONCAT

# extract necessary variables
echo -n "   Copying input data:"
if [[ "$TEST" == 'TEST' ]]; then VARLIST='TS' # only one variable (SST) required by subset
else VARLIST='TS PSL TREFHT PRECT SNOWDP'; fi # run full analysis with all variables
for V in $VARLIST; do 
  echo -n " $V,"
  CONCAT $V # function defined above
done # loop over variables
echo
if [[ "$TEST" != 'FALSE' ]]; then ls "$DATADIR"; echo ''; fi # check that data is present

## run CVDP
# some influential environment variables

export OUTDIR NAMELISTS_ONLY OBS OPT_CLIMO SPRD CLIM_FILE 
export TITLE="$RUN $SPRD-$EPRD"
TMP=$EPRD; export EPRD=$ENSPRD # NCL script reads EPRD, but ENSPRD is what we want!
# run NCL driver script
cd "$WORKDIR"
echo
if [[ "$TEST" == 'TEST' ]]; then 
  ncl driver_test.ncl # only run a subset of analyses, for test-purpose
  ERR=$? # the exit code does not seem to be very informative, though...
else 
  ncl driver.ncl; fi # run full analysis
  ERR=$? # the exit code does not seem to be very informative, though...
echo
EPRD=$TMP # restore original (physical) end-of-period

# chop up time dimension (separate ensemble members)
if [ $ERR -eq 0 ] && [ $ENSNO -gt 1 ]; then 
  OUTNC="${WORKDIR}/output/${RUN}.cvdp_data.${SPRD}-${ENSPRD}.nc" # ensemble file
  # loop over ensemble members
  Z=0
  for M in $ENSMEM; do
    S=$(( ( $PRDLEN * $Z ) + 1 )); E=$(( $PRDLEN * ( $Z + 1 ) )) # yearly time dimension
    SS=$(( ( $DIMLEN * $Z ) + 1 )); EE=$(( $DIMLEN * ( $Z + 1 ) )) # monthly time dimension
    ncks -F -d TIME,$S,$E -d time,$SS,$EE "$OUTNC" "${WORKDIR}/output/${M}.cvdp_data.${SPRD}-${EPRD}.nc" # now the original end-of-period
    Z=$(( Z + 1 ))
  done # loop over members
fi # if NCL successful

# make tarball
cd "$OUTDIR" # in output folder, because of convention
tar czf cvdp.tgz * # everything!

# copy results, clean up and exit
echo
if [ $ERR -ne 0 ]; then 
  cp "$OUTDIR/"* "$DST"
  echo "ERROR: the NCL driver script exited with exit code $ERR - aborting!"
  echo "       (copying working directory to: '$DMP')"
  cp -r "$WORKDIR/" "$DMP" # copy entire directory to disk
elif [[ "$TEST" != 'FALSE' ]]; then 
  echo "   The NCL driver script completed successfully!"
  echo "   (copying working directory to: '$DMP')"
  rm -rf "$DMP" # clear existing dump folder
  cp -r "$WORKDIR/" "$DMP" # copy entire directory to disk
else
  cp "$OUTDIR/"* "$DST"
  echo "   The NCL driver script completed successfully!"
  echo "   (removing working directory: '$WORKDIR')"
fi   
rm -r "$WORKDIR" # only clean, if this is not a test  
echo
# exit
exit $ERR
