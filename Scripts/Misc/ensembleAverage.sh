#!/bin/bash
# Andre R. Erler, GPLv3, 03/12/2013
# script to generate ensemble averages from NetCDF files in different folders using NCO

# settings
OVERWRITE=${OVERWRITE:-'FALSE'} # whether or not to overwrite existing files...
#OVERWRITE=${OVERWRITE:-'OVERWRITE'} # whether or not to overwrite existing files...
#EXCLUDE=${EXCLUDE:-'TSK,SolidPrecip_SR,LiquidPrecip_SR,liqprec_sr,solprec_sr'} # variables to be excluded from average (because the cause trouble)
VERBOSITY=${VERBOSITY:-1} # level of warning and error reporting
NCOFLAGS=${NCOFLAGS:-'--netcdf4 --overwrite'} # flags passed to NCO call
CLIMFILES='*clim*.nc' # regular expression defining the files to be averaged
# N.B.: these files have to be present in every ensemble member
# get ensemble name and folder, first argument
TMP="$1"; TMP="${TMP%/}" # cut trailing slash
# name of the ensemble average
ENSAVG="${ENSAVG##*/}" # just the name, no folders
ROOTDIR="${ENSAVG%%/*}/" # cut of ensemble name
if [[ "$ROOTDIR" != '/'*  ]]; then ROOTDIR="$PWD/$ROOTDIR"; fi # add present working directory, if necessary
ENSDIR="$ROOTDIR/$ENSAVG/" # destination folder
MASTER=$(cat "$ENSDIR/members.txt" | head -n 1) # to get file list
MASTERDIR="$ROOTDIR/$MASTER/" # folder for file list
TMP=$(cat "$ENSDIR/members.txt") # list of ensemble members
MEMBERS=''; for M in $TMP; do MEMBERS="$MEMBERS $M"; done # get rid of new-line characters
MEMDIRS=''; for M in $MEMBERS; do MEMDIRS="$MEMDIRS $ROOTDIR/$M/"; done # associated directories

ERR=0 # count errors (from exit codes)
OK=0 # count successes
# loop over files
FILELIST=$(ls "$MASTERDIR/"$CLIMFILES) # list of files that are potentially processed
echo 
echo "   ***   Generating Ensemble '${ENSAVG}'   ***   "
echo
echo "   Destination Folder: ${ENSDIR}   "
echo "   Ensemble Memebers: ${MEMBERS}   "
echo
for FILE in $FILELIST
  do
    FN=${FILE##*/} # file name without path
    # check that is it present in all ensemble members
    MISS=0
    for MD in $MEMDIRS; do
        if [[ ! -f $MD/$FN ]]; then 
            # N.B.: can't use quotes, or member filelist is interpreted as one file...
            MISS=$(( $MISS + 1 ))
            if [[ $VERBOSITY -gt 1 ]]; then echo "WARNING: $MD/$FN is missing!"; fi
        fi # if file exists
    done # count missing
    # is all files are there, produce ensemble average
    if [ $MISS == 0 ]
      then
        echo
        if [[ "$OVERWRITE" != 'OVERWRITE' ]] && [[ -f $ENSDIR/$FN ]]
          then
            echo "Skipping $FN - already exists!"
          else
            echo "${FN}"
            unset EXCLUDE # clear eclude list
            # detect file type and set an exlude list
            #if [[ $FN == *hydro* ]]; then EXCLUDE='T2,Tmean,SolidPrecip_SR,LiquidPrecip_SR,liqprec_sr,solprec_sr'
            #elif [[ $FN == *srfc* ]]; then EXCLUDE='TSK'
            #fi # file type/name
            # add flags to EXCLUDE list
            if [[ -n "$EXCLUDE" ]]; then EXCLUDE="--exclude --variable $EXCLUDE"; fi
            MEMFILES=''; for M in $MEMDIRS; do MEMFILES="$MEMFILES $M/$FN"; done # source files
            # NCO command
            if [[ $VERBOSITY -gt 0 ]]; then echo "ncea $NCOFLAGS $EXCLUDE $MEMFILES $ENSDIR/$FN"; fi
            ncea $NCOFLAGS $EXCLUDE $MEMFILES $ENSDIR/$FN # can't use quotes, or member filelist is interpreted as one file...
            if [ $? == 0 ]; then
                OK=$(( $OK + 1 ))
            else
                ERR=$(( $ERR + 1 ))
                echo "ERROR: $ENSDIR/$FN"
            fi # handle exit code
        fi # OVERWRITE
      else
        if [[ $VERBOSITY -gt 0 ]]; then 
            echo
            echo "WARNING: skipping $FN - $MISS inputs missing!"
        fi
      fi # if $MISS           
done # loop over $FILELIST
echo

# report summary
echo 
if [ ${ERR} == 0 ]; then
    echo "   ***   All ${OK} files were successfully averaged!  ***   "
elif [ ${OK} == 0 ]; then
    echo "   ###   All ${ERR} operations failed!  ###   "
else
    echo "   ===   ${OK} files were successfully averaged, ${ERR} errors occurred  ===   "
fi # summary
echo

# exit with error code
exit ${ERR} 
