#!/bin/bash

# namelistfile as command line argument
NL=$1

# read radiation scheme
RAD=`sed -n '/ra_lw_physics/ s/.*= *\(.\),.*/\1/p' $NL`
if [[ $RAD == 1 ]]; then RAD='RRTM';
elif [[ $RAD == 3 ]]; then RAD='CAM';
elif [[ $RAD == 4 ]]; then RAD='RRTMG';
fi	
# read land surface model
LSM=`sed -n '/sf_surface_physics/ s/.*= *\(.\),.*/\1/p' $NL`
if [[ $LSM == 1 ]]; then LSM='Diff';
elif [[ $LSM == 2 ]]; then LSM='Noah';
elif [[ $LSM == 3 ]]; then LSM='RUC';
fi	 