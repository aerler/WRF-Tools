#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and 
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
NOGEO=$1 # option to run without geogrid
STEPFILE='stepfile' # file in $INIDIR
INIDIR="${PWD}" # current directory
METDATA="${INIDIR}/metgrid/"
WRFOUT="${INIDIR}/wrfout/"
CASENAME='cycling' # name tag
WPSSCRIPT="run_${CASENAME}_WPS.pbs"
WRFSCRIPT="run_${CASENAME}_WRF.pbs"
STATICTGZ='static.tgz' # file for static data backup

# launch feedback
echo
echo "   ***   Starting Cycle  ***   "
echo
# echo "   Stepfile: ${STEPFILE}"
echo "   Root Dir: ${INIDIR}"
echo

# clear some folders
cd "${INIDIR}"
echo "   Clearing Output Folders:"
echo "${METDATA}"
echo "${WRFOUT}"
rm -rf "${METDATA}" "${WRFOUT}" 
mkdir -p "${WRFOUT}"
echo

# run geogrid
# clear files
cd "${INIDIR}"
if [[ "${NOGEO}" == 'NOGEO'* ]]; then
  echo "   Not running geogrid.exe"
else
  rm -f geo_em.d??.nc geogrid.log*
  # run with parallel processes
  echo "   Running geogrid.exe"
  mpirun -n 4 ./geogrid.exe > /dev/null # hide stdout
fi

# read first entry in stepfile 
export STEPFILE
NEXTSTEP=$(python cycling.py)
#export NEXTSTEP
echo
echo "   First Step: ${NEXTSTEP}"
echo

# prepare first working directory
# set restart to False for first step
sed -i '/restart\s/ s/restart\s*=\s*\.true\..*$/restart = .false.,/' "${INIDIR}/${NEXTSTEP}/namelist.input"  
# and make sure the rest is on restart
sed -i '/restart\s/ s/restart\s*=\s*\.false\..*$/restart = .true.,/' "${INIDIR}/namelist.input"
echo "   Setting restart option and interval in namelist."
# echo

# create backup of static files
cd "${INIDIR}"
rm -rf 'static/'
mkdir -p 'static'
echo $( cp -P * 'static/' &> /dev/null ) # trap this error and hide output
cp -rL 'meta/' 'tables/' 'static/'
tar czf "${STATICTGZ}" 'static/'
rm -r 'static/'
mv "${STATICTGZ}" "${WRFOUT}"
echo "   Saved backup file for static data:"
echo "${WRFOUT}/${STATICTGZ}"
echo

# submit first WPS instance
qsub ./${WPSSCRIPT} -v NEXTSTEP="${NEXTSTEP}"

# submit first WRF instance
qsub ./${WRFSCRIPT} -v NEXTSTEP="${NEXTSTEP}"
