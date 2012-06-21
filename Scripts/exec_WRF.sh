#!/bin/bash

## prepare environment

# variable defined in driver script: 
# $TASKS, $THREADS, $HYBRIDRUN, $INIDIR, $WORKDIR
# for real.exe
# $RUNREAL, $METDATA, $RAMIN, $RAMOUT
# for WRF
# $RUNWRF, $RAD, $LSM

# real.exe
RAMDATA=/dev/shm/aerler/data/ # RAM disk data folder
if [ ! $RUNREAL ]; then RUNREAL=0; fi # whether to run real.exe
if [ ! $RAMIN ]; then RAMIN=1; fi # process from hard disk
if [ ! $RAMOUT ]; then RAMOUT=0; fi # write to hard disk
METDATA=$INIDIR/metgrid/ # input files for real.exe
REALLOG=$WORKDIR/real/ # log folder for real.exe
# WRF
if [ ! $RUNWRF ]; then RUNWRF=1; fi # whether to run WRF
if [ ! $RAD ]; then $RAD='CAM'; fi # folder for WRF input data
if [ ! $LSM ]; then LSM='Noah'; fi # output folder for WRF


## run WRF pre-processor: real.exe

if [[ $RUNREAL == 1 ]]
  then
echo
echo ' >>> Running real.exe <<< '
echo

# if working on RAM disk get data from hard disk
echo
if [[ $RAMIN == 1 ]]
  then
    # prepare RAM disk
    rm -rf $RAMDISK # remove existing temporary folder (ramdisk)
    mkdir -p $RAMDATA # create data folder on ramdisk
    echo ' Copying metgrid data to ramdisk:'
    cp $METDATA/met_em.*.nc $RAMDATA # copy metgrid data to ramdisk
else
    echo ' Using metgrid data from:'
fi
echo $METDATA
echo
# resolve working directory for real.exe
if [[ $RAMOUT == 1 ]]
  then 
	REALDIR=$RAMDATA # write data to RAM and copy to HD later
else
    REALDIR=$WORKDIR # write data directly to hard disk
fi


# copy namelist and link to real.exe into working director
cp -P $INIDIR/real.exe $REALDIR # link to executable real.exe
cp $INIDIR/namelist.input $REALDIR # copy namelist

## run and time hybrid (mpi/openmp) job
cd $REALDIR # so that output is written here
echo
echo OMP_NUM_THREADS=$THREADS
echo $HYBRIDRUN ./real.exe
echo
echo Writing output to $REALDIR
echo
# launch
time -p $HYBRIDRUN ./real.exe
wait

## finish / clean-up
mkdir $REALLOG # make folder for log files
cd $REALDIR
# save log files and meta data
mv rsl.*.???? namelist.input namelist.output real.exe $REALLOG
# copy/move date to output directory (hard disk) if necessary
if [[ ! $REALDIR == $WORKDIR ]]
  then 
	echo ' Copying WRF input data to:'
    echo $WORKDIR
	time -p mv wrf*_d?? $WORKDIR
fi
# clean-up RAM disk
if [[ $RAMIN == 1 ]] || [[ $RAMOUT == 1 ]]
  then rm -rf $RAMDATA 
fi
# finish
echo
echo ' >>> real.exe finished <<< '
echo
echo
echo '   ***   ***   ***   '
echo

## otherwise copy input data from initial directory
else
    cp -P $INIDIR/wrf*_d?? $WORKDIR
fi # if RUNREAL


## run WRF pre-processor: real.exe

if [[ $RUNWRF == 1 ]]
  then
echo
echo ' >>> Running WRF <<< '
echo

## link/copy relevant input files
cd $INIDIR # folder containing input files
# essentials
cp -P namelist.input wrf.exe $WORKDIR
# radiation scheme
if [[ $RAD == 'CAM' ]]; then 
    cp -P CAM* ozone* $WORKDIR
elif [[ $RAD == 'RRTMG' ]]; then 
    cp -P RRTMG_* $WORKDIR
elif [[ $RAD == 'RRTM' ]]; then 
    cp -P RRTM_* $WORKDIR
else
    echo 'WARNING: no radiation scheme selected!'
fi
# land-surface scheme
if [[ $LSM == 'Noah' ]] || [[ $LSM == 'RUC' ]]; then 
    cp -P SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL $WORKDIR
elif [[ $RAD == 'Diff' ]]; then 
    cp -P LANDUSE.TBL $WORKDIR
else
    echo 'WARNING: no land-surface model selected!'
fi

## run and time hybrid (mpi/openmp) job
cd $WORKDIR
echo
echo OMP_NUM_THREADS=$THREADS
echo $HYBRIDRUN ./wrf.exe
echo
echo Writing output to $REALDIR
echo
# launch
time -p $HYBRIDRUN ./wrf.exe
wait

fi # if RUNWRF