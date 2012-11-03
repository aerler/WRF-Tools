#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and 
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
STEPFILE='stepfile' # file in $INIDIR
INIDIR="${PWD}" # current directory
METDATA="" # don't save metgrid output
WRFOUT="${INIDIR}/wrfout/" # WRF output folder
WPSSCRIPT='run_cycling_WPS.ll' # WPS run-scripts
WRFSCRIPT='run_cycling_WRF.ll' # WRF run-scripts
STATICTGZ='static.tgz' # file for static data backup

## figure out what we are doing
# determine mode
if [[ "${1}" == 'NOGEO'* ]]; then
  # cold start without geogrid
  NOGEO='TRUE' # run without geogrid
  RESTART='FALSE' # cold start 
  LASTSTEP='' # no last step
elif [[ "${1}" == 'RESTART' ]]; then
  # restart run (no geogrid)
  RESTART='TRUE' # restart previously terminated run
  LASTSTEP="${2}" # last step passed as second argument
  NOGEO='TRUE' # run without geogrid
else
  # cold start with geogrid
  NOGEO='FALSE' # run with geogrid
  RESTART='FALSE' # cold start 
  LASTSTEP='' # no last step
fi

# read first entry in stepfile 
export STEPFILE
NEXTSTEP=$( python cycling.py "${LASTSTEP}" )
#export NEXTSTEP

# launch feedback
echo
if [[ "${RESTART}" == 'TRUE' ]]
 then
  echo "   ***   Re-starting Cycle  ***   "
  echo
  echo "   Next Step: ${NEXTSTEP}"
 else	
  echo "   ***   Starting Cycle  ***   "
  echo
  echo "   First Step: ${NEXTSTEP}"
fi
echo
# echo "   Stepfile: ${STEPFILE}"
echo "   Root Dir: ${INIDIR}"
cd "${INIDIR}"
echo

## run geogrid
if [[ "${NOGEO}" == 'TRUE' ]]
 then
  echo "   Not running geogrid.exe"
 else
  # clear files
  rm -f geo_em.d??.nc geogrid.log*
  # run with parallel processes
  echo "   Running geogrid.exe"
  mpiexec -n 8 ./geogrid.exe > /dev/null # hide stdout
fi
echo

## if not restarting, setup initial and run directories
if [[ "${RESTART}" == 'TRUE' ]] 
 then

  ## restart previous cycle 
  cd "${INIDIR}/${NEXTSTEP}"
  echo "   Linking Restart Files:"
  for RST in ${WRFOUT}/wrfrst_d??_${NEXTSTEP}-??_??:??:??
   do
    echo  "${RST}"
    ln -sf "${RST}"
  done
  echo

 else 

  ## start new cycle
  # clear some folders
  echo "   Clearing Output Folders:"
  if [[ -n ${METDATA} ]]; then  
    echo "${METDATA}"
    rm -rf "${METDATA}"
    mkdir -p "${METDATA}"
  fi
  if [[ -n ${WRFOUT} ]]; then  
    echo "${WRFOUT}"
    rm -rf "${WRFOUT}" 
    mkdir -p "${WRFOUT}"
  fi
  echo

  # prepare first working directory
  # set restart to False for first step
  sed -i '/restart\s/ s/restart\s*=\s*\.true\..*$/restart = .false.,/' "${INIDIR}/${NEXTSTEP}/namelist.input"  
  # and make sure the rest is on restart
  sed -i '/restart\s/ s/restart\s*=\s*\.false\..*$/restart = .true.,/' "${INIDIR}/namelist.input"
  echo "   Setting restart option and interval in namelist."
  
  # create backup of static files
  cd "${INIDIR}"
  rm -rf 'static/'
  mkdir -p 'static'
  echo $( cp -P * 'static/' &> /dev/null ) # trap this error and hide output
  cp -rL 'meta/' 'tables/' 'static/'
  tar czf "${STATICTGZ}" 'static/'
  rm -r 'static/'
  mv "${STATICTGZ}" "${WRFOUT}"
  echo "   Saved backup file for static data:"
  echo "${WRFOUT}/${STATICTGZ}"
  echo

fi # if restart

## launch jobs
cd "${INIDIR}"

# use sleeper script to to launch WPS and WRF
./sleepCycle "${NEXTSTEP}"

# exit with 0 exit code: if anything went wrong we would already have aborted
exit 0

# # submit first independent WPS job to GPC (not TCS!)
# echo
# echo "   Submitting first WPS job to GPC queue:"
# ssh gpc-f104n084 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"
# echo
#
# # wait until WPS job is completed: check presence of wrfinput files
# echo
# echo "   Waiting for WPS job on GPC to complete..."
# while [[ ! -e "${INIDIR}/${NEXTSTEP}/${WPSSCRIPT}" ]]
#   do
#     sleep 30
# done
# echo "   ... WPS completed. Submitting WRF job to LoadLeveler."
# echo
#
# # submit first WRF instance on TCS
# echo
# echo "   Submitting first WRF job to TCS queue:"
# export NEXTSTEP # this is how env vars are passed to LL
# llsubmit ./${WRFSCRIPT}
# echo