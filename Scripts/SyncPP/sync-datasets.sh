#!/bin/bash
# script to synchronize datasets with SciNet
# Andre R. Erler, July 2013, GPL v3, revised by in April 2016

echo
hostname
date
echo
## load settings
if [[ "$KCFG" == "NONE" ]]; then
    echo "Using configuration from parent environment (not sourcing)."
elif [[ -z "$KCFG" ]]; then
    echo "Sourcing configuration from default file: $PWD/kconfig.sh"
    source kconfig.sh # default config file (in local directory)
elif [[ -f "$KCFG" ]]; then 
    echo "Sourcing configuration from alternative file: $KCFG"
    source "$KCFG" # alternative config file
else
    echo "ERROR: no configuration file '$KCFG'"
fi # if config file
echo
# N.B.: the following variables need to be set in the parent environment or sourced from a config file
#       HOST, OBSSRC, OBSDATA, DATASETS
# some defaults for optional variables
RESTORE=${RESTORE:-'FALSE'} # restore datasets from SciNet backup
OBSDATA="${OBSDATA:-${DATA_ROOT}}" # local datasets root, can be supplied by caller

echo 
echo "   >>>   Synchronizing Observational Datasets   <<<   " 
echo
echo "      Local:  ${OBSDATA}"
echo "      Remote: ${OBSSRC}"
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
      E="${OBSSRC}/${D}" # no trailing slash!
      # to restore from backup, local and remote are switched
      time rsync -vauz --copy-unsafe-links -e "ssh ${SSH}"  "${HOST}:${E}" "${OBSDATA}"
    else
      E="${OBSDATA}/${D}" # no trailing slash!
      time rsync -vauz -e "ssh ${SSH}"  "${E}" "${HOST}:${OBSSRC}"
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
