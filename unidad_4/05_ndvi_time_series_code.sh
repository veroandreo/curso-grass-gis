#!/bin/bash

########################################################################
# Commands for NDVI time series exercise
# Author: Veronica Andreo
# Date: October, 2018. Edits: December 2018, April 2019, July 2020
########################################################################


#
# Get familiar with NDVI data
#


# start GRASS GIS in `modis_ndvi` mapset - *nix
grass78 $HOME/grassdata/posgar2007_4_cba/modis_ndvi

# start GRASS GIS in the OSGeo4W console in `modis_ndvi` mapset - Windows
grass78 %HOME%\grassdata\posgar2007_4_cba\modis_ndvi

# add `modis_lst` to accessible mapsets path
g.mapsets -p
g.mapsets mapset=modis_lst operation=add

# list files and get info and stats
g.list type=raster mapset=.

r.info map=MOD13C2.A2015001.006.single_Monthly_NDVI
r.univar map=MOD13C2.A2015001.006.single_Monthly_NDVI


#
# Use of reliability band
#


# set computational region
g.region -p vector=provincia_cba \
  align=MOD13C2.A2015001.006.single_Monthly_NDVI

# set mask
r.mask vector=provincia_cba

# keep only NDVI most reliable pixels (one map) - *nix
PR=MOD13C2.A2015274.006.single_Monthly_pixel_reliability
NDVI=MOD13C2.A2015274.006.single_Monthly_NDVI

r.mapcalc \
  expression="${NDVI}_filt = if(${PR} != 0, null(), ${NDVI})"

# keep only NDVI most reliable pixels (one map) - windows
SET PR=MOD13C2.A2015274.006.single_Monthly_pixel_reliability
SET NDVI=MOD13C2.A2015274.006.single_Monthly_NDVI

r.mapcalc expression="%NDVI%_filt = if(%PR% != 0, null(), %NDVI%)"

# for all NDVI maps (Windows users run bash.exe and once done, exit)

# list of maps
PR=`g.list type=raster pattern="*_pixel_reliability" separator=" "`
NDVI=`g.list type=raster pattern="*_Monthly_NDVI" separator=" "`
# convert list to array
PR=($PR)
NDVI=($NDVI)

# iterate over the 2 arrays
for ((i=0;i<${#PR[@]};i++)) ; do
 r.mapcalc --o \
  expression="${NDVI[$i]}_filt = if(${PR[$i]} != 0, null(), ${NDVI[$i]})"
done


#
# Create NDVI time series
#


# create STRDS
t.create output=ndvi_monthly \
  type=strds temporaltype=absolute \
  title="Filtered monthly NDVI" \
  description="Filtered monthly NDVI - MOD13C2 - Cordoba, 2015-2019"

# check if it was created
t.list type=strds

# list NDVI filtered files
g.list type=raster pattern="*filt" output=ndvi_list.txt

# register maps
t.register -i input=ndvi_monthly \
  type=raster file=ndvi_list.txt \
  start="2015-01-01" \
  increment="1 months"

# print time series info
t.info input=ndvi_monthly

# print list of maps in time series
t.rast.list input=ndvi_monthly


#
# Estimate percentage of missing data
#


# How much missing data we have after filtering for pixel reliability?
t.rast.univar input=ndvi_monthly

# count valid data
t.rast.series input=ndvi_monthly \
  method=count \
  output=ndvi_count_valid

# estimate percentage of missing data
r.mapcalc \
 expression="ndvi_missing = ((60 - ndvi_count_valid) * 100.0)/60"


#
# Temporal gap-filling: HANTS
#


# install extension
g.extension extension=r.hants

# *nix
# list maps
maplist=`t.rast.list input=ndvi_monthly method=comma`

# gapfill: r.hants
r.hants input=$maplist range=-2000,10000 \
  nf=5 fet=500 base_period=12

# Windows
# list maps
FOR /F %c IN ('t.rast.list "-u" "input=ndvi_monthly" "method=comma"') DO SET maplist=%c

r.hants input=%maplist% range=-2000,10000 nf=5 fet=500 base_period=12

# patch original with filled (one map - *nix)
NDVI_ORIG=MOD13C2.A2015001.006.single_Monthly_NDVI_filt
NDVI_HANTS=MOD13C2.A2015001.006.single_Monthly_NDVI_filt_hants

r.patch input=${NDVI_ORIG},${NDVI_HANTS} \
  output=${NDVI_HANTS}_patch

# patch original with filled (one map - windows)
SET NDVI_ORIG=MOD13C2.A2015001.006.single_Monthly_NDVI_filt
SET NDVI_HANTS=MOD13C2.A2015001.006.single_Monthly_NDVI_filt_hants

r.patch input=%NDVI_ORIG%,%NDVI_HANTS% output=%NDVI_HANTS%_patch

# patch original with filled (all maps, Windows users run bash.exe, once done type exit)
# list of maps
ORIG=`g.list type=raster pattern="*_filt" separator=" "`
FILL=`g.list type=raster pattern="*_hants" separator=" "`
# convert list to array
ORIG=($ORIG)
FILL=($FILL)

# iterate over the 2 arrays
for ((i=0;i<${#ORIG[@]};i++)) ; do
  r.patch input=${ORIG[$i]},${FILL[$i]} output=${FILL[$i]}_patch --o
done

# create new time series 
t.create output=ndvi_monthly_patch \
  type=strds temporaltype=absolute \
  title="Patched monthly NDVI" \
  description="Filtered, gap-filled and patched monthly NDVI - MOD13C2 - Cordoba, 2015-2019"

# list NDVI patched files
g.list type=raster pattern="*patch" \
  output=list_ndvi_patched.txt

# register maps
t.register -i input=ndvi_monthly_patch \
  type=raster file=list_ndvi_patched.txt \
  start="2015-01-01" \
  increment="1 months"

# print time series info
t.info input=ndvi_monthly_patch


#
# Obtain phenological information
#


# get month of maximum and month of minimum
t.rast.series input=ndvi_monthly_patch \
  method=minimum output=ndvi_min
t.rast.series input=ndvi_monthly_patch \
  method=maximum output=ndvi_max

# get month of maximum and minimum
t.rast.mapcalc -n inputs=ndvi_monthly_patch \
  output=month_max_ndvi \
  expression="if(ndvi_monthly_patch == ndvi_max, start_month(), null())" \
  basename=month_max_ndvi

t.rast.mapcalc -n inputs=ndvi_monthly_patch \
  output=month_min_ndvi \
  expression="if(ndvi_monthly_patch == ndvi_min, start_month(), null())" \
  basename=month_min_ndvi

# get the earliest month in which the maximum and minimum appeared
t.rast.series input=month_max_ndvi \
  method=maximum output=max_ndvi_date
t.rast.series input=month_min_ndvi \
  method=minimum output=min_ndvi_date

# remove month_max_lst strds 
t.remove -rf inputs=month_max_ndvi,month_min_ndvi

# time series of slopes
t.rast.algebra \
 expression="slope_ndvi = (ndvi_monthly_patch[1] - ndvi_monthly_patch[0]) / td(ndvi_monthly_patch)" \
 basename=slope_ndvi suffix=gran
 
# get max slope per year
t.rast.aggregate input=slope_ndvi output=ndvi_slope_yearly \
  basename=NDVI_max_slope_year suffix=gran \
  method=maximum \
  granularity="1 years"

# install extension
g.extension extension=r.seasons

# start, end and length of growing season - *nix
r.seasons input=`t.rast.list -u input=ndvi_monthly_patch method=comma` \
  prefix=ndvi_season n=3 \
  nout=ndvi_season \
  threshold_value=3000 min_length=5

# start, end and length of growing season - Windows
FOR /F %c IN ('t.rast.list "-u" "input=ndvi_monthly_patch" "separator=," "method=comma"') DO SET ndvi_list=%c

r.seasons input=%ndvi_list% prefix=ndvi_season n=3 nout=ndvi_season threshold_value=3000 min_length=5

# create a threshold map: min ndvi + 0.1*ndvi
r.mapcalc expression="threshold_ndvi = ndvi_min * 1.1"


#
# Estimate NDWI
#


# create time series of NIR and MIR
t.create output=NIR \
  type=strds temporaltype=absolute \
  title="NIR monthly" \
  description="NIR monthly - MOD13C2 - 2015-2019"

t.create output=MIR \
  type=strds temporaltype=absolute \
  title="MIR monthly" \
  description="MIR monthly - MOD13C2 - 2015-2019"
 
# list NIR and MIR files
g.list type=raster pattern="*NIR*" output=list_nir.txt
g.list type=raster pattern="*MIR*" output=list_mir.txt

# register maps
t.register -i input=NIR \
  type=raster file=list_nir.txt \
  start="2015-01-01" increment="1 months"

t.register -i input=MIR \
  type=raster file=list_mir.txt \
  start="2015-01-01" increment="1 months"
 
# print time series info
t.info input=NIR
t.info input=MIR

# estimate NDWI time series
t.rast.algebra basename=ndwi_monthly \
  expression="ndwi_monthly = if(NIR > 0 && MIR > 0, (float(NIR - MIR) / float(NIR + MIR)), null())" \
  suffix=gran

#
# Frequency of inundation
#


# reclassify
t.rast.mapcalc -n input=ndwi_monthly \
  output=flood basename=flood \
  expression="if(ndwi_monthly > 0.8, 1, null())"

# flooding frequency
t.rast.series input=flood output=flood_freq method=sum


#
# Regression between NDWI and NDVI
#


# install extension
g.extension extension=r.regression.series

# use in *nix
xseries=`t.rast.list input=ndvi_monthly_patch method=comma`
yseries=`t.rast.list input=ndwi_monthly method=comma`

r.regression.series xseries=$xseries \
  yseries=$yseries \
  output=ndvi_ndwi_rsq \
  method=rsq

# use in Windows
FOR /F %c IN ('t.rast.list "-u" "input=ndvi_monthly_patch" "method=comma"') DO SET xseries=%c
FOR /F %c IN ('t.rast.list "-u" "input=ndwi_monthly" "method=comma"') DO SET yseries=%c

r.regression.series xseries=%xseries% yseries=%yseries% output=ndvi_ndwi_rsq method=rsq

