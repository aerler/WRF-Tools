# ============================================================================
# Name        : Makefile
# Author      : Andre R. Erler
# Version     : 0.2
# Copyright   : GPL v3
# Description : Makefile for Fortran Tools
# ============================================================================

.PHONY: all clean

## Select Build System here: Intel, GFortran, GPC
#SYSTEM = GFortran
# default build
ifndef SYSTEM
SYSTEM = Intel
endif
# debugging flags
#MODE = Debug

## Load Build Environment
# Standard Intel 
ifeq ($(SYSTEM), Intel)
include config/Intel # Intel Compiler
endif
# Standard GFortran 
ifeq ($(SYSTEM), GFortran)
include config/GFortran # GFortran Compiler
endif
# GPC, SciNet
ifeq ($(SYSTEM), GPC)
include config/GPC # Intel Compiler
endif
# P7, SciNet
ifeq ($(SYSTEM), P7)
include config/P7 # IBM Linux Compiler
endif

## Assemble Flags
ifeq ($(MODE), Debug)
FCFLAGS = $(DBGFLAGS) -pg -DDEBUG -DDIAG
else
FCFLAGS = $(OPTFLAGS) -DDIAG
endif

# this gets build before other scripts are executed
all: 

## build unccsm.exe program to convert CCSM netcdf output to WRF intermediate files
unccsm: unccsm.exe

unccsm.exe: bin/nc2im.o
	$(FC) -convert big_endian $(FCFLAGS) -o bin/$@ $^ $(NC_LIB)
	
bin/nc2im.o: src/nc2im.f90
	$(FC) -convert big_endian $(FCFLAGS) $(NC_INC) -c $^
	mv nc2im.o bin/

## build convert_spectra to convert spherical harmonic coefficients from ECMWF
# grib files to total wavenumber spectra and save as netcdf
spectra: convert_spectra

convert_spectra: bin/gribSpectra.o
	$(FC) $(FCFLAGS) -o bin/$@ $^ $(GRIBLIBS) $(NCLIBS)

bin/gribSpectra.o: src/gribSpectra.f90
	$(FC) $(FCFLAGS) $(INCLUDE) -c $^
	mv gribSpectra.o bin/ 

clean:
	rm -f bin/* *.mod *.o *.so 
	
### F2Py Flags (for reference)
#F2PYCC = intelem
#F2PYFC = intelem
#F2PYFLAGS = -openmp # -parallel -par-threshold50 -par-report3
#F2PYOPT = -O3 -xHost -no-prec-div -static
#PYTHON_MODULE_LOCATION = # relative path
