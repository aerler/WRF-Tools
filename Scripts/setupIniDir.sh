#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC

## load configuration 
source config.setup
# run folder
RUNDIR="${PWD}"
mkdir -p "${RUNDIR}"

# link meta data
mkdir -p "${RUNDIR}/meta"
cd "${RUNDIR}/meta"
ln -sf "${WRFTOOLS}/misc/data/${POPMAP}" ${POPMAP}  
ln -sf "${WRFTOOLS}/misc/data/${GEOGRID}" GEOGRID.TBL
ln -sf "${WRFTOOLS}/misc/data/${METGRID}" METGRID.TBL
ln -sf "${WRFTOOLS}/misc/data/${UNCCSM}" namelist.data
ln -sf "${WRFTOOLS}/misc/data/${PYWPS}" namelist.py
ln -sf "${WRFTOOLS}/misc/data/${NCL}" setup.ncl
# link boundary data
cd "${RUNDIR}"
ln -sf "${DATADIR}/atm/hist/" "atm" # atmosphere
ln -sf "${DATADIR}/lnd/hist/" "lnd" # land surface
ln -sf "${DATADIR}/ice/hist/" "ice" # sea ice

## link in WPS stuff
# WPS scripts and executables
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWPS.sh"
ln -sf "${WRFTOOLS}/Python/pyWPS.py"
ln -sf "${WRFTOOLS}/NCL/eta2p.ncl"
# WPS GPC-specific stuff (for largemem-nodes)
if [[ "$WPSSYS" == "GPC" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/GPC/setupGPC.sh"
	ln -sf "${WRFTOOLS}/bin/GPC-lm/unccsm.exe"
	ln -sf "${WPSSRC}/GPC-MPI/O3xHost/geogrid.exe"
	ln -sf "${WPSSRC}/GPC-MPI/O3xSSSE3/metgrid.exe"
	ln -sf "${WRFSRC}/GPC-MPI-Clim/O3xSSSE3/real.exe"
	if [[ -n "${CYCLING}" ]]; then
		cp "${WRFTOOLS}/Scripts/GPC/run_cycling_WPS.pbs" .
	else
		cp "${WRFTOOLS}/Scripts/GPC/run_test_WPS.pbs" .
	fi		
fi
# Some modifications if WRF is running on TCS
if [[ "$WRFSYS" == "TCS" ]]; then
	ln -sf "${WPSSRC}/TCS-MPI/NoOptO3/geogrid.exe"
fi

## link in WRF stuff
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWRF.sh"
ln -sf "${WRFTOOLS}/misc/tables" 'tables' # WRF default tables
#ln -sf "${WRFTOOLS}/misc/tables/" # new tables includign Noah-MP stuff 
# WRF on GPC
if [[ "$WRFSYS" == "GPC" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/GPC/setupGPC.sh"
	if [[ -n "${CYCLING}" ]]; then
        ln -sf "${WRFTOOLS}/Scripts/GPC/run_cycle_pbs.sh"
        ln -sf "${WRFTOOLS}/Python/cycling.py"
        cp "${WRFTOOLS}/misc/namelists/stepfile.${CYCLING}" 'stepfile' 
		cp "${WRFTOOLS}/Scripts/GPC/run_cycling_WRF.pbs" .
	else
		cp "${WRFTOOLS}/Scripts/GPC/run_test_WRF.pbs" .
	fi
	ln -sf "${WRFSRC}/GPC-MPI-Clim/O3xHost/wrf.exe"
fi
# WRF on TCS
if [[ "$WRFSYS" == "TCS" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/TCS/setupTCS.sh"
	cp "${WRFTOOLS}/Scripts/TCS/run_test_WRF.ll" .
    if [[ -n "${CYCLING}" ]]; then
        ln -sf "${WRFTOOLS}/Scripts/TCS/run_cycle_ll.sh"
        ln -sf "${WRFTOOLS}/Python/cycling.py"
        cp "${WRFTOOLS}/misc/namelists/stepfile.${CYCLING}" 'stepfile' 
        cp "${WRFTOOLS}/Scripts/TCS/run_cycling_WRF.ll" .
    else
        cp "${WRFTOOLS}/Scripts/TCS/run_test_WRF.ll" .
    fi
	ln -sf "${WRFSRC}/TCS-MPI-Clim/O3q64/wrf.exe"
fi

## prompt user to create data links
echo "Remainign tasks:"
echo " * review meta data (meta/ and tables/) and edit namelists"
echo " * adapt run scripts, if necessary" 
