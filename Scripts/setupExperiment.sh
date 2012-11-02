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
ARSCRIPT='DEFAULT' # this is a dummy name...
# WPS and WRF executables
WPSSYS="GPC" # WPS
WRFSYS="GPC" # WRF
## some shortcuts for WRF/WPS settings
MAXDOM=2 # number of domains in WRF and WPS
FEEDBACK=0 # WRF nesting option: one-way=0 or two-way=1
## load configuration 
source xconfig.sh
# default archive script name (no $ARSCRIPT means no archiving)
if [[ "${ARSCRIPT}" == 'DEFAULT' ]] && [[ -n "${IO}" ]]; then ARSCRIPT="ar_wrfout_${IO}.pbs"; fi # always runs from GPC
# infer default $CASETYPE (can also set $CASETYPE in xconfig.sh)
if [[ -z "${CASETYPE}" ]]; then
  if [[ -n "${CYCLING}" ]]; then CASETYPE='cycling';
  else CASETYPE='test'; fi
fi
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
elif [[ "${WRFSYS}" == "P7" ]]; then
	GEOEXE=${GEOEXE:-"${WPSSRC}/P7-MPI/Clim-fineIO/O3/geogrid.exe"}
	WRFEXE=${WRFEXE:-"${WRFSRC}/P7-MPI/Clim-fineIO/O3NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "i7" ]]; then
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
if [[ "${WPSQ}" == "pbs" ]] || [[ "${WPSQ}" == "ll" ]]; then # if it has a queue system, it has to have a setup script...
	ln -sf "${WRFTOOLS}/Scripts/${WPSSYS}/setup_${WPSSYS}.sh"; fi
# if cycling
cp "${WRFTOOLS}/Scripts/${WPSSYS}/run_${CASETYPE}_WPS.${WPSQ}" .
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
if [[ "${WRFQ}" == "pbs" ]] || [[ "${WRFQ}" == "ll" ]]; then # if it has a queue system, it has to have a setup script...
	ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/setup_${WRFSYS}.sh"; fi
if [[ "${WRFQ}" == "ll" ]]; then
    ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/sleepCycle.sh"; fi
if [[ -n "${CYCLING}" ]]; then
	ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/run_cycle_${WRFQ}.sh"
	ln -sf "${WRFTOOLS}/Python/cycling.py"
	cp "${WRFTOOLS}/misc/stepfiles/stepfile.${CYCLING}" 'stepfile' 
fi
cp "${WRFTOOLS}/Scripts/${WRFSYS}/run_${CASETYPE}_WRF.${WRFQ}" .
# WRF executable
ln -sf "${WRFEXE}"

## insert name into run scripts
echo "Defining experiment name in run scripts:"
# name of experiment (and WRF dependency) depends on queue system
if [[ "${WPSQ}" == "pbs" ]]; then
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WPS/" "run_${CASETYPE}_WPS.${WPSQ}"
    echo "  run_${CASETYPE}_WPS.${WRFQ}"
fi
if [[ "${WRFQ}" == "pbs" ]]; then
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WRF/" "run_${CASETYPE}_WRF.${WRFQ}"
	sed -i "/#PBS -W/ s/#PBS -W\s.*$/#PBS -W depend:afterok:${NAME}_WPS/" "run_${CASETYPE}_WRF.${WRFQ}"
    echo "  run_${CASETYPE}_WRF.${WRFQ}"    
elif [[ "${WRFQ}" == "ll" ]]; then
	sed -i "/#\s*@\s*job_name/ s/#\s*@\s*job_name\s*=.*$/# @ job_name = ${NAME}_WRF/" "run_${CASETYPE}_WRF.${WRFQ}"
    echo "  run_${CASETYPE}_WRF.${WRFQ}"
    sed -i "/WPSSCRIPT/ s/WPSSCRIPT=.*$/WPSSCRIPT=\'run_${CASETYPE}_WPS.${WPSQ}\' # WPS run-scripts/" "sleepCycle.sh" # TCS sleeper script
    sed -i "/WRFSCRIPT/ s/WRFSCRIPT=.*$/WRFSCRIPT=\'run_${CASETYPE}_WRF.${WRFQ}\' # WRF run-scripts/" "sleepCycle.sh" # TCS sleeper script
else
    echo "  N/A"
fi
# run_cycle-script
if [[ -n "${CYCLING}" ]]; then
    sed -i "/WPSSCRIPT/ s/WPSSCRIPT=.*$/WPSSCRIPT=\'run_${CASETYPE}_WPS.${WPSQ}\' # WPS run-scripts/" "run_cycle_${WRFQ}.sh" # WPS run-script
    sed -i "/WRFSCRIPT/ s/WRFSCRIPT=.*$/WRFSCRIPT=\'run_${CASETYPE}_WRF.${WRFQ}\' # WRF run-scripts/" "run_cycle_${WRFQ}.sh" # WPS run-script
fi
# archive script
sed -i "/export ARSCRIPT/ s/export\sARSCRIPT=.*$/export ARSCRIPT=\'${ARSCRIPT}\' # archive script to be executed after WRF finishes/" "run_${CASETYPE}_WRF.${WRFQ}"
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
sed -i "/export GHG/ s/export\sGHG=.*$/export GHG=\'${GHG}\' # GHG emission scenario set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"

## shortcuts for some WRF/WPS options
# number of domains (WRF and WPS namelist!)
sed -i "/max_dom/ s/^\s*max_dom\s*=\s*.*$/ max_dom = ${MAXDOM}, ! this entry was edited by the setup script/" namelist.input namelist.wps
# nesting option
sed -i "/feedback/ s/^\s*feedback\s*=\s*.*$/ feedback = ${FEEDBACK}, ! this entry was edited by the setup script/" namelist.input

## finish up
# prompt user to create data links
echo
echo "Remaining tasks:"
echo " * review meta data and namelists"
echo " * edit run scripts, if necessary,"
echo "   e.g. adjust wallclock time"
echo
# count number of broken links
for FILE in * meta/* tables/*; do # need to list meta/ and table/ extra, because */ includes data links (e.g. atm/)
  if [[ ! -e $FILE ]]; then
    CNT=$(( CNT + 1 ))
    if (( CNT == 1 )); then
      echo " * fix broken links"
      echo
      echo "  Broken links:"
      echo
    fi
    ls -l "${FILE}"
  fi
done
if (( CNT > 0 )); then
  echo "   >>>   WARNING: there are ${CNT} broken links!!!   <<<   "
  echo
fi

echo
