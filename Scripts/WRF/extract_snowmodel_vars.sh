#!/bin/bash
# a very simple script to extract certain variables needed for to run SnowModel with WRF output

# load NCO
module purge
module load NiaEnv/2018a intel/2018.2 hdf5/1.8.20 netcdf/4.6.1 udunits/2.2.26 nco/4.7.6

# settings
SNODIR='snow_d02'
REGEX='d02*.nc' # also matches wrfconst_* files

# prepare folders
cd wrfout/
rm -rf "$SNODIR" # clean
mkdir "$SNODIR"
# copy constants file
cp wrfconst_$REGEX "$SNODIR/"

# loop over daily output files
for D in wrfhydro_$REGEX;
  do
    NCF="${SNODIR}/${D/hydro/snow_1d}"
    echo "$D > $NCF"
    ncks -O -4 -v Times,RAINNC,RAINC,I_RAINC,I_RAINNC,SNOWNC,ACSNOM,SFCEVP "$D" "$NCF"
    echo "${D/hydro/lsm} > ${D/hydro/snow_1d}"
    ncks -A -4 -v ACSNOW "${D/hydro/lsm}" "$NCF"
    echo "${D/hydro/rad} > ${D/hydro/snow_1d}"
    ncks -A -4 -v ACSWUPB,ACSWDNB,ACLWUPB,ACLWDNB,I_ACSWUPB,I_ACSWDNB,I_ACLWUPB,I_ACLWDNB "${D/hydro/rad}" "$NCF"
done

# loop over 6-hourly output files
for D in wrfsrfc_$REGEX;
  do
    NCF="${SNODIR}/${D/srfc/snow_6h}"
    echo "$D > $NCF"
    ncks -O -4 -v Times,PSFC,T2,Q2,U10,V10,RAINNC,RAINC,I_RAINC,I_RAINNC,SNOWNC,SR,GLW,SWDOWN,SNOW,SNOWH "$D" "$NCF"
done

cd ..
exit 0
