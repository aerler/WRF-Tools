#This is the script that calls cdb_query from python

##  imports
import os # directory operations

# os.system("cdb_query CMIP5 ask --null --help")

# Define directory and filename variables
Svalidate_file='MIROC5_rcp85_2085_pointer_local_full.validate.nc'
Soutput_file='reduce_output.nc'
Syear='2085'
Smonth='1'
Sday='1'
Shour='06'

# os.system('echo "Hello {0:} World!"'.format(Svalidate_file))

# Here defines the functions to call cdb_query_CMIP5_reduce to slice out data files
# Different numbers of arguments are needed to specify time step, so three functions are needed.
def call_cdb_query_download_6hour(validate_file, output_file, year, month, day, hour):
    os.putenv('HDF5_DISABLE_VERSION_CHECK', '1') 
    os.system('cdb_query CMIP5 reduce -O --year={0:} --month={1:} --day={2:} --hour={3:} --var=huss --var=tas --var=uas --var=vas --var=ua --var=va --var=ta --var=hus --var=ps --var=psl --out_destination=./\'{4:}_{5:}_{6:}_{7:}/\' \'\' {8:} {9:} '.format(year, month, day, hour, year, month, day, hour, validate_file, output_file))
    
def call_cdb_query_download_day(validate_file, output_file, year, month, day):
    os.putenv('HDF5_DISABLE_VERSION_CHECK', '1') 
    os.system('cdb_query CMIP5 reduce -O --year={0:} --month={1:} --day={2:} --var=snw --var=tslsi --var=sic --var=sit --var=tos --out_destination=./\'{3:}_{4:}_{5:}/\' \'\' {6:} {7:}'.format(year, month, day, year, month, day, validate_file, output_file))

def call_cdb_query_download_month(validate_file, output_file, year, month):
    os.putenv('HDF5_DISABLE_VERSION_CHECK', '1') 
    os.system('cdb_query CMIP5 reduce -O --year={0:} --month={1:} --var=tsl --var=mrlsl --var=snd --out_destination=./\'{2:}_{3:}/\' \'\' {4:} {5:}'.format(year, month, year, month, validate_file, output_file))

# Define the function that merges the reduced files into a single file
def merge_files_from_reduce(reduce_directory,file_outname):
    os.system('mv ./{0:}/*/*/*/*/*/*/*/*/*/*.nc {1:}/'.format(reduce_directory, reduce_directory))
    os.system('cdo merge ./{0:}/*.nc ./{1:}.nc'.format(reduce_directory, file_outname))

# Define the function that removes the temporary directories created by the merge functions
def clean_reduce_directory(reduce_directory):
    os.system('rm -rv ./{0:}'.format(reduce_directory))

def apply_cdb_query_singleWPSstep(Vfile,inputdate):
    #Break up the namelist date string into individual components
    stepyear = inputdate[0]
    stepmonth = inputdate[1]
    stepday = inputdate[2]
    stephour = inputdate[3]
    
    #Validate filename
    source_validate_file = Vfile
    
    #define the output file for cdb_query_reduce
    #This is not the data file so the name is standard. Having the same name for different functions does not affect the result.
    temp_output_file='reduce_output.nc'
    
    #Execute the cdb_query_CMIP5_reduce functions here for monthly/daily/6hourly files
    call_cdb_query_download_6hour(source_validate_file, temp_output_file, stepyear, stepmonth, stepday, stephour)
    call_cdb_query_download_day(source_validate_file, temp_output_file, stepyear, stepmonth, stepday)
    call_cdb_query_download_month(source_validate_file, temp_output_file, stepyear, stepmonth)
    
    #Merge the files and cleanup temporary directory tree
    #filenames are built in and consistent with the input of unCMIP5.ncl
    #6hourly files
    merged_filename='merged_6hourly'
    temp_reduce_directory='{0:}_{1:}_{2:}_{3:}'.format(stepyear, stepmonth, stepday, stephour)
    merge_files_from_reduce(temp_reduce_directory,merged_filename)
    clean_reduce_directory(temp_reduce_directory)
    
    #Daily files
    merged_filename='merged_daily'
    temp_reduce_directory='{0:}_{1:}_{2:}'.format(stepyear, stepmonth, stepday)
    merge_files_from_reduce(temp_reduce_directory,merged_filename)
    clean_reduce_directory(temp_reduce_directory)
    
    #Monthly files
    merged_filename='merged_monthly'
    temp_reduce_directory='{0:}_{1:}'.format(stepyear, stepmonth)
    merge_files_from_reduce(temp_reduce_directory,merged_filename)
    clean_reduce_directory(temp_reduce_directory)
    
    print(inputdate, 'completed cdb_query operation')
    
name='__main__'
if name == '__main__':
  # Test the full function with date
  # Note that the test requires a single validate file and date that associates with the validate file!
  sampledate=('2085','01','01','00')
  print('date=',sampledate)
  sampleVfile = 'MIROC5_rcp85_2085_pointer_local_full.validate.nc'
  print('validate_file=',sampleVfile)
  apply_cdb_query_singleWPSstep(sampleVfile,sampledate)
  
