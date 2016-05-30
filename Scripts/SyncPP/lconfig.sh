#!/bin/bash
# this is a sample configuration file for the client synchronization script (sync-client.sh)
# Andre R. Erler, 30/05/2016, GPL v3

# essential variables
export CODE_ROOT="${CODE_ROOT:-${HOME}/Code/}" # code root (makes things easier)
export DATA_ROOT="${DATA_ROOT:-/data/}" # root folder of data repository
# N.B.: these two variables need to respect defaults, otherwise the variables can not be changed from the command line
SCRIPTS="${CODE_ROOT}/WRF-Tools/Scripts/SyncPP/" # folder with sync and NCO scripts
NICENESS=${NICENESS:-10}

# Environment variables used by rsync scripts are defined here

# data root directories
export SUBDIR='GreatLakes' # project subfolders
#export SUBDIR='WesternCanada GreatLakes' # project subfolders
# WRF & CESM data directories
export WRFDATA="${DATA_ROOT}/WRF/" # local WRF data root
export CESMDATA="${DATA_ROOT}/CESM/" # local CESM data root

# connection settings for rsync scripts

# SSH settings for HPC cluster
# same as ssh settings for unattended nightly update: 
# special identity/ssh key, batch mode, and connection sharing
CLUSTER='' # user login for HPC cluster
CLUSTERSSH="-i ${HOME}/.ssh/rsync -o BatchMode=yes -o ControlPath=${HOME}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1"
# SSH settings for workstation
WORKSTN='' # user login for workstation
WORKSTNSSH="-o BatchMode=yes"
# N.B.: the logins can also be SSH configurations which are defined in ${HOME}/.ssh/config
