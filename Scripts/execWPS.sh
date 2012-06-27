#!/bin/bash
# driver script to run WRF pre-processing: runs pyWPS.py and real.exe on RAM disk
# created 25/06/2012 by Andre R. Erler, GPL v3

# variable defined in driver script: 
# $TASKS, $THREADS, $HYBRIDRUN, ${WORKDIR}, $WORKDIR, $RAMDISK
# optional arguments:
# $RUNPYWPS, $METDATA, $RUNREAL, $REALIN, $RAMIN, $REALOUT, $RAMOUT

## prepare environment

# RAM disk
RAMDATA="${RAMDISK}/data/" # data folder used by Python script
RAMTMP="${RAMDISK}/tmp/" # temporary folder used by Python script
# pyWPS.py
if [ -z "$RUNPYWPS" ]; then RUNPYWPS=1; fi # whether to run runWPS.py
PYDATA="${WORKDIR}/data/" # data folder used by Python script
PYLOG="pyWPS" # log folder for Python script (use relative path for tar) 
PYTGZ="${NAME}_${PYLOG}.tgz" # archive for log folder
if [ -z "$METDATA" ]; then METDATA="${INIDIR}/metgrid/"; fi # final destination for metgrid data 
# real.exe
if [ -z "$RUNREAL" ]; then RUNREAL=1; fi # whether to run real.exe
if [ -z "$REALIN" ]; then REALIN="${METDATA}"; fi
if [ -z "$RAMIN" ]; then RAMIN=1; fi # copy input data to ramdisk or read from HD
if [ -z "$REALOUT" ]; then REALOUT="${WORKDIR}"; fi # output folder for WRF input data
if [ -z "$RAMOUT" ]; then RAMOUT=1; fi # write output data to ramdisk or directly to HD
REALLOG="real" # log folder for real.exe
REALTGZ="${NAME}_${REALLOG}.tgz" # archive for log folder


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
# N.B.: ´mkdir $RAMTMP´ is actually done by Python script
# copy links to source data (or create links)
cd "${INIDIR}" 
cp -P atm lnd ice pyWPS.py eta2p.ncl unccsm.exe metgrid.exe "${WORKDIR}"
cp -r meta/ "${WORKDIR}"
cp -P geo_em.d??.nc "${WORKDIR}" # copy or link to geogrid files
cp namelist.wps "${WORKDIR}" # configuration file

# run and time main pre-processing script (Python)
cd "${WORKDIR}" # using current working directory
time -p python pyWPS.py
wait

# copy log files to disk
rm "${RAMTMP}"/*.nc "${RAMTMP}"/*/*.nc # remove data files
cp -r "$RAMTMP" "${WORKDIR}/${PYLOG}/" # copy entire folder and rename
rm -rf "$RAMTMP"
# archive log files 
tar czf $PYTGZ "${PYLOG}/"
# move metgrid data to final destination
mkdir -p "$METDATA"
mv $PYTGZ "$METDATA"
mv "${PYDATA}"/* "$METDATA"
rm -r "$PYDATA"

# finish
echo
echo ' >>> WPS finished <<< '
echo

# if not running Python script, get data from disk
elif [[ $RAMIN == 1 ]]; then 
	echo
	echo ' Copying source data to ramdisk.'
	echo
		cp "${REALIN}"/*.nc "${RAMDATA}" # copy alternate data to ramdisk
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

# resolve working directory for real.exe
if [[ $RAMOUT == 1 ]]; then
	REALDIR="$RAMDATA" # write data to RAM and copy to HD later
else
	REALDIR="$REALOUT" # write data directly to hard disk
fi
# specific environment for real.exe
mkdir -p "$REALOUT" # make sure data destination folder exists
# copy namelist and link to real.exe into working director
cp -P "${INIDIR}/real.exe" "$REALDIR" # link to executable real.exe
cp "${INIDIR}/namelist.input" "$REALDIR" # copy namelists

# change input directory in namelist.input
cd "$REALDIR" # so that output is written here
sed -i '/.*auxinput1_inname.*/d' namelist.input # remove and input directories
if [[ $RAMIN == 1 ]]; then
	sed -i '/\&time_control/ a\ auxinput1_inname = "'"${RAMDATA}"'/met_em.d<domain>.<date>"' namelist.input
else
	sed -i '/\&time_control/ a\ auxinput1_inname = "'"${REALIN}"'/met_em.d<domain>.<date>"' namelist.input
fi

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

# clean-up and move output to hard disk
mkdir "${REALLOG}" # make folder for log files locally
#cd "$REALDIR"
# save log files and meta data
mv rsl.*.???? namelist.input namelist.output real.exe "${REALLOG}"
tar czf $REALTGZ "$REALLOG" # archive logs with data
if [[ ! "$REALDIR" == "$WORKDIR" ]]; then 
	mv "$REALLOG" "$WORKDIR" # move log folder to working directory
fi
# copy/move date to output directory (hard disk) if necessary
if [[ ! "$REALDIR" == "$REALOUT" ]]; then 
	echo "Copying data to ${REALOUT}"
	time -p mv wrf* $REALTGZ "$REALOUT"
fi

# finish
echo
echo ' >>> real.exe finished <<< '
echo

fi # if RUNREAL


## finish / clean-up

# delete temporary data
rm -r "$RAMDATA"
