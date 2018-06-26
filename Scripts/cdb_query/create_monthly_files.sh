#!/bin/bash
# This is a sample script to execute cdb_query using shell.
# This scripts contains the ask, validate, download, reduce process for cdb_query. Each step would generate a netCDF file as the input for the next step.
# To create the validate file used by pyWPS, only the first two steps are needed.
# The variables quaried are hard-coded into the script. User is expected to modify those variables based on request.

module purge
module load intel/15.0.2 intelmpi/4.1.0.027 gcc/4.8.1 anaconda2/4.1.1 gdal/1.9.2 ncl/6.2.0 gsl/1.13-intel udunits/2.1.11 extras/64_6.4
module list

# List of environment variables that are used by the script
CDBPATH="DIRECTORY FOR CDB_QUERY 'SWAP_DIR' COMMAND"
CMIP5PATH="DIRECTORY FOR LOCAL CMIP5 DATA ARCHIVE"
BADC_USERNAME="ENTER YOUR BADC USERNAME"
BADC_PASSWORD="ENTER YOUR BADC PASSWORD"
OPENID="ENTER YOUR ESGF OPENID"

# List of setup variables to indicate Model and Time Period

MODEL="GFDL-CM3"    #FUll model name for the CMIP5 model
TIMEPERIOD="2050"  #Time period for the experiment file

# Create enviromental variable based on required time period.
case ${TIMEPERIOD} in 
  "hist")
    SEARCHPERIOD="historical:1979-1994"
    INIYEAR="1979"
    ENDYEAR="1994";;
  "2050")
    SEARCHPERIOD="rcp85:2045-2060"
    INIYEAR="2045"
    ENDYEAR="2060";;
  "2100")
    SEARCHPERIOD="rcp85:2085-2100"
    INIYEAR="2085"
    ENDYEAR="2100";;
esac

#This is to solve the HDF5 library version problem
export HDF5_DISABLE_VERSION_CHECK=1


#Discover data:
echo ${BADC_PASSWORD} | cdb_query CMIP5 ask --ask_month=1,2,3,4,5,6,7,8,9,10,11,12 \
                    --ask_var=clt:mon-atmos-Amon,evspsbl:mon-atmos-Amon,hfls:mon-atmos-Amon,hfss:mon-atmos-Amon,hur:mon-atmos-Amon,hus:mon-atmos-Amon,huss:mon-atmos-Amon,pr:mon-atmos-Amon,prc:mon-atmos-Amon,prsn:mon-atmos-Amon,prw:mon-atmos-Amon,ps:mon-atmos-Amon,psl:mon-atmos-Amon,rlds:mon-atmos-Amon,rlus:mon-atmos-Amon,rlut:mon-atmos-Amon,rsds:mon-atmos-Amon,rsdt:mon-atmos-Amon,rsus:mon-atmos-Amon,rsut:mon-atmos-Amon,ta:mon-atmos-Amon,tas:mon-atmos-Amon,tasmax:mon-atmos-Amon,tasmin:mon-atmos-Amon,ts:mon-atmos-Amon,ua:mon-atmos-Amon,uas:mon-atmos-Amon,va:mon-atmos-Amon,vas:mon-atmos-Amon,zg:mon-atmos-Amon \
                    --ask_experiment=${SEARCHPERIOD} \
                    --model=${MODEL} \
                    --ensemble=r1i1p1 \
                    --search_path=${CMIP5PATH} \
                    --swap_dir=${CDBPATH} \
                    --username=${BADC_USERNAME} \
                    --password_from_pipe \
                    ${MODEL}_${TIMEPERIOD}_monthly_pointer.nc

#
# Here are all variables needed
#--ask_var=huss:3hr-atmos-3hr,tas:3hr-atmos-3hr,uas:3hr-atmos-3hr,vas:3hr-atmos-3hr,ua:6hr-atmos-6hrLev,va:6hr-atmos-6hrLev,ta:6hr-atmos-6hrLev,hus:6hr-atmos-6hrLev,ps:6hr-atmos-6hrLev,psl:6hr-atmos-6hrPlev,snw:day-landIce-day,tslsi:day-land-day,sic:day-seaIce-day,sit:day-seaIce-day,tos:day-ocean-day,snw:mon-landIce-LImon,tsl:mon-land-Lmon,mrlsl:mon-land-Lmon,snd:mon-seaIce-OImon \

#List simulations:
cdb_query CMIP5 list_fields -f institute \
                            -f model \
                            -f ensemble \
                            -f var \
                            ${MODEL}_${TIMEPERIOD}_monthly_pointer.nc

#Validate Header File:
YEARS=$(seq -s' ' ${INIYEAR} ${ENDYEAR})
echo ${YEARS}

for YY in ${YEARS}; do
  echo "Validating for year ${YY}"
  
  if [[ "${YY}" != ${INIYEAR} ]]; then
    APPEND='-A'
    echo "Appending to previous file ${APPEND}"
  fi
  echo $BADC_PASSWORD | cdb_query CMIP5 validate ${APPEND} \
                --openid=$OPENID                     \
                --username=$BADC_USERNAME            \
                --password_from_pipe                 \
                --Xdata_node=http://esgf2.dkrz.de    \
                --year=${YY}                         \
                --num_procs=3                       \
                --swap_dir=${CDBPATH}                \
                ${MODEL}_${TIMEPERIOD}_monthly_pointer.nc   \
                ${MODEL}_${TIMEPERIOD}_monthly_pointer.validate.nc
  echo "Validation for year ${YY} completed"
done
echo "Validation Complete"

#List simulations:
cdb_query CMIP5 list_fields -f institute \
                            -f model \
                            -f ensemble \
                            -f var \
                            ${MODEL}_${TIMEPERIOD}_monthly_pointer.validate.nc

# Download data
echo $BADC_PASSWORD | cdb_query CMIP5 download_opendap  \
                --download_all_opendap \
                --openid=$OPENID \
                --username=$BADC_USERNAME \
                --password_from_pipe \
                --swap_dir=${CDBPATH}                \
                --debug  \
                ${MODEL}_${TIMEPERIOD}_monthly_pointer.validate.nc \
                ${MODEL}_${TIMEPERIOD}_monthly_pointer.validate.downloaded.nc

#List simulations:
cdb_query CMIP5 list_fields -f institute \
                            -f model \
                            -f ensemble \
                            -f var \
                            MIROC5_${TIMEPERIOD}_monthly_pointer.validate.downloaded.nc

# Change the archive structure into directory structure using the reduce option
cdb_query CMIP5 reduce '' \
                --out_destination=./out/ \
                ${MODEL}_${TIMEPERIOD}_monthly_pointer.validate.downloaded.nc \
                ${MODEL}_${TIMEPERIOD}_monthly_pointer.validate.downloaded.converted.nc


echo "All process to create monthly output files completed"
