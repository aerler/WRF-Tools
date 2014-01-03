#!/bin/bash

date
echo
echo Settings:

if [[ -z "$CASES" ]] || [[ -z "$YEARS" ]]
  then

    # seaice
    CASES='seaice-5r-hf'
    YEARS=$(seq 2055 2060)
    # ensemble 2100
    #CASES='habrcp85cn1x1d hbbrcp85cn1x1d hcbrcp85cn1x1d'
    #YEARS=$(seq 2085 2100)

  else

    echo '(inherited from caller)'	  

fi # CASES & YEARS

echo "  CASES: $CASES" 
echo "  YEARS: $YEARS"
echo

# start loop
for YEAR in $YEARS
  do 

    echo "YEAR: $YEAR"

    for CASE in $CASES
      do
    
        echo "CASE: $CASE"
    
        mkdir -p ${CCA}/${CASE}/atm/hist/${YEAR}
        mkdir -p ${CCA}/${CASE}/lnd/hist/${YEAR}
        mkdir -p ${CCA}/${CASE}/ice/hist/${YEAR}

        til=../${YEAR}
        
        ## atmosphere files
        lstyr=$((${YEAR}-1))
        tt=${CCA}/${CASE}/atm/hist/${lstyr}
        ti=${CCA}/${CASE}/atm/hist/${YEAR}
        if [ -e ${tt} ] && [ -e ${ti} ] ; then
          #echo linking ${CASE}.cam2.h1.${YEAR}-01-01-00000.nc to the previous year directory
          ln -s ${til}/${CASE}.cam2.h1.${YEAR}-01-01-00000.nc ${tt}/
          ls -l ${tt}/*${YEAR}-01-01-00000.nc
        elif [ ! -e ${tt} ] && [ -e ${ti} ] ; then
          #echo linking ${CASE}.cam2.h1.${YEAR}-01-01-21600.nc to linking ${CASE}.cam2.h1.${YEAR}-01-01-00000.nc
          ln -s ${CASE}.cam2.h1.${YEAR}-01-01-21600.nc ${ti}/${CASE}.cam2.h1.${YEAR}-01-01-00000.nc
          ls -l ${ti}/*${YEAR}-01-01-00000.nc
        elif [ -e ${tt} ] && [ ! -e ${ti} ] ; then
          #echo linking ${CASE}.cam2.h1.${lstyr}-12-31-64800.nc to linking ${CASE}.cam2.h1.${YEAR}-01-01-00000.nc
          ln -s ${CASE}.cam2.h1.${lstyr}-12-31-64800.nc ${tt}/${CASE}.cam2.h1.${YEAR}-01-01-00000.nc
          ls -l ${tt}/*${YEAR}-01-01-00000.nc
        fi
        
        ## land files
        lstyr=$((${YEAR}-1))
        tt=${CCA}/${CASE}/lnd/hist/${lstyr}
        ti=${CCA}/${CASE}/lnd/hist/${YEAR}
        if [ -e ${tt} ] && [ -e ${ti} ] ; then
          #echo linking ${CASE}.clm2.h1.${YEAR}-01-01-00000.nc to the previous year directory
          ln -s ${til}/${CASE}.clm2.h1.${YEAR}-01-01-00000.nc ${tt}/
          ls -l ${tt}/*${YEAR}-01-01-00000.nc
        elif [ ! -e ${tt} ] && [ -e ${ti} ] ; then
          #echo linking ${CASE}.clm2.h1.${YEAR}-01-01-21600.nc to linking ${CASE}.clm2.h1.${YEAR}-01-01-00000.nc
          ln -s ${CASE}.clm2.h1.${YEAR}-01-01-21600.nc ${ti}/${CASE}.clm2.h1.${YEAR}-01-01-00000.nc
          ls -l ${ti}/*${YEAR}-01-01-00000.nc
        elif [ -e ${tt} ] && [ ! -e ${ti} ] ; then
          #echo linking ${CASE}.clm2.h1.${lstyr}-12-31-64800.nc to linking ${CASE}.clm2.h1.${YEAR}-01-01-00000.nc
          ln -s ${CASE}.clm2.h1.${lstyr}-12-31-64800.nc ${tt}/${CASE}.clm2.h1.${YEAR}-01-01-00000.nc
          ls -l ${tt}/*${YEAR}-01-01-00000.nc
        fi
        
        ## ice files
        lstyr=$((${YEAR}-1))
        tt=${CCA}/${CASE}/ice/hist/${lstyr}
        ti=${CCA}/${CASE}/ice/hist/${YEAR}
        if [ -e ${tt} ] && [ -e ${ti} ] ; then
          #echo linking ${CASE}.cice.h1_inst.${YEAR}-01-01-00000.nc to the previous year directory
          ln -s ${til}/${CASE}.cice.h1_inst.${YEAR}-01-01-00000.nc ${tt}/
          ls -l ${tt}/*${YEAR}-01-01-00000.nc
        elif [ ! -e ${tt} ] && [ -e ${ti} ] ; then
          #echo linking ${CASE}.cice.h1_inst.${YEAR}-01-01-21600.nc to linking ${CASE}.cice.h1_inst.${YEAR}-01-01-00000.nc
          ln -s ${CASE}.cice.h1_inst.${YEAR}-01-01-21600.nc ${ti}/${CASE}.cice.h1_inst.${YEAR}-01-01-00000.nc
          ls -l ${ti}/*${YEAR}-01-01-00000.nc
        elif [ -e ${tt} ] && [ ! -e ${ti} ] ; then
          #echo linking ${CASE}.cice.h1_inst.${lstyr}-12-31-64800.nc to linking ${CASE}.cice.h1_inst.${YEAR}-01-01-00000.nc
          ln -s ${CASE}.cice.h1_inst.${lstyr}-12-31-64800.nc ${tt}/${CASE}.cice.h1_inst.${YEAR}-01-01-00000.nc
          ls -l ${tt}/*${YEAR}-01-01-00000.nc
        fi
    

    done # CASES

done # YEARS

echo
date
echo
