!  Special program to only read netCDF files, and write some 
!  file information on the screen
!  Can read input/output and static files
!  Can read double precision file (like WRF-Var)
!  Can read both WRF ARW and NMM data
!
!=================================Make Executable============================
!  Make executable:
!    DEC Alpha
!      f90 read_wrf_nc.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o read_wrf_nc
!
!   linux flags - for PGI compiler
!      pgf90 read_wrf_nc.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -Mfree  -o read_wrf_nc
!
!   linux flags - for INTEL compiler
!      ifort read_wrf_nc.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -Mfree  -o read_wrf_nc
!
!   Sun flags
!      f90 read_wrf_nc.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -free  -o read_wrf_nc
!
!   SGI flags
!      f90 read_wrf_nc.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -freeform  -o read_wrf_nc
!
!   IBM flags
!      xlf read_wrf_nc.f -L/usr/local/lib32/r4i4 -lnetcdf -lm  \
!      -I/usr/local/netcdf/include  -qfree=f90  -o read_wrf_nc
!
!   Mac flags (with xlf compiler)
!      xlf read_wrf_nc.f -L/usr/local/netcdf-xlf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf-xlf/include  -qfree=f90  -o read_wrf_nc
!
!   Mac flags (with g95 compiler)
!      g95 read_wrf_nc.f -L/usr/local/netcdf/lib -lnetcdf -lm  \
!      -I/usr/local/netcdf/include -ffree-form -o read_wrf_nc
!
!   If you extra compile flags for other computers - please send along
!
!=================================Run Program================================
!  Run program:
!      read_wrf_nc   wrf_data_file_name  [-options] 
!      options : [-h / help] [-att] [-m] [-M z] [-s] [-S x y z] 
!                            [-v VAR] [-V VAR] [-w VAR]
!                            [-t t1 [t2]] [-times]
!                            [-ts xy X   Y   VAR VAR .....]
!                            [-ts ll lat lon VAR VAR .....]
!                            [-EditData VAR]
!  Options [-att] and [-t t1 [t2]] can be used together with other options
!     Options [-att] and [-times] cannot be used together
!
!=================================Options====================================
!
! -help     : Print help information                           
! -h        : Print help information                           
! -att      : Print global attributes
!             Work with other options.
! -m        : Print list of fields available for each time, 
!             plus the min and max values for each field
! -M  z     : Print list of fields available for each time, 
!             plus the min and max values for each field
!             The min max values for 3d fields will be for
!             the z level of the field
! -s        : Print list of fields available for each time, 
!             plus a sample value for each field
!             Sample value is in middle of domain
! -S  x y z : Print list of fields available for each time, 
!             plus a sample value for each field
!             Sample value is at point x y z in domain
!             Also print the header information
! -t t1 [t2]: Print information only from time t1 to t2         
!             t2 is optional
!             Work with other options.
! -times    : Print only the times in the file                  
! -ts       : Generate time series output 
!             Output for full vertical column is default, if
!             only one level is required, use -lev
!             xy X Y VAR VAR ...
!                will create time series output at X Y
!             ll lat lon VAR VAR ...
!                will create time series output at 
!                a point closest to lat/lon
!                No interpolation takes place
! -lev z    : Works only with -ts
!             Specify which level you want time series output for
! -rot      : Rotate winds to earth coordinates - only works with -ts
! -v VAR    : Print basic information about field VAR           
! -V VAR    : Print basic information about field VAR     
!             And dump the full field out to the screen
! -w VAR    : Write the full field out to a file VAR.out         
! -diag     : Add to command line if you would like to see information about
!             the diagnostic variables pressure/height/tk
! 
! Default Options are [-att -s]
!
!=================================Special Option=============================
!  -EditData VAR
!
!  This options will allow a user to READ a WRF netDFC file, CHANGE a 
!  specific field and RE-WRITE it BACK into the WRF netCDF file
!
!  This options will CHANGE your CURRENT WRF netCDF file so PLEASE 
!  TAKE CARE when using this option
!
!  ONLY one field at a time can be changed. So if you need 3 fields changed,
!  you will need to run this program 3 times, each with a different "VAR"
!
!  IF you have multiple times in your WRF netCDF file, but you only want
!  to change teh valued for ONE time, use the [-t t1 [t2]] option, ELSE 
!  ALL times will be changed
!
!  HOW TO USE THIS OPTION:
!
!  1. Make a COPY of your WRF netCDF file BEFORE using this option
!
!  2. EDIT the SUBROUTINE USER_CODE
!     - ADD an IF-statement block for the variable you want to change
!            For REAL data work with array "data_real" and 
!            for INTEGER data work with the array "data_int"
!       This is to prevent a variable getting overwritten by mistake
!     - Example 1: If you want to change all (all time periods too) 
!                  values of U to a constant 10.0 m/s, you would add
!                  the following IF_statement
!       elseif ( var == 'U') then   
!           data_real = 10.0
!       Example 2: If you want to change some of the LANDMASK data
!       elseif ( var == 'LANDMASK') then 
!           data_real(10:15,20:25,1) = 0   ! will change all land points
                                           ! in the box i=10 to 15 and
                                           ! i=20 to 25 to SEA point
!       Example 3: Change ALL ISLTYP category 3 into category 7
!                  NOTE this is an INTEGER field
!       elseif ( var == 'ISLTYP') then 
!           where (data_int == 3 )
!             data_int = 7
!           endwhere
!
!  3. Compile and run program
!     You will be prompted if this is really waht you want to do.
!     ONLY the answer "yes" will allow the change to take effect
!
!============================================================================
! Updates Feb 2009
! Fix to -rot + -ts for U10 and V10 
! Add unstaggering for all variables when -ts is used
!
! Updates Feb 2008
! Improved calculations for ll to xy in -ts option
!
! Updated Jul 2007
!   Fix bug in TK and wind rotation calculations
!   Thanks to Zhong-Xiang Wu
!
! Updated Dec 2006
! -ts will now plot full vertical profile
!   To only plot a single level, option -lev needs to be added
!   For PS and Lambert projects an option -rot is added to rotate
!   winds to earth coordiantes. This only works for -ts option
! Add 3 diagnostic variables - pressure, height and tk
!   Adding the option -diag to the command line will produce the 
!   values for these 3 variables, e.g.,
!   -s -diag
!   -v pressure -diag
!   -ts xy 50 50 U V pressure -diag
!
! Updated Sep 2005
! Can now read all NMM data
! Clean up code to simplify add extra options
! Option -head is replaced by -att
! Add an option to only look at specific times
! Some options [-att] and [-t] now work with other options
! Add Time Series Options
!
! Updated Dec 2005
! Fix problem with -w and -v options 
!
!  Initial version May 2004
!  Cindy Bruyere
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


MODULE map_utils

  TYPE proj_info

      INTEGER   :: code     ! Integer code for projection TYPE
      REAL      :: lat1     ! SW latitude (1,1) in degrees (-90->90N)
      REAL      :: lon1     ! SW longitude (1,1) in degrees (-180->180E)
      REAL      :: dx       ! Grid spacing in meters at truelats, used
                                      !  only for ps, lc, and merc projections
      REAL      :: dy       ! Grid spacing in meters at truelats, used
                                      !  only for ps, lc, and merc projections
      REAL      :: latinc   ! Latitude increment for cylindrical lat/lon
      REAL      :: loninc   ! Longitude increment for cylindrical lat/lon
                                      !  also the lon increment for Gaussian grid
      REAL      :: dlat     ! Lat increment for lat/lon grids
      REAL      :: dlon     ! Lon increment for lat/lon grids
      REAL      :: stdlon   ! Longitude parallel to y-axis (-180->180E)
      REAL      :: truelat1 ! First true latitude (all projections)
      REAL      :: truelat2 ! Second true lat (LC only)
      REAL      :: hemi     ! 1 for NH, -1 for SH
      REAL      :: cone     ! Cone factor for LC projections
      REAL      :: polei    ! Computed i-location of pole point
      REAL      :: polej    ! Computed j-location of pole point
      REAL      :: rsw      ! Computed radius to SW corner
      REAL      :: rebydx   ! Earth radius divided by dx
      REAL      :: knowni   ! X-location of known lat/lon
      REAL      :: knownj   ! Y-location of known lat/lon
      REAL      :: re_m     ! Radius of spherical earth, meters

  END TYPE proj_info

 CONTAINS


   SUBROUTINE latlon_to_ij(cdfid, proj, ts_ll, ts_xy )

      ! Converts input lat/lon values to the cartesian (i,j) value
      ! for the given projection. 

      IMPLICIT NONE
      include 'netcdf.inc' 
      INTEGER                              :: cdfid, rcode, id_var, nDims, ivtype, nAtts
      REAL                                 :: ts_ll(3)
      INTEGER                              :: ts_xy(3)
      TYPE(proj_info)                      :: proj
      REAL                                 :: lat
      REAL                                 :: lon
      REAL                                 :: i
      REAL                                 :: j

      lat = ts_ll(1)
      lon = ts_ll(2)

      SELECT CASE(proj%code)

         !CASE(PROJ_LATLON)
         !   CALL llij_latlon(lat,lon,proj,i,j)

         CASE(3)
            CALL llij_merc(lat,lon,proj,i,j)

         CASE(2)
            CALL llij_ps(lat,lon,proj,i,j)

         CASE(1)
            IF (ABS(proj%truelat2) .GT. 90.) THEN
               proj%truelat2=proj%truelat1
            ENDIF
            CALL llij_lc(lat,lon,proj,i,j)

         CASE DEFAULT
            PRINT '(A,I2)', 'Unrecognized map projection code: ', proj%code
            STOP 'LATLON_TO_IJ'

      END SELECT

      ts_xy(1) = nint(i)
      ts_xy(2) = nint(j)

      RETURN

   END SUBROUTINE latlon_to_ij


   SUBROUTINE llij_ps(lat,lon,proj,i,j)
      ! Given latitude (-90 to 90), longitude (-180 to 180), and the
      ! standard polar-stereographic projection information via the 
      ! public proj structure, this routine returns the i/j indices which
      ! if within the domain range from 1->nx and 1->ny, respectively.

      IMPLICIT NONE

      ! Delcare input arguments
      REAL, INTENT(IN)               :: lat
      REAL, INTENT(IN)               :: lon
      TYPE(proj_info)                :: proj

      ! Declare output arguments     
      REAL, INTENT(OUT)              :: i !(x-index)
      REAL, INTENT(OUT)              :: j !(y-index)

      ! Declare local variables

      REAL                           :: ala1
      REAL                           :: alo1
      REAL                           :: reflon
      REAL                           :: scale_top
      REAL                           :: ala
      REAL                           :: alo
      REAL                           :: rm
      REAL, PARAMETER                :: PI = 3.141592653589793
      REAL, PARAMETER                :: RAD_PER_DEG = PI/180.
      REAL, PARAMETER                :: DEG_PER_RAD = 180./PI

      ! BEGIN CODE

      reflon = proj%stdlon + 90.

      ! Compute numerator term of map scale factor
      scale_top = 1. + proj%hemi * SIN(proj%truelat1 * rad_per_deg)

      ! Compute radius to lower-left (SW) corner
      ala1 = proj%lat1 * rad_per_deg
      proj%rsw = proj%rebydx*COS(ala1)*scale_top/(1.+proj%hemi*SIN(ala1))

      ! Find the pole point
      alo1 = (proj%lon1 - reflon) * rad_per_deg
      proj%polei = proj%knowni - proj%rsw * COS(alo1)
      proj%polej = proj%knownj - proj%hemi * proj%rsw * SIN(alo1)

      ! Find radius to desired point
      ala = lat * rad_per_deg
      rm = proj%rebydx * COS(ala) * scale_top/(1. + proj%hemi *SIN(ala))
      alo = (lon - reflon) * rad_per_deg
      i = proj%polei + rm * COS(alo)
      j = proj%polej + proj%hemi * rm * SIN(alo)

      RETURN

   END SUBROUTINE llij_ps


   SUBROUTINE llij_lc( lat, lon, proj, i, j)

   ! Subroutine to compute the geographical latitude and longitude values
   ! to the cartesian x/y on a Lambert Conformal projection.

      IMPLICIT NONE

      ! Input Args
      REAL, INTENT(IN)              :: lat      ! Latitude (-90->90 deg N)
      REAL, INTENT(IN)              :: lon      ! Longitude (-180->180 E)
      TYPE(proj_info)               :: proj     ! Projection info structure

      ! Output Args                 
      REAL, INTENT(OUT)             :: i        ! Cartesian X coordinate
      REAL, INTENT(OUT)             :: j        ! Cartesian Y coordinate

      ! Locals 
      REAL                          :: deltalon1
      REAL                          :: arg
      REAL                          :: deltalon
      REAL                          :: tl1r
      REAL                          :: rm
      REAL                          :: ctl1r
      REAL, PARAMETER               :: PI = 3.141592653589793
      REAL, PARAMETER               :: RAD_PER_DEG = PI/180.
      REAL, PARAMETER               :: DEG_PER_RAD = 180./PI

      ! BEGIN CODE

      ! Compute longitude differences and ensure we stay out of the
      ! forbidden "cut zone"
      deltalon1 = proj%lon1 - proj%stdlon
      IF (deltalon1 .GT. +180.) deltalon1 = deltalon1 - 360.
      IF (deltalon1 .LT. -180.) deltalon1 = deltalon1 + 360.

      ! Convert truelat1 to radian and compute COS for later use
      tl1r = proj%truelat1 * rad_per_deg
      ctl1r = COS(tl1r)

      ! Compute the radius to our known lower-left (SW) corner
      proj%rsw = proj%rebydx * ctl1r/proj%cone * & 
             (TAN((90.*proj%hemi-proj%lat1)*rad_per_deg/2.) / &
              TAN((90.*proj%hemi-proj%truelat1)*rad_per_deg/2.))**proj%cone

      ! Find pole point
      arg = proj%cone*(deltalon1*rad_per_deg)
      proj%polei = proj%hemi*proj%knowni - proj%hemi * proj%rsw * SIN(arg)
      proj%polej = proj%hemi*proj%knownj + proj%rsw * COS(arg)

      ! Compute deltalon between known longitude and standard lon and ensure
      ! it is not in the cut zone
      deltalon = lon - proj%stdlon
      IF (deltalon .GT. +180.) deltalon = deltalon - 360.
      IF (deltalon .LT. -180.) deltalon = deltalon + 360.

      ! Radius to desired point
      rm = proj%rebydx * ctl1r/proj%cone * &
           (TAN((90.*proj%hemi-lat)*rad_per_deg/2.) / &
            TAN((90.*proj%hemi-proj%truelat1)*rad_per_deg/2.))**proj%cone

      arg = proj%cone*(deltalon*rad_per_deg)
      i = proj%polei + proj%hemi * rm * SIN(arg)
      j = proj%polej - rm * COS(arg)

      ! Finally, if we are in the southern hemisphere, flip the i/j
      ! values to a coordinate system where (1,1) is the SW corner
      ! (what we assume) which is different than the original NCEP
      ! algorithms which used the NE corner as the origin in the 
      ! southern hemisphere (left-hand vs. right-hand coordinate?)
      i = proj%hemi * i
      j = proj%hemi * j

      RETURN
   END SUBROUTINE llij_lc


   SUBROUTINE llij_merc(lat, lon, proj, i, j)

      ! Compute i/j coordinate from lat lon for mercator projection

      IMPLICIT NONE
      REAL, INTENT(IN)              :: lat
      REAL, INTENT(IN)              :: lon
      TYPE(proj_info)               :: proj
      REAL,INTENT(OUT)              :: i
      REAL,INTENT(OUT)              :: j
      REAL                          :: clain
      REAL                          :: deltalon
      REAL, PARAMETER               :: PI = 3.141592653589793
      REAL, PARAMETER               :: RAD_PER_DEG = PI/180.
      REAL, PARAMETER               :: DEG_PER_RAD = 180./PI

      !  Preliminary variables
      clain = COS(rad_per_deg*proj%truelat1)
      proj%dlon = proj%dx / (proj%re_m * clain)

      ! Compute distance from equator to origin, and store in the 
      ! proj%rsw tag.

      proj%rsw = 0.
      IF (proj%lat1 .NE. 0.) THEN
         proj%rsw = (ALOG(TAN(0.5*((proj%lat1+90.)*rad_per_deg))))/proj%dlon
      ENDIF

      deltalon = lon - proj%lon1
      IF (deltalon .LT. -180.) deltalon = deltalon + 360.
      IF (deltalon .GT. 180.) deltalon = deltalon - 360.
      i = proj%knowni + (deltalon/(proj%dlon*deg_per_rad))
      j = proj%knownj + (ALOG(TAN(0.5*((lat + 90.) * rad_per_deg)))) / &
             proj%dlon - proj%rsw

      RETURN

   END SUBROUTINE llij_merc

END MODULE map_utils
!------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------


  program read_wrf_nc

  implicit none
  character (len=80)    :: input_file                        
  character (len=10)    :: option                        
  character (len=10)    :: plot_var
  integer               :: length_input, length_option, time1, time2
  integer               :: plot_dim(3)
  logical               :: op_att, op_diag, op_rot
  
  integer               :: ts_xy(3)
  real                  :: ts_ll(3)
  character (len=10)    :: ts_var(100)
  integer               :: ts_i
  character (len=2)     :: ts_type


! Find out what we need to do first
  call read_args(input_file,length_input,op_att,op_diag,op_rot,option,plot_var,plot_dim, &
                 time1,time2,ts_type,ts_xy,ts_ll,ts_i,ts_var)
  print*,"INPUT FILE IS: ",trim(input_file)
  print*," "


! Now read the file
  call get_info_from_cdf (input_file,length_input,op_att,op_diag,op_rot,option,   &
                          plot_var,plot_dim,time1,time2,           &
                          ts_type,ts_xy,ts_ll,ts_i,ts_var) 


  end program read_wrf_nc

!------------------------------------------------------------------------------

  subroutine help_info

  print*," "
  print*," read_wrf_nc   wrf_data_file_name  [-options] "
  print*," "
  print*," Current options available are:"
  print*," -help     : Print this information"                           
  print*," -h        : Print this information"                           
  print*," -att      : Print global attributes"
  print*,"             Work with other options."
  print*," -m        : Print list of fields available for each time, "
  print*,"             plus the min and max values for each field"
  print*," -M  z     : Print list of fields available for each time, "
  print*,"             plus the min and max values for each field"
  print*,"             The min max values for 3d fields will be for"
  print*,"             the z level of the field"
  print*," -s        : Print list of fields available for each time, "
  print*,"             plus a sample value for each field"
  print*,"             Sample value is in middle of domain"
  print*," -S  x y z : Print list of fields available for each time, "
  print*,"             plus a sample value for each field"
  print*,"             Sample value is at point x y z in domain"
  print*," -t t1 [t2]: Print information only from time t1 to t2"         
  print*,"             t2 is optional"
  print*,"             Work with other options."
  print*," -times    : Print only the times in the file"                  
  print*," -ts       : Generate time series output "
  print*,"             Output for full vertical column is default, if"
  print*,"             only one level is required, use -lev"
  print*,"             xy X Y VAR VAR ..."
  print*,"                will create time series output at X Y"
  print*,"             ll lat lon VAR VAR ..."
  print*,"                will create time series output at "
  print*,"                a point closest to lat/lon"
  print*,"                No interpolation takes place"
  print*," -lev z    : Works only with -ts"
  print*,"             Specify which level you want time series output for"
  print*," -rot      : Rotate winds to earth coordinates - only works with -ts"
  print*," -v VAR    : Print basic information about field VAR"           
  print*," -V VAR    : Print basic information about field VAR"     
  print*,"             And dump the full field out to the screen"
  print*," -w VAR    : Write the full field out to a file VAR.out"         
  print*," -diag     : Add to command line if you would like to see information about"
  print*,"             the diagnostic variables pressure/height/tk"
  print*," "
  print*," Default Options are [-att -s]"
  print*," "

  STOP

  end subroutine help_info

!------------------------------------------------------------------------------

  subroutine read_args(input_file,length_input,op_att,op_diag,op_rot,option,plot_var,plot_dim, &
                       time1,time2,ts_type,ts_xy,ts_ll,ts_i,ts_var)

  implicit none
  character (len=80)    :: input_file                        
  character (len=10)    :: option                        
  character (len=10)    :: plot_var
  integer               :: length_input, plot_dim(3), time1, time2
  logical               :: op_att, op_diag, op_rot

  integer               :: numarg, i, idummy
  real                  :: rdummy
  integer, external     :: iargc
  character (len=80)    :: dummy

  integer               :: ts_xy(3)
  real                  :: ts_ll(3)
  character (len=10)    :: ts_var(100)
  integer               :: ts_i
  character (len=2)     :: ts_type

! set up some defaults first
  input_file = " "
  op_att  = .FALSE.
  op_diag = .FALSE.
  op_rot  = .FALSE.

  option = "-s"
  plot_dim = 0
  plot_var = " "
  time1 = 0
  time2 = 0
  numarg = iargc()
  i = 1

  ts_xy   = 0
  ts_ll   = 0.0
  ts_i    = 0
  ts_var  = " "
  ts_type = " "


  if (numarg == 0) call help_info

  if ( numarg == 1 ) then
    op_att = .TRUE.
  endif

  do while (i <= numarg)
    call getarg(i,dummy)

    if (dummy(1:1) == "-") then    ! We have an option, else it is the filename

      SELECTCASE (trim(dummy))
          CASE ("-help")
               call help_info
          CASE ("-h")
               call help_info
          CASE ("-att")
               op_att = .TRUE.
          CASE ("-times")
               option = dummy
          CASE ("-t")
               if ( option == " " ) option = "-s"
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               time1 = idummy
               i = i+1
               call getarg(i,dummy)
               if ( dummy(1:1)=="-" .or. dummy(1:3)=="geo" .or. &
                    dummy(1:3)=="met" .or. dummy(1:3)=="wrf") then ! only one time requested
                 i = i-1   
               else                          ! we have a start and end time
                 read(dummy,'(i3)')idummy
                 time2 = idummy
               endif
               if ( time2 == 0 ) time2 = time1
          CASE ("-s")
               option = dummy
          CASE ("-S")
               option = dummy
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               plot_dim(1) = idummy
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               plot_dim(2) = idummy
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               plot_dim(3) = idummy
          CASE ("-m")
               option = dummy
          CASE ("-M")
               option = dummy
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               plot_dim(3) = idummy
          CASE ("-v")
               option = dummy
               i = i+1
               call getarg(i,plot_var)
          CASE ("-V")
               option = dummy
               i = i+1
               call getarg(i,plot_var)
          CASE ("-w")
               option = dummy
               i = i+1
               call getarg(i,plot_var)
          CASE ("-ts")
               option = dummy
               i = i+1
               call getarg(i,dummy)
               ts_type = dummy
               if ( ts_type == 'xy' ) then
                 i = i+1
                 call getarg(i,dummy)
                 read(dummy,'(i3)')idummy
                 ts_xy(1) = idummy
                 i = i+1
                 call getarg(i,dummy)
                 read(dummy,'(i3)')idummy
                 ts_xy(2) = idummy
               elseif ( ts_type == 'll' ) then
                 i = i+1
                 call getarg(i,dummy)
                 read(dummy,'(f7.2)')rdummy
                 ts_ll(1) = rdummy
                 i = i+1
                 call getarg(i,dummy)
                 read(dummy,'(f7.2)')rdummy
                 ts_ll(2) = rdummy
               endif
               do
                 i = i+1
                 call getarg(i,dummy)
                 if ( dummy(1:1) == " " ) exit
                 if ( dummy(1:1)=="-" .or. dummy(1:3)=="geo" .or. &
                      dummy(1:3)=="met" .or. dummy(1:3)=="wrf") then ! found another option
                   i = i-1   
                   exit
                 else                          ! read variables               
                   ts_i = ts_i + 1
                   ts_var(ts_i) = dummy
                 endif
               enddo
          CASE ("-lev")
               i = i+1
               call getarg(i,dummy)
               read(dummy,'(i3)')idummy
               ts_xy(3) = idummy
          CASE ("-rot")
               op_rot = .TRUE.
          CASE ("-diag")
               op_diag = .TRUE.
          CASE ("-EditData")
               option = dummy
               i = i+1
               call getarg(i,plot_var)
          CASE DEFAULT
               call help_info
      END SELECT
    else
      input_file = dummy
      length_input = len_trim(input_file)
    endif

      i = i+1

  enddo

  if (input_file == " ") call help_info

  if (op_rot .and. option /= "-ts") then
     print*,"WARNING: -rot only has an effect for TIME SERIES option"
     op_rot = .FALSE.
  endif


  end subroutine read_args
!------------------------------------------------------------------------------
  subroutine get_info_from_cdf( file,length_input,op_att,op_diag,op_rot,option,   &
                                plot_var,plot_dim,time1,time2,     &
                                ts_type,ts_xy,ts_ll,ts_i,ts_var) 
        
  use map_utils

  implicit none

  include 'netcdf.inc'

  character (len=80), intent(in)                   :: file
  character (len=80)                               :: file_out
  character (len=10)                               :: option
  character (len=3)                                :: go_change
  character (len=10), intent(in)                   :: plot_var
  integer                                          :: i,j,k, ivtype, length, length_input
  integer                                          :: time1, time2
  integer                                          :: plot_dim(3), get_x, get_y, get_z
  logical                                          :: op_att, op_diag, op_rot
  logical                                          :: FirstTime = .TRUE.
  logical                                          :: static = .FALSE.
  
  character (len=80)                               :: varnam, att_name, value_chr, print_time
  character (len=80)                               :: att_sav(10)
  integer                                          :: dimids(10), FieldType
  character (len=80)                               ::  units, MemoryOrder, description, stagger

  integer                                          :: cdfid, rcode, id_var, idvar
  integer                                          :: id_att, attlen, ios
  integer                                          :: nDims, nVars, nAtts, unlimDimID, dims(4)
  integer                                          :: unit_place, order_place, nVars_sav
  integer                                          :: type_to_get, dims3, iatt
  integer                                          :: id_time, n_times, itimes

  double precision,  allocatable, dimension(:,:,:) :: data_dp_r
  real,    allocatable, dimension(:,:,:)           :: data_r
  integer, allocatable, dimension(:,:,:)           :: data_i
  real,    allocatable, dimension(:,:)             :: data_ts
  real,    allocatable, dimension(:)               :: value_real
  real,    allocatable, dimension(:,:)             :: xlat, xlong, diff, alpha
  real,    allocatable, dimension(:,:,:)           :: u10, v10
  real,    allocatable, dimension(:,:,:)           :: uuu, vvv, pressure, height, tk, tmp

  character (len=80)                               :: times(999), dname
  integer                                          :: istart(4), iend(4), isample(4)
  integer                                          :: istart_t(2), iend_t(2)
  real                                             :: sample_value_r, minvalue_r, maxvalue_r
  integer                                          :: sample_value_i, minvalue_i, maxvalue_i
  integer                                          :: value_int
  integer                                          :: wedim, sndim, btdim, kk, ii, dval

  integer                                          :: map_proj
  real                                             :: truelat1, truelat2, stand_lon, cone
  real                                             :: dx, dy, dummy_stdlon, dummy_lon1
  real, parameter                                  :: PI = 3.141592653589793
  real, parameter                                  :: RAD_PER_DEG = PI/180.

  integer                                          :: ts_xy(3)
  real                                             :: ts_ll(3)
  character (len=10)                               :: ts_var(100)
  integer                                          :: ts_i
  character (len=2)                                :: ts_type

  TYPE(proj_info)                                  :: proj


! Open netCDF file 
  if ( option == "-EditData") then
    rcode = nf_open(file(1:length_input), NF_WRITE, cdfid )
    print*,"Attempting to open netCDF file with write access"
  else
    rcode = nf_open(file(1:length_input), NF_NOWRITE, cdfid )
  endif
  length = max(1,index(file,' ')-1)
  if( rcode == 0) then
    write(6,*) ' '
  else
    write(6,*) ' error opening netcdf file ',file(1:length)
    stop
  end if

! Get the times first:
  rcode = nf_inq_varid ( cdfid, 'Times', id_var )
    if (rcode .ne. 0) then
      ! This is probably a static file - no times available
      n_times = 1
      static = .True.
      go to 10
    else
      id_time = ncvid( cdfid, 'Times', rcode )
    endif

  rcode = nf_inq_var( cdfid, id_time, varnam, ivtype, ndims, dimids, natts )
  do i=1,ndims
    rcode = nf_inq_dimlen( cdfid, dimids(i), dims(i) )
  enddo

  n_times = dims(2)
  do i=1,dims(2)
    istart_t(1) = 1
    iend_t(1) = dims(1)
    istart_t(2) = i
    iend_t(2) = 1
    rcode = NF_GET_VARA_TEXT  ( cdfid, id_time,      &
                     istart_t, iend_t, times(i))
  enddo

! If we only want information about time
  if ( option == "-times" ) then
    print*,"TIMES in file"
    do itimes = 1,n_times
      print_time = times(itimes)
      print*,trim(print_time)
    enddo
    STOP
  endif

 10 continue          ! come here direct for some static files        

  rcode = nf_inq(cdfid, nDims, nVars, nAtts, unlimDimID)
  nVars_sav = nVars

! Get some header information
  btdim = 24   ! max for geo_grid static data - not that we will need this
  do ii = 1, nDims
    rcode = nf_inq_dim(cdfid, ii, dname, dval)
    if     (dname .eq. 'west_east') then
      wedim = dval
    elseif (dname .eq. 'south_north') then
      sndim = dval
    elseif (dname .eq. 'bottom_top') then
      btdim = dval
    elseif (dname .eq. 'num_metgrid_levels') then
      btdim = dval
    endif
  enddo

  if ( op_att ) then 
    print*,"GLOBAL ATTRIBUTES:"
    print*," "
    do iatt = 1,nAtts
      rcode = nf_inq_attname(cdfid,nf_global,iatt,att_name)
      rcode = nf_inq_att( cdfid,nf_global,att_name,ivtype,attlen )
      if (ivtype == 2) then
        rcode = NF_GET_ATT_TEXT(cdfid, nf_global, att_name, value_chr )
        write(6,'(A," : ",A)') att_name(1:40),value_chr(1:attlen)
      elseif (ivtype == 4) then
        rcode = NF_GET_ATT_INT(cdfid, nf_global, att_name, value_int )
        write(6,'(A," : ",i5)') att_name(1:40),value_int
      elseif (ivtype == 5) then
        allocate (value_real(attlen))
        rcode = NF_GET_ATT_REAL(cdfid, nf_global, att_name, value_real )
        if (attlen .gt. 1) then
          print*,att_name(1:40),": ",value_real
        else
          write(6,'(A," : ",f12.4)') att_name(1:40),value_real(1)
        endif
        deallocate (value_real)
      endif
    enddo
    if ( option == " ") STOP
    print*," "
    print*,"--------------------------------------------------------------------- "
    print*," "
  endif

  if ( op_diag ) then
      rcode = NF_GET_ATT_TEXT(cdfid, nf_global, "TITLE", value_chr )
      if ( INDEX(value_chr,'OUTPUT FROM WRF ') == 0 ) then
         !! diagnostics only available for wrfout data
         print*,"This is not a wrfout file - no diagnostics will be done"
         op_diag = .FALSE.
      endif
  endif

  rcode = NF_GET_ATT_INT(cdfid, nf_global, "MAP_PROJ", map_proj )
  proj%code = map_proj
  if ( map_proj .ge. 3 ) op_rot = .FALSE.  ! mercator, no need to rotate
  if ( op_rot .OR. ts_type == "ll" ) then 
      proj%latinc   = -999.9  
      proj%loninc   = -999.9 
      proj%dlat     = -999.9  
      proj%dlon     = -999.9 
      proj%hemi     =    1.0  
      proj%polei    = -999.9 
      proj%polej    = -999.9  
      proj%rsw      = -999.9 
      proj%knowni   =    1.0 
      proj%knownj   =    1.0  
      proj%re_m     = 6370000.

      rcode = NF_GET_ATT_REAL(cdfid, nf_global, "TRUELAT1", truelat1 )
      rcode = NF_GET_ATT_REAL(cdfid, nf_global, "TRUELAT2", truelat2 )
      rcode = NF_GET_ATT_REAL(cdfid, nf_global, "STAND_LON", stand_lon )
      rcode = NF_GET_ATT_REAL(cdfid, nf_global, "DX", dx )
      rcode = NF_GET_ATT_REAL(cdfid, nf_global, "DY", dy )
      IF ( truelat1 < 0.0 ) proj%hemi = -1.0
      proj%truelat1 = truelat1
      proj%truelat2 = truelat2
      proj%dx = dx
      proj%dy = dy
      proj%rebydx = proj%re_m / dx
      dummy_stdlon = stand_lon
      IF (dummy_stdlon < -180.) dummy_stdlon = dummy_stdlon + 360.
      IF (dummy_stdlon > 180.) dummy_stdlon = dummy_stdlon - 360.
      proj%stdlon = dummy_stdlon

      if ( map_proj .eq. 2 ) cone = 1.
      if ( map_proj .eq. 1 ) then
        IF (ABS(truelat1-truelat2) .GT. 0.1) THEN
           cone=(ALOG(COS(truelat1*RAD_PER_DEG))-            &
                 ALOG(COS(truelat2*RAD_PER_DEG))) /          &
           (ALOG(TAN((90.-ABS(truelat1))*RAD_PER_DEG*0.5 ))- &
            ALOG(TAN((90.-ABS(truelat2))*RAD_PER_DEG*0.5 )) )
        ELSE
           cone = SIN(ABS(truelat1)*RAD_PER_DEG )
        ENDIF
      endif 
      proj%cone = cone

      istart        = 1
      iend          = 1
      iend(1)       = wedim
      iend(2)       = sndim
      allocate ( xlat(iend(1),iend(2)))
      rcode = nf_inq_varid ( cdfid, "XLAT", id_var )
      if (rcode /= 0) rcode = nf_inq_varid ( cdfid, "XLAT_M", id_var )
      call ncvgt( cdfid,id_var,istart,iend,xlat,rcode)
      proj%lat1 = xlat(1,1)
      allocate (xlong(iend(1),iend(2)))
      rcode = nf_inq_varid ( cdfid, "XLONG", id_var )
      if (rcode /= 0) rcode = nf_inq_varid ( cdfid, "XLONG_M", id_var )
      call ncvgt( cdfid,id_var,istart,iend,xlong,rcode)
      dummy_lon1 = xlong(1,1)
      IF (dummy_lon1 < -180.) dummy_lon1 = dummy_lon1 + 360.
      IF (dummy_lon1 >  180.) dummy_lon1 = dummy_lon1 - 360.
      proj%lon1 = dummy_lon1

      allocate ( diff(iend(1),iend(2)))
      diff = xlong - stand_lon
      where ( diff .gt. 180.) 
        diff = diff - 360.
      end where
      where ( diff .lt. -180.) 
        diff = diff + 360.
      end where

      allocate ( alpha(iend(1),iend(2)))
      alpha = diff * cone * RAD_PER_DEG
      where ( xlat .lt. 0.) 
        alpha = -1. * alpha
      end where

      deallocate (xlat)
      deallocate (xlong)
      deallocate (diff)
  endif


! OPTIONS
!===========================================================================================

      if ( op_diag ) nVars = nVars + 3
! Before we start, sort out locations if we are generating time series output
      if ( option  == "-ts" ) then
        allocate (data_ts(ts_i,btdim+1))
        nVars = ts_i
        !!if ( ts_type == "ll" ) call calc_nearest_xy(cdfid,ts_xy,ts_ll)
        if ( ts_type == "ll" ) then
           call latlon_to_ij( cdfid, proj, ts_ll, ts_xy )
           if ( ts_xy(1) < 0 .OR. ts_xy(1) > wedim ) STOP '   STOP: LON outside domain'
           if ( ts_xy(2) < 0 .OR. ts_xy(2) > sndim ) STOP '   STOP: LAT outside domain'
        endif
      endif
      if ( plot_var /= " " ) then
        nVars = 1
      endif


! New we are ready to start with the time loop
    if ( time1 == 0 ) time1 = 1
    if ( time2 == 0 ) time2 = n_times

    do itimes = time1,time2
      if ( static ) then
        print_time = " "            
      else
        print_time = times(itimes)
        if ( plot_var == " " .and. option .ne. "-ts" ) then
          print*,"  "
          print*,"TIME: ",print_time(1:19)
       endif
     endif

     if ( op_diag ) then
       istart        = 1
       istart(4)     = itimes
       iend          = 1
       iend(1)       = wedim
       iend(2)       = sndim
       iend(3)       = btdim
       rcode = nf_inq_varid ( cdfid, "P", id_var )
       if ( rcode == 0 ) then
         if (allocated(pressure)) deallocate(pressure)
         allocate ( pressure(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,pressure,rcode)
       endif
       rcode = nf_inq_varid ( cdfid, "PB", id_var )
       if ( rcode == 0 ) then
         if (allocated(data_r)) deallocate(data_r)
         allocate ( data_r(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,data_r,rcode)
       endif 
       pressure = (pressure + data_r)*0.01
       rcode = nf_inq_varid ( cdfid, "T", id_var )
       if ( rcode == 0 ) then
         if (allocated(tk)) deallocate(tk)
         allocate ( tk(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,tk,rcode)
       endif 
       tk = (tk+300.) * ( pressure / 1000. )**(287.04/1004.)

       iend(3)       = btdim+1
       rcode = nf_inq_varid ( cdfid, "PH", id_var )
       if ( rcode == 0 ) then
         if (allocated(height)) deallocate(height)
         allocate ( height(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,height,rcode)
       endif
       rcode = nf_inq_varid ( cdfid, "PHB", id_var )
       if ( rcode == 0 ) then
         if (allocated(data_r)) deallocate(data_r)
         allocate ( data_r(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,data_r,rcode)
       endif 
       height = ( (height+data_r) / 9.81 ) / 1000.
       if (allocated(data_r)) deallocate(data_r)
     endif 


     if ( op_rot ) then

       istart        = 1
       istart(3)     = itimes
       iend          = 1
       iend(1)       = wedim
       iend(2)       = sndim

       rcode = nf_inq_varid ( cdfid, "U10", id_var )
       if ( rcode == 0 ) then
         if (allocated(u10)) deallocate(u10)
         allocate ( u10(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,u10,rcode)
       endif
       rcode = nf_inq_varid ( cdfid, "V10", id_var )
       if ( rcode == 0 ) then
         if (allocated(v10)) deallocate(v10)
         allocate ( v10(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,v10,rcode)
       endif

       istart        = 1
       istart(4)     = itimes
       iend          = 1
       iend(1)       = wedim+1
       iend(2)       = sndim
       iend(3)     = btdim
       rcode = nf_inq_varid ( cdfid, "U", id_var )
       if (rcode /= 0) rcode = nf_inq_varid ( cdfid, "UU", id_var )
       if ( rcode == 0 ) then
         if (allocated(uuu)) deallocate(uuu)
         allocate ( uuu(iend(1)-1,iend(2),iend(3)))
         allocate ( tmp(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,tmp,rcode)
         uuu = (tmp(1:iend(1)-1,:,:)+tmp(2:iend(1),:,:))*0.5
         deallocate(tmp)
       endif

       iend          = 1
       iend(1)       = wedim
       iend(2)       = sndim+1
       iend(3)     = btdim
       rcode = nf_inq_varid ( cdfid, "V", id_var )
       if (rcode /= 0) rcode = nf_inq_varid ( cdfid, "VV", id_var )
       if ( rcode == 0 ) then
         if (allocated(vvv)) deallocate(vvv)
         allocate ( vvv(iend(1),iend(2)-1,iend(3)))
         allocate ( tmp(iend(1),iend(2),iend(3)))
         call ncvgt( cdfid,id_var,istart,iend,tmp,rcode)
         vvv = (tmp(:,1:iend(2)-1,:)+tmp(:,2:iend(2),:))*0.5
         deallocate(tmp)
       endif 

     endif 

      do idvar = 1,nVars
        if ( option .ne. "-ts" ) then           
          if ( plot_var == " " ) then
            id_var = idvar
          else
            varnam = plot_var
            rcode = nf_inq_varid ( cdfid, varnam, id_var )
            if (rcode .ne. 0) then
              if (varnam == "pressure" .or. varnam == "height" .or. varnam == "tk" ) then
                !!print*,"Dealing with a diagnostic - assume OK"
                if ( .not. op_diag ) then 
                   print*,"   Must add -diag on the command line for diagnistic fields"
                   print*," "
                   STOP
                endif
              else
                print*,plot_var," is not available in the input file"
                STOP
              endif
            endif
          endif
        else
          varnam = ts_var(idvar)
          rcode = nf_inq_varid ( cdfid, varnam, id_var )
          if (rcode .ne. 0) then
            if (varnam == "pressure" .or. varnam == "height" .or. varnam == "tk" ) then
              !!print*,"Dealing with a diagnostic - assume OK"
                if ( .not. op_diag ) then 
                   print*,"   Must add -diag on the command line for diagnistic fields"
                   print*," "
                   STOP
                endif
            else
              print*,plot_var," is not available in the input file"
              STOP
            endif
          endif
        endif


       if (idvar .gt. nVars_sav .or. &
           varnam == "pressure" .or. varnam == "height" .or. varnam == "tk") then  
         type_to_get = 5
         istart    = 1
         istart(4) = itimes
         iend      = 1
         iend(1)   = wedim
         iend(2)   = sndim
         iend(3)   = btdim
         MemoryOrder = "XYZ"
         FieldType = 104
         stagger = " " 
         nDims = 4

         if ( idvar == nVars_sav+1 .or. varnam == 'pressure' ) then
           varnam = "pressure"
           units  = "hPa"
           description = "Full model pressure - diagnostic"
           if (allocated(data_r)) deallocate(data_r)
           allocate (data_r(iend(1),iend(2),iend(3)))
           data_r = pressure
         endif
         if ( idvar == nVars_sav+2 .or. varnam == 'tk' ) then
           varnam = "temperature"
           units  = "K"
           description = "Model temperature - diagnostic"
           if (allocated(data_r)) deallocate(data_r)
           allocate (data_r(iend(1),iend(2),iend(3)))
           data_r = tk
         endif
         if ( idvar == nVars_sav+3 .or. varnam == 'height' ) then
           iend(3)   = btdim+1
           varnam = "height"
           units  = "km"
           description = "Model height - diagnostic"
           stagger = "Z" 
           if (allocated(data_r)) deallocate(data_r)
           allocate (data_r(iend(1),iend(2),iend(3)))
           data_r = height
         endif

         dims = iend

       else

         ! Get information about the field(s) we are interested in
          dims = 1
            rcode = nf_inq_var( cdfid, id_var, varnam, ivtype, nDims, dimids, nAtts )
         ! Need to know if this is a real/double-real/integer field
          type_to_get = ivtype
  
         ! Get units and memeory order of field
          rcode = NF_GET_ATT_TEXT(cdfid, id_var, "units", units )
          rcode = NF_GET_ATT_TEXT(cdfid, id_var, "MemoryOrder", MemoryOrder )
          rcode = NF_GET_ATT_INT (cdfid, id_var, "FieldType", FieldType )
          rcode = NF_GET_ATT_TEXT(cdfid, id_var, "description", description )
          rcode = NF_GET_ATT_TEXT(cdfid, id_var, "stagger", stagger )

          if (iachar(units(1:1)) == 0 ) units = "-"
  
         ! Get the dimensions of this field
          do i=1,ndims
            rcode = nf_inq_dimlen( cdfid, dimids(i), dims(i) )
          enddo
          istart        = 1
          istart(nDims) = itimes
          iend          = 1
          do i = 1,nDims-1
            iend(i)     = dims(i)
          enddo
  
         ! Get field from netCDF file
          if (type_to_get .eq. 5)  then                           !get_real
            allocate (data_r(iend(1),iend(2),iend(3)))
            call ncvgt( cdfid,id_var,istart,iend,data_r,rcode)
          elseif (type_to_get .eq. 6)  then                       !get_real_double
            allocate (data_dp_r(iend(1),iend(2),iend(3)))
            call ncvgt( cdfid,id_var,istart,iend,data_dp_r,rcode)
          elseif (type_to_get .eq. 4) then                        !get_integer
            allocate (data_i(iend(1),iend(2),iend(3)))
            call ncvgt( cdfid,id_var,istart,iend,data_i,rcode)
          endif

       endif
        

     ! Depending on the option, do something special 
      SELECTCASE (option)
        CASE ("-s")      ! Write out all field names and a sample value of each field
             isample        = 1
             do i = 1,nDims-1
               isample(i)   = iend(i)/2
               if (isample(i) == 0) isample(i) = 1
             enddo
             if (type_to_get .eq. 5)  then 
               sample_value_r = data_r(isample(1),isample(2),isample(3))
               write(*,301)varnam,nDims-1,trim(MemoryOrder),               &
                        iend(1),iend(2),iend(3),sample_value_r,trim(units)                 
             elseif (type_to_get .eq. 6)  then  
               sample_value_r = data_dp_r(isample(1),isample(2),isample(3))
               write(*,301)varnam,nDims-1,trim(MemoryOrder),               &
                        iend(1),iend(2),iend(3),sample_value_r,trim(units)               
             elseif (type_to_get .eq. 4) then   
               sample_value_i = data_i(isample(1),isample(2),isample(3))
               write(*,302)varnam,nDims-1,trim(MemoryOrder),               &
                        iend(1),iend(2),iend(3),sample_value_i,trim(units)                 
             endif
        CASE ("-S")      ! Write out all field names and a value at input X Y Z
             isample        = 1
             do i = 1,nDims-1
               isample(i) = plot_dim(i)
               if ( isample(i) .le. 0  .or. isample(i) .gt. dims(i) ) then
                 isample(i) = dims(i)/2
                 if (isample(i) == 0) isample(i) = 1
               endif
             enddo
             if (type_to_get .eq. 5)  then
               sample_value_r = data_r(isample(1),isample(2),isample(3))
               write(*,303)varnam,nDims-1,trim(MemoryOrder),               &
                        iend(1),iend(2),iend(3),                           &
                        isample(1),isample(2),isample(3),                  &
                        sample_value_r,trim(units)
             elseif (type_to_get .eq. 6)  then
               sample_value_r = data_dp_r(isample(1),isample(2),isample(3))
               write(*,303)varnam,nDims-1,trim(MemoryOrder),               &
                        iend(1),iend(2),iend(3),                           &
                        isample(1),isample(2),isample(3),                  &
                        sample_value_r,trim(units)
             elseif (type_to_get .eq. 4) then
               sample_value_i = data_i(isample(1),isample(2),isample(3))
               write(*,304)varnam,nDims-1,trim(MemoryOrder),               &
                        iend(1),iend(2),iend(3),                           &
                        isample(1),isample(2),isample(3),                  &
                        sample_value_i,trim(units)
             endif
        CASE ("-m")      ! Write out all field names plus the min/max values
             if (type_to_get .eq. 5)  then   
               minvalue_r =  MINVAL(data_r)
               maxvalue_r =  MAXVAL(data_r)
               write(*,305)varnam,nDims-1,trim(MemoryOrder),               &
                      iend(1),iend(2),iend(3),                             &
                      minvalue_r,maxvalue_r,trim(units)                 
             elseif (type_to_get .eq. 6)  then 
               minvalue_r =  MINVAL(data_dp_r)
               maxvalue_r =  MAXVAL(data_dp_r)
               write(*,305)varnam,nDims-1,trim(MemoryOrder),               &
                      iend(1),iend(2),iend(3),                             &
                      minvalue_r,maxvalue_r,trim(units)
             elseif (type_to_get .eq. 4) then 
               minvalue_i =  MINVAL(data_i)
               maxvalue_i =  MAXVAL(data_i)
               write(*,306)varnam,nDims-1,trim(MemoryOrder),               &
                      iend(1),iend(2),iend(3),                             &
                      minvalue_i,maxvalue_i,trim(units)
             endif
        CASE ("-M")      ! Write out all field names plus the min/max values (at level z for 3d fields)
             isample        = 1
             do i = 1,nDims-1
               isample(i) = plot_dim(i)
               if ( isample(i) .le. 0  .or. isample(i) .gt. dims(i) ) then
                 isample(i) = dims(i)/2
                 if (isample(i) == 0) isample(i) = 1
               endif
             enddo
             if (type_to_get .eq. 5)  then   
               minvalue_r =  MINVAL (MINVAL(data_r(:,:,isample(3)),DIM=1) ,DIM=1)
               maxvalue_r =  MAXVAL (MAXVAL(data_r(:,:,isample(3)),DIM=1) ,DIM=1)
               write(*,307)varnam,nDims-1,trim(MemoryOrder),               &
                      iend(1),iend(2),iend(3),isample(3),                  &
                      minvalue_r,maxvalue_r,trim(units)               
             elseif (type_to_get .eq. 6)  then 
               minvalue_r =  MINVAL (MINVAL(data_dp_r(:,:,isample(3)),DIM=1) ,DIM=1)
               maxvalue_r =  MAXVAL (MAXVAL(data_dp_r(:,:,isample(3)),DIM=1) ,DIM=1)
               write(*,307)varnam,nDims-1,trim(MemoryOrder),               &
                      iend(1),iend(2),iend(3),isample(3),                  &
                      minvalue_r,maxvalue_r,trim(units)               
             elseif (type_to_get .eq. 4) then 
               minvalue_i =  MINVAL (MINVAL(data_i(:,:,isample(3)),DIM=1) ,DIM=1)
               maxvalue_i =  MAXVAL (MAXVAL(data_i(:,:,isample(3)),DIM=1) ,DIM=1)
               write(*,308)varnam,nDims-1,trim(MemoryOrder),               &
                      iend(1),iend(2),iend(3),isample(3),                  &
                      minvalue_i,maxvalue_i,trim(units)               
             endif
        CASE ("-v")      ! Write out information about specifc field
             if ( FirstTime ) then
               write(6,'(" Field                : ", A)') trim(varnam)
               write(6,'(" FieldType            : ",i3)') FieldType 
               write(6,'(" Description          : ", A)') trim(description)
               write(6,'(" Units                : ", A)') trim(units)
               write(6,'(" Stagger              : ", A)') trim(stagger)
               write(6,'(" Total times in file  : ",i3)') n_times        
               write(6,'(" Dimensions           : ",                       &
&                         i4," (x) ",i4, " (y) ",i4, " (z) ")')            &
                          iend(1),iend(2),iend(3)
               write(6,'(" ")') 
               FirstTime = .FALSE.
             endif
             if (type_to_get .eq. 5)  then  
               minvalue_r =  MINVAL(data_r)
               maxvalue_r =  MAXVAL(data_r)
               write(6,'(" ",A,"  :   MIN =",G18.10E2,"    MAX =",G18.10E2)')print_time(1:19),  &
                   minvalue_r,maxvalue_r
             elseif (type_to_get .eq. 6)  then 
               minvalue_r =  MINVAL(data_dp_r)
               maxvalue_r =  MAXVAL(data_dp_r)
               write(6,'(" ",A,"  :   MIN =",G18.10E2,"    MAX =",G18.10E2)')print_time(1:19),  &
                   minvalue_r,maxvalue_r
             elseif (type_to_get .eq. 4) then 
               minvalue_i =  MINVAL(data_i)
               maxvalue_i =  MAXVAL(data_i)
               write(6,'(" ",A,"  :   MIN =",i12,"    MAX =",i12)')print_time(1:19),  &
                          minvalue_i,maxvalue_i
             endif
        CASE ("-V")      ! Write out information about specifc field, plus dump field
             if ( FirstTime ) then
               write(6,'(" Field                : ", A)') trim(varnam)
               write(6,'(" FieldType            : ",i3)') FieldType 
               write(6,'(" Description          : ", A)') trim(description)
               write(6,'(" Units                : ", A)') trim(units)
               write(6,'(" Stagger              : ", A)') trim(stagger)
               write(6,'(" Total times in file  : ",i3)') n_times        
               write(6,'(" Dimensions           : ",                       &
&                         i4," (x) ",i4, " (y) ",i4, " (z) ")')            &
                          iend(1),iend(2),iend(3)
               write(6,'(" ")') 
               FirstTime = .FALSE.
             endif
             print*,"  "
             print*,"TIME: ",print_time(1:19)
             if (type_to_get .eq. 5)  then  
               print*,data_r
             elseif (type_to_get .eq. 6)  then 
               print*,data_dp_r
             elseif (type_to_get .eq. 4) then 
               print*,data_i
             endif
        CASE ("-w")      ! Write out information about specifc field to a file
             if ( FirstTime ) then
               write(file_out,'(A,".out")')trim(varnam)
               open ( 13 , file=file_out )
               print*,"Data has been written to ",file_out
               write(13,'(" Field                : ", A)') trim(varnam)
               write(13,'(" FieldType            : ",i3)') FieldType 
               write(13,'(" Description          : ", A)') trim(description)
               write(13,'(" Units                : ", A)') trim(units)
               write(13,'(" Stagger              : ", A)') trim(stagger)
               write(13,'(" Total times in file  : ",i3)') n_times        
               write(13,'(" Dimensions           : ",                       &
&                         i4," (x) ",i4, " (y) ",i4, " (z) ")')            &
                          iend(1),iend(2),iend(3)
               write(13,'(" ")') 
               write(13,'("FORMAT:")') 
               write(13,'("  do k = 1 ,",i5)') iend(3)
               write(13,'("    do j = 1 ,",i5)') iend(2)
               write(13,'("      do i = 1 ,",i5)') iend(1)
               write(13,'(" ")') 
               FirstTime = .FALSE.
             endif
             write(13,'(" ")') 
             write(13,'("TIME: ",A)') print_time(1:19)
             if (type_to_get .eq. 5)  then  
               do k=1,iend(3)
                 do j=1,iend(2)
                   write ( 13, * ) (data_r(i,j,k),i=1,iend(1))
                 enddo
               enddo
             elseif (type_to_get .eq. 6)  then 
               do k=1,iend(3)
                 do j=1,iend(2)
                   write ( 13, * ) (data_dp_r(i,j,k),i=1,iend(1))
                 enddo
               enddo
             elseif (type_to_get .eq. 4) then 
               do k=1,iend(3)
                 do j=1,iend(2)
                   write ( 13, * ) (data_i(i,j,k),i=1,iend(1))
                 enddo
               enddo
             endif
        CASE ("-ts")      ! Generate Time Series output 
             if ( FirstTime ) then
               print*,"  "
               print*,"TIME SERIES OUTPUT IS GENERATED"
               print*,"   output is written to file:"
               print*,"   TIME_SERIES.out"
               print*,"  "

               open (13, file="TIME_SERIES.out",status='new',iostat=ios)
               if (ios .ne. 0) then
                 print*,"OUTPUT FILE EXIST, we will APPEND to this file"
                 open (13, file="TIME_SERIES.out",status='old',position='append')
               else
                 write(13,'(A20,A7,A7,A7,20A20)') &
                  "TIME                ","     X ","     Y ","     Z ",ts_var(1:ts_i)
               endif
               FirstTime = .FALSE.
             endif
             !  Keep all info for now - we will write later
              if (type_to_get .eq. 5)  then  
                    if ( varnam=="U" .or. varnam =="UU") then
                  data_ts(idvar,1:iend(3)) = (data_r(ts_xy(1),ts_xy(2),1:iend(3))+data_r(ts_xy(1)+1,ts_xy(2),1:iend(3)))*0.5
                elseif ( varnam=="V" .or. varnam =="VV") then
                  data_ts(idvar,1:iend(3)) = (data_r(ts_xy(1),ts_xy(2),1:iend(3))+data_r(ts_xy(1),ts_xy(2)+1,1:iend(3)))*0.5
                elseif ( varnam=="W" )then
                  data_ts(idvar,1:iend(3)-1) = (data_r(ts_xy(1),ts_xy(2),1:iend(3)-1)+data_r(ts_xy(1),ts_xy(2),2:iend(3)))*0.5
                else 
                  data_ts(idvar,1:iend(3)) = data_r(ts_xy(1),ts_xy(2),1:iend(3))
                endif
              elseif (type_to_get .eq. 6)  then  
                    if ( varnam=="U" .or. varnam =="UU") then
                  data_ts(idvar,1:iend(3)) = (data_dp_r(ts_xy(1),ts_xy(2),1:iend(3))+data_dp_r(ts_xy(1)+1,ts_xy(2),1:iend(3)))*0.5
                elseif ( varnam=="V" .or. varnam =="VV") then
                  data_ts(idvar,1:iend(3)) = (data_dp_r(ts_xy(1),ts_xy(2),1:iend(3))+data_dp_r(ts_xy(1),ts_xy(2)+1,1:iend(3)))*0.5
                elseif ( varnam=="W" )then
                  data_ts(idvar,1:iend(3)) = (data_dp_r(ts_xy(1),ts_xy(2),1:iend(3)-1)+data_dp_r(ts_xy(1),ts_xy(2),2:iend(3)))*0.5
                else 
                  data_ts(idvar,1:iend(3)) = data_dp_r(ts_xy(1),ts_xy(2),1:iend(3))
                endif
              elseif (type_to_get .eq. 4)  then  
                data_ts(idvar,1:iend(3)) = data_i(ts_xy(1),ts_xy(2),1:iend(3))
              endif

             if ( op_rot ) then
             
               if ( varnam == "U10" ) then
                   data_ts(idvar,1) = v10(ts_xy(1),ts_xy(2),1)*sin(alpha(ts_xy(1),ts_xy(2))) + &
                                      u10(ts_xy(1),ts_xy(2),1)*cos(alpha(ts_xy(1),ts_xy(2)))
               endif
               if ( varnam == "V10" ) then
                   data_ts(idvar,1) = v10(ts_xy(1),ts_xy(2),1)*cos(alpha(ts_xy(1),ts_xy(2))) - &
                                      u10(ts_xy(1),ts_xy(2),1)*sin(alpha(ts_xy(1),ts_xy(2)))
               endif
               if ( varnam == "U" .or. varnam == "UU" ) then
                 do  kk = 1,iend(3)
                   data_ts(idvar,kk) = vvv(ts_xy(1),ts_xy(2),kk)*sin(alpha(ts_xy(1),ts_xy(2))) + &
                                       uuu(ts_xy(1),ts_xy(2),kk)*cos(alpha(ts_xy(1),ts_xy(2)))
                 enddo 
               endif
               if ( varnam == "V" .or. varnam == "VV" ) then
                 do  kk = 1,iend(3)
                   data_ts(idvar,kk) = vvv(ts_xy(1),ts_xy(2),kk)*cos(alpha(ts_xy(1),ts_xy(2))) - &
                                       uuu(ts_xy(1),ts_xy(2),kk)*sin(alpha(ts_xy(1),ts_xy(2)))
                 enddo 
               endif

             endif
             do  kk = iend(3)+1,btdim
                  data_ts(idvar,kk) = -99999.99
             enddo
             !  Print out all vertical levels           
             if ( idvar == ts_i ) then
               if ( ts_xy(3) == 0 ) then
                 do kk = 1,btdim
                   write(13,'(A20,3I7,G20.10E2,$)') print_time(1:19),ts_xy(1),ts_xy(2),kk,data_ts(1,kk)
                   do ii = 2,idvar-1
                     write(13,'(G20.10E2,$)') data_ts(ii,kk)
                   enddo
                     write(13,'(G20.10E2)') data_ts(idvar,kk)
                 enddo
                 write(13,*)
               else
                 do kk = ts_xy(3),ts_xy(3)
                   write(13,'(A20,3I7,G20.10E2,$)') print_time(1:19),ts_xy(1),ts_xy(2),kk,data_ts(1,kk)
                   do ii = 2,idvar-1
                     write(13,'(G20.10E2,$)') data_ts(ii,kk)
                   enddo
                     write(13,'(G20.10E2)') data_ts(idvar,kk)
                 enddo
               endif
             endif

        CASE ("-EditData")      ! Option to alter a field - controller by routine USER_CODE 
             if ( FirstTime ) then
               print*,"CAUTION variable ",trim(varnam)," is about to change. Continue? (yes/no)"
               read(*,*)go_change
               if ( go_change .ne. "yes") STOP "USER controlled stop"
               FirstTime = .FALSE.
             endif
             print*,"  "
             print*,"Changing variable: ",trim(varnam), " for time ", print_time(1:19)
             if (type_to_get .eq. 5)  then  
               CALL USER_CODE(data_r,data_dp_r,data_i,iend(1),iend(2),iend(3),varnam)
               call ncvpt( cdfid,id_var,istart,iend,data_r,rcode)
             elseif (type_to_get .eq. 6)  then 
               CALL USER_CODE(data_r,data_dp_r,data_i,iend(1),iend(2),iend(3),varnam)
               call ncvpt( cdfid,id_var,istart,iend,data_dp_r,rcode)
             elseif (type_to_get .eq. 4) then 
               CALL USER_CODE(data_r,data_dp_r,data_i,iend(1),iend(2),iend(3),varnam)
               call ncvpt( cdfid,id_var,istart,iend,data_i,rcode)
             endif

        CASE DEFAULT
             print*,"BAD option"
      END SELECT

   varnam = " " 
   ! make sure units remain a clean field
    units = "                    "

   ! deallocate everything 
     if (type_to_get .eq. 5) deallocate (data_r)
     if (type_to_get .eq. 6) deallocate (data_dp_r)
     if (type_to_get .eq. 4) deallocate (data_i)

    enddo
  enddo

! format for -s
 301 format(A17,"  ",i2,"  ",A3,"  ",3(1x,i4),"  ",G18.10E2,"  ",A)    
 302 format(A17,"  ",i2,"  ",A3,"  ",3(1x,i4),"  ",i14,"      ",A)
! format for -S
 303 format(A11,"  ",i2,"  ",A3,3(1x,i4),"   (x=",i4," y=",i4," z=",i4,")  ",G18.10E2,"  ",A)
 304 format(A11,"  ",i2,"  ",A3,3(1x,i4),"   (x=",i4," y=",i4," z=",i4,")  ",i14,"      ",A)
! format for -m
 305 format(A11,"  ",i2,"  ",A3,"  ",3(1x,i4),"  ",G18.10E2," - ",G18.10E2,"  ",A)
 306 format(A11,"  ",i2,"  ",A3,"  ",3(1x,i4),"  ",i14," - ",i14,"      ",A)
! format for -M
 307 format(A11,"  ",i2,"  ",A3,"  ",3(1x,i4),"   (z=",i3,") ",G18.10E2," - ",G18.10E2,"  ",A)
 308 format(A11,"  ",i2,"  ",A3,"  ",3(1x,i4),"   (z=",i3,") ",i14," - ",i14,"      ",A)



!===========================================================================================
! END OF OPTIONS


  call ncclos(cdfid,rcode)

  print*,"  "
  print*,"   --- End of input file ---   "

  end subroutine get_info_from_cdf
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------

  subroutine USER_CODE (data_real,data_dp_real,data_int,dim1,dim2,dim3,var)

  implicit none
  integer                                      ::  dim1,dim2,dim3
  double precision,  dimension(dim1,dim2,dim3) ::  data_dp_real
  real,    dimension(dim1,dim2,dim3)           ::  data_real
  integer, dimension(dim1,dim2,dim3)           ::  data_int
  character (len=10)                           :: var                        


!------------------------------READ FIRST--------------------------------------------------
!
! USER MUST KNOW WHICH VARIABLE WILL BE COMING IN, INCLUDING IF VARIABLE
! WILL BE REAL OR INTEGER
! IF YOU PLAN ON CHANGING THE VALUE OF "TSK", WORK WITH THE "data_real"
! ARRAY, AND IGNORE 'data_int"

! IT IS THE USER RESPONSABILITY TO ENSURE THIS CODE IS CORRECT
! REMEMBER THAT THE netCDF FILE YOU READ WILL ALSO BE THE ONE THAT
! GETS CHANGED, SO MAKE A COPY OF YOUR netCDF FILE BEFORE USING
! THE "-EditData  VAR" OPTION
!------------------------------------------------------------------------------------------

! Add and if block for the variable you want to change - this will
! prevent the overwriting of a variable by mistake

  if ( var == 'TSK') then                 ! will turn all TSK values to 100.00
    data_real = 100.00
  elseif ( var == 'SOILHGT') then         ! raise soil height by 30%
    where (data_real .gt. 0.0)
      data_real = data_real + .3*data_real
    endwhere
  elseif ( var == 'ISLTYP') then          ! change all 1's in this field with 2's
    !where (data_int == 1 )
    !  data_int = 2
    !endwhere
      data_int = 2                        ! change all into 2's
  elseif ( var == 'TH2') then             ! change TH2 to 273.00  - this is for 3dvar
                                          !                 double precision fields
      data_dp_real = 273.0
  else
    print*,"Variable given was not one of above - so no change will be"
    print*,"  made to any variables"
  endif

  !print*,"Changes has been made to variable ",var
  
  end subroutine USER_CODE

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------

