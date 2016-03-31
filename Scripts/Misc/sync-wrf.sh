#!/bin/bash
# script to synchronize WRF data with SciNet or other sources
# Andre R. Erler, July 2013, GPL v3
# revised by Fengyi Xie and Andre R. Erler, March 2016, GPL v3

## load settings
echo
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
#       HOST, SRC, SUBDIR, WRFDATA or DATA
# some defaults for optional variables
WRFDATA="${DATA}/WRF/" # local WRF data root
SSH="${SSH:-"-o BatchMode=yes -o ControlPath=${HOME}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"}" # default SSH options
INVERT="${INVERT:-'FALSE'}" # source has experiment name first then folder type
STATIC=${STATIC:-'STATIC'} # transfer static/constant data
REX=${REX:-'*-*'} # regex defining experiments
FILETYPES=${FILETYPES:-'wrf*_d0?_monthly.nc'} # regex defining averaged files
if [[ "${FILETYPES}" == 'NONE' ]]; then FILETYPES=''; fi

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
for S in ${SUBDIR}
  do
    WRFAVG="${DST}/${S}/" # recreate first level subfolder structure from source
    #cd "${WRFAVG}" # go to local data folder to expand regular expression (experiment list)
    set -f # deactivate shell expansion of globbing expressions for $REX in for loop
    D=''; for R in ${REX}; do D="${D} ${SRC}/${S}/${R}/"; done # assemble list of source folders
    echo "$D"
    set +f # reactivate shell expansion of globbing expressions
    for E in $( ssh ${SSH} ${HOST} "ls -d ${D}" ) # get folder listing from scinet
      do 
        E=${E%/} # necessary for subsequent step (see below)
        N=${E##*/} # isolate folder name (local folder name)
        echo
		    echo "   ***   ${N}   ***   "
        echo "   ('${E}')"
		    echo
        if [[ "${INVERT}" == 'INVERT' ]]
          then E=${E%/wrfavg/*}; DIRAVG="wrfavg/${S}/${N}"; DIROUT="wrfavg/${S}/${N}" # komputer
          else E=${E%/${N}}; DIRAVG="${N}/wrfavg"; DIROUT="${N}/wrfout" # SciNet
        fi # if $INVERT
        # loop over file types
        for FILETYPE in ${FILETYPES}
          do
            F="${E}/${DIRAVG}/${FILETYPE}" # monthly means
            # check if experiment has any data
            echo "${F}"
            ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
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
