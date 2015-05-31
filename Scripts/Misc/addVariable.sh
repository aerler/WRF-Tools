#!/bin/bash
# short script to add a variable from one netcdf file to another, using NCO
# Andre R. Erler, 22/04/2013

# load module
module purge
module load intel/13.1.1 gcc/4.8.1 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel udunits/2.1.11 nco/4.0.8-intel-nocxx
module list
# NCO only works with the older versions of NetCDF4/HDF5

# settings
SRCDIR="${PWD}/wrfout/"
DSTDIR="${PWD}/wrfout/"
NCSFX='.nc'
# variable specific settings
VARNM="$1" # passed as argument
# VARNM='ACSNOW'|'SR' # variable to be transferred
if [[ "${VARNM}" == 'PREC_ACC_C' ]]; then
  DIM='Time,,,4' # dimension/hyperslab argument (only record dim supports stride)
  SRCPFX='wrfsrfc'
  DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'PREC_ACC_NC' ]]; then
  DIM='Time,,,4' # dimension/hyperslab argument (only record dim supports stride)
  SRCPFX='wrfsrfc'
  DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'SNOW_ACC_NC' ]]; then
  DIM='Time,,,4' # dimension/hyperslab argument (only record dim supports stride)
  SRCPFX='wrfsrfc'
  DSTPFX='wrfhydro'
#elif [[ "${VARNM}" == 'SR' ]]; then
#	DIM='Time,,,4' # dimension/hyperslab argument (only record dim supports stride)
#	SRCPFX='wrfsrfc'
#	DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'SR' ]]; then
	DIM=''
	SRCPFX='wrfhydro' # not used anymore...
	DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'ACSNOW' ]]; then
	DIM='' # same time intervall
	SRCPFX='wrflsm'
	DSTPFX='wrfhydro'
#elif [[ "${VARNM}" == 'T2MEAN' ]]; then
# DIM='' # same time intervall
# SRCPFX='wrfxtrm' # add variable to hydro (from xtrm)
# DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'TSLB' ]]; then
  DIM='' # same time intervall
  SRCPFX='wrfsrfc' # remove variable from srfc
  DSTPFX='wrfsrfc'
elif [[ "${VARNM}" == 'T2MEAN' ]]; then
  DIM='' # same time intervall
  SRCPFX='wrfhydro' # remove variable from hydro
  DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'SNOWNC' ]]; then
  DIM='' # same time intervall
  SRCPFX='wrfhydro' # remove variable from hydro
  DSTPFX='wrfhydro'
else
  echo
  echo "No Settings found for Variable '${VARNM}' - aborting!"
  echo
  exit 1
fi # if $VARNM

# prepare
echo
if [[ "${SRCDIR}" != "${DSTDIR}" ]]; then
  echo "Saving new files in ${DSTDIR} (clearing directory)"
  rm -rf "${DSTDIR}"
  mkdir -p "${DSTDIR}"
else
  echo "Saving new files in source directory ${DSTDIR}"
fi
echo
cd "${SRCDIR}"
ERR=0
# loop over files
for SRC in ${SRCPFX}*${NCSFX}
  do
    #echo $SRC
    # construct destination file name
    DST="${DSTPFX}${SRC#${SRCPFX}}" # swap prefix
    # skip if variable already present
    if [[ -e "${DST}" ]]; then
    
   		 	#echo cp "${DST}" "${DSTDIR}/${DST}"
				if [[ "${SRCDIR}" != "${DSTDIR}" ]]; then
			            cp "${DST}" "${DSTDIR}/${DST}"; fi
			 	#echo ncks -aA -d "${DIM}" -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}"
			  if [[ "${SRCPFX}" == "${DSTPFX}" ]] && [[ -z "${DIM}" ]] && \
			     [[ -n $( ncdump -h "${SRC}" | grep "${VARNM}(" ) ]]; then
            # REMOVE Variable        
			      ncks -aO -x -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}" # this means remove the variable!
        elif [[ "${SRCPFX}" != "${DSTPFX}" ]] && [[ -z $( ncdump -h "${DST}" | grep "${VARNM}(" ) ]]; then
            # ADD Variable
					  if [[ -n "${DIM}" ]]; then 
					      ncks -aA -d "${DIM}" -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}" # potentially different time spacing
					  else  
					      ncks -aA -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}" # same time spacing
					  fi # if $DIM
        fi # mode (add or remove)
	      # check exit code
				if [[ $? == 0 ]]; then 
				    echo " ...wrote ${DST} successfully"
				else
				    echo "ERROR: problem with ${DST}"
				    ERR=$(( ERR + 1 )) # count error
		    fi # if error
    
    fi # if not already there
done # loop over files
echo
if [[ $ERR == 0 ]]
  then
    echo "   ***   Operation successfully completed!   ***   "
  else
    echo "   WARNING: There were ${ERR} Error(s)!"
fi # if ERR == 0
