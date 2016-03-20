#!/bin/bash
# this is the configuration file for knightly.sh

# Environmental variable used by knightly.sh are defined here
NODOWNLOAD=''
NOCOMPUTE=''
NOENSEMBLE=''
NOLOGGING=''

# environment
export GDAL_DATA='' # for GDAL API
CODE="" # code root
export PYTHONPATH="" # path for python modules, include custom modules from Geopy/Gdal/other python builds.
# scripts/executables
PYTHON='' # path to Python home (do not export!)
SCRIPTS="" # folder with all the scripts
# data root directories
export ROOT="" # Root folder where data is
export WRFDATA="" # local WRF data root
export CESMDATA="" # local CESM data root
export WRFAVG="" #the experiment folder for sync jobs


# Environmental variable used by sync-wrf are defined here

# connection settings for sync jobs
if [[ "${HISPD}" == 'HISPD' ]]
  then
    # high-speed transfer: special identity/ssh key, batch mode, and connection sharing
    Echo "HISPD not implemented yet!"
else
    # ssh settings for login nodes of scinet
    SSH="" # ssh key file location for scinet connections
    HOST='' # username on Scinet
    CCA='' # data directory on Scinet
    INVERT='FALSE' # source has name first then folder type (like on SciNet)
fi
