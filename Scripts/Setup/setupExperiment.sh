#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 18/10/2012 by Andre R. Erler

# environment variables: $MODEL_ROOT, $WPSSRC, $WRFSRC, $SCRATCH

set -e # abort if anything goes wrong

## functions

# function to change common variables in run-scripts
function RENAME () {
    # use global variables:
    local FILE="$1" # file name
    # infer queue system
    local Q="${FILE##*.}" # strip of everything before last '.' (and '.')
    # feedback
    echo "Defining experiment name in run script ${FILE}"
    ## queue dependent changes
    # WPS run-script
    if [[ "${FILE}" == *WPS* ]] && [[ "${WPSQ}" == "${Q}" ]]; then
	if [[ "${WPSQ}" == "pbs" ]]; then
	    sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WPS/" "${FILE}"
	else
	    sed -i "/export JOBNAME/ s+export\sJOBNAME=.*$+export JOBNAME=${NAME}_WPS  # job name (dummy variable, since there is no queue)+" "${FILE}"
	fi # $Q
    fi # if WPS
    # WRF run-script
    if [[ "${FILE}" == *WRF* ]] && [[ "${WRFQ}" == "${Q}" ]]; then
	if [[ "${WRFQ}" == "pbs" ]]; then
	    sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WRF/" "run_${CASETYPE}_WRF.${WRFQ}"
	    sed -i "/#PBS -W/ s/#PBS -W\s.*$/#PBS -W depend:afterok:${NAME}_WPS/" "${FILE}"
	elif [[ "${WRFQ}" == "ll" ]]; then
	    sed -i "/#\s*@\s*job_name/ s/#\s*@\s*job_name\s*=.*$/# @ job_name = ${NAME}_WRF/" "${FILE}"
	else
	    sed -i "/export JOBNAME/ s+export\sJOBNAME=.*$+export JOBNAME=${NAME}_WPS  # job name (dummy variable, since there is no queue)+" "${FILE}"
	fi # $Q
    fi # if WRF
    ## queue independent changes
    # WPS script
    sed -i "/WPSSCRIPT/ s/WPSSCRIPT=.*$/WPSSCRIPT=\'run_${CASETYPE}_WPS.${WPSQ}\' # WPS run-scripts/" "${FILE}" # WPS run-script
    # WRF script
    sed -i "/WRFSCRIPT/ s/WRFSCRIPT=.*$/WRFSCRIPT=\'run_${CASETYPE}_WRF.${WRFQ}\' # WRF run-scripts/" "${FILE}" # WPS run-script
    # script folder
    sed -i '/export SCRIPTDIR/ s+export\sSCRIPTDIR=.*$+export SCRIPTDIR="${INIDIR}/scripts/"  # location of component scripts (pre/post processing etc.)+' "${FILE}"
    # executable folder
    sed -i '/export BINDIR/ s+export\sBINDIR=.*$+export BINDIR="${INIDIR}/bin/"  # location of executables nd scripts (WPS and WRF)+' "${FILE}"
    # archive script
    sed -i "/export ARSCRIPT/ s/export\sARSCRIPT=.*$/export ARSCRIPT=\'${ARSCRIPT}\' # archive script to be executed in specified intervals/" "${FILE}"
    # archive interval
    sed -i "/export ARINTERVAL/ s/export\ARINTERVAL=.*$/export ARINTERVAL=\'${ARINTERVAL}\' # interval in which the archive script is to be executed/" "${FILE}"
} # fct. RENAME

## scenario definition section
# defaults (may be set or overwritten in xconfig.sh)
NAME='test'
RUNDIR="${PWD}"
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="monthly.1979-2009" # stepfile to be used (leave empty if not cycling)
# boundary data
DATADIR='' # root directory for data
DATATYPE='CESM' # boundary forcing type
## run configuration
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
# I/O and archiving
IO='fineIO' # this is used for namelist construction and archiving
ARSCRIPT='DEFAULT' # this is a dummy name...
ARINTERVAL='MONTHLY' # default: archive after every job
## WPS
WPSSYS='' # WPS - define in xconfig.sh
# other WPS configuration files
GEODATA="${PROJECT}/geog/" # location of geogrid data
## WRF
WRFSYS='' # WRF - define in xconfig.sh
POLARWRF=0 # PolarWRF switch
FLAKE=1 # use FLake
# some settings depend on the number of domains
MAXDOM=2 # number of domains in WRF and WPS

## load configuration
source xconfig.sh

# infer default $CASETYPE (can also set $CASETYPE in xconfig.sh)
if [[ -z "${CASETYPE}" ]]; then
  if [[ -n "${CYCLING}" ]]; then CASETYPE='cycling';
  else CASETYPE='test'; fi
fi

# boundary data definition for WPS
if [[ "${DATATYPE}" == 'CESM' ]]; then
  POPMAP=${POPMAP:-'map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc'} # ocean grid definition
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.CESM'}
else # WPS default
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.V3.4'}
fi # $DATATYPE

if [[ ${FLAKE} == 1 ]]; then
  GEOGRIDTBL=${GEOGRIDTBL:-'GEOGRID.TBL.FLAKE'}
else
  GEOGRIDTBL=${GEOGRIDTBL:-'GEOGRID.TBL.V3.4'}
fi # $FLAKE

# look up default configurations
if [ ${POLARWRF} == 1 ]; then
  WPSBLD="Clim-fineIO" # not yet polar...
  WRFBLD="Polar-Clim-fineIOv2"
else
  WPSBLD="Clim-fineIO"
  WRFBLD="Clim-fineIOv2"
fi # if PolarWRF

# default WPS and real executables
if [[ "${WPSSYS}" == "GPC" ]]; then
    WPSQ='pbs' # queue system
    METEXE=${METEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xSSSE3/metgrid.exe"}
    REALEXE=${REALEXE:-"${WRFSRC}/GPC-MPI/${WRFBLD}/O3xSSSE3/real.exe"}
elif [[ "${WPSSYS}" == "i7" ]]; then
    WPSQ='sh' # no queue system
    METEXE=${METEXE:-"${WPSSRC}/i7-MPI/${WPSBLD}/O3xHost/metgrid.exe"}
    REALEXE=${REALEXE:-"${WRFSRC}/i7-MPI/${WRFBLD}/O3xHostNC4/real.exe"}
fi

# default WRF and geogrid executables
if [[ "${WRFSYS}" == "GPC" ]]; then
    WRFQ='pbs' # queue system
    GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xHost/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/GPC-MPI/${WRFBLD}/O3xHostNC4/wrf.exe"}
elif [[ "${WRFSYS}" == "TCS" ]]; then
    WRFQ='ll' # queue system
    GEOEXE=${GEOEXE:-"${WPSSRC}/TCS-MPI/${WPSBLD}/O3/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/TCS-MPI/${WRFBLD}/O3NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "P7" ]]; then
    WRFQ='ll' # queue system
    GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xHost/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/P7-MPI/${WRFBLD}/O3pwr7NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "i7" ]]; then
    WRFQ='sh' # queue system
    GEOEXE=${GEOEXE:-"${WPSSRC}/i7-MPI/${WPSBLD}/O3xHost/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/i7-MPI/${WRFBLD}/O3xHostNC4/wrf.exe"}
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
export NOAH_MP
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
mkdir -p "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Setup/writeNamelists.sh"
mv writeNamelists.sh scripts/
./scripts/writeNamelists.sh
# number of domains (WRF and WPS namelist!)
sed -i "/max_dom/ s/^\s*max_dom\s*=\s*.*$/ max_dom = ${MAXDOM}, ! this entry was edited by the setup script/" namelist.input namelist.wps


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
# set correct path for geogrid data
echo "Setting path for geogrid data"
if [[ -n "${GEODATA}" ]]; then
  sed -i "/geog_data_path/ s+\s*geog_data_path\s*=\s*.*$+ geog_data_path = \'${GEODATA}\',+" namelist.wps
  echo "  ${GEODATA}"
else echo "WARNING: no geogrid path selected!"; fi


## link in WPS stuff
# WPS scripts
echo "Linking WPS scripts and executable (${WRFTOOLS})"
echo "  system: ${WPSSYS}, queue: ${WPSQ}"
# user scripts (in root folder)
cd "${RUNDIR}"
# WPS run script
cp "${WRFTOOLS}/Scripts/${WPSSYS}/run_${CASETYPE}_WPS.${WPSQ}" .
RENAME "run_${CASETYPE}_WPS.${WPSQ}"
# run-script components (go into folder 'scripts')
mkdir -p "${RUNDIR}/scripts/"
cd "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Common/execWPS.sh"
ln -sf "${WRFTOOLS}/Scripts/${WPSSYS}/setup_${WPSSYS}.sh" 'setup_machine.sh' # renaming
cd "${RUNDIR}"
# WPS/real executables (go into folder 'bin')
mkdir -p "${RUNDIR}/bin/"
cd "${RUNDIR}/bin/"
ln -sf "${WRFTOOLS}/Python/pyWPS.py"
ln -sf "${WRFTOOLS}/NCL/unccsm.ncl"
ln -sf "${WRFTOOLS}/bin/${WPSSYS}/unccsm.exe"
ln -sf "${GEOEXE}"
ln -sf "${METEXE}"
ln -sf "${REALEXE}"
cd "${RUNDIR}"

## link in WRF stuff
# WRF scripts
echo "Linking WRF scripts and executable (${WRFTOOLS})"
echo "  system: ${WRFSYS}, queue: ${WRFQ}"
# user scripts (go into root folder)
cd "${RUNDIR}"
if [[ -n "${CYCLING}" ]]; then
    cp "${WRFTOOLS}/misc/stepfiles/stepfile.${CYCLING}" 'stepfile'
    cp "${WRFTOOLS}/Scripts/${WRFSYS}/start_cycle_${WRFSYS}.sh" .
    RENAME "start_cycle_${WRFSYS}.sh"
fi # if cycling
if [[ "${WRFQ}" == "ll" ]]; then # because LL does not support dependencies
    cp "${WRFTOOLS}/Scripts/${WRFSYS}/sleepCycle.sh" .
    sleepCycle.sh
fi # if LL
# WRF run-script
cp "${WRFTOOLS}/Scripts/${WRFSYS}/run_${CASETYPE}_WRF.${WRFQ}" .
RENAME "run_${CASETYPE}_WRF.${WRFQ}"
# run-script component scripts (go into folder 'scripts')
mkdir -p "${RUNDIR}/scripts/"
cd "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Common/execWRF.sh"
ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/setup_${WRFSYS}.sh" 'setup_machine.sh' # renaming
if [[ -n "${CYCLING}" ]]; then
    ln -sf "${WRFTOOLS}/Scripts/Setup/setup_cycle.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/launchPreP.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/launchPostP.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/resubJob.sh"
    ln -sf "${WRFTOOLS}/Python/cycling.py"
fi # if cycling
cd "${RUNDIR}"
# WRF executable (go into folder 'bin')
mkdir -p "${RUNDIR}/bin/"
cd "${RUNDIR}/bin/"
ln -sf "${WRFEXE}"
cd "${RUNDIR}"


## setup archiving
# default archive script name (no $ARSCRIPT means no archiving)
if [[ "${ARSCRIPT}" == 'DEFAULT' ]] && [[ -n "${IO}" ]]; then ARSCRIPT="ar_wrfout_${IO}.pbs"; fi
# prepare archive script
if [[ -n "${ARSCRIPT}" ]]; then
    # copy script and change job name
    cp -f "${WRFTOOLS}/Scripts/HPSS/${ARSCRIPT}" .
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_ar/" "${ARSCRIPT}"
    ls "${ARSCRIPT}"
    # set appropriate dataset variable for number of domains
    if [[ ${MAXDOM} == 1 ]]; then
	sed -i "/DATASET/ s/DATASET=\${DATASET:-.*}\s.*$/DATASET=\${DATASET:-'FULL_D1'} # default dataset: everything (one domain)/" "${ARSCRIPT}"
    elif [[ ${MAXDOM} == 2 ]]; then
	sed -i "/DATASET/ s/DATASET=\${DATASET:-.*}\s.*$/DATASET=\${DATASET:-'FULL_D12'} # default dataset: everything (two domains)/" "${ARSCRIPT}"
    else
      echo
      echo "WARNING: Number of domains (${MAXDOM}) incompatible with available archiving options."
      echo
    fi # $MAXDOM
fi # $ARSCRIPT


## copy data tables for selected physics options
# radiation scheme
RAD=$(sed -n '/ra_lw_physics/ s/^\s*ra_lw_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
echo "Determining radiation scheme from namelist: RAD=${RAD}"
# write default RAD into job script ('sed' sometimes fails on TCS...)
sed -i "/export RAD/ s/export\sRAD=.*$/export RAD=\'${RAD}\' # radiation scheme set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"
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
# write default LSM into job script ('sed' sometimes fails on TCS...)
sed -i "/export LSM/ s/export\sLSM=.*$/export LSM=\'${LSM}\' # land surface scheme set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"
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
if [[ ${LSM} == 4 ]]; then # NoahMP
  TABLES="${WRFTOOLS}/misc/tables-NoahMP/"
  echo "Linking Noah-MP tables: ${TABLES}"
elif [[ ${POLARWRF} == 1 ]]; then # PolarWRF
  TABLES="${WRFTOOLS}/misc/tables-PolarWRF/"
  echo "Linking PolarWRF tables: ${TABLES}"
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
