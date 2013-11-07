#!/bin/bash
# short script to add a variable from one netcdf file to another, using NCO
# Andre R. Erler, 22/04/2013

# load module
# module load netcdf nco
module list

# settings
VARNM='SR' # variable to be transferred
DIM='Time,,,4' # dimension/hyperslab argument (only record dim supports stride)
SRCDIR="${PWD}/wrfout/"
SRCPFX='wrfsrfc'
DSTDIR="${PWD}/wrftmp/"
DSTPFX='wrfhydro'
NCSFX='.nc'

# prepare
echo
echo "Saving new files in ${DSTDIR} (clearing directory)"
rm -rf "${DSTDIR}"
mkdir -p "${DSTDIR}"
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
    if [[ -e "${DST}" ]] && [[ -z $(ncdump -h "${DST}" | grep "${VARNM}(") ]]
      then
 	#echo cp "${DST}" "${DSTDIR}/${DST}"
	cp "${DST}" "${DSTDIR}/${DST}"
 	#echo ncks -aA -d "${DIM}" -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}"
	ncks -aA -d "${DIM}" -v "${VARNM}" "${SRC}" "${DSTDIR}/${DST}"
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
