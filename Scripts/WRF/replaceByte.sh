#!/bin/bash
# Script to change the time length byte; adapted from Marc's script
# usage: ./replaceByte.sh [ Filelist | RegEx ] 
# 10/03/2016, GPL v3, Andre R. Erler

# read arguments (optional)
REGEX=${2:-'wrf*.nc'} # default: all WRF output files
if [ $# -gt 0 ]; then REGEX="$1"; fi # use this regex for files
# the regex can also contain a path; it is expanded by a for loop

# function to actually replace bytes
function REPLACE (){
  printf "$( printf '\\x%02X' $2 )" | dd of="$1" bs=1 seek=7 count=1 conv=notrunc >& /dev/null
}

# byte settings
BYTE1D=(00 32 29 32 31 32 31 32 32 31 32 31 32)
BYTE6H=(00 125 113 125 121 125 121 125 125 121 125 121 125)

# loop over all NetCDF files
for NC in $REGEX
  do
    
    #echo
    #echo $NC
    
    # check if time dimension size is missing
    if [ $( ncdump -h "$NC" | grep -c 'Time = UNLIMITED ; // (0 currently)' ) -gt 0 ]
      then

        # parse filename: file type and month
        FT="$( echo "$NC" | sed -n '/wrf/ s/.*wrf\([a-z0-9]*\)_d[0-9]\{2\}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_00[:_]00[:_]00\.nc/\1/p' )"
        #echo $FT
        MN="$( echo "$NC" | sed -n '/wrf/ s/.*wrf[a-z0-9]*_d[0-9]\{2\}_[0-9]\{4\}-\([0-9]\{2\}\)-[0-9]\{2\}_00[:_]00[:_]00\.nc/\1/p' )"
        MN=$( echo "$MN" | sed 's/^0*//' ) # remove leading zeros
        #echo $MN

        # determine correct dimension size based on file type
        case "$FT" in
          hydro | xtrm | lsm | rad | fdda )
            BYTE="${BYTE1D[$MN]}" ;;
          srfc | plev3d | moist3d | drydyn3d )
            BYTE="${BYTE6H[$MN]}" ;;
          *)
            echo "Unknown Filetype '$FT'"; exit 1 ;;
        esac # length based on file type

        # replace byte (and print feedback) 
        echo "Settings time length to ${BYTE} in file: ${NC}"
        REPLACE "${NC}" ${BYTE}
        EC=$? # check exit code
        if [ $EC -gt 0 ]; then echo "ERROR processing file ${NC}"; fi  

    fi # if Time = 0

done # for NC files
echo
