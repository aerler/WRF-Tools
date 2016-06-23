#!/bin/bash
# This script will do extraction of certain variables from WRF output files;
# it is intended to be copied into the experiment folder, modified according 
# to requirements and executed within the folder.
# Therefore this template is not executable.
# Fengyi Xie, 03/05/2016, GPL v3

# load the modules required for this to run

module purge
module load intel/15.0.2 hdf5/1814-v18-serial-intel netcdf/4.3.3.1_serial-intel udunits/2.1.11 gsl/1.15-intel nco/4.4.8-intel
module list

# settings

# data folder
WRFOUT="${PWD}/wrfout/"    # output folder
SOURCEFILE="wrfxtrm"  # the file name of the WRF output file
DOMAIN="d02"          # the domain of the WRF output file

# make directory for the sliced data

WRFEXT="${PWD}/wrfext/" # folder for data after slicing
mkdir -p "${WRFEXT}" # this is to ensure its existence

# set up series for experiment times 
YEARS=$(seq -s' ' 1979 1988)
MONTHS=$(seq -s' ' -w 01 12)

# note here that DAY_HOUR is not specified since the output file are in a monthly format.

# generate variable list
VARIABLES="Times,T2MEAN,T2MIN,T2MAX,RAINCVMEAN,RAINNCVMEAN"

echo "Performing extraction of variables ${VARIABLES} for month ${MONTHS} in year ${YEARS}"

ERR=0 # count errors
# do data extraction for different output files
for YEAR in ${YEARS}; do
  for MONTH in ${MONTHS}; do
    echo $YEAR-$MONTH
	  ncks -4 -v "${VARIABLES}" "${WRFOUT}/${SOURCEFILE}_${DOMAIN}_${YEAR}-${MONTH}-01"_??[:_]??[:_]??* "${WRFSLICE}/${SOURCEFILE}_${DOMAIN}_${YEAR}-${MONTH}-01_00:00:00.nc"
	  # the globbing expression is necessary, because the format is not consistent in all experiments
	  ERR=$(( ERR + 1 )) # count error
  done
done

# report
if [[ $ERR == 0 ]]
  then echo "Data Slicing for Year ${YEARS} and month ${MONTHS} are successful!"
  else echo "   WARNING: There were ${ERR} Error(s)!"
fi # if ERR == 0
# exit with errors as exit code
exit $ERR