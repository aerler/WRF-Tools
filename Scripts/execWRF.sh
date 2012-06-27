#!/bin/bash

## prepare environment

# variable defined in driver script: 
# $TASKS, $THREADS, $HYBRIDRUN, $INIDIR, $WORKDIR
# for real.exe
# $RUNREAL, $REALIN, $RAMIN, REALOUT, $RAMOUT
# for WRF
# $RUNWRF, $WRFIN, $WRFOUT, $RAD, $LSM

# real.exe
RAMDATA=/dev/shm/aerler/data/ # RAM disk data folder
if [ -z "$RUNREAL" ]; then RUNREAL=1; fi # whether to run real.exe
if [ -z "$REALIN" ]; then REALIN="${INIDIR}/metgrid/"; fi
if [ -z "$RAMIN" ]; then RAMIN=1; fi # copy input data to ramdisk or read from HD
if [ -z "$REALOUT" ]; then REALOUT="${WORKDIR}"; fi # output folder for WRF input data
if [ -z "$RAMOUT" ]; then RAMOUT=1; fi # write output data to ramdisk or directly to HD
REALLOG="real" # log folder for real.exe
REALTGZ="${NAME}_${REALLOG}.tgz" # archive for log folder
# WRF
if [ -z "$RUNWRF" ]; then RUNWRF=1; fi # whether to run WRF
if [ -z "$WRFIN" ]; then 
	if [[ $RUNREAL == 1 ]]; then  WRFIN="${REALOUT}"; 
	else WRFIN="${INIDIR}"; fi; 
fi
if [ -z "$WRFOUT" ]; then WRFOUT="${WORKDIR}"; fi
if [ -z "$TABLES" ]; then TABLES="${INIDIR}/tables/"; fi # folder for WRF data tables
if [ -z "$RAD" ]; then RAD='CAM'; fi # folder for WRF input data
if [ -z "$LSM" ]; then LSM='Noah'; fi # output folder for WRF
WRFLOG="wrf" # log folder for wrf.exe
WRFTGZ="${NAME}_${WRFLOG}.tgz" # archive for log folder


## run WRF pre-processor: real.exe

if [[ $RUNREAL == 1 ]]
  then
echo
echo ' >>> Running real.exe <<< '
echo

# set up RAM disk
if [[ $RAMIN == 1 ]] || [[ $RAMOUT == 1 ]]; then
    # prepare RAM disk
    rm -rf "$RAMDATA" # remove existing temporary folder (ramdisk)
    mkdir -p "$RAMDATA" # create data folder on ramdisk
fi # if using RAM disk
# if working on RAM disk get data from hard disk
if [[ $RAMIN == 1 ]]; then 
	echo
	echo ' Copying metgrid data to ramdisk.'
	echo
	cp "${REALIN}"/*.nc "${RAMDATA}" # copy alternate data to ramdisk
else
    echo
    echo ' Using metgrid data from:'
	echo $METDATA
	echo
fi

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
cd "$REALDIR"
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
# clean-up RAM disk
if [[ $RAMIN == 1 ]] || [[ $RAMOUT == 1 ]]; then
	rm -rf "$RAMDATA" 
fi

# finish
echo
echo ' >>> real.exe finished <<< '
echo
echo
echo '   ***   ***   ***   '
echo

fi # if RUNREAL


## run WRF pre-processor: real.exe

if [[ $RUNWRF == 1 ]]
  then
echo
echo ' >>> Running WRF <<< '
echo

## link/copy relevant input files
WRFDIR="${WORKDIR}" # could potentially be executed in RAM disk as well...
mkdir -p "$WRFOUT" # make sure data destination folder exists 
# essentials
cd "${INIDIR}" # folder containing input files
cp -P namelist.input wrf.exe "${WRFDIR}"
cd "${TABLES}"
# radiation scheme
echo "Using $RAD radiation scheme."
if [[ $RAD == 'CAM' ]]; then 
    RADTAB="CAM_* ozone*"    
elif [[ $RAD == 'RRTMG' ]]; then 
    RADTAB="RRTMG_*"
elif [[ $RAD == 'RRTM' ]]; then 
    RADTAB="RRTM_*"
else
    echo 'WARNING: no radiation scheme selected!'
fi
# land-surface scheme
echo "Using $LSM land-surface scheme."
if [[ $LSM == 'Noah' ]] || [[ $LSM == 'RUC' ]]; then 
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
elif [[ $RAD == 'Diff' ]]; then 
    LSMTAB="LANDUSE.TBL"
else
    echo 'WARNING: no land-surface model selected!'
fi
# copy tables
cp $RADTAB $LSMTAB "${WRFDIR}"

# link to input data, if necessary
cd "${WRFDIR}"
if [[ ! "${WRFIN}" == "${WRFDIR}" ]]; then 
	for INPUT in "${WRFIN}"/wrf*_d??; do
		ln -s "${INPUT}"
	done 
fi
## run and time hybrid (mpi/openmp) job
echo
echo "OMP_NUM_THREADS=$THREADS"
echo "$HYBRIDRUN ./wrf.exe"
echo
# launch
time -p ${HYBRIDRUN} ./wrf.exe
wait

# clean-up and move output to destination
mkdir -p "${WRFLOG}" # make folder for log files locally
#cd "$WORKDIR"
# save log files and meta data
mv $RADTAB $LSMTAB rsl.*.???? namelist.input namelist.output wrf.exe "${WRFLOG}"
tar czf $WRFTGZ "$WRFLOG" # archive logs with data
if [[ ! "$WRFDIR" == "$WORKDIR" ]]; then 
	mv "$WRFLOG" "$WORKDIR" # move log folder to working directory
fi
# copy/move date to output directory (hard disk) if necessary
if [[ ! "$WRFDIR" == "$WRFOUT" ]]; then 
	echo "Copying data to ${WRFOUT}"
	time -p mv wrfout* $WRFTGZ "$WRFOUT"
fi

fi # if RUNWRF