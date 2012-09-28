#!/bin/bash
# a script to write WRF and WPS namelist files from selected snippets
# Andre R. Erler, 27/09/2012

# root folder where namelist snippets are located
# every namelist group is assumed to have its own folder
# the files will be written to the current directory
nmldir="${MODEL_ROOT}/WRF Tools/misc/namelists/"

## definition section
# list of namelist groups and used snippets
# WRF
time_control=
diags=
physics=
domains=
fdda=
dynamics=
bdy_control=
namelist_quilt=
# WPS
share=
geogrid=
metgrid=

