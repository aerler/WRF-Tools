#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 04/10/2012 by Andre R. Erler
# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC
set -e # abort if anything goes wrong

## TODO:
# * handle data tables in setup, not in execution script?
# * put machine-independent execution scripts into PATH?

## defaults (may be set or overwritten in xconfig.sh)
# folders
RUNDIR="${PWD}"
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
ARSCRIPT='ar_wrfout.pbs'
# WPS and WRF executables
WPSSYS="GPC" # WPS
WRFSYS="GPC" # WRF
## load configuration 
source xconfig.sh
# look up default configurations
if [[ "${WPSSYS}" == "GPC" ]]; then 
	METEXE=${METEXE:-"${WPSSRC}/GPC-MPI/Clim-fullIO/O3xHost/metgrid.exe"}
	REALEXE=${REALEXE:-"${WRFSRC}/GPC-MPI/Clim-fineIO/O3xHost/real.exe"}
elif [[ "${WPSSYS}" == "GPC-lm" ]]; then
	METEXE=${METEXE:-"${WPSSRC}/GPC-MPI/Clim-fullIO/O3xSSS3/metgrid.exe"}
	REALEXE=${REALEXE:-"${WRFSRC}/GPC-MPI/Clim-fineIO/O3xSSS3/real.exe"}
elif [[ "${WPSSYS}" == "i7" ]]; then
	METEXE=${METEXE:-"${WPSSRC}/i7-MPI/Clim-reducedIO/O3xHost/metgrid.exe"}
	REALEXE=${REALEXE:-"${WRFSRC}/i7-MPI/Clim-reducedIO/O3xHost/real.exe"}
fi
if [[ "${WRFSYS}" == "GPC" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/Clim-fullIO/O3xHost/geogrid.exe"} 
	WRFEXE=${WRFEXE:-"${WRFSRC}/GPC-MPI/Clim-fineIO/O3xHostNC4/wrf.exe"}
elif [[ "${WRFSYS}" == "TCS" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/TCS-MPI/Clim-fullIO/O3/geogrid.exe"}
	WRFEXE=${WRFEXE:-"${WRFSRC}/TCS-MPI/Clim-fineIO/O3NC4/wrf.exe"}
elif [[ "${WPSSYS}" == "i7" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/i7-MPI/Clim-reducedIO/O3xHost/geogrid.exe"}
	WRFEXE=${WRFEXE:-"${WRFSRC}/i7-MPI/Clim-fineIO/O3xHostNC4/wrf.exe"}
fi
# create run folder 
mkdir -p "${RUNDIR}"

## create namelist files
# export relevant variables so that writeNamelist.sh can read them
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
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/writeNamelists.sh" 
./writeNamelists.sh
rm writeNamelists.sh

## link data and meta data
# link meta data
mkdir -p "${RUNDIR}/meta"
cd "${RUNDIR}/meta"
ln -sf "${WRFTOOLS}/misc/data/${POPMAP}"  
ln -sf "${WRFTOOLS}/misc/data/${GEOGRIDTBL}" 'GEOGRID.TBL'
ln -sf "${WRFTOOLS}/misc/data/${METGRIDTBL}" 'METGRID.TBL'
#ln -sf "${WRFTOOLS}/misc/data/${NCL}" 'setup.ncl'
# link boundary data
cd "${RUNDIR}"
rm -f 'atm' 'lnd' 'ice' # remove old links
ln -s "${DATADIR}/atm/hist/" 'atm' # atmosphere
ln -s "${DATADIR}/lnd/hist/" 'lnd' # land surface
ln -s "${DATADIR}/ice/hist/" 'ice' # sea ice

## link in WPS stuff
# queue system
if [[ "${WPSSYS}" == "GPC"* ]]; then 
	WPSQ='pbs' # GPC standard and largemem nodes
elif [[ "${WPSSYS}" == "P7" ]]; then
	WPSQ='ll'
else
	WPSQ='sh' # just a shell script on local system
fi
# WPS scripts
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWPS.sh"
ln -sf "${WRFTOOLS}/Python/pyWPS.py"
ln -sf "${WRFTOOLS}/NCL/unccsm.ncl"
# platform dependent stuff
ln -sf "${WRFTOOLS}/bin/${WPSSYS}/unccsm.exe"
if [[ "${WPSSYS}" == "GPC"* ]] || [[ "${WPSSYS}" == "P7" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/${WPSSYS}/setup_${WPSSYS}.sh"; fi
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
else
	WRFQ='sh' # just a shell script on local system
fi
# WRF scripts
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWRF.sh"
ln -sf "${WRFTOOLS}/misc/tables" # WRF default tables
#ln -sf "${WRFTOOLS}/misc/tables-NoahMP" 'tables' # new tables including Noah-MP stuff 
# if cycling
if [[ "${WRFSYS}" == "GPC" ]] || [[ "${WRFSYS}" == "TCS" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/setup_${WRFSYS}.sh"; fi
if [[ "${WRFSYS}" == "TCS" ]]; then
    ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/sleepCycle.sh"; fi
if [[ -n "${CYCLING}" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/run_cycle_${WRFQ}.sh"
	ln -sf "${WRFTOOLS}/Python/cycling.py"
	cp "${WRFTOOLS}/misc/stepfiles/stepfile.${CYCLING}" 'stepfile' 
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
# archive script
sed -i "/export ARSCRIPT/ s/export\sARSCRIPT=.*$/export ARSCRIPT=\'${ARSCRIPT}\' # archive script to be executed after WRF finishes/" run_*_WRF.${WRFQ}
if [[ -n "${ARSCRIPT}" ]]; then
    cp -f "${WRFTOOLS}/Scripts/HPSS/${ARSCRIPT}" .
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_ar/" "${ARSCRIPT}"
fi
# GHG emission scenario
sed -i "/export GHG/ s/export\sGHG=.*$/export GHG=\'${GHG}\' # GHG emission scenario set by setup script/" run_*_WRF.${WRFQ}

## set correct path for geogrid data
if [[ "${WPSSYS}" == "GPC"* ]] || [[ "${WPSSYS}" == "P7" ]]; then 
	sed -i "/geog_data_path/ s+\s*geog_data_path\s*=\s*.*$+ geog_data_path = \'/scratch/p/peltier/aerler/data/geog/\',+" namelist.wps
elif [[ "${WPSSYS}" == "i7" ]]; then
	sed -i "/geog_data_path/ s+\s*geog_data_path\s*=\s*.*$+ geog_data_path = \'/media/data/DATA/WRF/geog/\',+" namelist.wps
fi

## prompt user to create data links
echo "Remainign tasks:"
echo " * review meta data and namelists"
echo " * edit run scripts, if necessary" 
