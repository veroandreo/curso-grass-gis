#!/bin/bash

########################################################################
# Commands for the TGRASS lecture at GEOSTAT Summer School in Prague
# Author: Veronica Andreo
# Date: July - August, 2018 - Edited July, 2020
########################################################################


########### Before the workshop (done for you in advance) ##############

# Install i.modis add-on (requires pymodis library - www.pymodis.org)
g.extension extension=i.modis

# Download and import MODIS LST data (https://lpdaac.usgs.gov/products/mod11b3v006/)
# Note: User needs to be registered at Earthdata: 
# https://urs.earthdata.nasa.gov/users/new
i.modis.download settings=$HOME/gisdata/NASA_SETTING.txt \
  product=lst_terra_monthly_5600 \
  tile=h12v12 \
  startday=2015-01-01 endday=2019-12-31 \
  folder=/tmp

# Import LST Day and QC Day
i.modis.import files=/tmp/listfileMOD11B3.006.txt \
  spectral="( 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )"


############## For the workshop (what you have to do) ##################

## Download the ready to use location from:
## https://gitlab.com/veroandreo/maie-procesamiento
## and unzip it into your `grassdata`

# Get list of raster maps in the 'modis_lst' mapset
g.list type=raster mapset=.

# Get info from one of the raster maps
r.info map=MOD11B3.A2015060.h12v12.single_LST_Day_6km


## Region settings and MASK

# Set region to Cba boundaries with LST maps' resolution
g.region -p vector=provincia_cba \
  align=MOD11B3.A2015060.h12v12.single_LST_Day_6km

#projection: 99 (POSGAR 2007 / Argentina 4)
#zone:       0
#datum:      towgs84=-0.41,0.46,-0.35,0,0,0,0
#ellipsoid:  grs80
#north:      6737850.33740514
#south:      6121850.33740514
#west:       4230385.41968537
#east:       4616785.41968537
#nsres:      5600
#ewres:      5600
#rows:       110
#cols:       69
#cells:      7590

# Set a MASK to Cba boundary
r.mask vector=provincia_cba

# you should see this statement in the terminal from now on
#~ [Raster MASK present]


## Time series

# Create the STRDS
t.create type=strds temporaltype=absolute output=LST_Day_monthly \
  title="Monthly LST Day 5.6 km" \
  description="Monthly LST Day 5.6 km MOD11B3.006 Cordoba, 2015-2019"

# Check if the STRDS is created
t.list type=strds

# Get info about the STRDS
t.info input=LST_Day_monthly


## Add time stamps to maps (i.e., register maps)

# in Unix systems
t.register -i input=LST_Day_monthly \
 maps=`g.list type=raster pattern="MOD11B3*LST_Day*" separator=comma` \
 start="2015-01-01" increment="1 months"

# in MS Windows, first create the list of maps
g.list type=raster pattern="MOD11B3*LST_Day*" output=map_list.txt
t.register -i input=LST_Day_monthly \
 file=map_list.txt start="2015-01-01" increment="1 months"
               
# Check info again
t.info input=LST_Day_monthly

# Check the list of maps in the STRDS
t.rast.list input=LST_Day_monthly

# Check min and max per map
t.rast.list input=LST_Day_monthly columns=name,min,max

 
## Let's see a graphical representation of our STRDS
g.gui.timeline inputs=LST_Day_monthly


## Temporal calculations: K*50 to Celsius 
 
# Re-scale data to degrees Celsius
t.rast.algebra basename=LST_Day_monthly_celsius suffix=gran \
  expression="LST_Day_monthly_celsius = LST_Day_monthly * 0.02 - 273.15"

# Check info
t.info LST_Day_monthly_celsius


## Time series plots

# LST time series plot for Cba city center
g.gui.tplot strds=LST_Day_monthly_celsius \
  coordinates=4323478.531282977,6541664.09350761 \
  title="Monthly LST. City center of Cordoba" \
  xlabel="Time" ylabel="LST"


## Get specific lists of maps

# Maps with minimum value lower than or equal to 10
t.rast.list input=LST_Day_monthly_celsius order=min \
 columns=name,start_time,min where="min <= '10.0'"

# Maps with maximum value higher than 30
t.rast.list input=LST_Day_monthly_celsius order=max \
 columns=name,start_time,max where="max > '30.0'"

# Maps between two given dates
t.rast.list input=LST_Day_monthly_celsius columns=name,start_time \
 where="start_time >= '2015-05' and start_time <= '2015-08-01 00:00:00'"

# Maps from January
t.rast.list input=LST_Day_monthly_celsius columns=name,start_time \
 where="strftime('%m', start_time)='01'"


## Descriptive statistics for STRDS

# Print univariate stats for maps within STRDS
t.rast.univar input=LST_Day_monthly_celsius

# Get extended statistics
t.rast.univar -e input=LST_Day_monthly_celsius

# Write the univariate stats output to a csv file
t.rast.univar input=LST_Day_monthly_celsius separator=comma \
  output=stats_LST_Day_monthly_celsius.csv


## Temporal aggregations (full series)

# Get maximum LST in the STRDS
t.rast.series input=LST_Day_monthly_celsius \
  output=LST_Day_max method=maximum

# Get minimum LST in the STRDS
t.rast.series input=LST_Day_monthly_celsius \
  output=LST_Day_min method=minimum

# Change color pallete to celsius
r.colors map=LST_Day_min,LST_Day_max color=celsius


## Temporal operations with time variables

# Get month of maximum LST
t.rast.mapcalc -n inputs=LST_Day_monthly_celsius \
  output=month_max_lst \
  expression="if(LST_Day_monthly_celsius == LST_Day_max, start_month(), null())" \
  basename=month_max_lst
 
# Get basic info
t.info month_max_lst

# Get the earliest month in which the maximum appeared (method minimum)
t.rast.series input=month_max_lst \
  method=minimum \
  output=max_lst_date

# Remove month_max_lst strds 
# we were only interested in the resulting aggregated map
t.remove -rf inputs=month_max_lst


## Display maps in a wx monitor

# Open a monitor
d.mon wx0

# Display the raster map
d.rast map=max_lst_date

# Display boundary vector map
d.vect map=provincia_cba type=boundary color=#4D4D4D width=2

# Add raster legend
d.legend -t raster=max_lst_date title="Month" \
  labelnum=6 title_fontsize=20 font=sans fontsize=16

# Add scale bar
d.barscale length=100 units=kilometers segment=4 fontsize=14

# Add North arrow
d.northarrow style=1b text_color=black

# Add text
d.text text="Month of maximum LST" \
  color=black align=cc font=sans size=12


## Temporal aggregation (granularity of three months)
 
# 3-month mean LST
t.rast.aggregate input=LST_Day_monthly_celsius \
  output=LST_Day_mean_3month \
  basename=LST_Day_mean_3month suffix=gran \
  method=average granularity="3 months"

# Check info
t.info input=LST_Day_mean_3month

# Check map list
t.rast.list input=LST_Day_mean_3month


## Display seasonal LST using frames

# Set STRDS color table to celsius degrees
t.rast.colors input=LST_Day_mean_3month color=celsius

# Start a new graphics monitor
d.mon cairo out=frames.png width=1400 height=500 resolution=4 --o

# create a first frame
d.frame -c frame=first at=0,100,0,25
d.rast map=LST_Day_mean_3month_2015_01
d.vect map=provincia_cba type=boundary color=#4D4D4D width=2
d.text text='Ene-Mar 2015' color=black font=sans size=6 bgcolor=white

# create a second frame
d.frame -c frame=second at=0,100,25,50
d.rast map=LST_Day_mean_3month_2015_04
d.vect map=provincia_cba type=boundary color=#4D4D4D width=2
d.text text='Abr-Jun 2015' color=black font=sans size=6 bgcolor=white

# create a third frame
d.frame -c frame=third at=0,100,50,75
d.rast map=LST_Day_mean_3month_2015_07
d.vect map=provincia_cba type=boundary color=#4D4D4D width=2
d.text text='Jul-Sep 2015' color=black font=sans size=6 bgcolor=white

# create a fourth frame
d.frame -c frame=fourth at=0,100,75,100
d.rast map=LST_Day_mean_3month_2015_10
d.vect map=provincia_cba type=boundary color=#4D4D4D width=2
d.text text='Oct-Dic 2015' color=black font=sans size=6 bgcolor=white

# release monitor
d.mon -r


## Time series animation

# Animation of seasonal LST
g.gui.animation strds=LST_Day_mean_3month


## Long term monthly averages (Monthly climatoligies)

# January average LST
t.rast.series input=LST_Day_monthly_celsius \
  method=average \
  where="strftime('%m', start_time)='01'" \
  output=LST_average_jan

# for all months - *nix
for MONTH in `seq -w 1 12` ; do 
 t.rast.series input=LST_Day_monthly_celsius method=average \
  where="strftime('%m', start_time)='${MONTH}'" \
  output=LST_average_${MONTH}
done

# for all months - windows
FOR %c IN (01,02,03,04,05,06,07,08,09,10,11,12) DO (
 t.rast.series input=LST_Day_monthly_celsius method=average \
  where="strftime('%m', start_time)='%c'" \
  output=LST_average_%c
)


## Anomalies

# Get general average
t.rast.series input=LST_Day_monthly_celsius \
 method=average output=LST_average

# Get general SD
t.rast.series input=LST_Day_monthly_celsius \
 method=stddev output=LST_sd

# Get annual averages
t.rast.aggregate input=LST_Day_monthly_celsius \
 method=average granularity="1 years" \
 output=LST_yearly_average basename=LST_yearly_average

# Estimate annual anomalies
t.rast.algebra basename=LST_year_anomaly \
 expression="LST_year_anomaly = (LST_yearly_average - map(LST_average)) / map(LST_sd)"

# Set difference color table
t.rast.colors input=LST_year_anomaly color=difference

# Animation of annual anomalies
g.gui.animation strds=LST_year_anomaly


## Extract zonal statistics for areas

# Install v.strds.stats add-on
g.extension extension=v.strds.stats

# List maps in seasonal time series
t.rast.list input=LST_Day_mean_3month

# Extract summer average LST for Cba urban area
v.strds.stats input=area_edificada_cba \
  strds=LST_Day_mean_3month \
  where="fna == 'Gran Córdoba'" \
  t_where="strftime('%m', start_time)='01'" \
  output=cba_summer_lst \
  method=average

# Create outside buffer - 30 km
v.buffer input=cba_summer_lst \
  distance=30000 \
  output=cba_summer_lst_buf30

# Create inside buffer - 15 km
v.buffer input=cba_summer_lst \
  distance=15000 \
  output=cba_summer_lst_buf15

# Remove 15km buffer area from the 30km buffer area
v.overlay ainput=cba_summer_lst_buf15 \
  binput=cba_summer_lst_buf30 \
  operator=xor \
  output=cba_surr

# Extract zonal stats for Cba surroundings
v.strds.stats input=cba_surr \
  strds=LST_Day_mean_3month \
  t_where="strftime('%m', start_time)='01'" \
  method=average \
  output=cba_surr_summer_lst

# Take a look at mean summer LST in Cba and surroundings
v.db.select cba_summer_lst
v.db.select cba_surr_summer_lst


