#!/bin/bash
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
## scenario definition section
NAME='test'
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="1981-05-16:1981-05-21:1D" # run from May 16th to 21st 1981 in daily intervals
# N.B.: the date range is given as start:end:freq using the Pandas date_range format
# I/O and archiving
IO='fineIO' # this is used for namelist construction and archiving
ARSCRIPT='DEFAULT' # set ARSCRIPT='DEFAULT' to let $IO control archiving
ARINTERVAL='' # default is monthly (after every run), but yearly is preferable
AVGINTERVAL=''

## configure data sources
RUNDIR="${PWD}" # must not contain spaces!
# source data definition
DATATYPE='CFSR'
DATADIR='/data/CFSR/'
# other WPS configuration files
GEODATA='/data/WRF/geog_v3.6'

## namelist definition section
# list of namelist groups and used snippets
MAXDOM=1 # number of domains in WRF and WPS
RES='120km'
DOM="arb1-${RES}"
# WRF
TIME_CONTROL="cycling,${IO}"
DIAGS='hitop'
#PHYSICS='clim'
PHYSICS='clim-new-v36'
NOAH_MP='new'
DOMAINS="${DATATYPE,,}-${RES},${DOM}-grid"
FDDA='spectral'
DYNAMICS='default'
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

## custom environment section (will be inserted in run script)
# --- begin custom environment ---
export TEST='this is a test variable' # just to test custom environment snippets
# ---  end custom environment  ---

## system settings
#WPSWCT='00:03:00'
#WRFWCT='00:15:00'
#WRFNODES=4
#DELT='45'
WRFROOT="$MODEL_ROOT/WRFV3.6/"
# WPS executables
#WPSBLD='Clim-fineIO'
WPSSYS="Linux" # also affects unccsm.exe
# set path for metgrid.exe and real.exe explicitly using METEXE and REALEXE
# WRF executable
WRFSYS="Linux"
#WRFBLD='Clim-fineIO'
# set path for geogrid.exe and wrf.exe eplicitly using GEOEXE and WRFEXE
