#!/bin/bash

# a simple script to generate a list of valid monthly date tags for WRF cycling
TAGS='' 

# loop over years (as given by arguments
for Y in $( seq $1 $2 ); do 
	for M in $( seq 01 12 ); do 
		T=$( printf %04i-%02i $Y $M )
		if [[ "$3" == 'MISSING' ]]; then # skip dates that already exist
			if [[ ! -e "wrfout/${T}_wrf.tgz" ]]; then TAGS="$TAGS $T"; fi
		elif [[ "$3" == 'PRESENT' ]]; then # only dates that already exist
			if [[ -e "wrfout/${T}_wrf.tgz" ]]; then TAGS="$TAGS $T"; fi
		else TAGS="$TAGS $T" # use all dates
		fi # $3 (mode) 
	done # M (month)
done # Y (years)

# print dates
echo "$TAGS"

