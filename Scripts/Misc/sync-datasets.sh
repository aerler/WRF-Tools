#!/bin/bash
# script to synchronize datasets with SciNet

RESTORE=${RESTORE:-'FALSE'} # restore datasets from SciNet backup
LOC="${ROOT:-/data/}" # local datasets root, can be supplied by caller
REM=/reserved1/p/peltier/aerler/Datasets/ # datasets root on SciNet
DATASETS='Unity GPCC NARR CFSR CRU PRISM PCIC EC WSC' # list of datasets/folders
# DATASETS='PRISM' # for tests
# ssh settings: special identity/ssh key, batch mode, and connection sharing
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
hostname
date
echo 
echo "   >>>   Synchronizing Local Datasets with SciNet   <<<   " 
echo
echo "      Local:  ${LOC}"
echo "      Remote: ${REM}"
echo
echo

# loop over datasets
ERR=0
echo
for D in ${DATASETS}
  do
    echo
    echo "   ***   ${D}   ***   "
    echo
    # use rsync for the transfer; verbose, archive, update, gzip
    # N.B.: here gzip is used, because we are transferring entire directories with many uncompressed files
    if [[ "${RESTORE}" == 'RESTORE' ]]; then
      E="${REM}/${D}" # no trailing slash!
      # to restore from backup, local and remote are switched
      time rsync -vauz --copy-unsafe-links -e "ssh ${SSH}"  "${HOST}:${E}" "${LOC}"
    else
      E="${LOC}/${D}" # no trailing slash!
      time rsync -vauz -e "ssh ${SSH}"  "${E}" "${HOST}:${REM}"
    fi # if restore mode
    [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
    # N.B.: with connection sharing, repeating connection attempts is not really necessary
    echo    
done # for regex sets

# report
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

# exit
exit ${ERR}
