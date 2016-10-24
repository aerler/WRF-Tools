#!/bin/bash
# short script to recreate the wrfhydro output stream from other output streams, using NCO
# Andre R. Erler, 24/10/2016

# load module
module purge
module load intel/13.1.1 gcc/4.8.1 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel udunits/2.1.11 nco/4.0.8-intel-nocxx
module list
# NCO only works with the older versions of NetCDF4/HDF5

# read arguments (optional)
NCSFX=${NCSFX:-'.nc'}
REGEX=${@:-"wrfout/wrflsm_*$NCSFX"} # default: use LSM files as template
SRCDIR=${SRCDIR:-"${PWD}"}
DSTDIR=${DSTDIR:-"${PWD}"}
SRFCDIM=${SRFCDIM:-'Time,,,4'} # dimension/hyperslab argument (for surface files, which are 6-hourly)
OVERWRITE=${OVERWRITE:-'FALSE'} # skip existing files or overwrite

# begin execution
echo
cd "${SRCDIR}"
ERR=0
# loop over files
for SRC in ${REGEX}
  do
    #echo $SRC
    # extract domain and time stamp extension
	   EXT="$( echo "$SRC" | sed -n '/wrf/ s/.*wrf[a-z0-9]*_\(d[0-9]\{2\}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_00[:_]00[:_]00\)${NCSFX}/\1/p' )"
    # construct destination file name
	   HYDRO="wrfhydro_${EXT}" # name of hydro file
    # skip if variable already present (and not OVERWRITE)
  	if [[ "${OVERWRITE}" == 'OVERWRITE' ]] || [[ ! -e "${HYDRO}" ]]
  	  then
      
        # check prerequisits
        NC=0
        LSM="wrflsm_${EXT}" # name of LSM file
        [[ ! -e "$LSM" ]] && echo "Input file '$LSM' not found!" && NC=$(( $NC + 1 ))
        SRFC="wrfxtrm_${EXT}" # name of Surface file
        [[ ! -e "$SRFC" ]] && echo "Input file '$SRFC' not found!" && NC=$(( $NC + 1 ))
        XTRM="wrfxtrm_${EXT}" # name of Extremes file
        [[ ! -e "$XTRM" ]] && echo "Input file '$XTRM' not found!" && NC=$(( $NC + 1 ))
           
        
        # create hydro file if all prerequisites are present             
        if [ $NC -eq 0 ]
          then
            EC=0
            # copy relevant variables from LSM file
            LSMVARS='SFCEVP,ACSNOM,ACSNOW,NOAHRES,POTEVP,Times'
            ncks -aA -v "$LSMVARS"  "${LSM}" "${DSTDIR}/${HYDRO}" # same time spacing
            EC=$(( $EC + $? ))
    		    # copy relevant variables from SRFC file
    		    SRFCVARS='RAINC,RAINNC,I_RAINC,I_RAINNC,SNOWNC,GRAUPELNC,SR'
            ncks -aA -d "${DIM}" -v "${SRFCVARS}" "${SRFC}" "${DSTDIR}/${HYDRO}" # different time spacing
            EC=$(( $EC + $? ))
            # copy variable from Extreme file
            XTRMVARS='T2MEAN'
            ncks -aA -v "$XTRMVARS"  "${XTRM}" "${DSTDIR}/${HYDRO}" # same time spacing
            EC=$(( $EC + $? ))                
        else
            EC=1 # missing prerequisites is a failure 
        fi # prerequisites

        # check exit code
				if [[ $? == 0 ]]; then 
				    echo "Recreated ${HYDRO} successfully"
				else
				    echo "ERROR: failed to recreate ${HYDRO}"
				    ECC=$(( ECC + 1 )) # count error
		    fi # if error
    
    fi # if hydro-file not already there
done # loop over files

echo
if [[ $ECC == 0 ]]
  then
    echo "   ***   Successfully Recreated Hydro-files!   ***   "
  else
    echo "   WARNING: There were ${ECC} Error(s)!"
fi # $ECC
