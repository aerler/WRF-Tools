#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC

## some settings: source folders
RUNDIR="${PWD}"
mkdir -p "${RUNDIR}"
# WPS
WPSSYS="GPC"
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
GEOGRID="FLAKE"
METGRID="CESM"
DATA="cesm"
DATATAG="marc"
POPMAP="map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc"
CASE="clim"
# WRF
WRFSYS="GPC"

## link in WPS stuff
# meta data
mkdir -p "${RUNDIR}/meta"
cd meta
ln -sf "${WRFTOOLS}/misc/data/${POPMAP}" ${POPMAP}  
ln -sf "${WRFTOOLS}/misc/data/GEOGRID.TBL.${GEOGRID}" GEOGRID.TBL
ln -sf "${WRFTOOLS}/misc/data/METGRID.TBL.${METGRID}" METGRID.TBL
ln -sf "${WRFTOOLS}/misc/data/namelist.data.${DATA}" namelist.data
ln -sf "${WRFTOOLS}/misc/data/namelist.py.${DATATAG}" namelist.py
ln -sf "${WRFTOOLS}/misc/data/setup.ncl.${DATA}" setup.ncl
# WPS scripts and executables
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWPS.sh"
ln -sf "${WRFTOOLS}/Python/pyWPS.py"
ln -sf "${WRFTOOLS}/NCL/eta2p.ncl"
# WPS GPC-sfpecific stuff (for largemem-nodes)
if [[ "$WPSSYS" == "GPC" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/GPC/setupGPC.sh"
	ln -sf "${WRFTOOLS}/Scripts/GPC/run_test_WPS.pbs"
	ln -sf "${WRFTOOLS}/bin/GPC-lm/unccsm.exe"
	ln -sf "${WPSSRC}/GPC-MPI/O3xSSSE3/geogrid.exe"
	ln -sf "${WPSSRC}/GPC-MPI/O3xSSSE3/metgrid.exe"
	ln -sf "${WRFSRC}/GPC-MPI/O3xSSSE3/real.exe"
fi

## WPS/WRF namelists
cp "${WRFTOOLS}/misc/namelists/namelist.wps.${CASE}" namelist.wps
cp "${WRFTOOLS}/misc/namelists/namelist.input.${CASE}" namelist.input

## link in WRF stuff
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWRF.sh"
ln -sf "${WRFTOOLS}/misc/tables/"
# WRF on GPC
if [[ "$WRFSYS" == "GPC" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/GPC/setupGPC.sh"
	ln -sf "${WRFTOOLS}/Scripts/GPC/run_test_WRF.pbs"
	ln -sf "${WRFSRC}/GPC-MPI/O3xHost/wrf.exe"
fi
# WRF on TCS
if [[ "$WRFSYS" == "TCS" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/TCS/setupTCS.sh"
	ln -sf "${WRFTOOLS}/Scripts/TCS/run_test_WRF.ll"
	ln -sf "${WRFSRC}/TCS-MPI/O3/wrf.exe"
fi

## prompt user to create data links
echo "Remainign tasks:"
echo " * link to data folders: atm, lnd, ice"
echo " * review meta data (meta/) and edit namelists"
echo " * adapt run scripts" 