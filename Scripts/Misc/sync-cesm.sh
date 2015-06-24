#!/bin/bash
# script to synchronize CESM data with SciNet

RESTORE=${RESTORE:-'FALSE'} # restore datasets from SciNet backup
# CESM directories / data sources
REX=${REX:-'h[abc]b20trcn1x1 tb20trcn1x1 h[abcz]brcp85cn1x1 htbrcp85cn1x1 seaice-5r-hf h[abcz]brcp85cn1x1d htbrcp85cn1x1d seaice-5r-hfd'}
ENS=${ENS:-'ens20trcn1x1 ensrcp85cn1x1 ensrcp85cn1x1d'}
CVDP=${CVDP:-"${ENS} grand-ensemble"}
if [[ "${CVDP}" == 'NONE' ]]; then CVDP=''; fi
CESMDATA=${CESMDATA:-/data/CESM/} # can be supplied by caller
# data selection
FILETYPES=${FILETYPES:-'cesm[ali][tnc][mde]_monthly.nc'}
if [[ "${FILETYPES}" == 'NONE' ]]; then FILETYPES=''; fi
DIAGS=${DIAGS:-'diag cvdp'}
if [[ "${DIAGS}" == 'NONE' ]]; then DIAGS=''; fi
# connection settings
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
    SSH="-o BatchMode=yes -o ControlPath=${CESMDATA}/hispd-master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
    HOST='datamover' # defined in .ssh/config
    CCA='/reserved1/p/peltier/aerler//CESM/archive/'
    INVERT='FALSE' # source has name first then folder type (like on SciNet)
elif [[ "${HOST}" == 'komputer' ]]
  then
    # download from komputer instead of SciNet using sshfs connection
    SSH="-o BatchMode=yes"
    HOST='fskomputer' # defined in .ssh/config
    CCA='/data/CESM/cesmavg/' # archives with my own cesmavg files
    INVERT='INVERT' # invert name/folder order in source (i.e. like in target folder)
else
    # ssh settings for unattended nightly update: special identity/ssh key, batch mode, and connection sharing
    SSH="-i /home/me/.ssh/rsync -o BatchMode=yes -o ControlPath=${CESMDATA}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
    HOST='aerler@login.scinet.utoronto.ca'
    CCA='/reserved1/p/peltier/aerler//CESM/archive/'
    INVERT='FALSE' # source has name first then folder type (like on SciNet)
fi # if high-speed

echo
echo
hostname
date
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
D=''; for R in ${REX}; do D="${D} ${CCA}/${R}"; done # assemble list of source folders
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
            rsync -vau -e "ssh ${SSH}" "${HOST}:${F}" ${M}/ 
            [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
            # N.B.: with connection sharing, repeating connection attempts is not really necessary
            echo
        fi # if ls scinet
    done # loop over FILETYPES
        
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
            rsync -vau -e "ssh ${SSH}" "${HOST}:${F}" "${M}/"
            [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
            # N.B.: with connection sharing, repeating connection attempts is not really necessary
            # extract tarball, if file was updated
            ls "${M}"/*.tgz &> /dev/null # make sure tarball is there
            if [ $? -eq 0 ] # puttign the globex into the bracket fails if there is no tarball!
              then
                cd "${M}" # tar extracts into the current directory
                for TB in "${M}"/*.tgz; do
                    T=${TB%.tar} # get folder name (no .tar)
                    if [[ ! -e "${T}/" ]]; then
                        echo "Extracting diagnostic tarball (${ANA}): ${TB}"
                        tar xzf "${TB}"
                        [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                        touch "${T}" # update modification date of folder
                    elif [[ "${TB}" -nt "${T}/" ]]; then
                        echo "Extracting new diagnostic tarball (${ANA}): ${TB}"
                        rm -r "${T}/"
                        tar xzf "${TB}"
                        [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
                        touch "${T}" # update modification date of folder
                    else
                        echo "${T} diagnostics are up-to-date (${ANA})"
                    fi # if $T/
                done # for *.tar
            fi # if ${M}/*.tar
            echo
        fi # if ls scinet
    done # for amwg & cvdp
done # for experiments

# generate list of additional CVDP folders (ensembles)
D=''; for R in ${CVDP}; do D="${D} ${CCA}/${R}"; done # assemble list of source folders
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
        rsync -vau -e "ssh ${SSH}" "${HOST}:${F}" "${M}/"
        [ $? -gt 0 ] && ERR=$(( $ERR + 1 )) # capture exit code
        # N.B.: with connection sharing, repeating connection attempts is not really necessary
        # extract tarball, if file was updated
        ls "${M}"/*.tgz &> /dev/null # make sure tarball is there
        if [ $? -eq 0 ] # putting the globex into the bracket fails if there is no tarball!
          then
            cd "${M}" # tar extracts into the current directory
            for TB in "${M}"/*.tgz; do
                T=${TB%.tar} # get folder name (no .tar)
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
            done # for *.tar
        fi # if ${M}/*.tar
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
            F="${CCA}/${N}/cesmavg/cesm[ali][tnc][mde]_*.nc" # absolute path
            # check if experiment has any data
            ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
            if [ $? == 0 ] # check exit code 
              then
                echo "${E}/" # feedback
                M="${E}/"
                # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
                rsync -vau -e "ssh ${SSH}" "${HOST}:${F}" "${M}/" # from here to SciNet 
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
                M="${CCA}/${N}/cesmavg" # absolute path
                ssh ${SSH} ${HOST} "mkdir -p '${M}'" # make sure remote directory exists
                echo "${E}/" # feedback
                # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
                rsync -vau -e "ssh ${SSH}" ${F} "${HOST}:${M}/" # from here to SciNet 
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
