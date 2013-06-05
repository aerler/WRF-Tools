#!/bin/bash
# short script to setup a new experiment and/or re-link restart files
# Andre R. Erler, 02/03/2013, GPL v3

## figure out what we are doing
if [[ "${MODE}" == 'NOGEO'* ]]; then
  # cold start without geogrid
  NOGEO='NOGEO' # run without geogrid
  NOTAR='FALSE' # star static
  RESTART='FALSE' # cold start
elif [[ "${MODE}" == 'NOSTAT'* ]]; then
  # cold start without geogrid
  NOGEO='NOGEO' # run without geogrid
  NOTAR='NOTAR' # star static
  RESTART='FALSE' # cold start
elif [[ "${MODE}" == 'RESTART' ]]; then
  # restart run (no geogrid)
  RESTART='RESTART' # restart previously terminated run
  NOGEO='NOGEO' # run without geogrid
  NOTAR='FALSE' # star static
elif [[ "${MODE}" == 'CLEAN' ]] || [[ "${MODE}" == '' ]]; then
  # cold start with geogrid
  NOGEO='FALSE' # run with geogrid
  NOTAR='FALSE' # star static
  RESTART='FALSE' # cold start
else
  echo
  echo "   >>>   Unknown command ${MODE} - aborting!!!   "
  echo
  exit 1
fi

# launch feedback
echo
if [[ "${RESTART}" == 'RESTART' ]]
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
if [[ "${NOGEO}" == 'NOGEO' ]]
 then
  echo "   Not running geogrid.exe"
 else
  # clear files
  rm -f geo_em.d??.nc geogrid.log*
  # run with parallel processes
  echo "   Running geogrid.exe"
  eval "${GEOGRID}" # command specified in caller instance
fi
echo

## if not restarting, setup initial and run directories
if [[ "${RESTART}" == 'RESTART' ]]
 then # restart

  ## restart previous cycle
  cd "${INIDIR}/${NEXTSTEP}"
  echo "   Linking Restart Files:"
  for RST in ${WRFOUT}/wrfrst_d??_${NEXTSTEP}-??_??:??:??
   do
    echo  "${RST}"
    ln -sf "${RST}"
  done
  echo

 else # cold start

  ## start new cycle
  # clear some folders
  echo "   Clearing Output Folders:"
  if [[ -n ${METDATA} ]]; then
    echo "${METDATA}"
    if [[ "${MODE}" == 'CLEAN' ]]; then rm -rf "${METDATA}"; fi
    mkdir -p "${METDATA}"
  fi
  if [[ -n ${WRFOUT} ]]; then
    echo "${WRFOUT}"
    if [[ "${MODE}" == 'CLEAN' ]]; then rm -rf "${WRFOUT}"; fi
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
  if [[ "${NOTAR}" != 'NOTAR' ]]; then
    cd "${INIDIR}"
    rm -rf 'static/'
    mkdir -p 'static'
    echo $( cp -P * 'static/' &> /dev/null ) # trap this error and hide output
    cp -rL 'scripts/' 'bin/' 'meta/' 'tables/' 'static/'
    tar czf "${STATICTGZ}" 'static/'
    rm -r 'static/'
    mv "${STATICTGZ}" "${WRFOUT}"
    echo "   Saved backup file for static data:"
    echo "${WRFOUT}/${STATICTGZ}"
    echo
  fi # if not LASTSTEP==NOTAR

fi # if restart
