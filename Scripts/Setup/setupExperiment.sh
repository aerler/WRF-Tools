#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 11/06/2013 by Andre R. Erler

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
	    sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WPS/" "${FILE}" # name
	    sed -i "/#PBS -l/ s/#PBS -l nodes=.*:\(.*\)$/#PBS -l nodes=1:\1/" "${FILE}" # nodes (WPS only runs on one node)
	    sed -i "/#PBS -l/ s/#PBS -l walltime=.*$/#PBS -l walltime=${WPSWCT}/" "${FILE}" # wallclock time	    
	else
	    sed -i "/export JOBNAME/ s+export\sJOBNAME=.*$+export JOBNAME=${NAME}_WPS  # job name (dummy variable, since there is no queue)+" "${FILE}" # name
	fi # $Q
    fi # if WPS
    # WRF run-script
    if [[ "${FILE}" == *WRF* ]] && [[ "${WRFQ}" == "${Q}" ]]; then
	if [[ "${WRFQ}" == "pbs" ]]; then
	    sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_WRF/" "run_${CASETYPE}_WRF.${WRFQ}" # experiment name
	    sed -i "/#PBS -W/ s/#PBS -W\s.*$/#PBS -W depend:afterok:${NAME}_WPS/" "${FILE}" # dependency on WPS
	    sed -i "/#PBS -l/ s/#PBS -l nodes=.*:\(.*\)$/#PBS -l nodes=${WRFNODES}:\1/" "${FILE}" # number of nodes
	    sed -i "/#PBS -l/ s/#PBS -l walltime=.*$/#PBS -l walltime=${WRFWCT}/" "${FILE}" # wallclock time
	    sed -i "/qsub/ s/qsub ${WRFSCRIPT} -v NEXTSTEP=*\s-W*$/qsub ${WRFSCRIPT} -v NEXTSTEP=*\s-W\s${NAME}_WPS/" "${FILE}" # dependency
	elif [[ "${WRFQ}" == "sge" ]]; then
	    sed -i "/#$ -N/ s/#$ -N\s.*$/#$ -N ${NAME}_WRF/" "run_${CASETYPE}_WRF.${WRFQ}" # experiment name
# 	    sed -i "/#PBS -W/ s/#PBS -W\s.*$/#PBS -W depend:afterok:${NAME}_WPS/" "${FILE}" # dependency on WPS
	    sed -i "/#$ -pe/ s/#$ -pe .*$/#$ -pe mpich $((WRFNODES*16))/" "${FILE}" # number of MPI tasks
	    sed -i "/#$ -l/ s/#$ -l h_rt=.*$/#$ -l h_rt=${WRFWCT}/" "${FILE}" # wallclock time
	elif [[ "${WRFQ}" == "ll" ]]; then
	    sed -i "/#\s*@\s*job_name/ s/#\s*@\s*job_name\s*=.*$/# @ job_name = ${NAME}_WRF/" "${FILE}" # experiment name
	    sed -i "/#\s*@\s*node/ s/#\s*@\s*node\s*=.*$/# @ node = ${WRFNODES}/" "${FILE}" # number of nodes
	    sed -i "/#\s*@\s*wall_clock_limit/ s/#\s*@\s*wall_clock_limit\s*=.*$/# @ wall_clock_limit = ${WRFWCT}/" "${FILE}" # wallclock time
	else
	    sed -i "/export JOBNAME/ s+export\sJOBNAME=.*$+export JOBNAME=${NAME}_WRF # job name (dummy variable, since there is no queue)+" "${FILE}" # name
	    sed -i "/export TASKS/ s+export\sTASKS=.*$+export TASKS=${WRFNODES} # number of MPI tasks+" "${FILE}" # number of tasks (instead of nodes...)
	fi # $Q
    fi # if WRF
    ## queue independent changes
    # WRF script
    sed -i "/WRFSCRIPT/ s/WRFSCRIPT=.*$/WRFSCRIPT=\'run_${CASETYPE}_WRF.${WRFQ}\' # WRF run-scripts/" "${FILE}" # WPS run-script
    # WPS script
    sed -i "/WPSSCRIPT/ s/WPSSCRIPT=.*$/WPSSCRIPT=\'run_${CASETYPE}_WPS.${WPSQ}\' # WPS run-scripts/" "${FILE}" # WPS run-script
    # script folder
    sed -i '/WRFOUT/ s+WRFOUT=.*$+WRFOUT="${INIDIR}/wrfout/"  # WRF output folder+' "${FILE}"
    # WRF wallclock time limit
    sed -i "/WRFWCT/ s/WRFWCT=.*$/WRFWCT=\'${WRFWCT}\' # WRF wallclock time/" "${FILE}" # used for queue time estimate
    # number of WRF nodes on given system
    sed -i "/NODES/ s/NODES=.*$/NODES=${WRFNODES} # number of nodes/" "${FILE}" # use for TCS setup
    # WPS wallclock time limit
    sed -i "/WPSWCT/ s/WPSWCT=.*$/WPSWCT=\'${WPSWCT}\' # WPS wallclock time/" "${FILE}" # used for queue time estimate
    # script folder
    sed -i '/SCRIPTDIR/ s+SCRIPTDIR=.*$+SCRIPTDIR="${INIDIR}/scripts/"  # location of component scripts (pre/post processing etc.)+' "${FILE}"
    # executable folder
    sed -i '/BINDIR/ s+BINDIR=.*$+BINDIR="${INIDIR}/bin/"  # location of executables nd scripts (WPS and WRF)+' "${FILE}"
    # archive script
    sed -i "/ARSCRIPT/ s/ARSCRIPT=.*$/ARSCRIPT=\'${ARSCRIPT}\' # archive script to be executed in specified intervals/" "${FILE}"
    # archive interval
    sed -i "/ARINTERVAL/ s/ARINTERVAL=.*$/ARINTERVAL=\'${ARINTERVAL}\' # interval in which the archive script is to be executed/" "${FILE}"
    # type of initial and boundary focing  data (mainly for WPS)
    sed -i "/DATATYPE/ s/DATATYPE=.*$/DATATYPE=\'${DATATYPE}\' # type of initial and boundary focing  data /" "${FILE}"
} # fct. RENAME


## scenario definition section
# defaults (may be set or overwritten in xconfig.sh)
NAME='test'
RUNDIR="${PWD}" # experiment root
WRFOUT="${RUNDIR}/wrfout/" # folder to collect output data
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="monthly.1979-2009" # stepfile to be used (leave empty if not cycling)
# boundary data
DATADIR='' # root directory for data
DATATYPE='CESM' # boundary forcing type
## run configuration
WRFROOT="${HOME}/WRFV3.4/"
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
# I/O and archiving
IO='fineIO' # this is used for namelist construction and archiving
ARSCRIPT='DEFAULT' # this is a dummy name...
ARINTERVAL='MONTHLY' # default: archive after every job
## WPS
WPSSYS='' # WPS - define in xconfig.sh
# other WPS configuration files
GEODATA="/project/p/peltier/WRF/geog/" # location of geogrid data
## WRF
WRFSYS='' # WRF - define in xconfig.sh
POLARWRF=0 # PolarWRF switch
FLAKE=1 # use FLake
# some settings depend on the number of domains
MAXDOM=2 # number of domains in WRF and WPS

## load configuration file
source xconfig.sh

## fix default settings

# WPS defaults
SHARE=${SHARE:-'arw'}
METGRID=${METGRID:-'pywps'}

# infer default $CASETYPE (can also set $CASETYPE in xconfig.sh)
if [[ -z "${CASETYPE}" ]]; then
  if [[ -n "${CYCLING}" ]]; then CASETYPE='cycling';
  else CASETYPE='test'; fi
fi

# default archive script name (no $ARSCRIPT means no archiving)
if [[ "${ARSCRIPT}" == 'DEFAULT' ]] && [[ -n "${IO}" ]]
    then ARSCRIPT="ar_wrfout_${IO}.pbs"; fi

# boundary data definition for WPS
if [[ "${DATATYPE}" == 'CESM' ]]; then
  POPMAP=${POPMAP:-'map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc'} # ocean grid definition
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.CESM'}
# elif [[ "${DATATYPE}" == 'CCSM' ]]; then
#   POPMAP=${POPMAP:-''} # ocean grid definition
#   METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.CCSM'}
elif [[ "${DATATYPE}" == 'CFSR' ]]; then
  VTABLE_PLEV=${VTABLE_PLEV:-'Vtable.CFSR_press_pgbh06'}
  VTABLE_SRFC=${VTABLE_SRFC:-'Vtable.CFSR_sfc_flxf06'}
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.ARW'}
else # WPS default
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.ARW'}
fi # $DATATYPE

if [[ ${FLAKE} == 1 ]]; then
  GEOGRIDTBL=${GEOGRIDTBL:-'GEOGRID.TBL.FLAKE'}
else
  GEOGRIDTBL=${GEOGRIDTBL:-'GEOGRID.TBL.ARW'}
fi # $FLAKE

# figure out WRF and WPS build
WPSBLD=${WPSBLD:-"Clim-fineIOv2"} # there is basically only one build...
# but there are many versions of WRF...
if [[ -z "$WRFBLD" ]]; then
  WRFBLD="${IO}v3" # current I/O version
  # GCM or reanalysis
  if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]]; then
    WRFBLD="Clim-${WRFBLD}" # variable GHG scenarios and no leap-years
  elif [[ "${DATATYPE}" == 'CFSR' ]]; then
    WRFBLD="ReA-${WRFBLD}" # variable GHG scenarios with leap-years
  else
    WRFBLD="Default-${WRFBLD}" # standard WRF build
  fi # $DATATYPE
  # Standard or PolarWRF
  if [ ${POLARWRF} == 1 ]; then
  #   WPSBLD="Clim-fineIO" # not yet polar...
    WRFBLD="Polar-${WRFBLD}"
  fi # if PolarWRF
fi # if $WRFBLD

# source folders (depending on $WRFROOT; can be set in xconfig.sh)
WPSSRC=${WPSSRC:-"${WRFROOT}/WPS/"}
WRFSRC=${WRFSRC:-"${WRFROOT}/WRFV3/"}

# default WPS and real executables
if [[ "${WPSSYS}" == "GPC" ]]; then
    WPSQ='pbs' # queue system
    WPSWCT=${WPSWCT:-'01:00:00'} # WPS wallclock time
    METEXE=${METEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xSSSE3/metgrid.exe"}
    REALEXE=${REALEXE:-"${WRFSRC}/GPC-MPI/${WRFBLD}/O3xSSSE3/real.exe"}
    UNGRIBEXE=${UNGRIBEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xSSSE3/ungrib.exe"}
elif [[ "${WPSSYS}" == "Rocks" ]]; then
    WPSQ='sh' # no queue system
    WPSWCT=${WPSWCT:-'01:00:00'} # WPS wallclock time
    METEXE=${METEXE:-"${WPSSRC}/Rocks-MPI/${WPSBLD}/O3xSSE42NC4Grb2/metgrid.exe"}
    REALEXE=${REALEXE:-"${WRFSRC}/Rocks-MPI/${WRFBLD}/O3xSSE42NC4/real.exe"}
    UNGRIBEXE=${UNGRIBEXE:-"${WPSSRC}/Rocks-MPI/${WPSBLD}/O3xSSE42NC4Grb2/ungrib.exe"}
elif [[ "${WPSSYS}" == "Bugaboo" ]]; then
    WPSQ='pbs' # queue system
    WPSWCT=${WPSWCT:-'02:00:00'} # WPS wallclock time
    METEXE=${METEXE:-"${WPSSRC}/Bugaboo-MPI/${WPSBLD}/O3xSSE42NC4/metgrid.exe"}
    REALEXE=${REALEXE:-"${WRFSRC}/Bugaboo-MPI/${WRFBLD}/O3xSSE42NC4/real.exe"}
    UNGRIBEXE=${UNGRIBEXE:-"${WPSSRC}/Bugaboo-MPI/${WPSBLD}/O3xSSE42NC4/ungrib.exe"}
elif [[ "${WPSSYS}" == "i7" ]]; then
    WPSQ='sh' # no queue system
    WPSWCT=${WPSWCT:-'0:00:00'} # WPS wallclock time
    METEXE=${METEXE:-"${WPSSRC}/i7-MPI/${WPSBLD}/O3xSSE42/metgrid.exe"}
    REALEXE=${REALEXE:-"${WRFSRC}/i7-MPI/${WRFBLD}/O3xSSE42NC4/real.exe"}
    UNGRIBEXE=${UNGRIBEXE:-"${WPSSRC}/i7-MPI/${WPSBLD}/O3xSSE42/ungrib.exe"}
fi

# default WRF and geogrid executables
if [[ "${WRFSYS}" == "GPC" ]]; then
    WRFQ='pbs' # queue system
    WRFWCT=${WRFWCT:-'06:00:00'}; WRFNODES=${WRFNODES:-16} # WRF resource config on GPC
    GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xSSSE3/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/GPC-MPI/${WRFBLD}/O3xSSE42NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "TCS" ]]; then
    WRFQ='ll' # queue system
    WRFWCT=${WRFWCT:-'06:00:00'}; WRFNODES=${WRFNODES:-4} # WRF resource config o TCS
    GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xSSSE3/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/TCS-MPI/${WRFBLD}/O3NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "P7" ]]; then
    WRFQ='ll' # queue system
    WRFWCT=${WRFWCT:-'15:00:00'}; WRFNODES=${WRFNODES:-1} # WRF resource config on P7
    GEOEXE=${GEOEXE:-"${WPSSRC}/GPC-MPI/${WPSBLD}/O3xSSSE3/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/P7-MPI/${WRFBLD}/O3NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "Rocks" ]]; then
    WRFQ='sge' # queue system
    WRFWCT=${WRFWCT:-'4:00:00'}; WRFNODES=${WRFNODES:-1} # WRF resource config on Rocks
    GEOEXE=${GEOEXE:-"${WPSSRC}/Rocks-MPI/${WPSBLD}/O3xSSE42NC4Grb2/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/Rocks-MPI/${WRFBLD}/O3xSSE42NC4/wrf.exe"}
elif [[ "${WRFSYS}" == "Bugaboo" ]]; then
    WRFQ='pbs' # queue system
    WRFWCT=${WRFWCT:-'12:00:00'}; WRFNODES=${WRFNODES:-1} # Bugaboo allocates cores, not nodes!
    GEOEXE=${GEOEXE:-"${WPSSRC}/Bugaboo-MPI/${WPSBLD}/O3xSSE42NC4/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/Bugaboo-MPI/${WRFBLD}/O3xSSE42NC4/wrf.exe"}    
elif [[ "${WRFSYS}" == "i7" ]]; then
    WRFQ='sh' # queue system
    WRFWCT=${WRFWCT:-'0:00:00'}; WRFNODES=${WRFNODES:-1} # WRF resource config on i7
    GEOEXE=${GEOEXE:-"${WPSSRC}/i7-MPI/${WPSBLD}/O3xSSE42/geogrid.exe"}
    WRFEXE=${WRFEXE:-"${WRFSRC}/i7-MPI/${WRFBLD}/O3xSSE42NC4/wrf.exe"}
fi

## ***                                            ***
## ***   now we actually start doing something!   ***
## ***                                            ***

# create run folder
echo
echo "   Creating Root Directory for Experiment ${NAME}"
echo
mkdir -p "${RUNDIR}"

# backup existing files
echo 'Backing-up existing files (moved to folder "backup/")'
echo
if [[ -e 'backup' ]]; then mv 'backup' 'backup_backup'; fi # because things can go wrong during backup...
mkdir -p 'backup'
eval $( cp -df --preserve=all * 'backup/' &> /dev/null ) # trap this error and hide output
eval $( cp -dRf --preserve=all 'scripts' 'bin' 'meta' 'tables' 'backup/' &> /dev/null ) # trap this error and hide output (don't append '/' so that links to folders are also removed)
# N.B.: the eval $() combination purposely suppresses exit codes, so that errors are not handled correctly
if [[ -e 'backup/xconfig.sh' && -e 'backup/setupExperiment.sh' ]]
  then # presumably everything went OK, if these two are in the backup folder
    eval $( rm -f *.sh *.pbs *.ll &> /dev/null ) # delete scripts
    eval $( rm -rf 'scripts' 'bin' 'meta' 'tables' &> /dev/null ) # delete script and data folders
    # N.B.: don't append '/' so that links to folders are also removed
    cp -P 'backup/setupExperiment.sh' 'backup/xconfig.sh' .
    rm -rf 'backup_backup/' # remove backup of backup, because we have a new backup
  else echo 'ERROR: backup failed - aborting!'; exit 1
fi 


## create namelist files
# export relevant variables so that writeNamelist.sh can read them
# WRF
export TIME_CONTROL
export TIME_CONTROL_MOD
export DIAGS
export DIAGS_MOD
export PHYSICS
export PHYSICS_MOD
export NOAH_MP
export NOAH_MP_MOD
export DOMAINS
export DOMAINS_MOD
export FDDA
export FDDA_MOD
export DYNAMICS
export DYNAMICS_MOD
export BDY_CONTROL
export BDY_CONTROL_MOD
export NAMELIST_QUILT
export NAMELIST_QUILT_MOD
# WPS
export SHARE
export SHARE_MOD
export GEOGRID
export GEOGRID_MOD
export METGRID
export METGRID_MOD
# create namelists
echo "Creating WRF and WPS namelists (using ${WRFTOOLS}/Scripts/Setup/writeNamelists.sh)"
cd "${RUNDIR}"
mkdir -p "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Setup/writeNamelists.sh"
mv writeNamelists.sh scripts/
export WRFTOOLS
./scripts/writeNamelists.sh
# number of domains (WRF and WPS namelist!)
sed -i "/max_dom/ s/^\s*max_dom\s*=\s*.*$/ max_dom = ${MAXDOM}, ! this entry was edited by the setup script/" namelist.input namelist.wps
# remove references to FLake, if not used
if [[ "${FLAKE}" != 1 ]]; then
  sed -i "/flake_update/ s/^\s*flake_update\s*=\s*.*$/! flake_update was removed because FLake is not used/" namelist.input
  sed -i "/tsk_flake/ s/^\s*tsk_flake\s*=\s*.*$/! tsk_flake was removed because FLake is not used/" namelist.input
  sed -i "/lake_depth_limit/ s/^\s*lake_depth_limit\s*=\s*.*$/! lake_depth_limit was removed because FLake is not used/" namelist.input
fi # flake

## link data and meta data
# link meta data
echo "Linking WPS meta data and tables (${WRFTOOLS}/misc/data/)"
mkdir -p "${RUNDIR}/meta"
cd "${RUNDIR}/meta"
ln -sf "${WPSSRC}/geogrid/${GEOGRIDTBL}" 'GEOGRID.TBL'
ln -sf "${WPSSRC}/metgrid/${METGRIDTBL}" 'METGRID.TBL'
if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]]; then
  ln -sf "${WRFTOOLS}/misc/data/${POPMAP}"
elif [[ "${DATATYPE}" == 'CFSR' ]]; then
  ln -sf "${WPSSRC}/ungrib/Variable_Tables/${VTABLE_PLEV}" 'Vtable.CFSR_plev'
  ln -sf "${WPSSRC}/ungrib/Variable_Tables/${VTABLE_SRFC}" 'Vtable.CFSR_srfc'
fi # $DATATYPE
# link boundary data
echo "Linking boundary data: ${DATADIR}"
echo "(Boundary data type: ${DATATYPE})"
cd "${RUNDIR}"
if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]]; then
  rm -f 'atm' 'lnd' 'ice'
  ln -sf "${DATADIR}/atm/hist/" 'atm' # atmosphere
  ln -sf "${DATADIR}/lnd/hist/" 'lnd' # land surface
  ln -sf "${DATADIR}/ice/hist/" 'ice' # sea ice
elif [[ "${DATATYPE}" == 'CFSR' ]]; then
  rm -f 'plev' 'srfc'
  ln -sf "${DATADIR}/PLEV/" 'plev' # pressure level date (3D, 0.5 deg)
  ln -sf "${DATADIR}/SRFC/" 'srfc' # surface date (2D, 0.33 deg)
fi # $DATATYPE
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
# WPS run script (cat machine specific and common component)
cat "${WRFTOOLS}/Scripts/${WPSSYS}/run_${CASETYPE}_WPS.${WPSQ}" > "run_${CASETYPE}_WPS.${WPSQ}"
cat "${WRFTOOLS}/Scripts/Common/run_${CASETYPE}_WPS.common" >> "run_${CASETYPE}_WPS.${WPSQ}"
RENAME "run_${CASETYPE}_WPS.${WPSQ}"
if [[ "${WPSQ}" == "sh" ]]; then # make executable in shell
    chmod u+x "run_${CASETYPE}_WPS.${WPSQ}"; fi # if shell
# run-script components (go into folder 'scripts')
mkdir -p "${RUNDIR}/scripts/"
cd "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Common/execWPS.sh"
ln -sf "${WRFTOOLS}/Scripts/${WPSSYS}/setup_${WPSSYS}.sh" 'setup_WPS.sh' # renaming
if [[ "${WPSSYS}" == "GPC" ]] || [[ "${WPSSYS}" == "i7" ]]; then # link to
    ln -sf "${WRFTOOLS}/Python/selectWPSqueue.py"; fi # if shell
cd "${RUNDIR}"
# WPS/real executables (go into folder 'bin')
mkdir -p "${RUNDIR}/bin/"
cd "${RUNDIR}/bin/"
ln -sf "${WRFTOOLS}/Python/pyWPS.py"
ln -sf "${GEOEXE}"
ln -sf "${METEXE}"
ln -sf "${REALEXE}"
if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]]; then
  ln -sf "${WRFTOOLS}/NCL/unccsm.ncl"
  ln -sf "${WRFTOOLS}/bin/${WPSSYS}/unccsm.exe"
else
  ln -sf "${UNGRIBEXE}"
fi # $DATATYPE
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
    RENAME 'sleepCycle.sh'
fi # if LL
# WRF run-script (cat machine specific and common component)
cat "${WRFTOOLS}/Scripts/${WRFSYS}/run_${CASETYPE}_WRF.${WRFQ}" > "run_${CASETYPE}_WRF.${WRFQ}"
cat "${WRFTOOLS}/Scripts/Common/run_${CASETYPE}_WRF.common" >> "run_${CASETYPE}_WRF.${WRFQ}"
RENAME "run_${CASETYPE}_WRF.${WRFQ}"
if [[ "${WRFQ}" == "sh" ]]; then # make executable in shell
    chmod u+x "run_${CASETYPE}_WRF.${WRFQ}"; fi # if shell
# run-script component scripts (go into folder 'scripts')
mkdir -p "${RUNDIR}/scripts/"
cd "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Common/execWRF.sh"
ln -sf "${WRFTOOLS}/Scripts/${WRFSYS}/setup_${WRFSYS}.sh" 'setup_WRF.sh' # renaming
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
# prepare archive script
if [[ -n "${ARSCRIPT}" ]]; then
    # copy script and change job name
    cp -f "${WRFTOOLS}/Scripts/HPSS/${ARSCRIPT}" .
	sed -i "/#PBS -N/ s/#PBS -N\s.*$/#PBS -N ${NAME}_ar/" "${ARSCRIPT}"
    ls "${ARSCRIPT}"
    # set archiving interval
    if [[ -n "${ARINTERVAL}" ]]; then
	sed -i "/INTERVAL/ s/^\s*INTERVAL=.*$/INTERVAL=\'${ARINTERVAL}\' # interval in which the archive script is to be executed/" "${ARSCRIPT}"
    fi
    # set appropriate dataset variable for number of domains
    if [[ ${MAXDOM} == 1 ]]; then
	sed -i "/DATASET/ s/^\s*DATASET=\${DATASET:-.*}\s.*$/DATASET=\${DATASET:-'FULL_D1'} # default dataset: everything (one domain)/" "${ARSCRIPT}"
    elif [[ ${MAXDOM} == 2 ]]; then
	sed -i "/DATASET/ s/^\s*DATASET=\${DATASET:-.*}\s.*$/DATASET=\${DATASET:-'FULL_D12'} # default dataset: everything (two domains)/" "${ARSCRIPT}"
    else
      echo
      echo "WARNING: Number of domains (${MAXDOM}) incompatible with available archiving options."
      echo
    fi # $MAXDOM
    # update folder names
    RENAME "${ARSCRIPT}"
fi # $ARSCRIPT

## link averaging script
ln -sf "${WRFTOOLS}/Python/dataset/avgWRF.py"

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
# urban surface scheme
URB=$(sed -n '/sf_urban_physics/ s/^\s*sf_urban_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
echo "Determining urban surface scheme from namelist: URB=${URB}"
# write default URB into job script ('sed' sometimes fails on TCS...)
sed -i "/export URB/ s/export\sURB=.*$/export URB=\'${URB}\' # radiation scheme set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"
# select scheme and print confirmation
if [[ ${URB} == 0 ]]; then
    echo 'No urban surface scheme selected.'
    URBTAB=""
elif [[ ${URB} == 1 ]]; then
    echo "  Using single layer urban surface scheme."
    URBTAB="URBPARM.TBL"
elif [[ ${URB} == 2 ]]; then
    echo "  Using multi-layer urban surface scheme."
    URBTAB="URBPARM_UZE.TBL"
    PBL=$(sed -n '/bl_pbl_physics/ s/^\s*bl_pbl_physics\s*=\s*\(.\),.*$/\1/p' namelist.input) # \s = space
    if [[ ${PBL} != 2 ]] && [[ ${PBL} != 8 ]]; then
      echo 'WARNING: sf_urban_physics = 2 requires bl_pbl_physics = 2 or 8!'; fi
else
    echo 'No no urban scheme selected! Default: none.'
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
elif [[ ${LSM} == 5 ]]; then
    echo "Using CLM4 land-surface scheme."
    LSMTAB="SOILPARM.TBL VEGPARM.TBL GENPARM.TBL LANDUSE.TBL CLM_ALB_ICE_DFS_DATA CLM_ASM_ICE_DFS_DATA CLM_DRDSDT0_DATA CLM_EXT_ICE_DRC_DATA CLM_TAU_DATA CLM_ALB_ICE_DRC_DATA CLM_ASM_ICE_DRC_DATA CLM_EXT_ICE_DFS_DATA CLM_KAPPA_DATA"
else
    echo 'WARNING: no land-surface model selected!'
fi
# determine tables folder
if [[ ${LSM} == 4 ]] && [[ -e "${WRFSRC}/run-NoahMP/" ]]; then # NoahMP
  TABLES="${WRFSRC}/run-NoahMP/"
  echo "Linking Noah-MP tables: ${TABLES}"
elif [[ ${POLARWRF} == 1 ]] && [[ -e "${WRFSRC}/run-PolarWRF/" ]]; then # PolarWRF
  TABLES="${WRFSRC}/run-PolarWRF/"
  echo "Linking PolarWRF tables: ${TABLES}"
else
  TABLES="${WRFSRC}/run/"
  echo "Linking default tables: ${TABLES}"
fi
# link appropriate tables for physics options
mkdir -p "${RUNDIR}/tables/"
cd "${RUNDIR}/tables/"
for TBL in ${RADTAB} ${LSMTAB} ${URBTAB}; do
    ln -sf "${TABLES}/${TBL}"
done
# copy data file for emission scenario, if applicable
if [[ -n "${GHG}" ]]; then # only if $GHG is defined!
    echo
    if [[ ${RAD} == 'RRTM' ]] || [[ ${RAD} == 1 ]] \
       || [[ ${RAD} == 'CAM' ]] || [[ ${RAD} == 3 ]] \
       || [[ ${RAD} == 'RRTMG' ]] || [[ ${RAD} == 4 ]]
    then
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
echo
# count number of broken links
for FILE in * bin/* scripts/* meta/* tables/*; do # need to list meta/ and table/ extra, because */ includes data links (e.g. atm/)
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
