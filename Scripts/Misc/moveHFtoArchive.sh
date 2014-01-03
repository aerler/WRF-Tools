#!/bin/bash

# seaice
CASES='seaice-5r-hf'
YEARS=$(seq 2055 2060)
# ensemble 2100
#CASES='habrcp85cn1x1d hbbrcp85cn1x1d hcbrcp85cn1x1d'
#YEARS=$(seq 2085 2100)

date
echo
echo Settings:
echo "  CASES: $CASES" 
echo "  YEARS: $YEARS"
echo

for YEAR in $YEARS
  do 

    echo "YEAR: $YEAR"

    for CASE in $CASES
      do
    
        echo "CASE: $CASE"
    
        mkdir -p ${CCA}/${CASE}/atm/hist/${YEAR}
        mkdir -p ${CCA}/${CASE}/lnd/hist/${YEAR}
        mkdir -p ${CCA}/${CASE}/ice/hist/${YEAR}
        
        mv ${CCR}/${CASE}/run/${CASE}.cam2.h1.${YEAR}* ${CCA}/${CASE}/atm/hist/${YEAR}/
        mv ${CCR}/${CASE}/run/${CASE}.clm2.h1.${YEAR}* ${CCA}/${CASE}/lnd/hist/${YEAR}/
        mv ${CCR}/${CASE}/run/${CASE}.cice.h1_inst.${YEAR}* ${CCA}/${CASE}/ice/hist/${YEAR}/
        mv ${CCR}/${CASE}/run/${CASE}.cice.h.${YEAR}* ${CCA}/${CASE}/ice/hist/
    
    done # CASES

    echo

done # YEARS

echo
date
echo '   Done moving files - running linking script!'
echo
export CASES
export YEARS
./linkYears.sh
