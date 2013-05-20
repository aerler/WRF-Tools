#!/bin/bash

export case=seaice-3r-hf

for year in {2045..2060}
  do
    
    echo year $year
    til=../${year}
    
    ## atmosphere files
    lstyr=$(($year-1))
    tt=$CCA/${case}/atm/hist/${lstyr}
    ti=$CCA/${case}/atm/hist/${year}
    if [ -e $tt ] && [ -e $ti ] ; then
      #echo linking ${case}.cam2.h1.${year}-01-01-00000.nc to the previous year directory
      ln -s $til/${case}.cam2.h1.${year}-01-01-00000.nc $tt/
      ls -l $tt/*${year}-01-01-00000.nc
    elif [ ! -e $tt ] && [ -e $ti ] ; then
      #echo linking ${case}.cam2.h1.${year}-01-01-21600.nc to linking ${case}.cam2.h1.${year}-01-01-00000.nc
      ln -s ${case}.cam2.h1.${year}-01-01-21600.nc $ti/${case}.cam2.h1.${year}-01-01-00000.nc
      ls -l $ti/*${year}-01-01-00000.nc
    elif [ -e $tt ] && [ ! -e $ti ] ; then
      #echo linking ${case}.cam2.h1.${lstyr}-12-31-64800.nc to linking ${case}.cam2.h1.${year}-01-01-00000.nc
      ln -s ${case}.cam2.h1.${lstyr}-12-31-64800.nc $tt/${case}.cam2.h1.${year}-01-01-00000.nc
      ls -l $tt/*${year}-01-01-00000.nc
    fi
    
    ## land files
    lstyr=$(($year-1))
    tt=$CCA/${case}/lnd/hist/${lstyr}
    ti=$CCA/${case}/lnd/hist/${year}
    if [ -e $tt ] && [ -e $ti ] ; then
      #echo linking ${case}.clm2.h1.${year}-01-01-00000.nc to the previous year directory
      ln -s $til/${case}.clm2.h1.${year}-01-01-00000.nc $tt/
      ls -l $tt/*${year}-01-01-00000.nc
    elif [ ! -e $tt ] && [ -e $ti ] ; then
      #echo linking ${case}.clm2.h1.${year}-01-01-21600.nc to linking ${case}.clm2.h1.${year}-01-01-00000.nc
      ln -s ${case}.clm2.h1.${year}-01-01-21600.nc $ti/${case}.clm2.h1.${year}-01-01-00000.nc
      ls -l $ti/*${year}-01-01-00000.nc
    elif [ -e $tt ] && [ ! -e $ti ] ; then
      #echo linking ${case}.clm2.h1.${lstyr}-12-31-64800.nc to linking ${case}.clm2.h1.${year}-01-01-00000.nc
      ln -s ${case}.clm2.h1.${lstyr}-12-31-64800.nc $tt/${case}.clm2.h1.${year}-01-01-00000.nc
      ls -l $tt/*${year}-01-01-00000.nc
    fi
    
    ## ice files
    lstyr=$(($year-1))
    tt=$CCA/${case}/ice/hist/${lstyr}
    ti=$CCA/${case}/ice/hist/${year}
    if [ -e $tt ] && [ -e $ti ] ; then
      #echo linking ${case}.cice.h1_inst.${year}-01-01-00000.nc to the previous year directory
      ln -s $til/${case}.cice.h1_inst.${year}-01-01-00000.nc $tt/
      ls -l $tt/*${year}-01-01-00000.nc
    elif [ ! -e $tt ] && [ -e $ti ] ; then
      #echo linking ${case}.cice.h1_inst.${year}-01-01-21600.nc to linking ${case}.cice.h1_inst.${year}-01-01-00000.nc
      ln -s ${case}.cice.h1_inst.${year}-01-01-21600.nc $ti/${case}.cice.h1_inst.${year}-01-01-00000.nc
      ls -l $ti/*${year}-01-01-00000.nc
    elif [ -e $tt ] && [ ! -e $ti ] ; then
      #echo linking ${case}.cice.h1_inst.${lstyr}-12-31-64800.nc to linking ${case}.cice.h1_inst.${year}-01-01-00000.nc
      ln -s ${case}.cice.h1_inst.${lstyr}-12-31-64800.nc $tt/${case}.cice.h1_inst.${year}-01-01-00000.nc
      ls -l $tt/*${year}-01-01-00000.nc
    fi
    
done

