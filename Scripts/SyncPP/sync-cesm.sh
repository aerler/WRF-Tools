#!/bin/bash
# script to synchronize CESM data with SciNet
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
#       HOST, SRC, CESMDATA or DATA
# some defaults for optional variables
RESTORE=${RESTORE:-'FALSE'} # restore datasets from SciNet backup
# CESM directories / data sources
REX=${REX:-'h[abc]b20trcn1x1 tb20trcn1x1 h[abcz]brcp85cn1x1 htbrcp85cn1x1 seaice-5r-hf h[abcz]brcp85cn1x1d htbrcp85cn1x1d seaice-5r-hfd'}
ENS=${ENS:-'ens20trcn1x1 ensrcp85cn1x1 ensrcp85cn1x1d'}
CVDP=${CVDP:-"${ENS} grand-ensemble"}
if [[ "${CVDP}" == 'NONE' ]]; then CVDP=''; fi
CESMDATA="${CESMDATA:-${DATA}/CESM/}" # can be supplied by caller
# data selection
FILETYPES=${FILETYPES:-'cesm[ali][tnc][mde]_*.nc'}
if [[ "${FILETYPES}" == 'NONE' ]]; then FILETYPES=''; fi
DIAGS=${DIAGS:-'diag cvdp'}
if [[ "${DIAGS}" == 'NONE' ]]; then DIAGS=''; fi

echo
echo "   >>>   Synchronizing Local CESM Climatologies   <<<   " 
echo
echo "      Local:  ${CESMDATA}"
echo "      Remote: ${HOST}"
echo
echo "   Experiments: ${REX}"
echo "   Ensembles:   ${ENS}"
echo
echo "   File Types:  ${FILETYPES}"
echo "   Diagnostics: ${DIAGS}"
echo

ERR=0
#shopt -s extglob

# generate list of experiments
cd "${CESMDATA}/cesmavg/" # go to data folder to expand regular expression
set -f # deactivate shell expansion of globbing expressions for $REX in for loop
D=''; for R in ${REX}; do D="${D} ${CESMSRC}/${R}"; done # assemble list of source folders
echo "$D"
set +f # reactivate shell expansion of globbing expressions
# loop over all relevant experiments
for E in $( ssh ${SSH} ${HOST} "ls -d ${D}" ) # get folder listing from scinet
  do 
    
    # determine experiment name and base folder 
    E=${E%/} # necessary for subsequent step (see below)
    N=${E##*/} # isolate folder name (local folder name)
    if [[ "${INVERT}" == 'INVERT' ]]; then E=${E%/cesmavg/*}
    else E=${E%/${N}}; fi # isolate root folder
    echo
    echo "   ***   ${N}   ***   "
    echo
    
    ## synchronize cesmavg files
    # mind order of folders
    if [[ "${INVERT}" == 'INVERT' ]]; then DIR="cesmavg/${N}" # komputer
    else DIR="${N}/cesmavg"; fi # SciNet
    # loop over file types
    set -f # deactivate shell expansion of globbing expressions for $FILETYPES in for loop
    for FILETYPE in ${FILETYPES}
      do
        F="${E}/${DIR}/${FILETYPE}"
        #echo $F
        # check if experiment has any data
        ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
        if [ $? == 0 ] # check exit code 
          then
            M="${CESMDATA}/cesmavg/${N}" # absolute path
            mkdir -p "${M}" # make sure directory is there
            echo "${N}" # feedback
            # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
            rsync -vau --copy-unsafe-links -e "ssh ${SSH}" "${HOST}:${F}" ${M}/ 
            [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
            # N.B.: with connection sharing, repeating connection attempts is not really necessary
            echo
        fi # if ls scinet
    done # loop over FILETYPES
    set +f # reactivate shell expansion of globbing expressions
    
    ## synchronize AMWG & CVDP dignostic files
    # loop over all relevant experiments (same list of source folders)
    for ANA in ${DIAGS}
      do 
        #echo $ANA
        # mind order of folders
        if [[ "${INVERT}" == 'INVERT' ]]; then DIR="${ANA}/${N}" # komputer
        else DIR="${N}/${ANA}"; fi # SciNet
        F="${E}/${DIR}/*.tgz"
        #echo $F
        # check if experiment has any data
        ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
        if [ $? == 0 ] # check exit code 
          then
            M="${CESMDATA}/${ANA}/${N}" # absolute path
            mkdir -p "${M}" # make sure directory is there
            #echo "${N}" # feedback
            # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
            rsync -vau --copy-unsafe-links -e "ssh ${SSH}" "${HOST}:${F}" "${M}/"
            [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
            # N.B.: with connection sharing, repeating connection attempts is not really necessary
            # extract tarball, if file was updated
            ls "${M}"/*.tgz &> /dev/null # make sure tarball is there
            if [ $? -eq 0 ] # putting the globex into the bracket fails if there is no tarball!
              then
                cd "${M}" # tar extracts into the current directory
                for TB in "${M}"/*.tgz; do
                    T=${TB%.tgz} # get folder name (no extension)
                    if [[ ! -e "${T}" ]]; then
                        echo "Extracting diagnostic tarball (${ANA}): ${TB}"
                        tar xzf "${TB}"
                        [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                        touch "${T}" # update modification date of folder
                    elif [[ "${TB}" -nt "${T}" ]]; then
                        echo "Extracting new diagnostic tarball (${ANA}): ${TB}"
                        rm -r "${T}"
                        tar xzf "${TB}"
                        [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                        touch "${T}" # update modification date of folder
                    else
                        echo "${T} diagnostics are up-to-date (${ANA})"
                    fi # if $T
                    # N.B.: $T is either a sub-folder into which the tarball extracts, or an indicator file 
                    #       that simply records whther or not the tarball was extracted (for "tar-bombs") 
                done # for *.tgz
            else
                echo "No diagnostics tarball found on local system (${ANA})"
                ERR=$(( $ERR + 1 )) # register as error
            fi # if ${M}/*.tgz
            echo
        else
            echo "No diagnostics tarball found on remote system (${ANA})"
            ERR=$(( $ERR + 1 )) # register as error
        fi # if ls scinet
    done # for amwg & cvdp
done # for experiments

# generate list of additional CVDP folders (ensembles)
cd "${CESMDATA}/cvdp/" # go to data folder to expand regular expression
D=''; for R in ${CVDP}; do D="${D} ${CESMSRC}/${R}"; done # assemble list of source folders
# loop over all relevant folders
for E in $( ssh ${SSH} ${HOST} "ls -d ${D}" ) # get folder listing from scinet
  do 
  
    E=${E%/} # necessary for subsequent step (see below)
    N=${E##*/} # isolate folder name (local folder name)
    echo
    echo "   ***   ${N}   ***   "
    echo

    ## synchronize CVDP dignostic files
    # isolate root folder and mind order of folders
    if [[ "${INVERT}" == 'INVERT' ]] 
      then E=${E%/cesmavg/*}; DIR="cvdp/${N}" # komputer
      else E=${E%/${N}}; DIR="${N}/${ANA}" # SciNet
    fi # if $INVERT 
    F="${E}/${DIR}/*.tgz"
    echo $F
    # check if experiment has any data
    ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
    if [ $? == 0 ] # check exit code 
      then
        M="${CESMDATA}/cvdp/${N}" # absolute path
        mkdir -p "${M}" # make sure directory is there
        echo "${N}" # feedback
        # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
        rsync -vau --copy-unsafe-links -e "ssh ${SSH}" "${HOST}:${F}" "${M}/"
        [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
        # N.B.: with connection sharing, repeating connection attempts is not really necessary
        # extract tarball, if file was updated
        ls "${M}"/*.tgz &> /dev/null # make sure tarball is there
        if [ $? -eq 0 ] # putting the globex into the bracket fails if there is no tarball!
          then
            cd "${M}" # tar extracts into the current directory
            for TB in "${M}"/*.tgz; do
                T=${TB%.tgz} # get folder name (no .tar)
                if [[ ! -e "${T}/" ]]; then
                    echo "Extracting diagnostic tarball (cvdp): ${TB}"
                    tar xzf "${TB}"
                    [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                    touch "${T}" # update modification date of folder
                elif [[ "${TB}" -nt "${T}/" ]]; then
                    echo "Extracting new diagnostic tarball (cvdp): ${TB}"
                    rm -r "${T}/"
                    tar xzf "${TB}"
                    [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                    touch "${T}" # update modification date of folder
                else
                    echo "${T} diagnostics are up-to-date (cvdp)"
                fi # if $T/
            done # for *.tgz
        fi # if ${M}/*.tgz
        echo
    fi # if ls scinet
done # for experiments

if [[ "${INVERT}" != 'INVERT' ]] # only update to SciNet
  then
    # generate list of ensembles to copy back to SciNet
    D=''; for R in ${ENS}; do D="${D} ${CESMDATA}/cesmavg/${R}"; done # assemble list of source folders
    # loop over all relevant ensembles
    for E in $( ls -d ${D} ) # get folder listing (this time local)
      do 

        E=${E%/} # necessary for folder/experiment name
        N=${E##*/} # isolate folder name (local folder name)
        echo
        echo "   ***   Copying $N to SciNet  ***   "
        echo
        
        ## synchronize/backup cesmavg/ens files
        if [[ "${RESTORE}" == 'RESTORE' ]]
          then
            F="${CESMSRC}/${N}/cesmavg/cesm[ali][tnc][mde]_*.nc" # absolute path
            # check if experiment has any data
            ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
            if [ $? == 0 ] # check exit code 
              then
                echo "${E}/" # feedback
                M="${E}/"
                # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
                rsync -vau --copy-unsafe-links -e "ssh ${SSH}" "${HOST}:${F}" "${M}/" # from here to SciNet 
                [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                # N.B.: with connection sharing, repeating connection attempts is not really necessary
                echo
            fi # if ls scinet
        else
            F="${E}/cesm[ali][tnc][mde]_*.nc" # only copy monthly climatology
            # check if experiment has any data
            ls ${F} &> /dev/null
            if [ $? == 0 ] # check exit code 
              then
                M="${CESMSRC}/${N}/cesmavg" # absolute path
                ssh ${SSH} ${HOST} "mkdir -p '${M}'" # make sure remote directory exists
                echo "${E}/" # feedback
                # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
                rsync -vau --copy-unsafe-links -e "ssh ${SSH}" ${F} "${HOST}:${M}/" # from here to SciNet 
                [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                # N.B.: with connection sharing, repeating connection attempts is not really necessary
                echo
            fi # if ls scinet
          fi # if $RESTORE

    done # for experiments
fi # if not $INVERT

# report
echo
echo
if [ $ERR -eq 0 ]
  then
    echo "   <<<   All Transfers/Post-Processing Completed Successfully!   >>>   "
  else
    echo "   ###   Transfers/Post-Processing Completed - there were ${ERR} Errors!   ###   "
fi
echo
date
echo
echo

# exit with error code
exit ${ERR}
