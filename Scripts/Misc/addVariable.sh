#!/bin/bash
# short script to add a variable from one netcdf file to another, using NCO
# Andre R. Erler, 22/04/2013

# load module
# module load netcdf nco
module list

# settings
SRCDIR="${PWD}/wrfout/"
DSTDIR="${PWD}/wrfout/"
NCSFX='.nc'
# variable specific settings
VARNM="$1" # passed as argument
# VARNM='ACSNOW'|'SR' # variable to be transferred
if [[ "${VARNM}" == 'SR' ]]; then
	DIM='Time,,,4' # dimension/hyperslab argument (only record dim supports stride)
	SRCPFX='wrfsrfc'
	DSTPFX='wrfhydro'
elif [[ "${VARNM}" == 'ACSNOW' ]]; then
	DIM='' # same time intervall
	SRCPFX='wrflsm'
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
    if [[ -e "${DST}" ]] && [[ -z $( ncdump -h "${DST}" | grep "${VARNM}(" ) ]]
      then
 	#echo cp "${DST}" "${DSTDIR}/${DST}"
	if [[ "${SRCDIR}" != "${DSTDIR}" ]]; then
            cp "${DST}" "${DSTDIR}/${DST}"; fi
 	#echo ncks -aA -d "${DIM}" -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}"
  if [[ -n "${DIM}" ]]; 
    then ncks -aA -d "${DIM}" -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}" # potentially different time spacing
    else  ncks -aA -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}" # same time spacing
  fi # if $DIM
	# check exit code
	if [[ $? == 0 ]] && [[ -n $(ncdump -h "${DSTDIR}/${DST}" | grep "${VARNM}(") ]]
	  then echo " ...wrote ${DST} successfully"
	  else
	    echo "ERROR: problem with ${DST}"
	    ERR=$(( ERR + 1 )) # count error
	  fi
    fi # if not already there
done # loop over files
echo
if [[ $ERR == 0 ]]
  then
    echo "   ***   Operation successfully completed!   ***   "
  else
    echo "   WARNING: There were ${ERR} Error(s)!"
fi # if ERR == 0
