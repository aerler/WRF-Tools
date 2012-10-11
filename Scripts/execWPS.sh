#!/bin/bash
# driver script to run WRF pre-processing: runs pyWPS.py and real.exe on RAM disk
# created 25/06/2012 by Andre R. Erler, GPL v3

# variable defined in driver script: 
# $TASKS, $THREADS, $HYBRIDRUN, ${WORKDIR}, $WORKDIR, $RAMDISK
# optional arguments:
# $RUNPYWPS, $METDATA, $RUNREAL, $REALIN, $RAMIN, $REALOUT, $RAMOUT

## prepare environment
NOCLOBBER=${NOCLOBBER:-'-n'} # prevent 'cp' from overwriting existing files
# RAM disk
RAMDATA="${RAMDISK}/data/" # data folder used by Python script
RAMTMP="${RAMDISK}/tmp/" # temporary folder used by Python script
# pyWPS.py
RUNPYWPS=${RUNPYWPS:-1} # whether to run runWPS.py
PYDATA="${WORKDIR}/data/" # data folder used by Python script
PYLOG="pyWPS" # log folder for Python script (use relative path for tar) 
PYTGZ="${RUNNAME}_${PYLOG}.tgz" # archive for log folder
METDATA=${METDATA:-"${INIDIR}/metgrid/"} # final destination for metgrid data 
# real.exe
RUNREAL=${RUNREAL:-1} # whether to run real.exe
REALIN=${REALIN:-"${METDATA}"} # location of metgrid files
RAMIN=${RAMIN:-1} # copy input data to ramdisk or read from HD
REALOUT=${REALOUT:-"${WORKDIR}"} # output folder for WRF input data
RAMOUT=${RAMOUT:-1} # write output data to ramdisk or directly to HD
REALLOG="real" # log folder for real.exe
REALTGZ="${RUNNAME}_${REALLOG}.tgz" # archive for log folder

# assuming working directory is already present
cp "${INIDIR}/execWPS.sh" "${WORKDIR}"
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
# copy links to source data (or create links)
cd "${INIDIR}" 
cp ${NOCLOBBER} -P atm lnd ice pyWPS.py unccsm.ncl unccsm.exe metgrid.exe "${WORKDIR}"
cp ${NOCLOBBER} -r meta/ "${WORKDIR}"
cp ${NOCLOBBER} -P geo_em.d??.nc "${WORKDIR}" # copy or link to geogrid files
cp ${NOCLOBBER} namelist.wps "${WORKDIR}" # configuration file

# run and time main pre-processing script (Python)
cd "${WORKDIR}" # using current working directory
export OMP_NUM_THREADS=1 # set OpenMP environment
export PYWPS_THREADS=$(( TASKS*THREADS ))
echo
echo "OMP_NUM_THREADS=${OMP_NUM_THREADS}"
echo "PYWPS_THREADS=${PYWPS_THREADS}"
echo
echo "python pyWPS.py"
echo
echo "Writing output to ${METDATA}"
echo
time -p python pyWPS.py
PYERR=$? # save WRF error code and pass on to exit
echo
wait

# copy log files to disk
rm "${RAMTMP}"/*.nc "${RAMTMP}"/*/*.nc # remove data files
rm -rf "${WORKDIR}/${PYLOG}/" # remove existing logs, just in case
cp -r "${RAMTMP}" "${WORKDIR}/${PYLOG}/" # copy entire folder and rename
rm -rf "${RAMTMP}"
# archive log files 
tar czf ${PYTGZ} "${PYLOG}/"
# move metgrid data to final destination (if pyWPS wrote data to disk)
if [[ -e "${PYDATA}" ]] && [[ ! "${METDATA}" == "${WORKDIR}" ]]; then
	mkdir -p "${METDATA}"
	mv ${PYTGZ} "${METDATA}"
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
cp ${NOCLOBBER} -P "${INIDIR}/real.exe" "${WORKDIR}" # link to executable real.exe
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
time -p ${HYBRIDRUN} ./real.exe
REALERR=$? # save WRF error code and pass on to exit
echo
wait # wait for all threads to finish

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


## finish / clean-up

# delete temporary data
rm -rf "${RAMDATA}"

# exit code handling
exit $(( PYERR + REALERR ))
