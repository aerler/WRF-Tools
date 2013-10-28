#!/bin/bash
# script to synchronize monthly means with SciNet

# WRF downscaling roots
L="${DATA:-'/data/WRF/wrfavg/'}" # should be supplied by caller
DR='/reserved1/p/peltier/aerler/Downscaling'
DS='/scratch/p/peltier/aerler/Downscaling'
# ssh settings: special identity/ssh key, batch mode, and connection sharing
SSH="-i /home/me/.ssh/rsync -o BatchMode=yes -o ControlPath=${L}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
HOST='aerler@login.scinet.utoronto.ca'

echo
echo
hostname
date
echo 
echo "   >>>   Synchronizing Local Averaged WRF Data with SciNet   <<<   " 
echo
echo "      Local:  ${L}"
echo "      Host: ${HOST}"
echo
echo

# stuff on reserved and scratch
ERR=0
for D in "$DR/*-*/" "$DS/*-*/"
  do
    for E in $( ssh $SSH $HOST "ls -d $D" ) # get folder listing from scinet
      do 
	 	 	 	E=${E%/} # necessary for subsequent step (see below)
        F="$E/wrfavg/wrf*_d0?_monthly.nc" # monthly means
        #F="$E/wrfout/wrfconst_d0?.nc" # constants files
	      # check if experiment has any data
				ssh $SSH $HOST "ls $F" &> /dev/null
				if [ $? == 0 ] # check exit code 
			    then
				    N=${E##*/} # isolate folder name (local folder name)
			    	M="$L/$N" # absolute path
			    	mkdir -p "$M" # make sure directory is there
				    echo "$N" # feedback
			    	# use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
			    	rsync -vau -e "ssh $SSH" "$HOST:$F" $M/ 
				    ERR=$(( $ERR + $? )) # capture exit code, and repeat, if unsuccessful
				    # N.B.: with connection sharing, repeating connection attempts is not really necessary
				    echo
			  fi # if ls scinet
    done # for subsets    
done # for regex sets

# report
echo
echo
if [ $ERR == 0 ]
  then
    echo "   <<<   All Transfers Completed Successfully!   >>>   "
  else
    echo "   ###   Transfers Completed - there were ${ERR} Errors!   ###   "
fi
echo
date
echo
echo

# exit with error code
exit $ERR
