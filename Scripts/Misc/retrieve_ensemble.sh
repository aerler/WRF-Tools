#!/bin/bash

ROOT="$PWD"

## create folders for ensemble members
# loop over periods
for P in '' '-2050' '-2100'; do 
  cd "$ROOT/"
  echo "max-ctrl$P"
  mkdir -p max-ctrl$P
  cp -P setupExperiment.sh max-ctrl/xconfig.sh max-ctrl$P/    
  cd max-ctrl$P/
  # change name of experiment
  sed -i "/NAME/ s/max-ctrl/max-ctrl$P/" xconfig.sh
  # change stepfile accoring to period (stepfile is faster than dynamic generation)
  if [[ "$P" == '-2050' ]]; then
      sed -i "/CYCLING/ s/monthly.1979-1995/monthly.2045-2060/" xconfig.sh
  elif [[ "$P" == '-2100' ]]; then
      sed -i "/CYCLING/ s/monthly.1979-1995/monthly.2085-2100/" xconfig.sh
  fi # $P
  # N.B.: To actually rerun an experiment, we msy have to change much more!
  #       In particular, we need to change the DATADIR for forcing data.
  ./setupExperiment.sh > setupExperiment.log
  # loop over ensemble members
  for E in A B C; do 
    cd "$ROOT/"
    EXP="max-ens-$E$P"
    echo "$EXP"
    mkdir -p $EXP
    cp -P setupExperiment.sh max-ctrl$P/xconfig.sh $EXP/
    cd $EXP/
    sed -i "/NAME/ s/max-ctrl$P/$EXP/" xconfig.sh
    ./setupExperiment.sh > setupExperiment.log
  done
done

## retrieve surface fields of an ensemble from HPSS and launch post-processing
# loop over existing experiment folders
for E in max-{ctrl,ens-?}{,-2050,-2100}; do 
    cd "$ROOT/$E"
    echo "$E"
    # determin period
    if [[ $E = *-2100 ]]; then TAGS="$(seq -s \  2085 2099)";
    elif [[ $E = *-2050 ]]; then TAGS="$(seq -s \  2045 2059)";
    else TAGS="$(seq -s \  1979 1994)"; fi
    echo $E   $TAGS
    # launch retrieval and post-processing
    T=$(sbatch --export=DATASET=MISCDIAG,MODE=RETRIEVE,TAGS="$TAGS" ar_wrfout_fineIO.sb)
    echo $T
    ID=$(echo $T | cut -d \  -f4); sbatch  --time=03:00:00 --export=ADDVAR=ADDVAR --dependency=afterok:$ID run_wrf_avg.sb
done
