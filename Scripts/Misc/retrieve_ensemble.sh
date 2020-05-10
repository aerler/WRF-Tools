#!/bin/bash
# Andre R. Erler, 28/04/2020
# script to restrieve and archived WRF ensemble and launch post-processing

# pre-process arguments using getopt
if [ -z $( getopt -T ) ]; then
  TMP=$( getopt -o sqe:dox:h --long root-folder:,ensemble:,no-setup,no-queue,dry-run,override,xconfig:,help -n "$0" -- "$@" ) # pre-process arguments
  [ $? != 0 ] && exit 1 # getopt already prints an error message
  eval set -- "$TMP" # reset positional parameters (arguments) to $TMP list
fi # check if GNU getopt ("enhanced")
# default parameters
ROOT="$PWD" # root folder for experiments
ENS='max' # default name of the ensemble, as in 'max-ctrl'
SETUP=1 # run experiment setup 
QUEUE=1 # submit jobs to queue
DRYRUN=0 # don't actuall execute/submit
OVERRIDE=0 # respect RETRIEVAL_OK indicator
XCONFIG='xconfig.sh' # template xconfig file for ensemble
# parse arguments
#while getopts 'fs' OPTION; do # getopts version... supports only short options
while true; do
  case "$1" in
    -s | --no-setup    )   SETUP=0; shift;;
    -q | --no-queue    )   QUEUE=0; shift;;
         --root-folder )   ROOT="$2"; shift 2;;
    -e | --ensemble    )   ENS="$2"; shift 2;;
    -d | --dry-run     )   DRYRUN=1; shift;;
    -o | --override    )   OVERRIDE=1; shift;;
    -x | --xconfig     )   XCONFIG="$2"; shift 2;;
    -h | --help        )   echo -e " \
                            \n\
    -s | --no-setup      do not run setupExperiment script (skip setup) \n\
    -q | --no-queue      do not submit jobs to the queue (just setup) \n\
         --root-folder   root folder for experiments \n\
    -e | --ensemble      name of the ensemble (default: 'max') \n\
    -d | --dry-run       do not actually execute setup or submit jobs \n\
    -o | --override      ignore indicator files and execute all \n\
    -x | --xconfig       xconfig template file (default: '\$ROOT/xconfig.sh')  \n\
    -h | --help          print this help \n\
                             "; exit 0;; # \n\ == 'line break, next line'; for syntax highlighting
    -- ) shift; break;; # this terminates the argument list, if GNU getopt is used
    * ) break;;
  esac # case $@
done # while getopts  

#  base ensemble name
echo
# define extension for control members
if [[ "$ENS" == 'ctrl' ]]; then CX=''
else CX="-ctrl"; fi
BASE="$ENS$CX" # assemble ensemble control base name
echo "Ensemble basename: $BASE "
echo " xconfig template: $XCONFIG"
echo

# make sure the archive interval is correct, or things are not going to work...
ARINT="$( grep 'ARINTERVAL' $XCONFIG )"
if [[ "$ARINT" != *YEARLY* ]]; then echo -e "\033[0;31m$ARINT\033[0m\n"; fi

## create folders for ensemble members
if [ $SETUP -gt 0 ]; then
    # loop over periods
    for P in '' '-2050' '-2100'; do 
        cd "$ROOT/"
        CTRL="$BASE$P" # control/master experiment of ensemble
        echo "$CTRL"
        mkdir -p "$CTRL/"
        cp -P setupExperiment.sh "$CTRL/"    
        cp "$XCONFIG" "$CTRL/xconfig.sh" # the name 'xconfig.sh' is hard-coded anyway
        cd "$CTRL/"
        # change name of experiment
        sed -i "/NAME/ s/$BASE/$CTRL/" xconfig.sh
        # change stepfile accoring to period (stepfile is faster than dynamic generation)
        if [[ "$P" == '-2050' ]]; then
            sed -i "/CYCLING/ s/monthly.1979-1995/monthly.2045-2060/" xconfig.sh
        elif [[ "$P" == '-2100' ]]; then
            sed -i "/CYCLING/ s/monthly.1979-1995/monthly.2085-2100/" xconfig.sh
        fi # $P
        # N.B.: To actually rerun an experiment, we msy have to change much more!
        #       In particular, we need to change the DATADIR for forcing data.
        if [ $DRYRUN -eq 0 ]; then
            ./setupExperiment.sh > setupExperiment.log
        else
            echo "DRYRUN: ./setupExperiment.sh > setupExperiment.log"
        fi # $DRYRUN
        # loop over ensemble members
        for E in A B C; do 
            cd "$ROOT/"
            EXP="$ENS-ens-$E$P"
            echo "$EXP"
            mkdir -p "$EXP"
            cp -P setupExperiment.sh "$CTRL/xconfig.sh" "$EXP/"
            cd "$EXP/"
            sed -i "/NAME/ s/$CTRL/$EXP/" xconfig.sh
            if [ $DRYRUN -eq 0 ]; then
                ./setupExperiment.sh > setupExperiment.log
            else
                echo "DRYRUN: ./setupExperiment.sh > setupExperiment.log"
            fi # $DRYRUN
        done
    done
    echo
fi # $SETUP

## retrieve surface fields of an ensemble from HPSS and launch post-processing
if [ $QUEUE -gt 0 ]; then
    cd "$ROOT"
    # loop over existing experiment folders
    for E in $ENS{$CX,-ens-?}{,-2050,-2100}; do 
        cd "$ROOT/$E"
        echo "   ***   $E   ***   "
        if [ -e RETRIEVAL_OK ] && [ $OVERRIDE -eq 0 ]; then
            echo "   Retrieval already complete."
        else
            # determine period
            if [[ $E = *-2100 ]]; then TAGS="$(seq -s \  2085 2099)";
            elif [[ $E = *-2050 ]]; then TAGS="$(seq -s \  2045 2059)";
            else TAGS="$(seq -s \  1979 1994)"; fi
            echo $E   $TAGS
            if [ $DRYRUN -eq 0 ]; then
                # launch retrieval: static data and surface diagnotics
                T=$(sbatch --export=DATASET=MISCDIAG,MODE=RETRIEVE,TAGS="$TAGS" ar_wrfout_fineIO.sb)
                echo "$T"
                S=$(sbatch --export=DATASET=FINAL,MODE=RETRIEVE,TAGS=FINAL ar_wrfout_fineIO.sb)
                echo "$S"
                # launch post-processing, dependent on retrieval
                IDT=$(echo $T | cut -d \  -f4); IDS=$(echo $S | cut -d \  -f4)
                sbatch  --time=03:00:00 --export=ADDVAR=ADDVAR --dependency=afterok:$IDT:$IDS run_wrf_avg.sb
            else
                # print queue submittion commands
                echo "DRYRUN: sbatch --export=DATASET=MISCDIAG,MODE=RETRIEVE,TAGS="$TAGS" ar_wrfout_fineIO.sb"
                echo "DRYRUN: sbatch --export=DATASET=FINAL,MODE=RETRIEVE,TAGS=FINAL ar_wrfout_fineIO.sb)"
                echo "DRYRUN: sbatch --time=03:00:00 --export=ADDVAR=ADDVAR --dependency=afterok:MID:FID run_wrf_avg.sb" 
            fi # $DRYRUN
        fi # -e RETRIEVAL_OK
    done
    echo
fi # $QUEUE
