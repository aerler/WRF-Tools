#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 04/10/2012 by Andre R. Erler
# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC

## TODO:
# * generate namelists in setup script
# * change name of experiment
# * handle GHG scenario in setup script, not in run-script
# * consider putting exec* scripts into PATH

## load configuration 
source xconfig.sh
# make run folder
# RUNDIR="${PWD}" in xconfig.sh 
mkdir -p "${RUNDIR}"

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
	ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/run_cycle_*.sh"
	ln -sf "${WRFTOOLS}/Python/cycling.py"
	cp "${WRFTOOLS}/misc/namelists/stepfile.${CYCLING}" 'stepfile' 
	cp "${WRFTOOLS}/Scripts/${WRFSYS}/run_cycling_WRF.*" .
else
	cp "${WRFTOOLS}/Scripts/${WRFSYS}/run_test_WRF.*" .
fi
# WRF executable
ln -sf "${WRFEXE}"

## prompt user to create data links
echo "Remainign tasks:"
echo " * review meta data and namelists"
echo " * edit run scripts, if necessary" 
