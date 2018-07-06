#!/bin/bash
# this is a sample configuration file for knightly.sh and associated scripts
# Fengyi Xie and Andre R. Erler, March 2016, GPL v3

# Environment variables used by knightly.sh can be defined here
NODOWNLOAD=''
NOCOMPUTE=''
NOENSEMBLE=''
NOLOGGING=''

# essential variables
export CODE_ROOT="${CODE_ROOT:-${HOME}/Code/}" # code root (makes things easier)
export DATA_ROOT="${DATA_ROOT:-/data/}" # root folder of data repository
# N.B.: these two variables need to respect defaults, otherwise the variables can not be changed from the command line

# some sensible defaults for Linux systems
export GDAL_DATA='/usr/local/share/gdal' # for GDAL API
PYTHON='/usr/bin/python' # path to Python executable (do not export!)
# Python modules and other scripts
export PYTHONPATH="${CODE_ROOT}/GeoPy/src/:${CODE_ROOT}/WRF-Tools/Python/" # required modules
SCRIPTS="${CODE_ROOT}/WRF-Tools/Scripts/SyncPP/" # folder with sync and NCO scripts
# WRF & CESM data directories
export WRFDATA="${DATA_ROOT}/WRF/" # local WRF data root
export CESMDATA="${DATA_ROOT}/CESM/" # local CESM data root
# general settings
export FIGURE_ROOT="${HOME}" # this variable is not used; only to prevent crash
NICENESS=${NICENESS:-10}

# location of YAML configuration files for Python scripts
PYYAML_WRFAVG="${WRFDATA}/wrfavg/wrfavg.yaml"
PYYAML_EXSTNS="${DATA_ROOT}/exstns.yaml"
PYYAML_REGRID="${DATA_ROOT}/regrid.yaml"
PYYAML_EXPORT="${DATA_ROOT}/export.yaml"
PYYAML_SHPAVG="${DATA_ROOT}/shpavg.yaml"


# Environment variables used by rsync scripts are defined here
export WRFREX='*-*' # all available
export SUBDIR='WesternCanada GreatLakes' # sub-folders for WRF projects
export CESMREX='h[abc]b20trcn1x1 tb20trcn1x1 h[abcz]brcp85cn1x1 htbrcp85cn1x1 seaice-5r-hf h[abcz]brcp85cn1x1d htbrcp85cn1x1d seaice-5r-hfd'
export CESMENS='ens20trcn1x1 ensrcp85cn1x1 ensrcp85cn1x1d'
export DATASETS='Unity NRCan GPCC NARR CFSR CRU PRISM PCIC EC GHCN WSC' # list of observational datasets

# connection settings for rsync scripts
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
    Echo "HISPD not implemented yet!"
else    
    export SSH="-o BatchMode=yes -o ControlPath=${HOME}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1" # default SSH login options
    export HOST='' # login for the remote host where the data repository is located
    export WRFSRC='' # root folder of remote WRF data (source)
    export CESMSRC='' # root folder of remote CESM data (source)
    export OBSSRC='' # root folder of remote observational datasets (source)
    export INVERT='FALSE' # source has name first then folder type (like on SciNet)
fi
