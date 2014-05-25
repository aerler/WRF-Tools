#!/bin/bash
# Andre R. Erler, 25/05/2014
# script to rerun setup script for all experiments (subfolders withxconfig.sh file)

# shell options
set -o pipefail # return highest exit status in pipe

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o vqth --long wrftools:,errorlog:,verbose,quiet,test,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# default parameters
ERRLOG='setup_errors.log'
WRFTOOLS=${WRFTOOLS:-"${MODEL_ROOT}/WRF Tools/"} # setup source folder
VERBOSITY=1 # show setup output 
TEST=0 # do not actually restart, just print parameters
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
         --wrftools )   WRFTOOLS="$2"; shift 2;;
         --errorlog )   ERRLOG="$2";   shift 2;;
    -v | --verbose  )   VERBOSITY=2;   shift;;
    -q | --quiet    )   VERBOSITY=0;   shift;;
    -t | --test     )   TEST=1;        shift;;
    -h | --help     )   echo -e " \
                            \n\
         --wrftools     WRF Tools folder \n\
         --errorlog     fileto write error log \n\
    -v | --verbose      print setup output \n\
    -q | --quiet        do not print any feedback \n\
    -t | --test         dry-run for tests; just print parameters \n\
    -h | --help         print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

ERR=0
# load job/experiment parameters
INIDIR=${INIDIR:-"${PWD}"}

cd "$INIDIR" # make sure that this is the current directory
rm -f "$ERRLOG" # clear error logs

# loop over subfolders
for EE in */;do 

  # identify experiment folders
  if [ -f "$INIDIR/$EE/xconfig.sh" ]; then
    [ $VERBOSITY -gt 0 ] && echo
    
    E=${EE%/} 
    [ $VERBOSITY -gt 0 ] && echo $E
    cd "$INIDIR/$E/" 
    ln -sf "$WRFTOOLS/Scripts/Setup/setupExperiment.sh" # update link
    if [ $TEST -gt 0 ]; then
      ls setupExperiment.sh xconfig.sh | tee setup.log
      EC=1 # always record error
    elif [ $VERBOSITY -gt 1 ]; then
      ./setupExperiment.sh | tee setup.log
      EC=$?
    else
      ./setupExperiment.sh &> setup.log
      EC=$?
    fi # $VERBOSITY
    # record errors
    if [ $EC -gt 0 ]; then 
      ERR=$(( $ERR + 1 ))
      [ $VERBOSITY -gt 0 ] && echo "ERROR in Experiment $E" 
      echo $E >> "$INIDIR/$ERRLOG"
    fi # if $EC
    
    [ $VERBOSITY -gt 0 ] && echo
  fi # if xconfig
done

cd "$INIDIR"

# report errors
if [ ${ERR} -gt 0 ]; then
  if [ $VERBOSITY -gt 0 ]; then
    echo
    echo "ERROR: $ERR Errors(s) occured!"
    echo "(see $ERRLOG for details)"
    echo
  fi
  exit $ERR
else
  exit 0
fi # summary
