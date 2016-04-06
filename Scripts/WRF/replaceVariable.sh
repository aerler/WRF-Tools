#!/bin/bash
# Script to replace a variable in one set of files with the same variable in a different set of files
# 16/03/2016, GPL v3, Andre R. Erler

# read arguments (optional)
RXSRC=${1:-'wrfsrfc_d01'} # file from which the variable will be copied
RXDST=${2:-'wrfsrfc_d02'} # file where variable is to be replaced
VARNM=${3:-'XTIME'} # variable to be replaced

# function to actually replace Times variable
function REPLACE (){
    ERR=0 # track errors
    # remove existing variable, if necessary
    if [ $( ncdump -h "$2" | grep -c "${VARNM}" ) -gt 0 ]; then
      ncks -aOx -v "${VARNM}" "$2" "$2" # remove Times variable first
      ERR=$(( $ERR + $? ))
    fi # if VARNM already present 
    # add new variable
    ncks -aA -v "${VARNM}" "$1" "$2" # now transfer from source file
    ERR=$(( $ERR + $? ))
    return $ERR
}


# loop over all NetCDF files
for NC in ${RXDST}*.nc
  do
    
    #echo
    #echo $NC
    
    # construct source file name
    MB="${NC/$RXDST/$RXSRC}" 
    
    # replace byte (and print feedback) 
    echo "Copying variable '${VARNM}' from  ${MB} to ${NC}."
    REPLACE "${MB}" "${NC}"
    EC=$? # check exit code
    if [ $EC -gt 0 ]; then echo "ERROR processing file ${NC}"; fi  

done # for NC files
echo
