#!/bin/bash
# a script to write WRF and WPS namelist files from selected snippets
# Andre R. Erler, 27/09/2012

# root folder where namelist snippets are located
# every namelist group is assumed to have its own folder
# the files will be written to the current directory
WRFTOOLS=${WRFTOOLS:-"${MODEL_ROOT}/WRF Tools/"}
NMLDIR=${NMLDIR:-"${WRFTOOLS}/misc/namelists/"}

## definition section
# list of namelist groups and used snippets
# N.B.: this is a sample list - defaults are not useful
# # WRF
# TIME_CONTROL=${TIME_CONTROL:-'cycling,fineIO'}
# DIAGS=${DIAGS:-'hitop'}
# PHYSICS=${PHYSICS:-'clim'}
# NOAHMP=${NOAH_MP:-'default'}
# DOMAINS=${DOMAINS:-'wc03'}
# FDDA=${FDDA:-'spectral'}
# DYNAMICS=${DYNAMICS:-'default'}
# BDY_CONTROL=${BDY_CONTROL:-'clim'}
# NAMELIST_QUILT=${NAMELIST_QUILT:-''}
# # WPS
# SHARE=${SHARE:-'d02'}
# GEOGRID=${GEOGRID:-"${DOMAINS}"}
# METGRID=${METGRID:-'pywps'}

## function to add namelist groups to namelist file
function WRITENML () {
    # #1: namelist group, #2: snippet list, #3: filename, #4: modifications (optional)
    NMLGRP="$1" # namelist groups
    SNIPPETS="$2" # snippet list
    FILENAME="$3" # file name
    MODLIST="$4" # list of modifications
    # boundaries
    BEGIN='0,/^\s*&\w.*$/d' # regex matching the namelist group opening
    END='/^\s*\/\s*$/,$d' # regex matching the namelist group closing
    # open namelist group
    rm -f 'TEMPFILE'; touch 'TEMPFILE' # temporary file
    echo "&${NMLGRP}" >> 'TEMPFILE'
    # insert snippets
    for SNIP in ${SNIPPETS//,/ }; do
        echo " ! --- ${SNIP} ---" >> 'TEMPFILE' # document origin of snippet
        sed -e "${BEGIN}" -e "${END}" "${NMLDIR}/${NMLGRP}/${NMLGRP}.${SNIP}" | cat - >> 'TEMPFILE'
    done
    # apply modifications
    while [[ -n "${MODLIST}" ]] && [[ "${MODLIST}" != "${TOKEN}" ]]
      do
        TOKEN="${MODLIST%%:*}" # read first token (cut off all others)
        MODLIST="${MODLIST#*:}" # cut off first token and save
        NAME=$( echo ${TOKEN%%=*} | xargs ) # cut off everything after '=' and trim spaces
        MSG='this namelist entry has been edited by the setup script'
        if [[ -n $( grep "${NAME}" 'TEMPFILE' ) ]]
            then sed -i "/${NAME}/ s/^\s*${NAME}\s*=\s*.*$/${TOKEN} ! ${MSG}/" 'TEMPFILE'
            else echo "${TOKEN} ! ${MSG}"  >> 'TEMPFILE' # just append, if not already present
        fi 
#   echo "${TOKEN}"
#   echo "${MODLIST}"
#   echo "${NAME}"
    done # while $MODLIST
    # close namelist group
    echo '/' >> 'TEMPFILE'; echo '' >> 'TEMPFILE'
    # append namelist group
    cat 'TEMPFILE' >> "${FILENAME}"
    rm 'TEMPFILE'
} # fct. WRITENML

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
WRITENML 'time_control' "${TIME_CONTROL}" "${NML}" "${TIME_CONTROL_MOD}"
# namelist group &diags
WRITENML 'diags' "${DIAGS}" "${NML}" "${DIAGS_MOD}"
# namelist group &physics
WRITENML 'physics' "${PHYSICS}" "${NML}" "${PHYSICS_MOD}"
# namelist group &noah_mp
WRITENML 'noah_mp' "${NOAH_MP}" "${NML}" "${NOAH_MP_MOD}"
# namelist group &domains
WRITENML 'domains' "${DOMAINS}" "${NML}" "${DOMAINS_MOD}"
# namelist group &fdda
WRITENML 'fdda' "${FDDA}" "${NML}" "${FDDA_MOD}"
# namelist group &dynamics
WRITENML 'dynamics' "${DYNAMICS}" "${NML}" "${DYNAMICS_MOD}"
# namelist group &bdy_control
WRITENML 'bdy_control' "${BDY_CONTROL}" "${NML}" "${BDY_CONTROL_MOD}"
# namelist group &namelist_quilt
WRITENML 'namelist_quilt' "${NAMELIST_QUILT}" "${NML}" "${NAMELIST_QUILT_MOD}"

## assemble WPS namelist
# go over namelist groups and concatenate file
NML='namelist.wps'
rm -f "${NML}"; touch "${NML}"  # create WPS namelist file in current directory
# namelist group &share
WRITENML 'share' "${SHARE}" "${NML}" "${SHARE_MOD}"
# namelist group &geogrid
WRITENML 'geogrid' "${GEOGRID}" "${NML}" "${GEOGRID_MOD}"
# namelist group &metgrid
WRITENML 'metgrid' "${METGRID}" "${NML}" "${METGRID_MOD}"
