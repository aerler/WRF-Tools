#!/bin/bash

# Author: Guido Vettoretti - 2015-11-12
# This script is used for calculating monthly maximum Temperature and Precipitation from
# daily Temperature and Precipitation maximum timeseries and then appending to monthly data.
# A timeseries of the monthly min/max for a series of years is also created.

function usage {
  echo 'Usage : calc_cesm_monmax.sh -z "<nco_options>" -d <data_directory> -c casename -s startyear -e endyear'
}

function usage {
	echo
	echo 'This script is used to create a timeseries of monthly min and max Temperature and Precipitation'
	echo 'from daily min/maxs timeseries of ATM CCSM4/CESM1 files'
	echo 
	echo 'Usage: calc_monmax takes 4 parameters'
	echo '-d, --dir         = archive directory containing monthly and daily data'
	echo '-c, --case        = case name'
	echo '-s, --startyear   = starting year e.g. 0'
	echo '-e, --endyear     = ending year e.g. 999'
	echo '-z, --ncoopts     = options to pass to nco operator in final timeseries creation (monthly model files are not altered yet)'
	echo '-h, --help        = this message'
	echo ''
	echo 'Examples:'
	echo 'To make timeseries of atm data from years 500 to 1500 and put the output in $SCRATCH'
	echo 'Using data from monthly files in the input directory $RES with no compression and netcdf format unchanged'
	echo '--> calc_monmax -z "" -d $RES/archive -c case -s 500 -e 1499 2>&1 /tmp/logfile'
	echo 'for netcdf4 format and Lemel-Ziv level 1 compression'
	echo '--> calc_monmax -z "-4 -L1" -d $RES/archive -c case -s 500 -e 1499 2>&1 /tmp/logfile'
	echo ''
	echo 'Data will be input from $RES/archive/$case/atm/hist'
	echo 'Data will be output to same directory'
	echo ''
	echo 'Note: A min of 1 year of monthly data will be used (=12 files) if it exists'
	echo 'e.g. (this script works on years)'
}

#get command line options

#number of command line arguments:
clargs=$#

# check stdin
while [[ $# > 1 ]]
do
  key="$1"

  case $key in
    -h|--help)
      comp_switch="$2"
      usage
      exit 1
      ;;
    -d|--dir)
      resarch="$2"
      shift
      ;;
    -c|--case)
      case="$2"
      shift
      ;;
    -s|--startyear)
      startyr="$2"
      shift
      ;;
    -e|--endyear)
      endyr="$2"
      shift
      ;;
    -z|--compression)
      comp_switch="$2"
      shift
      ;;
    *)
      # unknown option; exit 1
      echo "unknown option"
      usage
      exit 1
      ;;
  esac
  shift
done

#echo $clargs

if [ "$clargs" -lt 10 ]
then
  usage
  exit 1
fi

# set some variables for month length and day length
logdir=$(pwd)
styr4d=$(printf "%04d" ${startyr})
endyr4d=$(printf "%04d" ${endyr})
dpm=(31 28 31 30 31 30 31 31 30 31 30 31) #days per month
doy=(1 32 60 91 121 152 182 213 244 274 305 335) #day of the year that month starts at

echo
echo "Case Name        = $case"
echo "Start Year       = $styr4d"
echo "End Year         = $endyr4d"
echo "Input Directory  = $resarch"
echo "Compression      = $comp_switch"
echo
echo "Starting timeseries creation..."
echo



# Machine specific load modules
if [ $MACH = "tcs" ] ; then
  module purge
  module load ncl nco cdo/1.6.1
fi
if [ $MACH = "gpc" ] ; then
  module purge
  module load intel/13.1.1 gcc/4.6.1 udunits/2.1.11 gsl/1.13-intel hdf5/187-v18-serial-intel  netcdf/4.1.3_hdf5_serial-intel python/2.7.5  
  module load extras/64_6.4 cdo/1.6.1-intel nco/4.3.2-intel
  module load ncl
fi 

# function to count number of elements in variable seperated by space
howmany() { echo $#; }

# set the working directory (this needs to be changed if your cesm model output location changes)

#dd=${resarch}/CESM/archive/${case}/atm/hist  #diagnostic data directory (output)
#dd=${resarch}/${case}/atm/hist  #diagnostic data directory (output)
dd=${resarch}
if [ ! -d $dd ] ;
then
    echo "Error: atmospheric model directory $dd does not exist"
    exit 1
fi


# Cycle through all the montly data and daily data and calculate monthly max statistics
echo "Creating Monthly Min/Max variables from daily data..."

### ATM ###
monpre="cam2.h0" # monthly file notation
ddpre="cam2.h2" # daily file notation
modpp="cam2"
mod="atm"
# set blank variable for component timeseries file lists 
timeseries=
outyears=${case}.${modpp}.${styr4d}-${endyr4d}_minmax.nc # name of the yearly min/max file

i=$startyr
while [ $i -le $endyr ]
do
	i4d=$(printf "%04d" ${i})
	echo "["$(date +"%Y-%m-%d %H:%M:%S")"] Creating min/max (by month length) for each month for year: ${i}..."
	for mth in {0..11}; do
		#echo -ne .
		mmp1=$(expr $mth + 1)
		mm=$(printf "%02d" ${mmp1})
			 
		echo "${case}.${monpre}.${i4d}-${mm}.nc" # indicate which file is being worked on
		cd $dd # move into the model data dir
		mstime=$(expr ${doy[${mth}]} - 1)
		mftime=$(expr ${doy[${mth}]} + ${dpm[${mth}]})
		mftime=$(expr $mftime - 2)
		#echo $mstime $mftime
		outyearmonth=${case}.${modpp}.${i4d}-${mm}_minmax.nc # name of the yearly-month min/max file
		modelmonth=${case}.${monpre}.${i4d}-${mm}.nc # model monthly averaged file
	    # Check that the file has not been created in a previous run
		if [ ! -f $outyearmonth ] ; then
			# extract minmax variables 
			ncks -O -d time,${mstime},${mftime} -v PRECTMX,TREFHTMN,TREFHTMX ${case}.${ddpre}.${i4d}-01-02-00000.nc ${case}.${ddpre}.${i4d}-${mm}_dd.nc # TSMN,TSMX not present in all
			for minvar in TREFHTMN ; do # ,TSMN,TSMX
				ncra -O -v $minvar -y min ${case}.${ddpre}.${i4d}-${mm}_dd.nc ${case}.${ddpre}.${i4d}-${minvar}.nc
			done
			for maxvar in PRECTMX TREFHTMX ; do #  TSMX
				ncra -O -v $maxvar -y max ${case}.${ddpre}.${i4d}-${mm}_dd.nc ${case}.${ddpre}.${i4d}-${maxvar}.nc
			done
			# append into file with monthly min-max
			for minmaxvar in TREFHTMN TREFHTMX ; do # TSMN TSMX
				ncks -A ${case}.${ddpre}.${i4d}-${minmaxvar}.nc ${case}.${ddpre}.${i4d}-PRECTMX.nc
			done
			mv ${case}.${ddpre}.${i4d}-PRECTMX.nc $outyearmonth
			# take time and time bounds off of monthly average files then replace/append to minmax file
			#ncks -v time,time_bnds ${case}.${monpre}.${i4d}-${mm}.nc montime.nc
			#ncks -A montime.nc $outyearmonth
			#rm montime.nc
			ncks -A -v time,time_bnds $modelmonth $outyearmonth
			# append onto original monthly file
			ncks -A $outyearmonth $modelmonth
			# remove temp files
			for minmaxvar in TREFHTMN TREFHTMX ; do # TSMN TSMX
				rm ${case}.${ddpre}.${i4d}-${minmaxvar}.nc
			done
			rm ${case}.${ddpre}.${i4d}-${mm}_dd.nc 
		else
			echo "Found file: " $outyearmonth
		fi
		timeseries="$timeseries $outyearmonth"

	done

	i=$(expr $i + 1)
done

#use command for large number of files
echo $timeseries | ncrcat -O ${comp_switch} ${outyears}
if [ "$?" -ne 0 ] ; then
	echo "Error: exiting..."
	exit 1
fi

# check number of files before erasing
vnum=$(howmany $timeseries)
if [ "$vnum" -gt "1" ] ; then
	\rm $timeseries
fi

