#!/bin/bash
# Script to change the time length byte; adapted from Marc's script
# 10/03/2016, GPL v3, Andre R. Erler

# read arguments (optional)
RXSRC=${1:-'wrflsm_d02'}
RXDST=${2:-'wrfhydro_d02'}
if [ $# -gt 2 ]; then cd "$3"; fi

# function to actually replace Times variable
function REPLACE (){
    ERR=0 # track errors
    ncks -aOx -v Times "$2" "$2" # remove Times variable first
    ERR=$(( $ERR + $? ))
    ncks -aA -v Times "$1" "$2" # now transfer from source file
    ERR=$(( $ERR + $? ))
    return $ERR
}


# time dimension length
TLEN1D=(00 32 29 32 31 32 31 32 32 31 32 31 32)
TLEN6H=(00 125 113 125 121 125 121 125 125 121 125 121 125)
# N.B.: prescribing the time dimension length based on the month and file type helps to check if anything is missing;
#       however, it is not enitrely leap-year safe (i.e. can't detect missing leap day)

# loop over all NetCDF files
for NC in ${RXDST}*.nc
  do
    
    #echo
    #echo $NC
    
    # parse filename: file type and month
    FT="$( echo "$NC" | sed -n '/wrf/ s/.*wrf\([a-z0-9]*\)_d[0-9]\{2\}_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_00[:_]00[:_]00\.nc/\1/p' )"
    MN="$( echo "$NC" | sed -n '/wrf/ s/.*wrf[a-z0-9]*_d[0-9]\{2\}_[0-9]\{4\}-\([0-9]\{2\}\)-[0-9]\{2\}_00[:_]00[:_]00\.nc/\1/p' )"
    MN=$( echo "$MN" | sed 's/^0*//' ) # remove leading zeros
    #echo $MN

    # determine correct dimension size based on file type
    case "$FT" in
      hydro | xtrm | lsm | rad | fdda )
        TLEN="${TLEN1D[$MN]}" ;; # daily output
      srfc | plev3d | moist3d | drydyn3d )
        TLEN="${TLEN6H[$MN]}" ;; # 6-hourly output
      *)
        echo "Unknown Filetype '$FT'"; exit 1 ;;
    esac # length based on file type

    # check if all Times entries are properly formatted
    if [ $( ncdump -v Times "$NC" | grep -c '  "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]:[0-9][0-9]:[0-9][0-9]"' ) -lt $TLEN ]
      then
          
        # construct source file name
        MB="${NC/$RXDST/$RXSRC}" 

        # replace byte (and print feedback) 
        echo "Copying Times variable from  ${MB} to ${NC}."
        REPLACE "${MB}" "${NC}"
        EC=$? # check exit code
        if [ $EC -gt 0 ]; then echo "ERROR processing file ${NC}"; fi  

    fi # if Times is corrupted 

done # for NC files
echo
