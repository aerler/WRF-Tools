#!/bin/bash
# this is a sample configuration file for knightly.sh and associated scripts
# Fengyi Xie and Andre R. Erler, March 2016, GPL v3

# Environmental variable used by knightly.sh are defined here
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
NICENESS=${NICENESS:-10}

# location of YAML configuration files for Python scripts
PYYAML_WRFAVG="${WRFDATA}/wrfavg/wrfavg.yaml"
PYYAML_EXSTNS="${DATA_ROOT}/exstns.yaml"
PYYAML_SHPAVG="${DATA_ROOT}/shpavg.yaml"
PYYAML_REGRID="${DATA_ROOT}/regrid.yaml"


# Environmental variable used by sync-wrf are defined here

# connection settings for sync jobs
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
    Echo "HISPD not implemented yet!"
else    
    SSH="-o BatchMode=yes -o ControlPath=${HOME}/master-%l-%r@%h:%p -o ControlMaster=auto -o ControlPersist=1" # default SSH login options
    HOST='' # login for the remote host where the data repository is located
    SRC='' # root folder of remote data repository (source)
    SUBDIR='' # sub-folders of remote data repository
    INVERT='FALSE' # source has name first then folder type (like on SciNet)

fi
