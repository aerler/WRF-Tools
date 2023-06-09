GRIB1| Level| From |  To  | metgrid  |  metgrid | metgrid                                  |GRIB2|GRIB2|GRIB2|GRIB2|
Param| Type |Level1|Level2| Name     |  Units   | Description                              |Discp|Catgy|Param|Level|
-----+------+------+------+----------+----------+------------------------------------------+-----------------------+
 129 | 100  |   *  |      | GEOPT    | m2 s-2   |                                          |  0  |  3  |  4  | 100 |
     | 100  |   *  |      | HGT      | m        | Height                                   |  0  |  3  |  6  | 100 |
 130 | 100  |   *  |      | TT       | K        | Temperature                              |  0  |  0  |  0  | 100 |
 131 | 100  |   *  |      | UU       | m s-1    | U                                        |  0  |  2  |  2  | 100 |
 132 | 100  |   *  |      | VV       | m s-1    | V                                        |  0  |  2  |  3  | 100 |
 157 | 100  |   *  |      | RH       | %        | Relative Humidity                        |  0  |  1  |  1  | 100 |
 165 |  1   |   0  |      | UU       | m s-1    | U                 At 10 m                |  0  |  2  |  2  | 103 |
 166 |  1   |   0  |      | VV       | m s-1    | V                 At 10 m                |  0  |  2  |  3  | 103 |
 167 |  1   |   0  |      | TT       | K        | Temperature       At 2 m                 |  0  |  0  |  0  | 103 |
 168 |  1   |   0  |      | DEWPT    | K        |                   At 2 m                 |  0  |  0  |  6  | 103 |
     |  1   |   0  |      | RH       | %        | Relative Humidity At 2 m                 |  0  |  1  |  1  | 103 |
 172 |  1   |   0  |      | LANDSEA  | 0/1 Flag | Land/Sea flag                            |  2  |  0  |  0  |   1 |
 129 |  1   |   0  |      | SOILGEO  | m2 s-2   |                                          |  0  |  3  |  4  |   1 |
     |  1   |   0  |      | SOILHGT  | m        | Terrain field of source analysis         |  0  |  3  |  6  |   1 |
 134 |  1   |   0  |      | PSFC     | Pa       | Surface Pressure                         |  0  |  3  |  0  |   1 |
 151 |  1   |   0  |      | PMSL     | Pa       | Sea-level Pressure                       |  0  |  3  |  0  | 101 |
 235 |  1   |   0  |      | SKINTEMP | K        | Sea-Surface Temperature                  |  0  |  0  | 17  |   1 |
  31 |  1   |   0  |      | SEAICE   | fraction | Sea-Ice Fraction                         | 10  |  2  |  0  |   1 |
  34 |  1   |   0  |      | SST      | K        | Sea-Surface Temperature                  | 10  |  3  |  0  |   1 |
  33 |  1   |   0  |      | SNOW_DEN | kg m-3   |                                          |  0  |  1  | 61  |   1 |
 141 |  1   |   0  |      | SNOW_EC  | m        |                                          |  0  |  1  | 254 |   1 |
     |  1   |   0  |      | SNOW     | kg m-2   |Water Equivalent of Accumulated Snow Depth|  0  |  1  | 13  |   1 |
     |  1   |   0  |      | SNOWH    | m        | Physical Snow Depth                      |  0  |  1  | 11  |   1 |
 139 | 112  |   0  |    7 | ST000007 | K        | T of 0-7 cm ground layer                 | 192 | 128 | 139 | 106 |
 170 | 112  |   7  |   28 | ST007028 | K        | T of 7-28 cm ground layer                | 192 | 128 | 170 | 106 |
 183 | 112  |  28  |  100 | ST028100 | K        | T of 28-100 cm ground layer              | 192 | 128 | 183 | 106 |
 236 | 112  | 100  |  255 | ST100289 | K        | T of 100-289 cm ground layer             | 192 | 128 | 236 | 106 |
  39 | 112  |   0  |    7 | SM000007 | m3 m-3   | Soil moisture of 0-7 cm ground layer     | 192 | 128 | 39  | 106 |
  40 | 112  |   7  |   28 | SM007028 | m3 m-3   | Soil moisture of 7-28 cm ground layer    | 192 | 128 | 40  | 106 |
  41 | 112  |  28  |  100 | SM028100 | m3 m-3   | Soil moisture of 28-100 cm ground layer  | 192 | 128 | 41  | 106 |
  42 | 112  | 100  |  255 | SM100289 | m3 m-3   | Soil moisture of 100-289 cm ground layer | 192 | 128 | 42  | 106 |
-----+------+------+------+----------+----------+------------------------------------------+-----+-----+-----+-----+
#
#  For use with ERA-interim pressure-level output.
#
#  Grib codes are from Table 128
#  http://www.ecmwf.int/services/archive/d/parameters/order=grib_parameter/table=128/
#  
# snow depth is converted to the proper units in rrpr.F
#
#  For ERA-interim data at NCAR, use the pl (sc and uv) and sfc sc files. 

