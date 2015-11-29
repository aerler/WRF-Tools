#!/bin/bash

# load modules (for some reason newer versions will crash)
module purge
#module load xlf vacpp netcdf
module list
echo

## define environment variables (used outside this script!)
export HFOUT='HFOUT' # whether or not to write with HF output
# case dependent variables
export REFCASE='abrcp85cn1x1'
export CASE="h${REFCASE}d" # standard naming scheme for ensemble members
export REFDATE='2085-01-01'
export COMPSET=B_RCP8.5_CN
export RES=f09_g16
# system dependent variables
export SCRATCH="${SCRATCH}"
export RUNDIR="/scratch/p/peltier/aerler/CESM/run/${CASE}/run/"
export CCSMROOT='/project/c/ccsm/cesm1_current/'
export RSTDIR="/${SCRATCH}/CESM/run/${REFCASE}/rest/${REFDATE}-00000/"
export MACH=tcs
export CASEROOT="${PROJECT}/CESM/build/${CASE}/"
export NML="${PROJECT}/CESM/build/namelists/"


# get source code
cd $CCSMROOT/scripts
./create_newcase -verbose -case $CASEROOT -mach $MACH -compset $COMPSET -res $RES 
echo

# get modified configuration files
cd $CASEROOT
echo Copying additional configuration files...
cp ../setup_$CASE-rerun.sh .
cp ../changeXML.sh .
# copy namelists for High-frequency (HF) output
if [[ "$HFOUT" == 'HFOUT' ]]
  then cp ${NML}/HF/user_nl_* . 
  # N.B.: also need to change CICE namelist!
  else cp ${NML}/Default/user_nl_* .
fi # if HFOUT
# now change CICE namelist (special case for sea-ice experiment) 
if [[ -f ${NML}/cice/cice.buildnml.csh.$CASE ]]
  then cp ${NML}/cice/cice.buildnml.csh.$CASE cice.buildnml.csh
  else cp ${NML}/cice/cice.buildnml.csh.default cice.buildnml.csh
fi

# apply modifications
echo Making changes to XML files...
./changeXML.sh
echo
# if case name is the same as ref-case
if [[ "${CASE}" == "${REFCASE}" ]]; then
    ./xmlchange -file env_conf.xml -id="BRNCH_RETAIN_CASENAME"   -val="TRUE"
    ./xmlchange -file env_run.xml -id="RESUBMIT"   -val="5"
fi

# run configure script
./configure -case
echo

# edit namelist script
if [[ "$HFOUT" == 'HFOUT' ]]; then
    echo Editing and copying namelist script for sea-ice...
    sed -i "/\${REFCASE}/ s/\${REFCASE}/${REFCASE}/g" cice.buildnml.csh
    sed -i "/\${REFDATE}/ s/\${REFDATE}/${REFDATE}/g" cice.buildnml.csh
    # copy modified namelist script (overwrites existing script)
    cp cice.buildnml.csh Buildconf/
    #diff cice.buildnml.csh Buildconf/
fi # if HFOUT

# get input data (restart files)
echo Copying input data...
mkdir -p "$RUNDIR"
cp $RSTDIR/* "$RUNDIR"
#cp $RSTDIR/rpointer.* "$RUNDIR" 
## N.B.: rpointer-files need to be copied, because they are modified during run time, the rest can be linked
#for NC in $RSTDIR/*.nc
#  do ln -s $NC "$RUNDIR"
#done
echo
echo "RUNDIR: $RUNDIR"
echo
ls "$RUNDIR"
echo
# create a preambel for the build script
echo '#! /bin/bash

# preambel: we need to purge modules and remove GNU tools from the PATH
module purge
export PATH=${PATH#/usr/linux/bin/:}
' > $CASE.$MACH.bash_build
echo "# launch actual build script in C shell
csh -f $CASE.$MACH.build
" >> $CASE.$MACH.bash_build
chmod u+x $CASE.$MACH.bash_build
echo "Navigate to simulation folder: cd $CASE/"
echo "Build model with ./$CASE.$MACH.bash_build ($CASE.$MACH.bash_build requires clean environment)"
sed -i "/llsubmit/ s/llsubmit ${CASE}.${MACH}.run/ssh tcs02 \"cd \${PWD}; export CCSMSRC=\${CCSMSRC}; llsubmit ${CASE}.${MACH}.run\"/g" $CASE.$MACH.submit
echo "Run (from any node): ./$CASE.$MACH.submit"
echo
