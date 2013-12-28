#!/bin/bash

export case=seaice-5r-hf

echo

for year in {2055..2059}
  do 

    echo year $year
    mkdir -p ${CCA}/${case}/atm/hist/${year}
    mkdir -p ${CCA}/${case}/lnd/hist/${year}
    mkdir -p ${CCA}/${case}/ice/hist/${year}
    
    mv ${CCR}/${case}/run/${case}.cam2.h1.${year}* ${CCA}/${case}/atm/hist/${year}/
    mv ${CCR}/${case}/run/${case}.clm2.h1.${year}* ${CCA}/${case}/lnd/hist/${year}/
    mv ${CCR}/${case}/run/${case}.cice.h1_inst.${year}* ${CCA}/${case}/ice/hist/${year}/
    mv ${CCR}/${case}/run/${case}.cice.h.${year}* ${CCA}/${case}/ice/hist/

done

echo
echo '   Done moving files - don'\''t forget to run the linking script!'
echo
