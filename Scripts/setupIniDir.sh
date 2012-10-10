#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 04/10/2012 by Andre R. Erler
# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC

## TODO:
# * handle data tables in setup, not in execution script?
# * put machine-independent execution scripts into PATH?

## load configuration 
source xconfig.sh
## defaults
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
# WPS executables
WPSSYS=${WPSSYS:-"GPC"} # general system
GEOEXE="${WPSSRC}/GPC/Clim-fullIO/O3xHost/geogrid.exe"
if [[ "${WPSSYS}" == "GPC" ]]; then 
	METEXE="${WPSSRC}/GPC/Clim-fullIO/O3xHost/metgrid.exe"
	REALEXE="${WRFSRC}/GPC/Clim-fineIO-03/O3xHost/real.exe"
elif [[ "${WPSSYS}" == "GPC-lm" ]]; then
	METEXE="${WPSSRC}/GPC/Clim-fullIO/O3xSSS3/metgrid.exe"
	REALEXE="${WRFSRC}/GPC/Clim-fineIO-03/O3xSSS3/real.exe"
fi
# WRF executable
WRFSYS="GPC" # WRF
if [[ "${WRFSYS}" == "GPC" ]]; then 
	WRFEXE="${WRFSRC}/GPC/Clim-fineIO-03/O3xHost/wrf.exe"
elif [[ "${WRFSYS}" == "TCS" ]]; then
	WRFEXE="${WRFSRC}/TCS/Clim-fineIO-03/O3/wrf.exe"
fi
# run folder
RUNDIR=${RUNDIR:-"${PWD}"} # default; set in xconfig.sh 
mkdir -p "${RUNDIR}"

## create namelist files
# WRF
export TIME_CONTROL
export DIAGS
export PHYSICS
export DOMAINS
export FDDA
export DYNAMICS
export BDY_CONTROL
export NAMELIST_QUILT
# WPS
export SHARE
export GEOGRID
export METGRID
# create namelists
cd "${RUNDIR}/meta"
ln -sf "${WRFTOOLS}/Scripts/writeNamelists.sh" 
./writeNamelists.sh
rm writeNamelists.sh

## link data and meta data
# link meta data
mkdir -p "${RUNDIR}/meta"
cd "${RUNDIR}/meta"
ln -sf "${WRFTOOLS}/misc/data/${POPMAP}"  
ln -sf "${WRFTOOLS}/misc/data/${GEOGRID}" 'GEOGRID.TBL'
ln -sf "${WRFTOOLS}/misc/data/${METGRID}" 'METGRID.TBL'
ln -sf "${WRFTOOLS}/misc/data/${NCL}" 'setup.ncl'
# link boundary data
cd "${RUNDIR}"
ln -sf "${DATADIR}/atm/hist/" 'atm' # atmosphere
ln -sf "${DATADIR}/lnd/hist/" 'lnd' # land surface
ln -sf "${DATADIR}/ice/hist/" 'ice' # sea ice

## link in WPS stuff
# queue system
if [[ "${WPSSYS}" == "GPC"* ]]; then 
	WPSQ='pbs' # GPC standard and largemem nodes
elif [[ "${WPSSYS}" == "P7" ]]; then
	WPSQ='ll'
fi
# WPS scripts
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWPS.sh"
ln -sf "${WRFTOOLS}/Python/pyWPS.py"
ln -sf "${WRFTOOLS}/NCL/eta2p.ncl"
# platform dependent stuff
ln -sf "${WRFTOOLS}/bin/${WPSSYS}/unccsm.exe"
ln -sf "${WRFTOOLS}/Scripts/${WPSSYS}/setup${WPSSYS}.sh"
# if cycling
if [[ -n "${CYCLING}" ]]; then
	cp "${WRFTOOLS}/Scripts/${WPSSYS}/run_cycling_WPS.${WPSQ}" .
else
	cp "${WRFTOOLS}/Scripts/${WPSSYS}/run_test_WPS.${WPSQ}" .
fi		
# WPS/WRF executables
ln -sf "${GEOEXE}"
ln -sf "${METEXE}"
ln -sf "${REALEXE}"

## link in WRF stuff
# queue system
if [[ "${WRFSYS}" == "GPC" ]]; then 
	WRFQ='pbs' # GPC standard and largemem nodes
elif [[ "${WRFSYS}" == "TCS" ]] || [[ "${WRFSYS}" == "P7" ]]; then
	WRFQ='ll'
fi
# WRF scripts
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWRF.sh"
ln -sf "${WRFTOOLS}/misc/tables" # WRF default tables
#ln -sf "${WRFTOOLS}/misc/tables-NoahMP" 'tables' # new tables including Noah-MP stuff 
# if cycling
ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/setup${WRFSYS}.sh"
if [[ -n "${CYCLING}" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/run_cycle_${WRFQ}.sh"
	ln -sf "${WRFTOOLS}/Python/cycling.py"
	cp "${WRFTOOLS}/misc/namelists/stepfile.${CYCLING}" 'stepfile' 
	cp "${WRFTOOLS}/Scripts/${WRFSYS}/run_cycling_WRF.${WRFQ}" .
else
	cp "${WRFTOOLS}/Scripts/${WRFSYS}/run_test_WRF.${WRFQ}" .
fi
# WRF executable
ln -sf "${WRFEXE}"

## insert name and GHG emission scenario into run scripts
# name of experiment (and WRF dependency)
if [[ "${WPSSYS}" == "GPC" ]]; then
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WPS/" run_*_WPS.pbs
fi
if [[ "${WRFSYS}" == "GPC" ]]; then
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WRF/" run_*_WRF.pbs
	sed -i "/#PBS -W/ s/#PBS -W\s.*$/#PBS -W depend:afterok:${NAME}_WPS/" run_*_WRF.pbs
elif [[ "${WRFSYS}" == "TCS" ]]; then
	sed -i "/#\s*@\s*job_name/ s/#\s*@\s*job_name\s*=.*$/# @ job_name = ${NAME}_WRF/" run_*_WRF.ll
fi
# GHG emission scenario
sed -i "/export GHG/ s/export\sGHG=\'.*.'.*$/export GHG=\'${GHG}\' # GHG emission scenario set by setup script/" run_*_WRF.${WRFQ}

## prompt user to create data links
echo "Remainign tasks:"
echo " * review meta data and namelists"
echo " * edit run scripts, if necessary" 
