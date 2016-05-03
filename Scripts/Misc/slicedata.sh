#This is the script that will do the required data slicing
#This function is intended to be copied into the experiment folde and executed within.
#This script should serve as a template for further usage, instead of a completely tunned executable.

# load the modules required for this to run

module purge
module load intel/15.0.2 hdf5/1814-v18-serial-intel netcdf/4.3.3.1_serial-intel udunits/2.1.11 gsl/1.15-intel nco/4.4.8-intel
module list

#Generate variables that will be used

# data folder
WRFOUT="./wrfout/"    # output folder
SOURCEFILE="wrfxtrm"  # the file name of the WRF output file
DOMAIN="d02"          # the domain of the WRF output file

# make directory for the sliced data
mkdir ./wrfslice #this is to ensure its existence

WRFSLICE="./wrfslice/" # folder for data after slicing

# set up series for experiment times 
YEARS=$(seq -s' ' 1979 1988)
MONTHS=$(seq -s' ' -w 01 12)

# note here that DAY_HOUR is not specified since the output file are in a monthly format.

# generate variable list
VARIABLES="Times,T2MEAN,T2MIN,T2MAX,RAINCVMEAN,RAINNCVMEAN"

echo "Performing data slicing of variables ${VARIABLES} for month {MONTHS} in year ${YEARS}"

# do data slicing for different output files
for YEAR in ${YEARS}; do
  for MONTH in ${MONTHS}; do
    echo $YEAR-$MONTH
    ncks -4 -v ${VARIABLES} ${WRFOUT}${SOURCEFILE}_${DOMAIN}_$YEAR-$MONTH-01_00_00_00.nc ${WRFSLICE}wrfxtrmslice_d02_$YEAR-$MONTH-01_00_00_00.nc
  done
done

echo "Data Slicing for Year ${YEARS} and month ${MONTHS} are completed"