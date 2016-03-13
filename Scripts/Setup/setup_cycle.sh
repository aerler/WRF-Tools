#!/bin/bash
# short script to setup a new experiment and/or re-link restart files
# Andre R. Erler, 02/03/2013, GPL v3

VERBOSITY=${VERBOSITY:-1} # output verbosity

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
if [ $VERBOSITY -gt 0 ]; then
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
	echo "   Root Dir: ${INIDIR}"
	echo
fi # $VERBOSITY
cd "${INIDIR}"

## run geogrid
if [[ "${NOGEO}" == 'NOGEO' ]]
 then
  [ $VERBOSITY -gt 0 ] && echo "   Not running geogrid.exe"
 else
  # clear files
  rm -f geo_em.d??.nc geogrid.log*
  # run with parallel processes
  [ $VERBOSITY -gt 0 ] && echo "   Running geogrid.exe (suppressing output)"
  if [ $VERBOSITY -gt 1 ]
    then eval "${RUNGEO}" # command specified in caller instance
    else eval "${RUNGEO}" > /dev/null # swallow output
  fi # $VERBOSITY
fi
[ $VERBOSITY -gt 0 ] && echo

## if not restarting, setup initial and run directories
if [[ "${RESTART}" == 'RESTART' ]]; then # restart

  ## restart previous cycle
  # read date string for restart file
    RSTDATE=$(sed -n "/${NEXTSTEP}/ s/${NEXTSTEP}[[:space:]]\+'\([-_\:0-9]\{19\}\)'[[:space:]]\+'[-_\:0-9]\{19\}'$/\1/p" stepfile)
  NEXTDIR="${INIDIR}/${NEXTSTEP}" # next $WORKDIR
  cd "${NEXTDIR}"
  # link restart files
  [ $VERBOSITY -gt 0 ] && echo "Linking restart files to next working directory:"
  [ $VERBOSITY -gt 0 ] && echo "${NEXTDIR}"
  for RST in "${WRFOUT}"/wrfrst_d??_${RSTDATE//:/[_:]}; do # match hh:mm:ss and hh_mm_ss
    ln -sf "${RST}" 
    [ $VERBOSITY -gt 0 ] && echo  "${RST}"
  done

else # cold start

  ## start new cycle
  cd "${INIDIR}"
  # clear some folders
  [ $VERBOSITY -gt 0 ] && [[ "${MODE}" == 'CLEAN' ]] && echo "   Clearing Output Folders:"
  if [[ -n ${METDATA} ]]; then
    if [[ "${MODE}" == 'CLEAN' ]]; then 
      [ $VERBOSITY -gt 0 ] && echo "${METDATA}"
      rm -rf "${METDATA}" 
    fi
    mkdir -p "${METDATA}" # will fail, if path depends on job step, but can be ignored
  fi
  if [[ -n ${WRFOUT} ]]; then
    if [[ "${MODE}" == 'CLEAN' ]]; then 
	    [ $VERBOSITY -gt 0 ] && echo "${WRFOUT}"
      rm -rf "${WRFOUT}" 
    fi
    mkdir -p "${WRFOUT}"
  fi
  if [[ "${MODE}" == 'CLEAN' ]] && [ -f stepfile ]; then
    # remove all existing step folders
    for STEP in $( awk '{print $1}' stepfile ); do
      if [[ "${STEP}" == "${NEXTSTEP}" ]]; then
        # special treatment for next step: need to preserve dates in namelists
        mv "${NEXTSTEP}/namelist.input" 'zzz.input'; mv "${NEXTSTEP}/namelist.wps" 'zzz.wps'
        [ $VERBOSITY -gt 0 ] && echo "${STEP}"
        rm -r "${STEP}"; mkdir "${STEP}"
        mv 'zzz.input' "${NEXTSTEP}/namelist.input"; mv 'zzz.wps' "${NEXTSTEP}/namelist.wps"
      elif [ -e "${STEP}/" ]; then
        [ $VERBOSITY -gt 0 ] && echo "${STEP}"
        rm -r "${STEP}"
      fi # if -e $STEP   
    done # loop over all steps
  fi
  [ $VERBOSITY -gt 0 ] && echo

  # prepare first working directory
  # set restart to False for first step
  sed -i '/restart\ / s/restart\ *=\ *\.true\..*$/restart = .false.,/' "${NEXTSTEP}/namelist.input"
  # and make sure the rest is on restart
  sed -i '/restart\ / s/restart\ *=\ *\.false\..*$/restart = .true.,/' "namelist.input"
  [ $VERBOSITY -gt 0 ] && echo "   Setting restart option and interval in namelist."


  # create backup of static files
  if [[ "${NOTAR}" != 'NOTAR' ]]; then
    cd "${INIDIR}"
    rm -rf 'static/'
    mkdir -p 'static'
    echo $( cp -P * 'static/' &> /dev/null ) # trap this error and hide output
    cp -rL 'scripts/' 'bin/' 'meta/' 'tables/' 'static/'
    tar cf - 'static/' | gzip > "${STATICTGZ}"
    rm -r 'static/'
    mv "${STATICTGZ}" "${WRFOUT}"
    if [ $VERBOSITY -gt 0 ]; then
	    echo "   Saved backup file for static data:"
	    echo "${WRFOUT}/${STATICTGZ}"
	    echo
    fi # $VERBOSITY
  fi # if not LASTSTEP==NOTAR

fi # if restart
[ $VERBOSITY -gt 0 ] && echo
