#!/bin/bash
## scenario definition section
NAME=''
# GHG emission scenario
GHG='A2' # CAMtr_volume_mixing_ratio.* file to be used
# time period and cycling interval
CYCLING="monthly" # stepfile to be used (leave empty if not cycling)

## namelist definition section
# list of namelist groups and used snippets
# WRF
TIME_CONTROL='cycling,fineio'
DIAGS='hitop'
PHYSICS='clim'
DOMAINS='wc02'
FDDA='spectral'
DYNAMICS='default'
BDY_CONTROL='clim'
NAMELIST_QUILT=''
# WPS
SHARE='default'
GEOGRID="${DOMAINS}"
METGRID='pywps'

## configure data sources
RUNDIR="${PWD}"
# source data definiton 
NCL="setup.ncl.cesm" # CESM grid parameters (for sea-ice) for NCL
DATADIR="/scratch/p/peltier/marcdo/archive/tb20trcn1x1/" 
# other WPS configuration files
POPMAP="map_gx1v6_to_fv0.9x1.25_aave_da_090309.nc" # ocean grid definition
GEOGRID="GEOGRID.TBL.FLAKE"
METGRID="METGRID.TBL.CESM"

## system settings
WRFTOOLS="${MODEL_ROOT}/WRF Tools/"
# WPS executables
WPSSYS="GPC" # general system
GEOEXE="${WPSSRC}/GPC/Clim-fullIO/O3xHost/geogrid.exe"
METEXE="${WPSSRC}/GPC/Clim-fullIO/O3xHost/metgrid.exe"
REALEXE="${WRFSRC}/GPC/Clim-fineIO-03/O3xHost/real.exe"
# WRF executable
WRFSYS="GPC" # WRF
WRFEXE="${WRFSRC}/GPC/Clim-fineIO-03/O3xHost/wrf.exe"