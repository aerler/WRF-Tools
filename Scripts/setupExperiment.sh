#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 18/10/2012 by Andre R. Erler

# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC, $SCRATCH

set -e # abort if anything goes wrong

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
	METEXE=${METEXE:-"${WPSSRC}/GPC-MPI/Clim-fineIO/O3xHost/metgrid.exe"}
	REALEXE=${REALEXE:-"${WRFSRC}/GPC-MPI/Clim-fineIO/O3xHost/real.exe"}
elif [[ "${WPSSYS}" == "GPC-lm" ]]; then
	METEXE=${METEXE:-"${WPSSRC}/GPC-MPI/Clim-fineIO/O3xSSS3/metgrid.exe"}
	REALEXE=${REALEXE:-"${WRFSRC}/GPC-MPI/Clim-fineIO/O3xSSS3/real.exe"}
elif [[ "${WPSSYS}" == "i7" ]]; then
	METEXE=${METEXE:-"${WPSSRC}/i7-MPI/Clim-fineIO/O3xHost/metgrid.exe"}
	REALEXE=${REALEXE:-"${WRFSRC}/i7-MPI/Clim-fineIO/O3xHost/real.exe"}
fi
if [[ "${WRFSYS}" == "GPC" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/Clim-fineIO/O3xHost/geogrid.exe"} 
	WRFEXE=${WRFEXE:-"${WRFSRC}/GPC-MPI/Clim-fineIO/O3xHostNC4/wrf.exe"}
elif [[ "${WRFSYS}" == "TCS" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/TCS-MPI/Clim-fineIO/O3/geogrid.exe"}
	WRFEXE=${WRFEXE:-"${WRFSRC}/TCS-MPI/Clim-fineIO/O3NC4/wrf.exe"}
elif [[ "${WPSSYS}" == "i7" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/i7-MPI/Clim-fineIO/O3xHost/geogrid.exe"}
	WRFEXE=${WRFEXE:-"${WRFSRC}/i7-MPI/Clim-fineIO/O3xHostNC4/wrf.exe"}
fi
# create run folder
echo
echo "   Creating Root Directory for Experiment ${NAME}"
echo
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
echo "Creating WRF and WPS namelists (using ${WRFTOOLS}/Scripts/writeNamelists.sh)"
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/writeNamelists.sh" 
./writeNamelists.sh
rm writeNamelists.sh

## link data and meta data
# link meta data
echo "Linking WPS meta data and tables (${WRFTOOLS}/misc/data/)"
mkdir -p "${RUNDIR}/meta"
cd "${RUNDIR}/meta"
ln -sf "${WRFTOOLS}/misc/data/${POPMAP}"  
ln -sf "${WRFTOOLS}/misc/data/${GEOGRIDTBL}" 'GEOGRID.TBL'
ln -sf "${WRFTOOLS}/misc/data/${METGRIDTBL}" 'METGRID.TBL'
#ln -sf "${WRFTOOLS}/misc/data/${NCL}" 'setup.ncl'
# link boundary data
echo "Linking boundary data: ${DATADIR}"
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
echo "Linking WPS scripts and executable (${WRFTOOLS})"
echo "  system: ${WPSSYS}, queue: ${WPSQ}"
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
echo "Linking WRF scripts and executable (${WRFTOOLS})"
echo "  system: ${WRFSYS}, queue: ${WRFQ}"
cd "${RUNDIR}"
ln -sf "${WRFTOOLS}/Scripts/prepWorkDir.sh"
ln -sf "${WRFTOOLS}/Scripts/execWRF.sh"
#ln -sf "${WRFTOOLS}/misc/tables" # WRF default tables
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

## insert name into run scripts
echo "Defining experiment name in run scripts:"
# name of experiment (and WRF dependency)
if [[ "${WPSSYS}" == "GPC"* ]]; then
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WPS/" run_*_WPS.pbs
    ls run_*_WPS.pbs
fi
if [[ "${WRFSYS}" == "GPC" ]]; then
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WRF/" run_*_WRF.pbs
	sed -i "/#PBS -W/ s/#PBS -W\s.*$/#PBS -W depend:afterok:${NAME}_WPS/" run_*_WRF.pbs
    ls run_*_WRF.pbs
elif [[ "${WRFSYS}" == "TCS" ]]; then
	sed -i "/#\s*@\s*job_name/ s/#\s*@\s*job_name\s*=.*$/# @ job_name = ${NAME}_WRF/" run_*_WRF.ll
    ls run_*_WRF.ll
else
    echo "  N/A"
fi
# archive script
sed -i "/export ARSCRIPT/ s/export\sARSCRIPT=.*$/export ARSCRIPT=\'${ARSCRIPT}\' # archive script to be executed after WRF finishes/" run_*_WRF.${WRFQ}
if [[ -n "${ARSCRIPT}" ]]; then
    cp -f "${WRFTOOLS}/Scripts/HPSS/${ARSCRIPT}" .
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_ar/" "${ARSCRIPT}"
    ls "${ARSCRIPT}"
fi

## set correct path for geogrid data
echo "Setting path for geogrid data"
if [[ "${WPSSYS}" == "GPC"* ]] || [[ "${WPSSYS}" == "P7" ]]; then 
	sed -i "/geog_data_path/ s+\s*geog_data_path\s*=\s*.*$+ geog_data_path = \'${SCRATCH}/data/geog/\',+" namelist.wps
    echo "  ${SCRATCH}/data/geog/"
elif [[ "${WPSSYS}" == "i7" ]]; then
	sed -i "/geog_data_path/ s+\s*geog_data_path\s*=\s*.*$+ geog_data_path = \'/media/data/DATA/WRF/geog/\',+" namelist.wps
    echo '  /media/data/DATA/WRF/geog/'
else
    echo "WARNING: no geogrid path selected!"
fi

## copy data tables for selected physics options
# radiation scheme
RAD=$(sed -n '/ra_lw_physics/ s/^\s*ra_lw_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
echo "Determining radiation scheme from namelist: RAD=${RAD}"
# select scheme and print confirmation
if [[ ${RAD} == 1 ]]; then
    echo "  Using RRTM radiation scheme."
    RADTAB="RRTM_DATA RRTM_DATA_DBL"
elif [[ ${RAD} == 3 ]]; then
    echo "  Using CAM radiation scheme."
    RADTAB="CAM_ABS_DATA CAM_AEROPT_DATA ozone.formatted ozone_lat.formatted ozone_plev.formatted"
    #RADTAB="${RADTAB} CAMtr_volume_mixing_ratio" # this is handled below
elif [[ ${RAD} == 4 ]]; then
    echo "  Using RRTMG radiation scheme."
    RADTAB="RRTMG_LW_DATA RRTMG_LW_DATA_DBL RRTMG_SW_DATA RRTMG_SW_DATA_DBL"
else
    echo 'WARNING: no radiation scheme selected!'
fi
# land-surface scheme
LSM=$(sed -n '/sf_surface_physics/ s/^\s*sf_surface_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
echo "Determining land-surface scheme from namelist: LSM=${LSM}"
# select scheme and print confirmation
if [[ ${LSM} == 1 ]]; then
    echo "  Using diffusive land-surface scheme."
    LSMTAB="LANDUSE.TBL"
elif [[ ${LSM} == 2 ]]; then
    echo "  Using Noah land-surface scheme."
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
elif [[ ${LSM} == 3 ]]; then
    echo "  Using RUC land-surface scheme."
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL"
elif [[ ${LSM} == 4 ]]; then
    echo "  Using Noah-MP land-surface scheme."
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL MPTABLE.TBL"
else
    echo 'WARNING: no land-surface model selected!'
fi
# determine tables folder
if [[ ${LSM} == 4 ]]; then
  TABLES="${WRFTOOLS}/misc/tables-NoahMP/"
  echo "Linking Noah-MP tables: ${TABLES}"
else
  TABLES="${WRFTOOLS}/misc/tables/"
  echo "Linking default tables: ${TABLES}"
fi
# link appropriate tables for physics options
mkdir -p "${RUNDIR}/tables/"
cd "${RUNDIR}/tables/"
for TBL in ${RADTAB} ${LSMTAB}; do
    ln -sf "${TABLES}/${TBL}"
done
# copy data file for emission scenario, if applicable
if [[ -n "${GHG}" ]]; then # only if $GHG is defined!
    if [[ ${RAD} == 'CAM' ]] || [[ ${RAD} == 3 ]]; then
        echo "GHG emission scenario: ${GHG}"
        ln -sf "${TABLES}/CAMtr_volume_mixing_ratio.${GHG}" # do not clip scenario extension (yet)
    else
        echo "WARNING: variable GHG emission scenarios not available with the selected ${RAD} scheme!"
        unset GHG # for later use
    fi
fi
cd "${RUNDIR}" # return to run directory
# GHG emission scenario (if no GHG scenario is selected, the variable will be empty)
sed -i "/export GHG/ s/export\sGHG=.*$/export GHG=\'${GHG}\' # GHG emission scenario set by setup script/" run_*_WRF.${WRFQ}

## finish up
# prompt user to create data links
echo
echo "Remaining tasks:"
echo " * review meta data and namelists"
echo " * edit run scripts, if necessary"
# count number of broken links
for FILE in * meta/* tables/*; do
  if [[ ! -e $FILE ]]; then
    CNT=$(( CNT + 1 ))
    if (( CNT == 1 )); then
      echo " * fix broken links"
      echo
      echo "  Broken links:"
    fi
    ls -l "${FILE}"
  fi
done
if (( CNT > 0 )); then
  echo
  echo "   >>>   WARNING: there are ${CNT} broken links!!!   <<<   "
  echo
fi

