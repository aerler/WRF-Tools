#!/bin/bash
# Bash script to pull/update all HG and SVN repositories
# Andre R. Erler, 2013, GPL v3, revised 30/11/2014

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o d:r:qpush --long dir:,recurse:,hg-only,pull-only,update-only,svn-only,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# set default parameters
ROOT="$PWD"
RECLEV=1
HGSYNC=1
HGPULL=1
HGUPDATE=1
SVNSYNC=1
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -d | --dir         )   ROOT=$2; shift 2;;
    -r | --recurse     )   RECLEV=$2; shift 2;;
    -q | --hg-only     )   SVNSYNC=0; shift;;
    -p | --pull-only   )   HGUPDATE=0; shift;;
    -u | --update-only )   HGPULL=0; shift;;
    -s | --svn-only    )   HGSYNC=0; shift;;
    -h | --help        )   echo -e " \
                            \n\
    -d | --dir           Specify root folder of repositories (default: current path) \n\
    -r | --recurse       Set a maximum level for recursing into sub-folders (default: 3) \n\
    -q | --hg-only       Only synchronize HG repositories \n\
    -p | --pull-only     Only run HG pull (no updates) \n\
    -u | --update-only   Only run HG update (no pull) \n\
    -s | --svn-only      Only synchronize SVN repositories \n\
    -h | --help          print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

# set search expression based on recursion level
PATTERN='*/ */*/ */*/*/' # globbing expressions for search
HGSRCX='' 
SVNSRCX=''
for L in $( seq $RECLEV ); do
  # check which patterns actually apply
  DIR="${ROOT}/$( echo "${PATTERN}" | cut -d ' ' -f ${L} )/"
  ls -d ${DIR}/.hg &> /dev/null # check if any HG repositories present
  [ $? -eq 0 ] && [ ${HGSYNC} -eq 1 ] && HGSRCX="${HGSRCX} ${DIR}/.hg" 
  ls -d ${DIR}/.svn &> /dev/null # check if any SVN repositories present
  [ $? -eq 0 ] && [ ${SVNSYNC} -eq 1 ] && SVNSRCX="${SVNSRCX} ${DIR}/.svn" 
done


ERR=0 # error counter
OK=0 # success counter

if [[ -n "${HGSRCX}" ]]; then
  # feedback
  echo
  echo "   ***   Updating HG Repositories   ***  "
  echo

  # update HG repositories (and pull)
  for HG in ${HGSRCX}
    do 
      LEC=0 # local error counter
      D=${HG%/.hg} # get parent of .hg folder
      echo ${D#"${ROOT}/"}
      cd "${D}"
      # pull & update repository
      if [ ${HGPULL} -eq 1 ]; then 
        hg pull
        [ $? -gt 0 ] && LEC=$(( $LEC + 1 ))
      fi # if pull
      if [ ${HGUPDATE} -eq 1 ]; then
        hg update
        [ $? -gt 0 ] && LEC=$(( $LEC + 1 ))
      fi # if update
      # evaluate results
      if [ ${LEC} -eq 0 ] 
        then OK=$(( ${OK} + 1 ))
        else ERR=$(( ${ERR} + 1 ))
      fi # if no error
      cd "${ROOT}" # back to root folder
      echo
  done
fi # if HG
  
if [[ -n "${SVNSRCX}" ]]; then
# feedback
echo
echo "   ***   Updating SVN Repositories   ***  "
echo

  # update SVN repositories (and pull)
  for HG in ${SVNSRCX}
    do 
      LEC=0 # local error counter
      D=${HG%/.svn} # get parent of .hg folder
      echo ${D#"${ROOT}/"}
      cd "${D}"
      # update repository
      svn update
      [ $? -gt 0 ] && LEC=$(( $LEC + 1 ))
      # evaluate results
      if [ ${LEC} -eq 0 ] 
        then OK=$(( ${OK} + 1 ))
        else ERR=$(( ${ERR} + 1 ))
      fi # if no error
      cd "${ROOT}" # back to root folder
      echo
  done
fi # if SVN

echo
if [ $ERR == 0 ]
  then
    echo "   <<<   ALL ${OK} UPDATES OK   >>>   "
    echo
    exit 0
  else
    echo "   ###   WARNING: ${ERR} UPDATES FAILED OR INCOMPLETE!   ###   "
    echo "   >>>                 ${OK} UPDATES OK                <<<   "
    echo
    exit ${ERR}
fi
