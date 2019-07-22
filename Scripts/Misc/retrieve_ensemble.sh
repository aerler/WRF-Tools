#!/bin/bash

## create folders for ensemble members
# loop over periods
for P in '' '-2050' '-2100'; do 
  # generate max-ctrl-* experiments - untested!!!
  mkdir max-ctrl$P
  cp -P setupExperiment.sh max-ctrl/xconfig.sh max-ctrl$P/    
  cd max-ctrl$P/
  # change name of experiment
  sed -i "/NAME/ s/max-ctrl/max-ctrl$P/" xconfig.sh
  # N.B.: to actually rerun an experiment, we have to change much more!
  ./setupExperiment.sh > setupExperiment.log
  # loop over ensemble members
  for E in A B C; do 
    mkdir max-ens-$E$P
    cp -P setupExperiment.sh max-ctrl$P/xconfig.sh $E$P    
    cd $E$P/
    sed -i "/NAME/ s/max-ctrl$P/max-ens-$E$P/" xconfig.sh
    ./setupExperiment.sh > setupExperiment.log
  done
done

## retrieve surface fields of an ensemble from HPSS and launch post-processing
# loop over existing experiment folders
for E in max-{ctrl,ens-?}{,-2050,-2100}; do 
    cd $WC/$E 
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
