#!/bin/bash
# driver script to run WRF pre-processing: runs pyWPS.py and real.exe on RAM disk
# created 25/06/2012 by Andre R. Erler, GPL v3

# variable defined in driver script: 
# $TASKS, $THREADS, $HYBRIDRUN, $INIDIR, $WORKDIR, $RAMDISK
# optional arguments:
# $RUNPYWPS, $RUNREAL, $REALRAM, $METDATA, $ALTSRC, $WRFINPUT 

## prepare environment

# RAM disk
RAMDATA="$RAMDISK/data/" # data folder used by Python script
RAMTMP="$RAMDISK/tmp/" # temporary folder used by Python script
# pyWPS.py
if [ ! $RUNPYWPS ]; then RUNPYWPS=1; fi # whether to run runWPS.py
PYDATA="$WORKDIR/data" # data folder used by Python script
PYWPSLOG="$WORKDIR/pyWPS/" # log folder for Python script
if [ ! $METDATA ]; then METDATA="$INIDIR/metgrid/"; fi # final destination for metgrid data 
if [ ! $ALTSRC ]; then ALTSRC="$INIDIR/metgrid/"; fi  # alternate data source (if runWPS.py is not run)
# real.exe
if [ ! $RUNREAL ]; then RUNREAL=1; fi # whether to run real.exe
if [ ! $REALRAM ]; then REALRAM=1; fi # run real.exe in RAM or on disk
if [ ! $WRFINPUT ]; then WRFINPUT="$WORKDIR"; fi # output folder for WRF input data
REALLOG="$WORKDIR/real/" # log folder for real.exe
# resolve working directory for real.exe
if [ ! $REALDIR ] || [ $REALDIR == HD ]
	then REALDIR="$WRFINPUT" # write data directly to hard disk
elif [ $REALDIR == RAM ] || [ $REALDIR == ram ]
	then REALDIR="$RAMDATA" # write data to RAM and copy to HD later
fi

# remove existing work dir and create new
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
# remove and recreate temporary folder (ramdisk)
rm -rf "$RAMDATA"
mkdir -p "$RAMDATA" # create data folder on ramdisk


## run WPS driver script: pyWPS.py

if [[ $RUNPYWPS == 1 ]]
  then

# launch feedback
echo
echo ' >>> Running WPS <<< '
echo

# specific environment for pyWPS.py
# ´mkdir $METDATA´ is actually done by Python script
cd "$INIDIR" 
# copy links to source data (or create links)
cp -P atm lnd ice pyWPS.py eta2p.ncl unccsm.exe metgrid.exe "$WORKDIR"
cp -r meta/ "$WORKDIR"
cp -P geo_em.d??.nc "$WORKDIR" # copy or link to geogrid files
cp namelist.wps "$WORKDIR" # configuration file

# run and time main pre-processing script (Python)
cd "$WORKDIR" # using current working directory
time -p python pyWPS.py
wait

#TODO: copy log files into data directory
# move metgrid data to final destination
mkdir -p "$METDATA"
mv "$PYDATA"/* "$METDATA" # N.B.: the parent folder of $METDATA has to exist!
rm -r "$PYDATA"
# copy log files to disk
rm "$RAMTMP"*.nc "$RAMTMP"/*/*.nc # remove data files
cp -r "$RAMTMP" "$PYWPSLOG" # copy entire folder and rename

# finish
echo
echo ' >>> WPS finished <<< '
echo

# if not running Python script, get data from disk
else
	echo
	echo ' Copying source data to ramdisk.'
	echo
	cp "$ALTSRC/"*.nc "$RAMDATA" # copy alternate data to ramdisk

fi # if RUNPYWPS


echo 
echo '   ***   ***   '
echo

## run WRF pre-processor: real.exe

if [[ $RUNREAL == 1 ]]
  then

# launch feedback
echo
echo ' >>> Running real.exe <<< '
echo

# specific environment for real.exe
mkdir -p "$WRFINPUT" # make data destination folder
# create symbolic links to data on ramdisk
# N.B.: This is not necessary since the input path can be changed in the namelist
#cd $WRFINPUT
#time -p for METFILE in $RAMDATA/met_em.*.nc; do ln -s $METFILE; done

# copy namelist and link to real.exe into working director
cp -P "$INIDIR/real.exe" "$REALDIR" # link to executable real.exe
cp "$INIDIR/namelist.input" "$REALDIR" # copy namelists

## run and time hybrid (mpi/openmp) job
cd "$REALDIR" # so that output is written here
echo
echo OMP_NUM_THREADS=$THREADS
echo $HYBRIDRUN ./real.exe
echo
echo Writing output to $REALDIR
echo
time -p $HYBRIDRUN ./real.exe
wait

# clean-up output folder on hard disk
#rm met_em.*.nc real.exe # remove met file links
# save log files and meta data
mkdir "$REALLOG" # make folder for log files
cd "$REALDIR"
mv rsl.*.???? namelist.input namelist.output real.exe "$REALLOG"
# copy/move date to output directory (hard disk) if necessary
if [[ ! "$REALDIR" == "$WRFINPUT" ]]
  then 
	echo Copying data to $WRFINPUT
	time -p mv wrf* "$WRFINPUT"
  fi

# finish
echo
echo ' >>> real.exe finished <<< '
echo

fi # if RUNREAL


## finish / clean-up

# delete temporary data
rm -r "$RAMDATA" "$RAMTMP"
