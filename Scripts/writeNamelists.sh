#!/bin/bash
# a script to write WRF and WPS namelist files from selected snippets
# Andre R. Erler, 27/09/2012

# root folder where namelist snippets are located
# every namelist group is assumed to have its own folder
# the files will be written to the current directory
NMLDIR="${MODEL_ROOT}/WRF Tools/misc/namelists"

## definition section
# list of namelist groups and used snippets
# WRF
TIME_CONTROL=${TIME_CONTROL:-'cycling,fineio'}
DIAGS=${DIAGS:-'hitop'}
PHYSICS=${PHYSICS:-'clim'}
DOMAINS=${DOMAINS:-'wc02'}
FDDA=${FDDA:-'spectral'}
DYNAMICS=${DYNAMICS:-'default'}
BDY_CONTROL=${BDY_CONTROL:-'clim'}
NAMELIST_QUILT=${NAMELIST_QUILT:-''}
# WPS
SHARE=${SHARE:-'d02'}
GEOGRID=${GEOGRID:-"${DOMAINS}"}
METGRID=${METGRID:-'pywps'}

## function to add namelsit groups to namelist file
function WRITENML () {
	# #1: namelist group, #2: snippet list, #3: filename
	BEGIN='0,/^\s*&\w.*$/d' # regex matching the namelist group opening
	END='/^\s*\/\s*$/,$d' # regex matching the namelist group closing
	# open namelist group
	echo "&${1}" >> "${3}"
	# insert snippets
	for SNIP in ${2//,/ }; do
		echo " ! --- ${SNIP} ---" >> "${3}" # document origin of snippet
 		sed -e "${BEGIN}" -e "${END}" "${NMLDIR}/${1}/${1}.${SNIP}" | cat - >> "${3}"
	done		
	# close namelist group
	echo '/' >> "${3}"; echo '' >> "${3}"
}

# write preamble
function WRITEPREAMBLE () {
	DATE=$( date )
	echo "! This file was automatically generated on $DATE" >> "${1}" 
	echo "! The namelist snippets from which this file was concatenated, can be found in" >> "${1}"
	echo "! ${NMLDIR}" >> "${1}"
	echo '' >> "${1}"
}

## assemble WRF namelist
# go over namelist groups and concatenate file
NML='namelist.input'
rm -f "${NML}"; touch "${NML}"  # create WPS namelist file in current directory
# write preamble
WRITEPREAMBLE "${NML}"
# namelist group &time_control
WRITENML 'time_control' "${TIME_CONTROL}" "${NML}"
# namelist group &diags
WRITENML 'diags' "${DIAGS}" "${NML}"
# namelist group &physics
WRITENML 'physics' "${PHYSICS}" "${NML}"
# namelist group &domains
WRITENML 'domains' "${DOMAINS}" "${NML}"
# namelist group &fdda
WRITENML 'fdda' "${FDDA}" "${NML}"
# namelist group &dynamics
WRITENML 'dynamics' "${DYNAMICS}" "${NML}"
# namelist group &bdy_control
WRITENML 'bdy_control' "${BDY_CONTROL}" "${NML}"
# namelist group &namelist_quilt
WRITENML 'namelist_quilt' "${NAMELIST_QUILT}" "${NML}"

## assemble WPS namelist
# go over namelist groups and concatenate file
NML='namelist.wps'
rm -f "${NML}"; touch "${NML}"  # create WPS namelist file in current directory
# namelist group &share
WRITENML 'share' "${SHARE}" "${NML}"
# namelist group &geogrid
WRITENML 'geogrid' "${GEOGRID}" "${NML}"
# namelist group &metgrid
WRITENML 'metgrid' "${METGRID}" "${NML}"