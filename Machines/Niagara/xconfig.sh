#!/bin/bash
## scenario definition section
NAME='erai-test'
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="1979:2009:1M" # stepfile to be used (leave empty if not cycling)
# I/O and archiving
IO='fineIO' # this is used for executables and archiving
ARSYS='HPSS' # archiving on Niagara
ARSCRIPT='DEFAULT' # default archiving script
ARINTERVAL='YEARLY' # default is yearly
AVGSYS='Niagara' # post-processign on Niagara
AVGSCRIPT='DEFAULT' # default post-processing
AVGINTERVAL='YEARLY' # default is yearly

## configure data sources
RUNDIR="${PWD}" # must not contain spaces!
# source data definition
DATATYPE='ERA-I'
DATADIR="/scratch/p/peltier/aerler/${DATATYPE}/"
# other WPS configuration files
GEODATA="/project/p/peltier/WRF/geog_v3.9/"

## namelist definition section
# list of namelist groups and used snippets
MAXDOM=2 # number of domains in WRF and WPS
RES='30km'
DOM="arb3-${RES}"
# WRF
TIME_CONTROL="cycling,${IO}" # use fineIO and switch on snow diagnostics
TIME_CONTROL_MOD=' io_form_auxhist10 = 2 ! switch on hourly snow diagnostics'
DIAGS='hitop' # needs output stream #23
PHYSICS='clim-new-v36' # this namelist has to be compatible with the WRF build used!
# PHYSICS_MOD=' cu_physics = 5, 0, 0, ! no convection scheme in inner domain : cu_rad_feedback = .true., .false., .false., : cu_diag = 0, : cugd_avedx = 2 ! increase subsidence spreading in outer domain ' # fractional_seaice = 0, ! does not work with ERA-I? 
# PHYSICS_MOD=' sf_lake_physics = 1, 1, 1, ! maybe works now... : use_lakedepth = 0 ! lets try with default depth'
NOAH_MP='new-v36'
DOMAINS="${DATATYPE,,}-${RES},${DOM}-grid" # lower-case dataset name
DOMAINS_MOD=' time_step   = 150 ! for more stability: e_vert   = 42, 42, 42, ! increase vertical resolution for V3.6'
FDDA='spectral'
DYNAMICS='default'
DYNAMICS_MOD=' epssm = 0.5, 0.5, 0.5 ! necessary over the Rocky Mountains'
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
FLAKE=0 # don't use FLake (doesn't work with FLake in V3.6)

## system settings
WRFTOOLS="${HOME}/WRF Tools/"
WRFROOT="${HOME}/WRFV3.9/"
# WRF and WPS wallclock  time limits (no way to query from queue system)
# WRF and WPS wallclock  time limits (no way to query from queue system)
MAXWCT='24:00:00' # WRF wallclock hard limit
WRFWCT='04:00:00' # WRF expected wallclock time
WPSWCT='02:00:00' # WPS wallclock time limit
WRFNODES=4
# WPS executables
WPSSYS="Niagara"
# set path for metgrid.exe and real.exe explicitly using METEXE and REALEXE
# WRF executable
WRFSYS="Niagara"
# set path for geogrid.exe and wrf.exe eplicitly using GEOEXE and WRFEXE
