! ====================================================================================
! Name        : nc2im.f90
! Author      : original version by Jonathan Gula, adapted by Andre R. Erler
! Version     : 2.0
! Copyright   : GPL v3
! Description : Program to convert CCSM netcdf output into the WRF
!               intermediate file format
! ====================================================================================

program unccsm

  ! Import modules
  use netcdf
  implicit none

  ! Declarations: meta data for WRF intermediate file format
  integer, parameter :: IUNIT = 10
  character (len = *), parameter :: FILEOUT = "FILEOUT"
  integer :: IFV=5
  character(len=24) :: HDATE
  real :: XFCST
  character(len=8) :: STARTLOC
  character(len=9) :: FIELD
  character(len=9) :: fieldnetcdf(50)
  character(len=25) :: UNITS
  character(len=46) :: DESC
  character(len=32) :: MAP_SOURCE
  real :: XLVL
  integer :: NX
  integer :: NY
  integer :: IPROJ
  real :: STARTLAT
  real :: STARTLON
  real :: DELTALAT
  real :: DELTALON
  real :: DX
  real :: DY
  real :: XLONC
  real :: TRUELAT1
  real :: TRUELAT2
  real :: NLATSGAUSS
  real :: EARTH_RADIUS = 6367470. * .001
  logical :: IS_WIND_EARTH_REL = .FALSE.

  ! Declarations: meta data for NetCDF source files
  ! (GCM output interpolated to pressure levels and merged into one file)
  character (len = *), parameter :: FILE_NAME = "intermed.nc"
  integer :: ncid, ncerr
  logical :: lskip

!  integer, parameter :: NDIMS = 4, NRECS = 1
  !integer, parameter :: NLVLS = 26, NLATS = 128, NLONS = 256 ! T85 version of CCSM
!  integer, parameter :: NLVLS = 26, NLATS = 192, NLONS = 288 ! 0.9x1.25 version of CESM
  integer :: NLVLS, NLATS, NLONS
  character (len = *), parameter :: LVL_NAME = "lev_p"
  character (len = *), parameter :: LAT_NAME = "lat"
  character (len = *), parameter :: LON_NAME = "lon"
  character (len = *), parameter :: REC_NAME = "time"
  integer :: lvl_dimid, lon_dimid, lat_dimid, rec_dimid

  ! In addition to the latitude and longitude dimensions, we will also
  ! create latitude and longitude variables which will hold the actual
  ! latitudes and longitudes. Since they hold data about the
  ! coordinate system, the netCDF term for these is "coordinate
  ! variables".
  real, dimension(:), allocatable :: lats, lons, lvls
  integer :: lon_varid, lat_varid, lvl_varid

  ! We will read surface temperature and pressure fields. In netCDF
  ! terminology these are called "variables."
  integer :: psl_varid
!  integer :: dimids(NDIMS)
  integer, dimension(5) :: nbvar ! list of dimnsion IDs

  ! Arrays to hold the data we will read in. We will only
  ! need enough space to hold one timestep of data; one record.
  real, dimension(:,:), allocatable :: datafield2d
  real, dimension(:,:,:), allocatable :: datafield3d

  ! Loop indices
  integer :: lvl, lat, lon, rec, i, ilvl

  ! Namelist input control
  integer :: NLUNIT = 8
  character (len = *), parameter :: NAMLISTFILE = "meta/namelist.data"
  namelist /meta/ HDATE, MAP_SOURCE
  namelist /grid/ IPROJ, NLONS, NLATS, NLVLS

! ====================================================================================

! Read Namelist parameter
open(NLUNIT, FILE=NAMLISTFILE, action='read',status='old', delim='quote')
read(NLUNIT, NML=meta)
read(NLUNIT, NML=grid)
close(NLUNIT)

! Allocate memory
allocate( lats(NLATS), lons(NLONS), lvls(NLVLS) )
allocate( datafield2d(NLONS,NLATS), datafield3d(NLONS,NLATS,NLVLS) )

! ====================================================================================

! Open the NetCDF file.
ncerr = nf90_open(FILE_NAME, nf90_nowrite, ncid)
#ifdef DIAG
write(*,*)
write(*,*) 'Opening NetCDF file ', FILE_NAME, ' for reading.'
#endif

! Open a file to write the output (in WRF intermediate file format)
! Note: this file has to be in Big Endian format!
OPEN(IUNIT, CONVERT='BIG_ENDIAN', FILE=FILEOUT, form='unformatted',status='replace')
#ifdef DEBUG
write(*,*) 'Opening file ', FILEOUT, ' for writing.'
#endif

! Get the varids of the latitude and longitude coordinate variables.
ncerr = nf90_inq_varid(ncid, LAT_NAME, lat_varid)
ncerr = nf90_inq_varid(ncid, LON_NAME, lon_varid)
ncerr = nf90_inq_varid(ncid, LVL_NAME, lvl_varid)

! Read the latitude and longitude data.
ncerr = nf90_get_var(ncid, lat_varid, lats)
ncerr = nf90_get_var(ncid, lon_varid, lons)
ncerr = nf90_get_var(ncid, lvl_varid, lvls)

  ! Pressure levels Pa, not hPa
  lvls = 100*lvls

!  IPROJ=4 ! Gaussian projection (T85 version)
!  HDATE="1987:01:01_00:00:00"
  XFCST=0
!  MAP_SOURCE="CCSM3"
  NX=NLONS
  NY=NLATS
  NLATSGAUSS=NLATS/2 ! number of latitudes north of equator
  STARTLOC="SWCORNER"
  STARTLAT=lats(1)
  STARTLON=lons(1)
  DELTALAT=lats(2)-lats(1)
  DELTALON=lons(2)-lons(1)

#ifdef DEBUG
write(*,*)
write(*,*) 'Found coordinate variables and pressure levels:'
write(*,*) 'Latitude: ', lats(1), '/', lats(NY), '/', DELTALAT
write(*,*) 'Longitude: ', lons(1), '/', lons(NX), '/', DELTALON
write(*,*) 'Pressure levels (Pa): '
write(*,*) lvls
#endif

  fieldnetcdf(1)='PS'
  fieldnetcdf(2)='PSL'
  fieldnetcdf(3)='TS'
  fieldnetcdf(4)='RELHUMS'
  fieldnetcdf(5)='US'
  fieldnetcdf(6)='VS'
  fieldnetcdf(7)='SKT'

  fieldnetcdf(8)='ICEFRAC'
  fieldnetcdf(9)='landmask'

  fieldnetcdf(10)='ST000010'
  fieldnetcdf(11)='ST010040'
  fieldnetcdf(12)='ST040100'
  fieldnetcdf(13)='ST100200'
  fieldnetcdf(14)='SM000010'
  fieldnetcdf(15)='SM010040'
  fieldnetcdf(16)='SM040100'
  fieldnetcdf(17)='SM100200'

  fieldnetcdf(18)='SNOWHLND'
  fieldnetcdf(19)='SITHIK'
  fieldnetcdf(20)='SNOWSI'
  fieldnetcdf(21)='ALBSI'
  fieldnetcdf(22)='SST'

  fieldnetcdf(23)='TMN'

  fieldnetcdf(24)='T'
  fieldnetcdf(25)='U'
  fieldnetcdf(26)='V'
  fieldnetcdf(27)='Z3'
  fieldnetcdf(28)='RELHUM'

! ====================================================================================

#ifdef DIAG
write(*,*)
write(*,*) '     === === Beginning Conversion === === '
#endif

! Loop over variables
VARLIST : &
do i = 1,28
  lskip = .false.

  ! Retrieve meta data for variables
  ncerr = varmeta(fieldnetcdf(i), field, units, desc, XLVL)
  if ( ncerr .ne. 0) then
    lskip = .true.
    write(*,*)
    write(*,*) ' *** No meta data available for variable ', fieldnetcdf(i), ' *** '
  endif

  ! Get the varids and fields netCDF variables.
  ncerr = nf90_inq_varid(ncid, fieldnetcdf(i), psl_varid)
  if ( ncerr .ne. 0) then
    lskip = .true.
    write(*,*)
    write(*,*) ' *** Variable ', fieldnetcdf(i), ' (',field,')', ' not found in source file *** '
  endif
  
  ! if meta data and source data are present, continue
  Check: &
  if ( .not. lskip) then

#ifdef DIAG
    ! Feedback
    write(*,*)
    write(*,*) '  Processing variable ', fieldnetcdf(i), ' (',field,')'
#endif

    ! 2D or 3D field
    ncerr = nf90_inquire_variable(ncid, psl_varid, dimids = nbvar)
    ndim: &
    if (nbvar(3) .eq. 0) then
      lvl = 1
      ncerr = nf90_get_var(ncid, psl_varid, datafield2d)
    else
      ncerr = nf90_inquire_dimension(ncid, nbvar(3), len = lvl)
      ncerr = nf90_get_var(ncid, psl_varid, datafield3d)
#ifdef DEBUG
      write(*,*) lvl, ' levels'
#endif
    endif ndim

    ! *** Loop over levels ***
    LEVELS: &
    do ilvl = 1 , lvl

      ! Treat 3D fields level-wise as 2D fields
      if (nbvar(3) .ne. 0) then
      datafield2d=datafield3d(:,:,ilvl)
      endif

      ! Begin record in intermediate file (using Fortran WRITE statments)
      write (IUNIT) IFV

      ! WRITE the second record, common to all projections:
      write (IUNIT) HDATE, XFCST, MAP_SOURCE, FIELD, UNITS, DESC, XLVL, NX, NY, IPROJ
!      write(*,*) HDATE//"  ", XLVL, FIELD

      ! WRITE the third record, which depends on the projection:
      projection: &
      if (IPROJ == 0) then
        !  This is the Cylindrical Equidistant (lat/lon) projection:
        write (IUNIT) STARTLOC, STARTLAT, STARTLON, DELTALAT, DELTALON, EARTH_RADIUS
      elseif (IPROJ == 1) then
        ! This is the Mercator projection:
        write (IUNIT) STARTLOC, STARTLAT, STARTLON, DX, DY, TRUELAT1, EARTH_RADIUS
      elseif (IPROJ == 3) then
        ! This is the Lambert Conformal projection:
        write (IUNIT) STARTLOC, STARTLAT, STARTLON, DX, DY, XLONC, TRUELAT1, TRUELAT2, EARTH_RADIUS
      elseif (IPROJ == 4) then
        ! Gaussian projection
        write (IUNIT) STARTLOC, STARTLAT, STARTLON, NLATSGAUSS, DELTALON, EARTH_RADIUS
      elseif (IPROJ == 5) then
        ! This is the Polar Stereographic projection:
        write (IUNIT) STARTLOC, STARTLAT, STARTLON, DX, DY, XLONC, TRUELAT1, EARTH_RADIUS
      endif projection

      write (IUNIT) IS_WIND_EARTH_REL
      write (IUNIT) datafield2d

    enddo LEVELS

  endif Check

enddo VARLIST

! Close files
ncerr = nf90_close(ncid) ! NetCDF
CLOSE(IUNIT) ! WRF intermediate file

! Deallocate memory
deallocate( lats, lons, lvls )
deallocate( datafield2d, datafield3d )

#ifdef DIAG
write(*,*)
write(*,*) '     === === done === === '
write(*,*)
write(*,*) 'Closing NetCDF file ', FILE_NAME, ', wrote results to file ', FILEOUT, '.'
#endif

! ====================================================================================

contains

  function varmeta(fieldnetcdf, field, units, desc, XLVL) result(err)
    character(len=9), intent(in) :: fieldnetcdf
    character(len=9), intent(out) :: field
    character(len=25), intent(out) :: units
    character(len=46), intent(out) :: desc
    real, intent(out) :: XLVL
    integer :: err
    err = 0 ! error code if everything is OK

    ! List of variables and associated meta data
    META: &
    if (fieldnetcdf == 'PS') then
      field = 'PSFC'
      units = 'Pa'
      desc = 'Surface Pressure'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'PSL') then
      field = 'PMSL'
      units = 'Pa'
      desc = 'Sea-level Pressure'
                  XLVL = 201300.0
    elseif (fieldnetcdf == 'TS') then
      field = 'TT'
      units = 'K'
      desc = 'Temperature'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'RELHUMS') then
      field = 'RH'
      units = '%'
      desc = 'Relative Humidity'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'US') then
      field = 'UU'
      units = 'm s-1'
      desc = 'U'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'VS') then
      field = 'VV'
      units = 'm s-1'
      desc = 'V'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SKT') then
      field = 'SKINTEMP'
      units = 'K'
      desc = 'Skin Temperature'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SST') then
      field = 'SST'
      units = 'K'
      desc = 'Sea-Surface Temperature'
                  XLVL = 201300.0
    elseif (fieldnetcdf == 'TLAKE') then
      field = 'TLAKE'
      units = 'K'
      desc = 'Lake Temperature'
                  XLVL = 201300.0
    elseif (fieldnetcdf == 'T') then
      field = 'TT'
      units = 'K'
      desc = 'Temperature'
                  XLVL = lvls(ilvl)
    elseif (fieldnetcdf == 'U') then
      field = 'UU'
      units = 'm s-1'
      desc = 'U'
                  XLVL = lvls(ilvl)
    elseif (fieldnetcdf == 'V') then
      field = 'VV'
      units = 'm s-1'
      desc = 'V'
                  XLVL = lvls(ilvl)
    elseif (fieldnetcdf == 'Z3') then
      field = 'GHT'
      units = 'm'
      desc = 'Height'
                  XLVL = lvls(ilvl)
    elseif (fieldnetcdf == 'RELHUM') then
      field = 'RH'
      units = '%'
      desc = 'Relative Humidity'
                  XLVL = lvls(ilvl)
    elseif (fieldnetcdf == 'ST000010') then
      field = 'ST000010'
      units = 'K'
      desc = 'T 0-10 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'ST010040') then
      field = 'ST010040'
      units = 'K'
      desc = 'T 10-40 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'ST040100') then
      field = 'ST040100'
      units = 'K'
      desc = 'T 40-100 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'ST100200') then
      field = 'ST100200'
      units = 'K'
      desc = 'T 100-200 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'TMN') then
      field = 'TMN'
      units = 'K'
      desc = 'T 300 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SM000010') then
      field = 'SM000010'
      units = 'kg m-3'
      desc = 'Soil Moist 0-10 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SM010040') then
      field = 'SM010040'
      units = 'kg m-3'
      desc = 'Soil Moist 10-40 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SM040100') then
      field = 'SM040100'
      units = 'kg m-3'
      desc = 'Soil Moist 40-100 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SM100200') then
      field = 'SM100200'
      units = 'kg m-3'
      desc = 'Soil Moist 100-200 cm below ground layer'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'landmask') then
      field = 'LANDSEA'
      units = 'proprtn'
      desc = 'Land/Sea flag (1=land, 0 or 2=sea)'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'ICEFRAC') then
      field = 'XICE'
  !   field = 'SEAICE'
      units = 'proprtn'
      desc = 'Ice flag'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SITHIK') then
      field = 'SITHIK'
  !   field = 'SEAICE'
      units = 'm'
      desc = 'sea ice thickness'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SNOWSI') then
      field = 'SNOWSI'
  !   field = 'SEAICE'
      units = 'm'
      desc = 'snow depth on sea ice'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'ALBSI') then
      field = 'ALBSI'
  !   field = 'SEAICE'
      units = ''
      desc = 'snow/ice albedo'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SNOWHLND') then
      field = 'SNOW'
      units = 'kg m-2'
      desc = 'Water equivalent snow depth'
                  XLVL = 200100.0
    elseif (fieldnetcdf == 'SOILHGT') then
      field = 'SOILHGT'
      units = 'm'
      desc = 'Terrain field of source analysis'
                  XLVL = 200100.0
    else
      err = 1 ! error code if variable not in list
    endif META

  end function varmeta

! ====================================================================================

end program unccsm
