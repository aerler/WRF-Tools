#!/bin/bash
## scenario definition section
NAME='erai-wc2'
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="monthly.2013-08" # stepfile to be used (leave empty if not cycling)
# I/O and archiving
IO='snowIO' # this is used for namelist construction and archiving
ARSYS='' # not available
ARSCRIPT='' # no archiving available on Bugaboo yet
ARINTERVAL='' # default is yearly
AVGSYS='Bugaboo' # post-processign on Bugaboo
AVGSCRIPT='DEFAULT' # default post-processing
AVGINTERVAL='MONTHLY' # default is yearly

## configure data sources
RUNDIR="${PWD}" # must not contain spaces!
# source data definition
DATATYPE='ERA-I'
DATADIR="/global/scratch/aerler/${DATATYPE}/"
# other WPS configuration files
GEODATA="/home/aerler/scratch/geog_v3.6/"

## namelist definition section
# list of namelist groups and used snippets
MAXDOM=2 # number of domains in WRF and WPS
RES='7km'
DOM="wc2-${RES}"
# WRF
TIME_CONTROL="cycling,${IO}" # default I/O: only output stream
DIAGS='hitop' # needs output stream #23
PHYSICS='clim-new-v36' # this namelist has to be compatible with the WRF build used!
PHYSICS_MOD=' cu_physics = 5, 0, 0, ! no convection scheme in inner domain : cu_rad_feedback = .true., .false., .false., : cu_diag = 0, : cugd_avedx = 2 ! increase subsidence spreading in outer domain ' # fractional_seaice = 0, ! does not work with ERA-I? 
# sf_lake_physics = 1, 1, 1, ! maybe works now... : use_lakedepth = 0 ! lets try with default depth'
NOAH_MP='new-v36'
DOMAINS="${DATATYPE,,}-${RES},${DOM}-grid" # lower-case dataset name
FDDA='spectral'
DYNAMICS='default'
DYNAMICS_MOD=' epssm = 0.5, 0.5, 0.5'
BDY_CONTROL='clim'
NAMELIST_QUILT=''
# WPS
# SHARE,GEOGRID, and METGRID usually don't have to be set manually
GEOGRID="${DOM},${DOM}-grid"
## namelist modifications by group
# you can make modifications to namelist groups in the {NMLGRP}_MOD variables
# the line in the *_MOD variable will replace the corresponding entry in the template
# you can separate multiple modifications by colons ':'
#PHYSICS_MOD=' cu_physics = 3, 3, 3,: shcu_physics = 0, 0, 0,: sf_surface_physics = 4, 4, 4,'
FLAKE=0 # don't use FLake

## system settings
WRFTOOLS="${HOME}/WRF Tools/"
WRFROOT="${HOME}/WRFV3.6/"
# WRF and WPS wallclock  time limits (no way to query from queue system)
# WRF and WPS wallclock  time limits (no way to query from queue system)
MAXWCT='360:00:00' # WRF wallclock hard limit
WRFWCT='120:00:00' # WRF expected wallclock time
WPSWCT='24:00:00' # WPS wallclock time limit
WRFNODES=128
# WPS executables
WPSSYS="Bugaboo"
# set path for metgrid.exe and real.exe explicitly using METEXE and REALEXE
# WRF executable
WRFSYS="Bugaboo"
# set path for geogrid.exe and wrf.exe eplicitly using GEOEXE and WRFEXE
