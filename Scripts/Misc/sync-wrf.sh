#!/bin/bash
# script to synchronize monthly means with SciNet

# WRF downscaling roots
WRFDATA="${WRFDATA:-/data/WRF/}" # should be supplied by caller
WRFAVG="${WRFDATA}/wrfavg/"
DR='/reserved1/p/peltier/aerler/Downscaling'
DS='/scratch/p/peltier/aerler/Downscaling'
# connection settings
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
    SSH="-o BatchMode=yes -o ControlPath=${WRFDATA}/hispd-master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
    HOST='datamover' # defined in .ssh/config
  else
    # ssh settings for unattended nightly update: special identity/ssh key, batch mode, and connection sharing
    SSH="-i /home/me/.ssh/rsync -o BatchMode=yes -o ControlPath=${WRFDATA}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
    HOST='aerler@login.scinet.utoronto.ca'
fi # if high-speed

echo
echo
hostname
date
echo 
echo "   >>>   Synchronizing Local Averaged WRF Data with SciNet   <<<   " 
echo
echo "      Local:  ${WRFDATA}"
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
        G="$E/wrfout/wrfconst_d0?.nc" # constants files
        H="$E/wrfout/static.tgz" # config files 
	      # check if experiment has any data
        ssh $SSH $HOST "ls $F" &> /dev/null
        if [ $? == 0 ]; then # check exit code 
            N=${E##*/} # isolate folder name (local folder name)
			    	M="${WRFAVG}/${N}" # absolute path
			    	mkdir -p "$M" # make sure directory is there
				    echo "$N" # feedback
        fi # if ls scinet
    		# transfer monthly averages 
				ssh $SSH $HOST "ls $F" &> /dev/null
				if [ $? == 0 ]; then # check exit code 			    
			    	# use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
				    # N.B.: with connection sharing, repeating connection attempts is not really necessary
			    	rsync -vau -e "ssh $SSH" "$HOST:$F" $M/ 
				    ERR=$(( $ERR + $? )) # capture exit code, and repeat, if unsuccessful
			  fi # if ls scinet
        # transfer constants files
        ssh $SSH $HOST "ls $G" &> /dev/null
        if [ $? == 0 ]; then # check exit code 
            rsync -vau -e "ssh $SSH" "$HOST:$G" $M/ 
            ERR=$(( $ERR + $? )) # capture exit code, and repeat, if unsuccessful
        fi # if ls scinet
        # transfer config files
        ssh $SSH $HOST "ls $H" &> /dev/null
        if [ $? == 0 ]; then # check exit code 
            rsync -vau -e "ssh $SSH" "$HOST:$H" $M/ 
            ERR=$(( $ERR + $? )) # capture exit code, and repeat, if unsuccessful
        fi # if ls scinet
        echo
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
exit ${ERR}
