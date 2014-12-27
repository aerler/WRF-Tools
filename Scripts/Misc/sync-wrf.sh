#!/bin/bash
# script to synchronize monthly means with SciNet

# WRF downscaling roots
WRFDATA="${WRFDATA:-/data/WRF/}" # should be supplied by caller
WRFAVG="${WRFDATA}/wrfavg/"
# data selection
STATIC=${STATIC:-'STATIC'} # transfer static/constant data
REX=${REX:-'*-*'} # regex defining experiments
FILETYPES=${FILETYPES:-'wrf*_d0?_monthly.nc'} # regex defining averaged files
if [[ "${FILETYPES}" == 'NONE' ]]; then FILETYPES=''; fi
# connection settings
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
    SSH="-o BatchMode=yes -o ControlPath=${CESMDATA}/hispd-master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
    HOST='datamover' # defined in .ssh/config
    CCA='/reserved1/p/peltier/aerler/Downscaling /scratch/p/peltier/aerler/Downscaling'
    INVERT='FALSE' # source has name first then folder type (like on SciNet)
elif [[ "${HOST}" == 'komputer' ]]
  then
    # download from komputer instead of SciNet using sshfs connection
    SSH="-o BatchMode=yes"
    HOST='fskomputer' # defined in .ssh/config
    CCA='/data/WRF/wrfavg/' # archives with my own cesmavg files
    INVERT='INVERT' # invert name/folder order in source (i.e. like in target folder)
else
    # ssh settings for unattended nightly update: special identity/ssh key, batch mode, and connection sharing
    SSH="-i /home/me/.ssh/rsync -o BatchMode=yes -o ControlPath=${CESMDATA}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
    HOST='aerler@login.scinet.utoronto.ca'
    CCA='/reserved1/p/peltier/aerler/Downscaling /scratch/p/peltier/aerler/Downscaling'
    INVERT='FALSE' # source has name first then folder type (like on SciNet)
fi # if high-speed

echo
echo
hostname
date
echo 
echo "   >>>   Synchronizing Local Averaged WRF Data   <<<   " 
echo
echo "      Local:  ${WRFDATA}"
echo "      Remote: ${HOST}"
echo
echo "   Experiments: ${REX}"
echo "   File Types:  ${FILETYPES}"
echo

# stuff on reserved and scratch
ERR=0
for DD in ${CCA}
  do
    D=''; for R in ${REX}; do D="${D} ${DD}/${R}"; done # assemble list of source folders
    for E in $( ssh $SSH $HOST "ls -d $D" ) # get folder listing from scinet
      do 
        E=${E%/} # necessary for subsequent step (see below)
        N=${E##*/} # isolate folder name (local folder name)
        if [[ "${INVERT}" == 'INVERT' ]]
          then E=${E%/wrfavg/*}; DIRAVG="wrfavg/${N}"; DIROUT="wrfavg/${N}" # komputer
          else E=${E%/${N}}; DIRAVG="${N}/wrfavg"; DIROUT="${N}/wrfout" # SciNet
        fi # if $INVERT
        # loop over file types
        for FILETYPE in ${FILETYPES}
          do
            F="${E}/${DIRAVG}/${FILETYPE}" # monthly means
            # check if experiment has any data
            ssh $SSH $HOST "ls $F" &> /dev/null
            if [ $? == 0 ]; then # check exit code 
              M="${WRFAVG}/${N}" # absolute path
              mkdir -p "$M" # make sure directory is there
              #echo "$N" # feedback
              # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
              # N.B.: with connection sharing, repeating connection attempts is not really necessary
              rsync -vau -e "ssh $SSH" "$HOST:$F" $M/ 
              [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
            fi # if ls scinet
        done # for $FILETYPES
        if [[ "${STATIC}" == 'STATIC' ]]; then
          # transfer constants files
          G="${E}/${DIROUT}/wrfconst_d0?.nc" # constants files
          ssh $SSH $HOST "ls $G" &> /dev/null
          if [ $? == 0 ]; then # check exit code 
            rsync -vau -e "ssh $SSH" "$HOST:$G" $M/ 
            [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
          fi # if ls scinet
          # transfer config files
          H="${E}/${DIROUT}/static.tgz" # config files 
          ssh $SSH $HOST "ls $H" &> /dev/null
          if [ $? == 0 ]; then # check exit code 
            rsync -vau -e "ssh $SSH" "$HOST:$H" $M/ 
            [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
          fi # if ls scinet
        fi # if $STATIC
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
