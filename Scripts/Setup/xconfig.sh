#!/bin/bash
## scenario definition section
NAME='test'
# GHG emission scenario
GHG='RCP8.5' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="monthly.1979-2009" # stepfile to be used (leave empty if not cycling)
# I/O and archiving
IO='fineIO' # this is used for namelist construction and archiving
ARSCRIPT='DEFAULT' # set ARSCRIPT='DEFAULT' to let $IO control archiving
ARINTERVAL='YEARLY' # default is monthly (after every run), but yearly is preferable

## namelist definition section
# list of namelist groups and used snippets
MAXDOM=2 # number of domains in WRF and WPS
# WRF
TIME_CONTROL="cycling,$IO"
DIAGS='hitop'
PHYSICS='clim'
NOAH_MP=''
DOMAINS='wc02'
FDDA='spectral'
DYNAMICS='default'
BDY_CONTROL='clim'
NAMELIST_QUILT=''
# WPS
SHARE='d02'
GEOGRID="${DOMAINS}"
METGRID='pywps'

## configure data sources
RUNDIR="${PWD}"
# source data definiton
DATADIR="/scratch/p/peltier/marcdo/archive/tb20trcn1x1/"
# other WPS configuration files
POPMAP="map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc" # ocean grid definition
GEOGRIDTBL="GEOGRID.TBL.FLAKE"
METGRIDTBL="METGRID.TBL.CESM"

## system settings
WRFTOOLS="${MODEL_ROOT}/WRF-Tools-tmp/"
# WPS executables
WPSSYS="GPC" # also affects unccsm.exe
# set path for metgrid.exe and real.exe explicitly using METEXE and REALEXE
# WRF executable
WRFSYS="GPC"
# set path for geogrid.exe and wrf.exe eplicitly using GEOEXE and WRFEXE
