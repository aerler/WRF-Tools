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
RUNREAL=${RUNREAL:-1} # whether to run real.exe
REALIN=${REALIN:-"${INIDIR}/metgrid/"} # location of metgrid files
RAMIN=${RAMIN:-1} # copy input data to ramdisk or read from HD
REALOUT=${REALOUT:-"${WORKDIR}"} # output folder for WRF input data
RAMOUT=${RAMOUT:-1} # write output data to ramdisk or directly to HD
REALLOG="real" # log folder for real.exe
REALTGZ="${NAME}_${REALLOG}.tgz" # archive for log folder
# WRF
RUNWRF=${RUNWRF:-1} # whether to run WRF
if [[ -z "$WRFIN" ]]; then # location of wrfinput_d?? files etc. 
	if [[ $RUNREAL == 1 ]]; then  WRFIN="${REALOUT}"; 
	else WRFIN="${INIDIR}"; fi; 
fi
WRFOUT=${WRFOUT:-"${WORKDIR}"} # final destination of WRF output
TABLES=${TABLES:-"${INIDIR}/tables/"} # folder for WRF data tables
#RAD=${RAD:-'CAM'} # folder for WRF input data
#LSM=${LSM:-'Noah'} # output folder for WRF
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
export OMP_NUM_THREADS=${THREADS} # set OpenMP environment
echo
echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"
echo "${HYBRIDRUN} ./real.exe"
echo
echo "Writing output to ${REALDIR}"
echo
${TIMING} ${HYBRIDRUN} ./real.exe
echo
wait # wait for all threads to finish

# clean-up and move output to hard disk
rm -rf "$WORKDIR/${REALLOG}" # remove old logs
mkdir -p "${REALLOG}" # make folder for log files locally
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
	${TIMING} mv wrf* $REALTGZ "$REALOUT"
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
cd "${WRFDIR}"
# radiation scheme
if [[ -z "$RAD" ]]; then # read from namelist if not defined (need to be in $WRFDIR)
	RAD=`sed -n '/ra_lw_physics/ s/.*= *\(.\),.*/\1/p' namelist.input`
	echo "Determining radiation scheme from namelist: RAD=$RAD"
fi
# select scheme and print confirmation
if [[ $RAD == 'RRTM' ]] || [[ $RAD == 1 ]]; then
	echo "Using RRTM radiation scheme." 
    RADTAB="RRTM_DATA RRTM_DATA_DBL"
elif [[ $RAD == 'CAM' ]] || [[ $RAD == 3 ]]; then 
	echo "Using CAM radiation scheme."
    RADTAB="CAM_ABS_DATA CAM_AEROPT_DATA ozone.formatted ozone_lat.formatted ozone_plev.formatted"
    #RADTAB="${RADTAB} CAMtr_volume_mixing_ratio"
elif [[ $RAD == 'RRTMG' ]] || [[ $RAD == 4 ]]; then
	echo "Using RRTMG radiation scheme." 
    RADTAB="RRTMG_LW_DATA RRTMG_LW_DATA_DBL RRTMG_SW_DATA RRTMG_SW_DATA_DBL"
else
    echo 'WARNING: no radiation scheme selected!'
fi
# land-surface scheme
if [[ -z "$LSM" ]]; then # read from namelist if not defined (need to be in $WRFDIR)
	LSM=`sed -n '/sf_surface_physics/ s/.*= *\(.\),.*/\1/p' namelist.input`
	echo "Determining land-surface scheme from namelist: LSM=$LSM"
fi
# select scheme and print confirmation
if [[ $RAD == 'Diff' ]] || [[ $LSM == 1 ]]; then
	echo "Using diffusive land-surface scheme." 
    LSMTAB="LANDUSE.TBL"
elif [[ $LSM == 'Noah' ]] || [[ $LSM == 2 ]]; then
	echo "Using Noah land-surface scheme."
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
elif [[ $LSM == 'RUC' ]] || [[ $LSM == 3 ]]; then 
	echo "Using RUC land-surface scheme."
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
else
    echo 'WARNING: no land-surface model selected!'
fi
# copy appropriate tables for physics options 
cd "${TABLES}"
cp $RADTAB $LSMTAB "${WRFDIR}"
# copy data file for emission scenario, if applicable
if [[ -n "$GHG" ]]; then # only if $GHG is defined!
	echo
	if [[ $RAD == 'CAM' ]] || [[ $RAD == 3 ]]; then				 
		echo "GHG emission scenario: $GHG"    	
		cp "CAMtr_volume_mixing_ratio.${GHG}" "${WRFDIR}/CAMtr_volume_mixing_ratio"
    else
    	echo "WARNING: variable GHG emission scenarios not available with the ${RAD} scheme!"
    	unset GHG # for later use
    fi
    echo
fi

# link to input data, if necessary
cd "${WRFDIR}"
if [[ ! "${WRFIN}" == "${WRFDIR}" ]]; then 
	for INPUT in "${WRFIN}"/wrf*_d??; do
		ln -s "${INPUT}"
	done 
fi
## run and time hybrid (mpi/openmp) job
export OMP_NUM_THREADS=${THREADS} # set OpenMP environment
echo
echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"
echo "${HYBRIDRUN} ./wrf.exe"
echo
# launch
${TIMING} ${HYBRIDRUN} ./wrf.exe
echo
wait # wait for all threads to finish

# clean-up and move output to destination
rm -rf "$WORKDIR/${WRFLOG}" # remove old logs
mkdir -p "${WRFLOG}" # make folder for log files locally
#cd "$WORKDIR"
# save log files and meta data
mv $RADTAB $LSMTAB rsl.*.???? namelist.input namelist.output wrf.exe "${WRFLOG}"
if [[ -n "$GHG" ]]; then # also add emission scenario to log
	mv 'CAMtr_volume_mixing_ratio' "${WRFLOG}/CAMtr_volume_mixing_ratio.${GHG}"
fi
tar czf $WRFTGZ "$WRFLOG" # archive logs with data
if [[ ! "$WRFDIR" == "$WORKDIR" ]]; then 
	mv "$WRFLOG" "$WORKDIR" # move log folder to working directory
fi
# copy/move date to output directory (hard disk) if necessary
if [[ ! "$WRFDIR" == "$WRFOUT" ]]; then 
	echo "Moving data to ${WRFOUT}"
	# copy real.exe log files to wrf output
	if [[ "$WRFIN" == "$WORKDIR" ]] && [[ "$REALOUT" == "$WORKDIR" ]]; then
		echo "  (including ${REALTGZ})"
		mv $REALTGZ "$WRFOUT"
	fi	
	${TIMING} mv wrfout* $WRFTGZ "$WRFOUT"
fi

# finish
echo
echo ' >>> WRF finished <<< '
echo
fi # if RUNWRF