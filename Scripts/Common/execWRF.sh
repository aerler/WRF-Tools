#!/bin/bash
# driver script to run WRF itself: runs real.exe and wrf.exe
# created 25/06/2012 by Andre R. Erler, GPL v3

# variable defined in driver script:
# $TASKS, $THREADS, $HYBRIDRUN, $INIDIR, $WORKDIR
# for real.exe
# $RUNREAL, $REALIN, $RAMIN, REALOUT, $RAMOUT
# for WRF
# $RUNWRF, $WRFIN, $WRFOUT, $RAD, $LSM

#set -e # abort if anything goes wrong

## prepare environment
SCRIPTDIR=${SCRIPTDIR:-"${INIDIR}"} # script location
BINDIR=${BINDIR:-"${INIDIR}"} # executable location
NOCLOBBER=${NOCLOBBER:-'-n'} # prevent 'cp' from overwriting existing files
# real.exe
RAMDATA=/dev/shm/aerler/data/ # RAM disk data folder
RUNREAL=${RUNREAL:-0} # whether to run real.exe
REALIN=${REALIN:-"${INIDIR}/metgrid/"} # location of metgrid files
RAMIN=${RAMIN:-0} # copy input data to ramdisk or read from HD
REALOUT=${REALOUT:-"${WORKDIR}"} # output folder for WRF input data
RAMOUT=${RAMOUT:-0} # write output data to ramdisk or directly to HD
REALLOG="real" # log folder for real.exe
REALTGZ="${RUNNAME}_${REALLOG}.tgz" # archive for log folder
# WRF
RUNWRF=${RUNWRF:-1} # whether to run WRF
WRFIN=${WRFIN:-"${WORKDIR}"} # location of wrfinput_d?? files etc.
WRFOUT=${WRFOUT:-"${WORKDIR}"} # final destination of WRF output
RSTDIR=${RSTDIR:-"${WRFOUT}"} # final destination of WRF restart files
TABLES=${TABLES:-"${INIDIR}/tables/"} # folder for WRF data tables
#RAD=${RAD:-'CAM'} # folder for WRF input data
#LSM=${LSM:-'Noah'} # output folder for WRF
WRFLOG="wrf" # log folder for wrf.exe
WRFTGZ="${RUNNAME}_${WRFLOG}.tgz" # archive for log folder
# N.B.: tgz-extension also used later in cp *.tgz $WRFOUT

# assuming working directory is already present
cp "${SCRIPTDIR}/execWRF.sh" "${WORKDIR}"


## run WRF pre-processor: real.exe

if [[ ${RUNREAL} == 1 ]]
  then

    # launch feedback
    echo
    echo ' >>> Running real.exe <<< '
    echo

    # copy namelist and link to real.exe into working directory
    cp -P "${BINDIR}/real.exe" "${WORKDIR}" # link to executable real.exe
    cp ${NOCLOBBER} "${INIDIR}/namelist.input" "${WORKDIR}" # copy namelists
    # N.B.: this is necessary so that already existing files in $WORKDIR are used

    # resolve working directory for real.exe
    if [[ ${RAMOUT} == 1 ]]; then
	REALDIR="${RAMDATA}" # write data to RAM and copy to HD later
    else
	REALDIR="${REALOUT}" # write data directly to hard disk
    fi
    # specific environment for real.exe
    mkdir -p "${REALOUT}" # make sure data destination folder exists
    # copy namelist and link to real.exe into actual working directory
    if [[ ! "${REALDIR}" == "${WORKDIR}" ]]; then
	cp -P "${WORKDIR}/real.exe" "${REALDIR}" # link to executable real.exe
	cp "${WORKDIR}/namelist.input" "${REALDIR}" # copy namelists
    fi

    # change input directory in namelist.input
    cd "${REALDIR}" # so that output is written here
    sed -i '/.*auxinput1_inname.*/d' namelist.input # remove and input directories
    if [[ ${RAMIN} == 1 ]]; then
	sed -i '/\&time_control/ a\ auxinput1_inname = "'"${RAMDATA}"'/met_em.d<domain>.<date>"' namelist.input
    else
	sed -i '/\&time_control/ a\ auxinput1_inname = "'"${REALIN}"'/met_em.d<domain>.<date>"' namelist.input
    fi

    ## run and time hybrid (mpi/openmp) job
    cd "${REALDIR}" # so that output is written here
    export OMP_NUM_THREADS=${THREADS} # set OpenMP environment
    echo
    echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"
    echo
    echo "${HYBRIDRUN} ./real.exe"
    echo
    echo "Writing output to ${REALDIR}"
    echo
    eval "time -p ${HYBRIDRUN} ./real.exe"
    wait # wait for all threads to finish
    echo
    # check REAL exit status
    if [[ -n $(grep 'SUCCESS COMPLETE REAL_EM INIT' rsl.error.0000) ]];
	then REALERR=0
	else REALERR=1
    fi

    # clean-up and move output to hard disk
    mkdir "${REALLOG}" # make folder for log files locally
    #cd "${REALDIR}"
    # save log files and meta data
    mv rsl.*.???? namelist.output "${REALLOG}"
    cp -P namelist.input real.exe "${REALLOG}" # leave namelist in place
    tar czf ${REALTGZ} "${REALLOG}" # archive logs with data
    if [[ ! "${REALDIR}" == "${WORKDIR}" ]]; then
	rm -rf "${WORKDIR}/${REALLOG}" # remove existing logs, just in case
	mv "${REALLOG}" "${WORKDIR}" # move log folder to working directory
    fi
    # copy/move date to output directory (hard disk) if necessary
    if [[ ! "${REALDIR}" == "${REALOUT}" ]]; then
	    echo "Copying data to ${REALOUT}"
	    time -p mv wrf* ${REALTGZ} "${REALOUT}"
    fi

    # finish
    echo
    echo ' >>> real.exe finished <<< '
    echo

fi # if RUNREAL


## run WRF: wrf.exe

if [[ ${RUNWRF} == 1 ]]
  then

    # launch feedback
    echo
    echo ' >>> Running WRF <<< '
    echo

    ## link/copy relevant input files
    WRFDIR="${WORKDIR}" # could potentially be executed in RAM disk as well...
    mkdir -p "${WRFOUT}" # make sure data destination folder exists
    # essentials
    cd "${INIDIR}" # folder containing input files
    cp -P "${BINDIR}/wrf.exe" "${WRFDIR}"
    cp ${NOCLOBBER} "${INIDIR}/namelist.input" "${WRFDIR}"
    cd "${WRFDIR}"

    ## figure out data tables (for radiation and surface scheme)
    # radiation scheme: try to infer from namelist using 'sed'
    SEDRAD=$(sed -n '/ra_lw_physics/ s/^\s*ra_lw_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
    if [[ -n "${SEDRAD}" ]]; then
	RAD="${SEDRAD}" # prefer namelist value over pre-set default
	echo "Determining radiation scheme from namelist: RAD=${RAD}"
    fi
    # select scheme and print confirmation
    if [[ ${RAD} == 'RRTM' ]] || [[ ${RAD} == 1 ]]; then
	echo "Using RRTM radiation scheme."
	RADTAB="RRTM_DATA RRTM_DATA_DBL"
    elif [[ ${RAD} == 'CAM' ]] || [[ ${RAD} == 3 ]]; then
	echo "Using CAM radiation scheme."
	RADTAB="CAM_ABS_DATA CAM_AEROPT_DATA ozone.formatted ozone_lat.formatted ozone_plev.formatted"
	#RADTAB="${RADTAB} CAMtr_volume_mixing_ratio" # this is handled below
    elif [[ ${RAD} == 'RRTMG' ]] || [[ ${RAD} == 4 ]]; then
	    echo "Using RRTMG radiation scheme."
	RADTAB="RRTMG_LW_DATA RRTMG_LW_DATA_DBL RRTMG_SW_DATA RRTMG_SW_DATA_DBL"
    else
	echo 'WARNING: no radiation scheme selected!'
	# this will only happen if no defaults are set and inferring from namelist via 'sed' failed
    fi
    # land-surface scheme: try to infer from namelist using 'sed'
    SEDLSM=$(sed -n '/sf_surface_physics/ s/^\s*sf_surface_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
    if [[ -n "${SEDLSM}" ]]; then
	LSM="${SEDLSM}" # prefer namelist value over pre-set default
	echo "Determining land-surface scheme from namelist: LSM=${LSM}"
    fi
    # select scheme and print confirmation
    if [[ ${LSM} == 'Diff' ]] || [[ ${LSM} == 1 ]]; then
	echo "Using diffusive land-surface scheme."
	LSMTAB="LANDUSE.TBL"
    elif [[ ${LSM} == 'Noah' ]] || [[ ${LSM} == 2 ]]; then
	echo "Using Noah land-surface scheme."
	LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
    elif [[ ${LSM} == 'RUC' ]] || [[ ${LSM} == 3 ]]; then
	echo "Using RUC land-surface scheme."
	LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
    elif [[ ${LSM} == 'Noah-MP' ]] || [[ ${LSM} == 4 ]]; then
	echo "Using Noah-MP land-surface scheme."
	LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL MPTABLE.TBL"
    elif [[ ${LSM} == 'CLM4' ]] || [[ ${LSM} == 5 ]]; then
	echo "Using CLM4 land-surface scheme."
	LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL CLM_ALB_ICE_DFS_DATA CLM_ASM_ICE_DFS_DATA CLM_DRDSDT0_DATA CLM_EXT_ICE_DRC_DATA CLM_TAU_DATA CLM_ALB_ICE_DRC_DATA CLM_ASM_ICE_DRC_DATA CLM_EXT_ICE_DFS_DATA CLM_KAPPA_DATA"
    else
	echo 'WARNING: no land-surface model selected!'
	# this will only happen if no defaults are set and inferring from namelist via 'sed' failed
    fi
    # copy appropriate tables for physics options
    cd "${TABLES}"
    cp ${NOCLOBBER} ${RADTAB} ${LSMTAB} "${WRFDIR}"
    # copy data file for emission scenario, if applicable
    if [[ -n "${GHG}" ]]; then # only if $GHG is defined!
	echo
	if [[ ${RAD} == 'CAM' ]] || [[ ${RAD} == 3 ]]; then
	    echo "GHG emission scenario: ${GHG}"
	    cp ${NOCLOBBER} "CAMtr_volume_mixing_ratio.${GHG}" "${WRFDIR}/CAMtr_volume_mixing_ratio"
	else
	    echo "WARNING: variable GHG emission scenarios not available with the ${RAD} scheme!"
	    unset GHG
	    # N.B.: $GHG is used later to test if a variable GHG scenario has been used (for logging purpose)fi
	fi
	echo
    fi

    # link to input data, if necessary
    cd "${WRFDIR}"
    if [[ "${WRFIN}" != "${WRFDIR}" ]]; then
	echo
	echo "Linking input data from location:"
	echo "${WRFIN}"
	for INPUT in "${WRFIN}"/wrf*_d??; do
		ln -s "${INPUT}"
	done
	echo
    fi
    ## run and time hybrid (mpi/openmp) job
    export OMP_NUM_THREADS=${THREADS} # set OpenMP environment
    echo
    echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"
    echo "${HYBRIDRUN} ./wrf.exe"
    echo
    # launch
    eval "time -p ${HYBRIDRUN} ./wrf.exe"
    wait # wait for all threads to finish
    echo
    # check WRF exit status
    echo
    if [[ -n $(grep 'SUCCESS COMPLETE WRF' 'rsl.error.0000') ]]; then
      	WRFERR=0
      	echo '   ***   WRF COMPLETED SUCCESSFULLY!!!   ***   '
    elif [[ -n $(grep 'NaN' 'rsl.error.'*) ]] || [[ -n $(grep 'NAN' 'rsl.error.'*) ]]; then
      	WRFERR=1
      	echo '   >>>   WRF FAILED:   NUMERICAL INSTABILITY   <<<   '
    else 
      	WRFERR=1
      	echo '   >>>   WRF FAILED! (UNKNOWN ERROR)   <<<   '
    fi
    echo

    # clean-up and move output to destination
    rm -rf "${WORKDIR}/${WRFLOG}" # remove old logs
    mkdir -p "${WRFLOG}" # make folder for log files locally
    #cd "${WORKDIR}"
    # save log files and meta data
    mv rsl.*.???? namelist.output "${WRFLOG}" # do not add tables to logs: ${RADTAB} ${LSMTAB}
    cp -P namelist.input wrf.exe "${WRFLOG}" # leave namelist in place
    if [[ -n "${GHG}" ]]; then # also add emission scenario to log
	    mv 'CAMtr_volume_mixing_ratio' "${WRFLOG}/CAMtr_volume_mixing_ratio.${GHG}"
    fi
    tar czf ${WRFTGZ} "${WRFLOG}" # archive logs with data
    if [[ ! "${WRFDIR}" == "${WORKDIR}" ]]; then
	    mv "${WRFLOG}" "${WORKDIR}" # move log folder to working directory
    fi
    # copy/move data to output directory (hard disk) if necessary
    if [[ ! "${WRFDIR}" == "${WRFOUT}" ]]; then
	# move new restart files as well
	for RESTART in "${WORKDIR}"/wrfrst_d??_????-??-??_??:??:??; do
	    if [[ ! -h "${RESTART}" ]]; then
		mv "${RESTART}" "${RSTDIR}" # defaults to $WRFOUT
	    fi # if not a link itself
	done
	echo "Moving data (*.nc) and log-files (*.tgz) to ${WRFOUT}"
	# time -p mv wrfout_d??_* "${WRFOUT}"}"
	mv wrfconst_d??.nc "${WRFOUT}" # this one doesn't have a date string
	mv wrf*_d??_????-??-??_??:??:??.nc "${WRFOUT}" # otherwise identify output files by date string
	# N.B.: I don't know how to avoid the error message cause by the restart-symlinks...
	# copy real.exe log files to wrf output
	mv "${WORKDIR}"/*.tgz "${WRFOUT}"
    fi

    # finish
    echo
    echo ' >>> WRF finished <<< '
    echo

fi # if RUNWRF

# handle exit code
exit $(( REALERR + WRFERR ))
