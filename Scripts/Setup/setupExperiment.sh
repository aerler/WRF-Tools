#!/bin/bash
# script to set up a WPS/WRF run folder on SciNet
# created 28/06/2012 by Andre R. Erler, GPL v3
# last revision 11/06/2013 by Andre R. Erler

# environment variables: $CODE_ROOT, $WPSSRC, $WRFSRC, $SCRATCH

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
        sed -i "/#PBS -N/ s/#PBS -N\ .*$/#PBS -N ${NAME}_WPS/" "${FILE}" # name
        sed -i "/#PBS -l/ s/#PBS -l nodes=.*:\(.*\)$/#PBS -l nodes=${WPSNODES}:\1/" "${FILE}" # number of nodes (task number is fixed)
        sed -i "/#PBS -l/ s/#PBS -l procs=.*$/#PBS -l procs=${WPSNODES}/" "${FILE}" # processes (alternative to nodes)
        sed -i "/#PBS -l/ s/#PBS -l walltime=.*$/#PBS -l walltime=${WPSWCT}/" "${FILE}" # wallclock time      
      elif [[ "${WPSQ}" == "sb" ]]; then
        sed -i "/#SBATCH -J/ s/#SBATCH -J\ .*$/#SBATCH -J ${NAME}_WPS/" "${FILE}" # name
        sed -i "/#SBATCH --output/ s/#SBATCH --output=.*$/#SBATCH --output=${NAME}_WPS.%j.out/" "${FILE}"
        sed -i "/#SBATCH --nodes/ s/#SBATCH --nodes=.*$/#SBATCH --nodes=${WPSNODES}/" "${FILE}" # number of nodes (preserve task number)
        sed -i "/#SBATCH --time/ s/#SBATCH --time=.*$/#SBATCH --time=${WPSWCT}/" "${FILE}" # wallclock time      
      else
        sed -i "/export JOBNAME/ s+export\ JOBNAME=.*$+export JOBNAME=${NAME}_WPS  # job name (dummy variable, since there is no queue)+" "${FILE}" # name
      fi # $Q
    # WRF run-script
    elif [[ "${FILE}" == *WRF* ]] && [[ "${WRFQ}" == "${Q}" ]]; then
      if [[ "${WRFQ}" == "pbs" ]]; then
        sed -i "/#PBS -N/ s/#PBS -N\ .*$/#PBS -N ${NAME}_WRF/" "${FILE}" # experiment name
        #sed -i "/#PBS -W/ s/#PBS -W\ .*$/#PBS -W depend=afterok:${NAME}_WPS/" "${FILE}" # dependency on WPS
        sed -i "/#PBS -l/ s/#PBS -l nodes=.*:\(.*\)$/#PBS -l nodes=${WRFNODES}:\1/" "${FILE}" # number of nodes (preserve task number)
        sed -i "/#PBS -l/ s/#PBS -l procs=.*$/#PBS -l procs=${WRFNODES}/" "${FILE}" # processes (alternative to nodes)
        sed -i "/#PBS -l/ s/#PBS -l walltime=.*$/#PBS -l walltime=${MAXWCT}/" "${FILE}" # wallclock time
        sed -i "/qsub/ s/qsub ${WRFSCRIPT} -v NEXTSTEP=*\ -W*$/qsub ${WRFSCRIPT} -v NEXTSTEP=*\ -W\ ${NAME}_WPS/" "${FILE}" # dependency
      elif [[ "${WRFQ}" == "sb" ]]; then
        sed -i "/#SBATCH -J/ s/#SBATCH -J\ .*$/#SBATCH -J ${NAME}_WRF/" "${FILE}" # experiment name
        sed -i "/#SBATCH --output/ s/#SBATCH --output=.*$/#SBATCH --output=${NAME}_WRF.%j.out/" "${FILE}"
        sed -i "/#SBATCH --nodes/ s/#SBATCH --nodes=.*$/#SBATCH --nodes=${WRFNODES}/" "${FILE}" # number of nodes (task number is fixed)
        sed -i "/#SBATCH --time/ s/#SBATCH --time=.*$/#SBATCH --time=${MAXWCT}/" "${FILE}" # wallclock time      
        sed -i "/#SBATCH --dependency/ s/#SBATCH --dependency=.*$/#SBATCH --dependency=afterok:${NAME}_WPS/" "${FILE}" # dependency on WPS
      elif [[ "${WRFQ}" == "sge" ]]; then
        sed -i "/#\$ -N/ s/#\$ -N\ .*$/#\$ -N ${NAME}_WRF/" "${FILE}" # experiment name
        #sed -i "/#PBS -W/ s/#PBS -W\ .*$/#PBS -W depend=afterok:${NAME}_WPS/" "${FILE}" # dependency on WPS
        sed -i "/#\$ -pe/ s/#\$ -pe .*$/#\$ -pe mpich $((WRFNODES*32))/" "${FILE}" # number of MPI tasks
        sed -i "/#\$ -l/ s/#\$ -l h_rt=.*$/#\$ -l h_rt=${MAXWCT}/" "${FILE}" # wallclock time
      elif [[ "${WRFQ}" == "ll" ]]; then
        sed -i "/#\ *@\ *job_name/ s/#\ *@\ *job_name\ *=.*$/# @ job_name = ${NAME}_WRF/" "${FILE}" # experiment name
        sed -i "/#\ *@\ *node/ s/#\ *@\ *node\ *=.*$/# @ node = ${WRFNODES}/" "${FILE}" # number of nodes
        sed -i "/#\ *@\ *wall_clock_limit/ s/#\ *@\ *wall_clock_limit\ *=.*$/# @ wall_clock_limit = ${MAXWCT}/" "${FILE}" # wallclock time
      else
        sed -i "/export JOBNAME/ s+export\ JOBNAME=.*$+export JOBNAME=${NAME}_WRF # job name (dummy variable, since there is no queue)+" "${FILE}" # name
        sed -i "/export TASKS/ s+export\ TASKS=.*$+export TASKS=${WRFNODES} # number of MPI tasks+" "${FILE}" # number of tasks (instead of nodes...)
      fi # $Q
    # archive-script
    elif [[ "${FILE}" == "${ARSCRIPT}" ]]; then
      if [[ "${WPSQ}" == "pbs" ]]; then
        sed -i "/#PBS -N/ s/#PBS -N\ .*$/#PBS -N ${NAME}_ar/" "${FILE}"
      elif [[ "${WPSQ}" == "sb" ]]; then
        sed -i "/#SBATCH -J/ s/#SBATCH -J\ .*$/#SBATCH -J ${NAME}_ar/" "${FILE}"
        sed -i "/#SBATCH --output/ s/#SBATCH --output=.*$/#SBATCH --output=${NAME}_ar.%j.out/" "${FILE}"
      else
        sed -i "/export JOBNAME/ s+export\ JOBNAME=.*$+export JOBNAME=${NAME}_ar # job name (dummy variable, since there is no queue)+" "${FILE}" # name                    
      fi # $Q
    # averaging-script
    elif [[ "${FILE}" == "${AVGSCRIPT}" ]]; then
      if [[ "${WPSQ}" == "pbs" ]]; then
        sed -i "/#PBS -N/ s/#PBS -N\ .*$/#PBS -N ${NAME}_avg/" "${FILE}"
      elif [[ "${WPSQ}" == "sb" ]]; then
        sed -i "/#SBATCH -J/ s/#SBATCH -J\ .*$/#SBATCH -J ${NAME}_avg/" "${FILE}"
        sed -i "/#SBATCH --output/ s/#SBATCH --output=.*$/#SBATCH --output=${NAME}_avg.%j.out/" "${FILE}"
      else
        sed -i "/export JOBNAME/ s+export\ JOBNAME=.*$+export JOBNAME=${NAME}_avg # job name (dummy variable, since there is no queue)+" "${FILE}" # name                    
      fi # $Q
    fi # if WPS,WRF,AR,AVG
    # set email address for notifications
    if [[ -n "$EMAIL" ]]; then
	    if [[ "${Q}" == "pbs" ]]; then
	      sed -i "/#PBS -M/ s/#PBS -M\ .*$/#PBS -M \"${EMAIL}\"/" "${FILE}" # notification address
	    elif [[ "${WPSQ}" == "sb" ]]; then
        sed -i "/#SBATCH --mail-user/ s/#SBATCH --mail-user=.*$/#SBATCH --mail-user=${EMAIL}/" "${FILE}"
      elif [[ "${WRFQ}" == "sge" ]]; then
	      sed -i "/#\$ -M/ s/#\$ -M\ .*$/#\$ -M ${EMAIL}/" "${FILE}" # notification address
      elif [[ "${Q}" == "ll" ]]; then
        : # apparently email address is not set here...?
	    else
	      sed -i "/\\\$EMAIL/ s/\\\$EMAIL/${EMAIL}/" "${FILE}" # random email address
	    fi
  	else
	    sed -i '/\$EMAIL/d' "${FILE}" # remove references to email address
    fi # replace email address
    ## queue independent changes
    # N.B.: variables that depend on other variables are not overwritten!
    # WRF script
    sed -i "/WRFSCRIPT=/ s/WRFSCRIPT=[^$][^$].*$/WRFSCRIPT=\'run_${CASETYPE}_WRF.${WRFQ}\' # WRF run-scripts/" "${FILE}" # WPS run-script
    # WPS script
    sed -i "/WPSSCRIPT=/ s/WPSSCRIPT=[^$][^$].*$/WPSSCRIPT=\'run_${CASETYPE}_WPS.${WPSQ}\' # WPS run-scripts/" "${FILE}" # WPS run-script
    # output folder
    sed -i '/WRFOUT=/ s+WRFOUT=[^$][^$].*$+WRFOUT="${INIDIR}/wrfout/" # WRF output folder+' "${FILE}"
    # metdata folder
    [[ -n $METDATA ]] && sed -i "/METDATA=/ s+METDATA=[^$][^$].*$+METDATA=\'${METDATA}\' # optional WPS/metgrid output folder+" "${FILE}"
    # WRF version
    [[ -n $WRFVERSION ]] && sed -i "/WRFVERSION=/ s/WRFVERSION=[^$].*$/WRFVERSION=${WRFVERSION} # optional WRF version parameter (default: 3) /" "${FILE}"
    # WRF wallclock time limit
    sed -i "/WRFWCT=/ s/WRFWCT=[^$][^$].*$/WRFWCT=\'${WRFWCT}\' # WRF wallclock time/" "${FILE}" # used for queue time estimate
    # number of WPS & WRF nodes on given system
    sed -i "/WPSNODES=/ s/WPSNODES=[^$][^$].*$/WPSNODES=${WPSNODES} # number of WPS nodes/" "${FILE}" 
    sed -i "/WRFNODES=/ s/WRFNODES=[^$][^$].*$/WRFNODES=${WRFNODES} # number of WRF nodes/" "${FILE}"
    # WPS wallclock time limit
    sed -i "/WPSWCT=/ s/WPSWCT=[^$][^$].*$/WPSWCT=\'${WPSWCT}\' # WPS wallclock time/" "${FILE}" # used for queue time estimate
    # script folder
    sed -i '/SCRIPTDIR=/ s+SCRIPTDIR=[^$][^$].*$+SCRIPTDIR="${INIDIR}/scripts/"  # location of component scripts (pre/post processing etc.)+' "${FILE}"
    # executable folder
    sed -i '/BINDIR=/ s+BINDIR=[^$][^$].*$+BINDIR="${INIDIR}/bin/"  # location of executables nd scripts (WPS and WRF)+' "${FILE}"
    # archive script
    sed -i "/ARSCRIPT=/ s/ARSCRIPT=[^$][^$].*$/ARSCRIPT=\'${ARSCRIPT}\' # archive script to be executed in specified intervals/" "${FILE}"
    # archive interval
    sed -i "/ARINTERVAL=/ s/ARINTERVAL=[^$][^$].*$/ARINTERVAL=\'${ARINTERVAL}\' # interval in which the archive script is to be executed/" "${FILE}"
    # averaging script
    sed -i "/AVGSCRIPT=/ s/AVGSCRIPT=[^$][^$].*$/AVGSCRIPT=\'${AVGSCRIPT}\' # averaging script to be executed in specified intervals/" "${FILE}"
    # averaging interval
    sed -i "/AVGINTERVAL=/ s/AVGINTERVAL=[^$][^$].*$/AVGINTERVAL=\'${AVGINTERVAL}\' # interval in which the averaging script is to be executed/" "${FILE}"
    # number of domains (string of single-digit index numbers)
    sed -i "/DOMAINS=/ s/'1234'/'${DOMS}'/" "${FILE}" # just replace the default value
    # type of initial and boundary focing  data (mainly for WPS)
    sed -i "/DATATYPE=/ s/DATATYPE=[^$][^$].*$/DATATYPE=\'${DATATYPE}\' # type of initial and boundary focing  data /" "${FILE}"
    # whether or not to restart job after a numerical instability (used by crashHandler.sh)
    sed -i "/AUTORST=/ s/AUTORST=[^$][^$].*$/AUTORST=\'${AUTORST}\' # whether or not to restart job after a numerical instability /" "${FILE}"
    # time decrement to use in case of instability (used by crashHandler.sh)
    sed -i "/DELT=/ s/DELT=[^$][^$].*$/DELT=\'${DELT}\' # time decrement for auto restart /" "${FILE}"
    ## Geogrid number of tasks 
    sed -i "/export GEOTASKS=/ s/export GEOTASKS=.*$/export GEOTASKS=${GEOTASKS} # Number of geogrid processes\./" "${FILE}"
    ## WRF Env
    sed -i "/export WRFENV=/ s/export WRFENV=.*$/export WRFENV=\'${WRFENV}\' # WRF environment version\./" "${FILE}"
} # fct. RENAME


## scenario definition section
# defaults (may be set or overwritten in xconfig.sh)
NAME='test' # should be overwritten in xconfig
RUNDIR="${PWD}" # experiment root
WRFOUT="${RUNDIR}/wrfout/" # folder to collect output data
METDATA='' # folder to collect output data from metgrid
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="1979:2009:1M" # stepfile to be used (leave empty if not cycling)
AUTORST='RESTART' # whether or not to restart job after a numerical instability (used by crashHandler.sh)
DELT='DEFAULT' # time decrement for auto restart (DEFAULT: select according to timestep) 
# boundary data
DATADIR='' # root directory for data
DATATYPE='CESM' # boundary forcing type
## run configuration
WRFROOT="${CODE_ROOT}/WRFV3.9/"
WRFTOOLS="${CODE_ROOT}/WRF-Tools/"
# I/O, archiving, and averaging 
IO='fineIO' # this is used for namelist construction and archiving
ARSYS='' # archive - define in xconfig.sh
ARSCRIPT='DEFAULT' # this is a dummy name...
ARINTERVAL='YEARLY' # default
AVGSYS='' # post-processing - define in xconfig.sh
AVGSCRIPT='DEFAULT' # this is a dummy name...
AVGINTERVAL='YEARLY' # default
# N.B.: interval options are: YEARLY, MONTHLY, DAILY, wiht YEARLY being preferred;
#       unknown/empty intervals trigger archiving/averaging after every step
## WPS
WPSSYS='' # WPS - define in xconfig.sh
# other WPS configuration files
GEODATA="/project/p/peltier/WRF/geog/" # location of geogrid data
## WRF
WRFSYS='' # WRF - define in xconfig.sh
MAXWCT='' # to some extent dependent on cluster
POLARWRF=0 # PolarWRF switch
FLAKE=0 # FLake lake model (in-house; only V3.4 & V3.5)
# some settings depend on the number of domains
MAXDOM=2 # number of domains in WRF and WPS

## load configuration file
echo "Sourcing experimental setup file (xconfig.sh)" 
source xconfig.sh

# apply command line argument for WRFSYS (overrides xconfig)
[[ -n $1 ]] && WRFSYS="$1"

# set default wallclock limit by machine
if [[ -z "${MAXWCT}" ]]; then
  if [[ "${WRFSYS}" == 'Niagara' ]]; then
    MAXWCT='24:00:00' # Niagara has reduced wallclock limit time
  elif [[ "${WRFSYS}" == 'P7' ]]; then
    MAXWCT='72:00:00' # P7 has increased wallclock limit time
  else
    MAXWCT='48:00:00' # this is common on most clusters
  fi # WRFSYS
fi # $MAXWCT

# create run folder
echo
echo "   Setting up Experiment ${NAME}"
echo
mkdir -p "${RUNDIR}"
mkdir -p "${WRFOUT}"

## fix default settings

# WPS defaults
SHARE=${SHARE:-'arw'}
METGRID=${METGRID:-'pywps'}

# infer default $CASETYPE (can also set $CASETYPE in xconfig.sh)
if [[ -z "${CASETYPE}" ]]; then
  if [[ -n "${CYCLING}" ]]; then CASETYPE='cycling';
  else CASETYPE='test'; fi
fi

# boundary data definition for WPS
if [[ "${DATATYPE}" == 'CMIP5' ]]; then
  POPMAP=${POPMAP:-'map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc'} # ocean grid definition
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.CESM'}
elif [[ "${DATATYPE}" == 'CESM' ]]; then
  POPMAP=${POPMAP:-'map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc'} # ocean grid definition
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.CESM'}
# elif [[ "${DATATYPE}" == 'CCSM' ]]; then
#   POPMAP=${POPMAP:-''} # ocean grid definition
#   METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.CCSM'}
elif [[ "${DATATYPE}" == 'CFSR' ]]; then
  VTABLE_PLEV=${VTABLE_PLEV:-'Vtable.CFSR_press_pgbh06'}
  VTABLE_SRFC=${VTABLE_SRFC:-'Vtable.CFSR_sfc_flxf06'}
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.ARW'}
elif [[ "${DATATYPE}" == 'ERA-I' ]]; then
  VTABLE=${VTABLE:-'Vtable.ERA-interim.pl'}
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.ERAI'}
elif [[ "${DATATYPE}" == 'ERA5' ]]; then
  VTABLE=${VTABLE:-'Vtable.ERA5.pl'}
  METGRIDTBL=${METGRIDTBL:-'METGRID.TBL.ERA5'}
elif [[ "${DATATYPE}" == 'NARR' ]]; then
  VTABLE=${VTABLE:-'Vtable.NARR'}
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
# but there are many versions of WRF...
if [[ -z "$WRFBLD" ]]; then
  # GCM or reanalysis with current I/O version
  if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]] || [[ "${DATATYPE}" == 'CMIP5' ]]; then
    WRFBLD="Clim-${IO}" # variable GHG scenarios and no leap-years
    LLEAP='--noleap' # option for Python script to omit leap days
  elif [[ "${DATATYPE}" == 'ERA-I' ]] || [[ "${DATATYPE}" == 'ERA5' ]] || [[ "${DATATYPE}" == 'CFSR' ]] || [[ "${DATATYPE}" == 'NARR' ]]; then
    WRFBLD="ReA-${IO}" # variable GHG scenarios with leap-years
  else
    WRFBLD="Default-${IO}" # standard WRF build with current I/O version
  fi # $DATATYPE
  # Standard or PolarWRF (add Polar-prefix)
  if [ ${POLARWRF} == 1 ]; then WRFBLD="Polar-${WRFBLD}"; fi
fi # if $WRFBLD
WPSBLD=${WPSBLD:-"${WRFBLD}"} # should be analogous...

# source folders (depending on $WRFROOT; can be set in xconfig.sh)
WPSSRC=${WPSSRC:-"${WRFROOT}/WPS/"}
WRFSRC=${WRFSRC:-"${WRFROOT}/WRFV3/"}

# figure out queue systems from machine setup scripts
TMP=$( eval $( grep 'QSYS=' "${WRFTOOLS}/Machines/${WPSSYS}/setup_${WPSSYS}.sh" ); echo "${QSYS}" )
WPSQ=${WPSQ:-$( echo "${TMP}" | tr '[:upper:]' '[:lower:]' )} # "${QSYS,,}" is not POSIX compliant
TMP=$( eval $( grep 'QSYS=' "${WRFTOOLS}/Machines/${WRFSYS}/setup_${WRFSYS}.sh" ); echo "${QSYS}" )
WRFQ=${WRFQ:-$( echo "${TMP}" | tr '[:upper:]' '[:lower:]' )}
# fallback queue: shell script
if [ ! -f "${WRFTOOLS}/Machines/${WPSSYS}/run_cycling_WPS.${WPSQ}" ]; then WPSQ='sh'; fi
if [ ! -f "${WRFTOOLS}/Machines/${WRFSYS}/run_cycling_WRF.${WRFQ}" ]; then WRFQ='sh'; fi
# N.B.: the queue names are also used as file name extension for the run scripts
# then figure out default wallclock times
TMP=$( eval $( grep 'WPSWCT=' "${WRFTOOLS}/Machines/${WPSSYS}/run_cycling_WPS.${WPSQ}" ); echo "$WPSWCT" )
WPSWCT=${WPSWCT:-"${TMP}"}
TMP=$( eval $( grep 'WRFWCT=' "${WRFTOOLS}/Machines/${WRFSYS}/run_cycling_WRF.${WRFQ}" ); echo "$WRFWCT" )
WRFWCT=${WRFWCT:-"${TMP}"}
# read number of WPS & WRF nodes/processes (defaults to one)
TMP=$( eval $( grep 'WPSNODES=' "${WRFTOOLS}/Machines/${WPSSYS}/run_cycling_WPS.${WPSQ}" ); echo "${WPSNODES:-1}" )
WPSNODES=${WPSNODES:-$TMP}
TMP=$( eval $( grep 'WRFNODES=' "${WRFTOOLS}/Machines/${WRFSYS}/run_cycling_WRF.${WRFQ}" ); echo "${WRFNODES:-1}" )
WRFNODES=${WRFNODES:-$TMP}

# default WPS and real executables
GEOEXE=${GEOEXE:-"${WPSSRC}/${WPSSYS}-MPI/${WPSBLD}/Default/geogrid.exe"} 
UNGRIBEXE=${UNGRIBEXE:-"${WPSSRC}/${WPSSYS}-MPI/${WPSBLD}/Default/ungrib.exe"}
METEXE=${METEXE:-"${WPSSRC}/${WPSSYS}-MPI/${WPSBLD}/Default/metgrid.exe"}
REALEXE=${REALEXE:-"${WRFSRC}/${WPSSYS}-MPI/${WPSBLD}/Default/real.exe"}
# default WRF executable
WRFEXE=${WRFEXE:-"${WRFSRC}/${WRFSYS}-MPI/${WRFBLD}/Default/wrf.exe"}
# N.B.: the folder 'Default' can be a symlink to the default directory for executables 

# default archive script name (no $ARSCRIPT means no archiving)
if [[ "${ARSCRIPT}" == 'DEFAULT' ]] && [[ -n "${IO}" ]]; then ARSCRIPT="ar_wrfout_${IO}.${WPSQ}"; fi
# default averaging script name (no $AVGSCRIPT means no averaging)
if [[ "${AVGSCRIPT}" == 'DEFAULT' ]]; then AVGSCRIPT="run_wrf_avg.${WPSQ}"; fi
# string of single-digit dimensions for archvie and averaging script
DOMS=''; for I in $( seq 1 ${MAXDOM} ); do DOMS="${DOMS}${I}"; done
    

## ***                                            ***
## ***   now we actually start doing something!   ***
## ***                                            ***

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
    eval $( rm -rf 'scripts' 'bin' 'meta' 'tables' &> /dev/null ) # delete script and table folders
    eval $( rm -f 'atm' 'lnd' 'ice' 'plev' 'srfc' 'uv' 'sc' 'sfc' 'pl' 'sl' &> /dev/null ) # delete input data folders
    eval $( rm -f 'GPC' 'TCS' 'P7' 'i7' 'Bugaboo' 'Rocks' 'Niagara' &> /dev/null ) # delete machine markers
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
sed -i "/max_dom/ s/^\ *max_dom\ *=\ *.*$/ max_dom = ${MAXDOM}, ! this entry was edited by the setup script/" namelist.input namelist.wps
# remove references to FLake, if not used
if [[ "${FLAKE}" != 1 ]]; then
  sed -i "/flake_update/ s/^\ *flake_update\ *=\ *.*$/! flake_update was removed because FLake is not used/" namelist.input
  sed -i "/tsk_flake/ s/^\ *tsk_flake\ *=\ *.*$/! tsk_flake was removed because FLake is not used/" namelist.input
  sed -i "/transparent/ s/^\ *transparent\ *=\ *.*$/! transparent was removed because FLake is not used/" namelist.input
  sed -i "/lake_depth_limit/ s/^\ *lake_depth_limit\ *=\ *.*$/! lake_depth_limit was removed because FLake is not used/" namelist.input
fi # flake
# determine time step and restart decrement
if [[ "${DELT}" == 'DEFAULT' ]]; then 
  DT=$(sed -n '/time_step/ s/^\ *time_step\ *=\ *\([0-9]\+\).*$/\1/p' namelist.input) # '\ ' = space
  if [[ -z "$DT" ]]; then echo -e '\nERROR: No time step identified in namelist - aborting!\n'; exit 1;
  elif [ $DT -gt 400 ]; then DELT='120'
  elif [ $DT -gt 200 ]; then DELT='60'
  elif [ $DT -gt 100 ]; then DELT='30'
  elif [ $DT -gt  50 ]; then DELT='15'
  elif [ $DT -gt  30 ]; then DELT='10'
  else DELT='5'; fi
fi # if $DELT=DEFAULT


## link data and meta data
# link meta data
echo "Linking WPS meta data and tables (${WRFTOOLS}/misc/data/)"
mkdir -p "${RUNDIR}/meta"
cd "${RUNDIR}/meta"
ln -sf "${WPSSRC}/geogrid/${GEOGRIDTBL}" 'GEOGRID.TBL'
ln -sf "${WPSSRC}/metgrid/${METGRIDTBL}" 'METGRID.TBL'
if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]] || [[ "${DATATYPE}" == 'CMIP5' ]]; then
  ln -sf "${WRFTOOLS}/misc/data/${POPMAP}"
elif [[ "${DATATYPE}" == 'CFSR' ]]; then
  ln -sf "${WPSSRC}/ungrib/Variable_Tables/${VTABLE_PLEV}" 'Vtable.CFSR_plev'
  ln -sf "${WPSSRC}/ungrib/Variable_Tables/${VTABLE_SRFC}" 'Vtable.CFSR_srfc'
elif [[ -n "${VTABLE}" ]]; then 
  ln -sf "${WPSSRC}/ungrib/Variable_Tables/${VTABLE}" 'Vtable'
else 
  echo "VTABLE variable is needed but not defined. Aborting." 
  exit 1  
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
elif [[ "${DATATYPE}" == 'CMIP5' ]]; then
  rm -f 'init'
  ln -sf "${DATADIR}/" 'init'  # initial file directory
elif [[ "${DATATYPE}" == 'CFSR' ]]; then
  rm -f 'plev' 'srfc'
  ln -sf "${DATADIR}/plev/" 'plev' # pressure level date (3D, 0.5 deg)
  ln -sf "${DATADIR}/srfc/" 'srfc' # surface data (2D, 0.33 deg)
elif [[ "${DATATYPE}" == 'ERA-I' ]]; then
  rm -f 'uv' 'sc' 'sfc' 
  ln -sf "${DATADIR}/uv/" 'uv' # pressure level date (3D, 0.7 deg)
  ln -sf "${DATADIR}/sc/" 'sc' # pressure level date (3D, 0.7 deg)
  ln -sf "${DATADIR}/sfc/" 'sfc' # surface data (2D, 0.7 deg)
elif [[ "${DATATYPE}" == 'ERA5' ]]; then
  rm -f 'pl' 'sl' 
  ln -sf "${DATADIR}/pl/" 'pl' # Pressure level date (3D, 0.25 deg).
  ln -sf "${DATADIR}/sl/" 'sl' # Surface data (2D, 0.25 deg).  
fi # $DATATYPE
# set correct path for geogrid data
echo "Setting path for geogrid data"
if [[ -n "${GEODATA}" ]]; then
  sed -i "/geog_data_path/ s+\ *geog_data_path\ *=\ *.*$+ geog_data_path = \'${GEODATA}\',+" namelist.wps
  echo "  ${GEODATA}"
else echo "WARNING: no geogrid path selected!"; fi


## link in WPS stuff
echo
# WPS scripts
echo "Linking WPS scripts and executable (${WRFTOOLS})"
echo "  system: ${WPSSYS}, queue: ${WPSQ}"
# user scripts (in root folder)
cd "${RUNDIR}"
# WPS run script (concatenate machine specific and common components)
cat "${WRFTOOLS}/Machines/${WPSSYS}/run_${CASETYPE}_WPS.${WPSQ}" > "run_${CASETYPE}_WPS.${WPSQ}"
cat "${WRFTOOLS}/Scripts/Common/run_${CASETYPE}.environment" >> "run_${CASETYPE}_WPS.${WPSQ}"
if [ $( grep -c 'custom environment' xconfig.sh ) -gt 0 ]; then
  RUNSCRIPT="run_${CASETYPE}_WPS.${WPSQ}"
  echo "Adding custom environment section from xconfig.sh to run-script '${RUNSCRIPT}'"
  echo '' >> "${RUNSCRIPT}" # add line break
  sed -n '/begin\ custom\ environment/,/end\ custom\ environment/p' xconfig.sh >>  "${RUNSCRIPT}"
  echo '' >> "${RUNSCRIPT}" # add line break
fi # if custom environment
cat "${WRFTOOLS}/Scripts/Common/run_${CASETYPE}_WPS.common" >> "run_${CASETYPE}_WPS.${WPSQ}"
RENAME "run_${CASETYPE}_WPS.${WPSQ}"
if [[ "${WPSQ}" == "sh" ]]; then # make executable in shell
    chmod u+x "run_${CASETYPE}_WPS.${WPSQ}"; fi # if shell
# run-script components (go into folder 'scripts')
mkdir -p "${RUNDIR}/scripts/"
cd "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Common/execWPS.sh"
ln -sf "${WRFTOOLS}/Machines/${WPSSYS}/setup_${WPSSYS}.sh" 'setup_WPS.sh' # renaming
if [[ "${WPSSYS}" == "GPC" ]] || [[ "${WPSSYS}" == "i7" ]]; then # link to
    ln -sf "${WRFTOOLS}/Python/wrfrun/selectWPSqueue.py"; fi # if shell
cd "${RUNDIR}"
# WPS/real executables (go into folder 'bin')
mkdir -p "${RUNDIR}/bin/"
cd "${RUNDIR}/bin/"
ln -sf "${WRFTOOLS}/Python/wrfrun/pyWPS.py"
ln -sf "${GEOEXE}"
ln -sf "${METEXE}"
ln -sf "${REALEXE}"
if [[ "${DATATYPE}" == 'CESM' ]] || [[ "${DATATYPE}" == 'CCSM' ]]; then
  ln -sf "${WRFTOOLS}/NCL/unccsm.ncl"
  ln -sf "${WRFTOOLS}/bin/${WPSSYS}/unccsm.exe"
elif  [[ "${DATATYPE}" == 'CMIP5' ]]; then
  ln -sf "${WRFTOOLS}/NCL/unCMIP5.ncl"
  ln -sf "${WRFTOOLS}/bin/${WPSSYS}/unccsm.exe"
elif  [[ "${DATATYPE}" == 'ERA5' ]]; then
    ln -sf "${WRFTOOLS}/Python/wrfrun/fixIM.py"
    ln -sf "${UNGRIBEXE}"
else
  ln -sf "${UNGRIBEXE}"
fi # $DATATYPE
cd "${RUNDIR}"

## link in WRF stuff
echo
touch "${WRFSYS}" # just a marker
chmod u+x "${WRFSYS}" # so it appears highlighted!
# WRF scripts
echo "Linking WRF scripts and executable (${WRFTOOLS})"
echo "  system: ${WRFSYS}, queue: ${WRFQ}"
# user scripts (go into root folder)
cd "${RUNDIR}"
if [[ -n "${CYCLING}" ]]; then
  if [[ -f "${WRFTOOLS}/misc/stepfiles/stepfile.${CYCLING}" ]]; then
    # use existing step file in archive (works without pandas)
    cp "${WRFTOOLS}/misc/stepfiles/stepfile.${CYCLING}" 'stepfile'
  else
    # interprete step definition string: begin:end:int
    BEGIN=${CYCLING%:*:*}
    INT=${CYCLING#*:*:}
    END=${CYCLING%:*}; END=${END#*:}
    # generate stepfile on-the-fly
    GENSTEPS=${GENSTEPS:-"${WRFTOOLS}/Python/wrfrun/generateStepfile.py"} # Python script to generate stepfiles
    echo "creating new stepfile: begin=${BEGIN}, end=${END}, interval=${INT}"    
    python "${GENSTEPS}" ${LLEAP} --interval="${INT}" "${BEGIN}" "${END}" 
    # LLEAP is defined above; don't quote option, because it may no be defined
  fi
  # concatenate start_cycle script
  cp "${WRFTOOLS}/Scripts/Common/startCycle.sh" .
  RENAME "startCycle.sh"
fi # if cycling
#if [[ "${WRFQ}" == "ll" ]]; then # because LL does not support dependencies
#    cp "${WRFTOOLS}/Machines/${WRFSYS}/sleepCycle.sh" .
#    RENAME 'sleepCycle.sh'
#fi # if LL
# WRF run-script (concatenate machine specific and common components)
cat "${WRFTOOLS}/Machines/${WRFSYS}/run_${CASETYPE}_WRF.${WRFQ}" > "run_${CASETYPE}_WRF.${WRFQ}"
cat "${WRFTOOLS}/Scripts/Common/run_${CASETYPE}.environment" >> "run_${CASETYPE}_WRF.${WRFQ}"
if [ $( grep -c 'custom environment' xconfig.sh ) -gt 0 ]; then
  RUNSCRIPT="run_${CASETYPE}_WRF.${WRFQ}"
  echo "Adding custom environment section from xconfig.sh to run-script '${RUNSCRIPT}'"
  echo '' >> "${RUNSCRIPT}" # add line break
  sed -n '/begin\ custom\ environment/,/end\ custom\ environment/p' xconfig.sh >>  "${RUNSCRIPT}"
  echo '' >> "${RUNSCRIPT}" # add line break
fi # if custom environment
cat "${WRFTOOLS}/Scripts/Common/run_${CASETYPE}_WRF.common" >> "run_${CASETYPE}_WRF.${WRFQ}"
RENAME "run_${CASETYPE}_WRF.${WRFQ}"
if [[ "${WRFQ}" == "sh" ]]; then # make executable in shell
    chmod u+x "run_${CASETYPE}_WRF.${WRFQ}"; fi # if shell
# run-script component scripts (go into folder 'scripts')
mkdir -p "${RUNDIR}/scripts/"
cd "${RUNDIR}/scripts/"
ln -sf "${WRFTOOLS}/Scripts/Common/execWRF.sh"
ln -sf "${WRFTOOLS}/Machines/${WRFSYS}/setup_${WRFSYS}.sh" 'setup_WRF.sh' # renaming
if [[ -n "${CYCLING}" ]]; then
    ln -sf "${WRFTOOLS}/Scripts/Setup/setup_cycle.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/launchPreP.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/launchPostP.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/resubJob.sh"
    ln -sf "${WRFTOOLS}/Scripts/Common/crashHandler.sh"
    ln -sf "${WRFTOOLS}/Python/wrfrun/cycling.py"
fi # if cycling
cd "${RUNDIR}"
# WRF executable (go into folder 'bin')
mkdir -p "${RUNDIR}/bin/"
cd "${RUNDIR}/bin/"
ln -sf "${WRFEXE}"
cd "${RUNDIR}"


## setup archiving and averaging
echo
# prepare archive script
if [[ -n "${ARSCRIPT}" ]] && [[ -n "${ARSYS}" ]]; then
    # copy script and change job name
    cp -f "${WRFTOOLS}/Machines/${ARSYS}/${ARSCRIPT}" .    
    echo "Setting up archiving: ${ARSCRIPT}"
    # update folder names and queue parameters
    RENAME "${ARSCRIPT}"
fi # $ARSCRIPT
# prepare averaging script
if [[ -n "${AVGSCRIPT}" ]] && [[ -n "${AVGSYS}" ]]; then
    # copy script and change job name
    ln -s "${WRFTOOLS}/Python/wrfavg/wrfout_average.py" "./scripts/"
    ln -s "${WRFTOOLS}/Machines/${AVGSYS}/addVariable.sh" "./scripts/"
    cp -f "${WRFTOOLS}/Machines/${AVGSYS}/${AVGSCRIPT}" .
    mkdir -p 'wrfavg' # folder for averaged output    
    echo "Setting up averaging: ${AVGSCRIPT}"
    # update folder names and queue parameters
    RENAME "${AVGSCRIPT}"
fi # $AVGSCRIPT


## copy data tables for selected physics options
echo
# radiation scheme
RAD=$(sed -n '/ra_lw_physics/ s/^\ *ra_lw_physics\ *=\ *\(.\),.*$/\1/p' namelist.input) # \  = space
if [[ "${RAD}" != $(sed -n '/ra_sw_physics/ s/^\ *ra_sw_physics\ *=\ *\(.\),.*$/\1/p' namelist.input) ]]; then
  echo 'Error: different schemes for SW and LW radiation are currently not supported.'
  exit 1
fi # check short wave 
echo "Determining radiation scheme from namelist: RAD=${RAD}"
# write default RAD into job script ('sed' sometimes fails on TCS...)
sed -i "/export RAD/ s/export\ RAD=.*$/export RAD=\'${RAD}\' # radiation scheme set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"
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
    # check additional radiation options: aer_opt & o3input     
		AER=$(sed -n '/aer_opt/ s/^\ *aer_opt\ *=\ *\(.\).*$/\1/p' namelist.input) # \  = space
    if [[ -n $AER ]] && [ $AER -eq 1 ]; then # add aerosol climatology of Tegen
      RADTAB="${RADTAB} aerosol.formatted aerosol_plev.formatted aerosol_lat.formatted aerosol_lon.formatted"; fi
    O3=$(sed -n '/o3input/ s/^\ *o3input\ *=\ *\(.\).*$/\1/p' namelist.input) # \  = space
    if [[ -z $O3 ]] || [ $O3 -eq 2 ]; then # add ozone climatology from CAM
      RADTAB="${RADTAB} ozone.formatted ozone_plev.formatted ozone_lat.formatted"; fi
      # N.B.: the default changed in V3.8 from o3input=0 to o3input=2, which means the input files are required by default
else
    echo 'WARNING: no radiation scheme selected, or selection not supported!'
fi
# urban surface scheme
URB=$(sed -n '/sf_urban_physics/ s/^\ *sf_urban_physics\ *=\ *\(.\),.*$/\1/p' namelist.input) # \  = space
echo "Determining urban surface scheme from namelist: URB=${URB}"
# write default URB into job script ('sed' sometimes fails on TCS...)
sed -i "/export URB/ s/export\ URB=.*$/export URB=\'${URB}\' # radiation scheme set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"
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
    PBL=$(sed -n '/bl_pbl_physics/ s/^\ *bl_pbl_physics\ *=\ *\(.\),.*$/\1/p' namelist.input) # \  = space
    if [[ ${PBL} != 2 ]] && [[ ${PBL} != 8 ]]; then
      echo 'WARNING: sf_urban_physics = 2 requires bl_pbl_physics = 2 or 8!'; fi
else
    echo 'No urban scheme selected! Default: none.'
fi
# land-surface scheme
LSM=$(sed -n '/sf_surface_physics/ s/^\ *sf_surface_physics\ *=\ *\(.\),.*$/\1/p' namelist.input) # \  = space
echo "Determining land-surface scheme from namelist: LSM=${LSM}"
# write default LSM into job script ('sed' sometimes fails on TCS...)
sed -i "/export LSM/ s/export\ LSM=.*$/export LSM=\'${LSM}\' # land surface scheme set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"
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
    if [[ ${RAD} == 'RRTM' ]] || [[ ${RAD} == 1 ]] || [[ ${RAD} == 'CAM' ]] || [[ ${RAD} == 3 ]] || [[ ${RAD} == 'RRTMG' ]] || [[ ${RAD} == 4 ]]
    then
        echo "GHG emission scenario: ${GHG}"
        ln -sf "${TABLES}/CAMtr_volume_mixing_ratio.${GHG}" # do not clip scenario extension (yet)
    else
        echo "WARNING: variable GHG emission scenarios not available with the selected ${RAD} scheme!"
        unset GHG 
        # unset GHG for later use
    fi
fi
cd "${RUNDIR}" # return to run directory
# GHG emission scenario (if no GHG scenario is selected, the variable will be empty)
sed -i "/export GHG/ s/export\ GHG=.*$/export GHG=\'${GHG}\' # GHG emission scenario set by setup script/" "run_${CASETYPE}_WRF.${WRFQ}"


## finish up
# prompt user to create data links
echo
echo "Remaining tasks:"
echo " * review meta data and namelists"
echo " * edit run scripts, if necessary,"
if  [[ "${DATATYPE}" == 'CMIP5' ]]; then
  echo
  echo "For CMIP5 data:"
  echo " * copy the necessary meta files for CMIP5 into the meta folder"
  echo " * These file includes the ocn2atm, orog, sftlf files for grid info"
  echo " * copy the cdb_query CMIP5 validate file into the meta folder"
fi
echo
# count number of broken links
CNT=0
for FILE in * bin/* scripts/* meta/* tables/*; do # need to list meta/ and table/ extra, because */ includes data links (e.g. atm/)
  if [[ ! -e $FILE ]]; then
    CNT=$(( CNT + 1 ))
    if  [ $CNT -eq 1 ]; then
      echo " * fix broken links"
      echo
      echo "  Broken links:"
      echo
    fi
    ls -l "${FILE}"
  fi
done
if [ $CNT -gt 0 ]; then
  echo "   >>>   WARNING: there are ${CNT} broken links!!!   <<<   "
  echo
fi
echo

exit ${CNT} # return number of broken links as error code
