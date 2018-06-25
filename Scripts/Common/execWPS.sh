#!/bin/bash
# driver script to run WRF pre-processing: runs pyWPS.py and real.exe on RAM disk
# created 25/06/2012 by Andre R. Erler, GPL v3

# variable defined in driver script:
# $TASKS, $THREADS, $HYBRIDRUN, $WORKDIR, $RAMDISK
# optional arguments:
# $RUNPYWPS, $METDATA, $RUNREAL, $REALIN, $RAMIN, $REALOUT, $RAMOUT

## prepare environment
SCRIPTDIR=${SCRIPTDIR:-"${INIDIR}"} # script location
BINDIR=${BINDIR:-"${INIDIR}"} # executable location
NOCLOBBER=${NOCLOBBER:-'-n'} # prevent 'cp' from overwriting existing files
# RAM disk
RAMDATA="${RAMDISK}/data/" # data folder used by Python script
RAMTMP="${RAMDISK}/tmp/" # temporary folder used by Python script
# pyWPS.py
RUNPYWPS=${RUNPYWPS:-1} # whether to run runWPS.py
DATATYPE=${DATATYPE:-'CESM'} # data source also see $PYWPS_DATA_SOURCE
PYDATA="${WORKDIR}/data/" # data folder used by Python script
PYLOG="pyWPS" # log folder for Python script (use relative path for tar)
PYTGZ="${RUNNAME}_${PYLOG}.tgz" # archive for log folder
METDATA=${METDATA:-''} # folder to store metgrid data on disk, if desired
# N.B.: leave undefined to skip disk storage; defining $METDATA will set "ldisk = True" in pyWPS
# real.exe
RUNREAL=${RUNREAL:-1} # whether to run real.exe
REALIN=${REALIN:-"${METDATA}"} # location of metgrid files
REALTMP=${REALTMP:-"${HOME}/metgrid"} # in case path to metgrid data is too long
RAMIN=${RAMIN:-1} # copy input data to ramdisk or read from HD
REALOUT=${REALOUT:-"${WORKDIR}"} # output folder for WRF input data
RAMOUT=${RAMOUT:-1} # write output data to ramdisk or directly to HD
REALLOG="real" # log folder for real.exe
REALTGZ="${RUNNAME}_${REALLOG}.tgz" # archive for log folder

# assuming working directory is already present
cp "${SCRIPTDIR}/execWPS.sh" "${WORKDIR}"
# remove and recreate temporary folder (ramdisk)
rm -rf "${RAMDATA}"
mkdir -p "${RAMDATA}" # create data folder on ramdisk


## run WPS driver script: pyWPS.py

if [[ ${RUNPYWPS} == 1 ]]
  then

    # launch feedback
    echo
    echo ' >>> Running WPS <<< '
    echo

    # specific environment for pyWPS.py
    # N.B.: ´mkdir $RAMTMP´ is actually done by Python script
    cd "${INIDIR}"
    # copy links to source data (or create links)
    cp ${NOCLOBBER} -P "${BINDIR}/pyWPS.py" "${BINDIR}/metgrid.exe" "${WORKDIR}"    
    if [[ "${DATATYPE}" == 'CESM' || "${DATATYPE}" == 'CCSM' ]]; then
    	# CESM/CCSM Global Climate Model
	    cp ${NOCLOBBER} -P "${INIDIR}/atm" "${INIDIR}/lnd" "${INIDIR}/ice" "${WORKDIR}"
	    cp ${NOCLOBBER} -P "${BINDIR}/unccsm.ncl" "${BINDIR}/unccsm.exe" "${WORKDIR}"
	elif [[ "${DATATYPE}" == 'CFSR' ]]; then
		# CFSR Reanalysis Data
		cp ${NOCLOBBER} -P "${INIDIR}/plev" "${INIDIR}/srfc" "${WORKDIR}"
		cp ${NOCLOBBER} -P "${BINDIR}/ungrib.exe" "${WORKDIR}"
  elif [[ "${DATATYPE}" == 'CMIP5' ]]; then
		# CMIP5 Global Climate Model series Data
		#cp ${NOCLOBBER} -P "${INIDIR}/MIROC5_rcp85_2085_pointer_local_full.validate.nc" "${WORKDIR}/CMIP5data.validate.nc"      # copy the validate file used by cdb_query
    cp ${NOCLOBBER} -P "${INIDIR}/init" "${WORKDIR}"     #copy the initial step data
		cp ${NOCLOBBER} -P "${BINDIR}/unCMIP5.ncl" "${BINDIR}/unccsm.exe" "${WORKDIR}"    # copy the executables
    find ./meta -maxdepth 1 -name "*validate*" -exec cp ${NOCLOBBER} -P {} "${WORKDIR}/CMIP5data.validate.nc" \;
		#cp ${NOCLOBBER} -P "${INIDIR}/orog_fx_MIROC5_rcp85_r0i0p0.nc" "${WORKDIR}/orog_file.nc"      # copy the coordinate files used by unCMIP5.ncl
    find ./meta -maxdepth 1 -name "*orog*" -exec cp ${NOCLOBBER} -P {} "${WORKDIR}/orog_file.nc" \;
		#cp ${NOCLOBBER} -P "${INIDIR}/sftlf_fx_MIROC5_rcp85_r0i0p0.nc" "${WORKDIR}/sftlf_file.nc"      
    find ./meta -maxdepth 1 -name "*sftlf*" -exec cp ${NOCLOBBER} -P {} "${WORKDIR}/sftlf_file.nc" \;
		#cp ${NOCLOBBER} -P "${INIDIR}/MIROC5_ocn2atm_linearweight.nc" "${WORKDIR}/ocn2atmweight_file.nc"      
    find ./meta -maxdepth 1 -name "*linearweight*" -exec cp ${NOCLOBBER} -P {} "${WORKDIR}/ocn2atmweight_file.nc" \;
		
	elif [[ "${DATATYPE}" == 'ERA-I' ]]; then
    # CFSR Reanalysis Data
    cp ${NOCLOBBER} -P "${INIDIR}/uv" "${INIDIR}/sc" "${INIDIR}/sfc" "${WORKDIR}"
    cp ${NOCLOBBER} -P "${BINDIR}/ungrib.exe" "${WORKDIR}"
	fi # $DATATYPE
    cp ${NOCLOBBER} -r "${INIDIR}/meta/" "${WORKDIR}"
    cp ${NOCLOBBER} -P "${INIDIR}/"geo_em.d??.nc "${WORKDIR}" # copy or link to geogrid files
    cp ${NOCLOBBER} "${INIDIR}/namelist.wps" "${WORKDIR}" # configuration file

    # run and time main pre-processing script (Python)
    cd "${WORKDIR}" # using current working directory
    # some influential environment variables
    export OMP_NUM_THREADS=1 # set OpenMP environment
    # environment variables required by Python script pyWPS
    export PYWPS_THREADS=$(( TASKS*THREADS ))
    export PYWPS_DATA_TYPE="${DATATYPE}"
    export PYWPS_KEEP_DATA="${RAMIN}"
    export PYWPS_MET_DATA="${METDATA}"
    echo
    echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"
    echo "PYWPS_THREADS=${PYWPS_THREADS}"
    echo "PYWPS_DATA_TYPE=${DATATYPE}"
    echo "PYWPS_KEEP_DATA=${RAMIN}"
    echo "PYWPS_MET_DATA=${METDATA}"
    echo
    echo "python pyWPS.py"
    echo
    if [[ -n "${METDATA}" ]];
	then echo "Writing metgrid files to ${METDATA}"
	else echo "Not writing metgrid files to disk."
    fi
    echo
    eval "time -p python pyWPS.py"
    PYERR=$? # save WRF error code and pass on to exit
    echo
    wait

    # copy log files to disk
    rm "${RAMTMP}"/*.nc "${RAMTMP}"/*/*.nc # remove data files
    rm -rf "${WORKDIR}/${PYLOG}/" # remove existing logs, just in case
    cp -r "${RAMTMP}" "${WORKDIR}/${PYLOG}/" # copy entire folder and rename
    rm -rf "${RAMTMP}"
    # archive log files
    tar cf - "${PYLOG}/" | gzip > ${PYTGZ} # pipe and gzip necessary for AIX compatibility
    # move metgrid data to final destination (if pyWPS wrote data to disk)
    if [[ -n "${METDATA}" ]] && [[ "${METDATA}" != "${WORKDIR}" ]]; then
		mkdir -p "${METDATA}"
		cp ${PYTGZ} "${METDATA}"
		mv "${PYDATA}"/* "${METDATA}"
		rm -r "${PYDATA}"
    fi
    
    # finish
    
    echo
    echo ' >>> WPS finished <<< '
    echo

# if not running Python script, get data from disk
elif [[ ${RAMIN} == 1 ]]; then

    echo
    echo ' Copying source data to ramdisk.'
    echo
    time -p cp "${REALIN}"/*.nc "${RAMDATA}" # copy alternate data to ramdisk

fi # if RUNPYWPS


echo
echo '   ***   ***   '
echo


## run WRF pre-processor: real.exe

if [[ ${RUNREAL} == 1 ]]
  then

    # launch feedback
    echo
    echo ' >>> Running real.exe <<< '
    echo

    # copy namelist and link to real.exe into working directory
    cd "${WORKDIR}"
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
    if [[ "${REALDIR}" == "${WORKDIR}" ]]; then
	    cp "${WORKDIR}/namelist.input" "${WORKDIR}/namelist.input.backup" # backup-copy of namelists
      # N.B.: the namelist for real is modified in-palce, hence the backup is necessary
     else
	    cp -P "${WORKDIR}/real.exe" "${REALDIR}" # link to executable real.exe
	    cp "${WORKDIR}/namelist.input" "${REALDIR}" # copy namelists
    fi

    # change input directory in namelist.input
    cd "${REALDIR}" # so that output is written here
    if [[ -n "$( grep 'nocolon' namelist.input )" ]]; then
      echo "Namelist option 'nocolon' is not supported by PyWPS - removing option for real.exe." 
      sed -i '/.*nocolon.*/d' namelist.input # remove from temporary namelist
    fi # if nocolon
    sed -i '/.*auxinput1_inname.*/d' namelist.input # remove from namelist and add actual input directory
    if [[ ${RAMIN} == 1 ]]; then
	    sed -i '/\&time_control/ a\ auxinput1_inname = "'"${RAMDATA}"'/met_em.d<domain>.<date>"' namelist.input
    else
      ln -sf "${REALIN}" "${REALTMP}" # temporary link to metgrid data, if path is too long for real.exe
	    sed -i '/\&time_control/ a\ auxinput1_inname = "'"${REALTMP}"'/met_em.d<domain>.<date>"' namelist.input
    fi

    ## run and time hybrid (mpi/openmp) job
    cd "${REALDIR}" # so that output is written here
    export OMP_NUM_THREADS=${THREADS} # set OpenMP environment
    LOOPACTIVE=true
    LOOPCOUNTER=0
    while $LOOPACTIVE; do
        echo "Number of loop is $LOOPCOUNTER"
        echo "Wait 1m before real.exe starts"
        sleep 1m
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
    	    then REALERR=0; LOOPACTIVE=false;
    	    else REALERR=1; let "LOOPCOUNTER=LOOPCOUNTER+1"; echo "real.exe failed, restarting...";
        fi
        if [[ "$LOOPCOUNTER" -gt 10 ]]; then
                LOOPACTIVE=false
                echo " real.exe loop exceed maximum trial of 10, aborting. "
        fi
    done

    # clean-up and move output to hard disk
    if [[ ${RAMIN} != 1 ]]; then rm "${REALTMP}"; fi # remove temporary link to metgrid data
    rm -rf "${WORKDIR}/${REALLOG}" # remove existing logs, just in case
    mkdir -p "${REALLOG}" # make folder for log files locally
    #cd "${REALDIR}" # still in $REALDIR
    # save log files and meta data
    mv rsl.*.???? namelist.output "${REALLOG}"
    cp -P namelist.input real.exe "${REALLOG}" # leave namelist in place
    tar cf - "${REALLOG}" | gzip > ${REALTGZ} # archive logs with data (pipe necessary for AIX compatibility)
    if [[ "${REALDIR}" == "${WORKDIR}" ]]; then
	    cp "${WORKDIR}/namelist.input.backup" "${WORKDIR}/namelist.input" # restore original namelist
      # N.B.: the namelist for real is modified in-palce, hence the backup is necessary
    else
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


## finish / clean-up

# delete temporary data
rm -rf "${RAMDATA}"

# exit code handling
exit $(( PYERR + REALERR ))
