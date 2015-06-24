#!/bin/bash
# short script to prepare working directory for execWPS.sh and execWRF.sh
# created 06/07/2012 by Andre R. Erler, GPL v3

# initial directory
cd "${INIDIR}"

# clear and (re-)create job folder if neccessary
	echo
if [[ $CLEARWDIR == 1 ]]; then
	# only delete folder if we are running real.exe or input data is coming from elsewhere
	echo 'Removing old working directory:'
	rm -rf "${WORKDIR}"
	mkdir -p "${WORKDIR}"
else
	echo 'Using existing working directory:'
	# N.B.: the execWPS-script does not clobber, i.e. config files in the work dir are used
	mkdir -p "${WORKDIR}"
fi
	echo "${WORKDIR}"
	echo
