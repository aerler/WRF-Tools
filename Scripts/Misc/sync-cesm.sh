#!/bin/bash
# script to synchronize CESM data with SciNet

# CESM directories / data sources
REX='h[abc]b20trcn1x1 tb20trcn1x1 h[abcz]brcp85cn1x1 htbrcp85cn1x1 seaice-5r-hf h[abcz]brcp85cn1x1d htbrcp85cn1x1d seaice-5r-hfd'
CESMDATA=${CESMDATA:-/data/CESM/} # can be supplied by caller
CCA='/reserved1/p/peltier/aerler/CESM/archive/' # archives with my own cesmavg files
# connection settings
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
		SSH="-o BatchMode=yes -o ControlPath=${CESMDATA}/hispd-master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
		HOST='datamover' # defined in .ssh/config
  else
    # ssh settings for unattended nightly update: special identity/ssh key, batch mode, and connection sharing
		SSH="-i /home/me/.ssh/rsync -o BatchMode=yes -o ControlPath=${CESMDATA}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
		HOST='aerler@login.scinet.utoronto.ca'
fi # if high-speed

echo
echo
hostname
date
echo 
echo "   >>>   Synchronizing Local CESM Climatologies with SciNet   <<<   " 
echo
echo "      Local:  ${CESMDATA}"
echo "      Host: ${HOST}"
echo
echo "   Experiments: ${REX}"
echo

ERR=0
#shopt -s extglob

# generate list of experiments
D=''; for R in ${REX}; do D="${D} ${CCA}/${R}"; done # assemble list of source folders
# loop over all relevant experiments
for E in $( ssh ${SSH} ${HOST} "ls -d ${D}" ) # get folder listing from scinet
  do 
    echo
    echo "   ***   $E   ***   "
    echo
    
    ## synchronize cesmavg files
    E=${E%/} # necessary for subsequent step (see below)
    F="${E}/cesmavg/cesm[ali][tnc][mde]_*.nc" # monthly climatology and time-series
    # check if experiment has any data
    ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
    if [ $? == 0 ] # check exit code 
      then
        N=${E##*/} # isolate folder name (local folder name)
        M="${CESMDATA}/cesmavg/${N}" # absolute path
        mkdir -p "${M}" # make sure directory is there
        echo "${N}" # feedback
        # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
        rsync -vau -e "ssh ${SSH}" "${HOST}:${F}" ${M}/ 
        ERR=$(( ${ERR} + $? )) # capture exit code, and repeat, if unsuccessful
        # N.B.: with connection sharing, repeating connection attempts is not really necessary
        echo
    fi # if ls scinet

    ## synchronize AMWG & CVDP dignostic files
	  # loop over all relevant experiments (same list of source folders)
		for ANA in diag cvdp
		  do 
		    #echo $ANA
		    E=${E%/} # necessary for subsequent step (see below)
		    F="${E}/${ANA}/*.tar" # tarball with HTML browseable diagnostics
		    #echo $F
		    # check if experiment has any data
		    ssh ${SSH} ${HOST} "ls ${F}" &> /dev/null
		    if [ $? == 0 ] # check exit code 
		      then
		        N=${E##*/} # isolate folder name (local folder name)
		        M="${CESMDATA}/${ANA}/${N}" # absolute path
		        mkdir -p "${M}" # make sure directory is there
		        echo "${N}" # feedback
		        # use rsync for the transfer; verbose, archive, update (gzip is probably not necessary)
		        rsync -vau -e "ssh ${SSH}" "${HOST}:${F}" "${M}/"
		        ERR=$(( ${ERR} + $? )) # capture exit code, and repeat, if unsuccessful
		        # N.B.: with connection sharing, repeating connection attempts is not really necessary
		        # extract tarball, if file was updated
            ls "${M}"/*.tar &> /dev/null # make sure tarball is there
		        if [ $? -eq 0 ] # puttign the globex into the bracket fails if there is no tarball!
		          then
		            cd "${M}" # tar extracts into the current directory
		            for TB in "${M}"/*.tar; do
		                T=${TB%.tar} # get folder name (no .tar)
		                if [[ ! -e "${T}/" ]]; then
		                    echo "Extracting diagnostic tarball (${ANA}): ${TB}"
		                    tar xf "${TB}"
		                    ERR=$(( ${ERR} + $? )) # capture exit code, and repeat, if unsuccessful
		                    touch "${T}" # update modification date of folder
		                elif [[ "${TB}" -nt "${T}/" ]]; then
		                    echo "Extracting new diagnostic tarball (${ANA}): ${TB}"
		                    rm -r "${T}/"
		                    tar xf "${TB}"
		                    ERR=$(( ${ERR} + $? )) # capture exit code, and repeat, if unsuccessful
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

# report
echo
echo
if [ $ERR -eq 0 ]
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
