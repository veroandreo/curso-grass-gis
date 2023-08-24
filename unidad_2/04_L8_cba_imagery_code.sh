#!/bin/bash

########################################################################
# Worflow for Landsat 8 data processing in GRASS GIS
# GRASS GIS online workshop
# Author: Veronica Andreo
# February, 2021
########################################################################


#
# Launch GRASS and settings
#


# start grass in Cordoba location
grass78 grassdata/posgar2007_4_cba/PERMANENT

# check the projection of the location
g.proj -p

# Create a new mapset
g.mapset -c mapset=landsat8

# list all the mapsets in the search path
g.mapsets -p

# list vector maps in all mapsets in the search path
g.list type=vector

# extract Cordoba urban area from `radios_urbanos`
v.extract input=radios_urbanos \
  where="nombre == 'CORDOBA'" \
  output=radio_urbano_cba

# set the computational region to the extent of
# Cordoba urban area
g.region -p vector=radio_urbano_cba


#
# Search, download and import L8 data
#


# install i.landsat toolset
g.extension extension=i.landsat

# search for Landsat 8 scenes
i.landsat.download -l settings=$HOME/gisdata/USGS_SETTING.txt \
  dataset=landsat_8_c1 clouds=35 \
  start='2019-10-27' end='2020-03-15'

# download selected scenes
i.landsat.download settings=$HOME/gisdata/USGS_SETTING.txt \
  id=LC82290822020062LGN00,LC82290822020014LGN00 \
  output=$HOME/gisdata/landsat_data

# print all landsat bands within landsat_data folder
i.landsat.import -p input=$HOME/gisdata/landsat_data

# print a selection of bands - might be sloooow
i.landsat.import -p \
  input=$HOME/gisdata/landsat_data \
  pattern='B(2|3|4|5|6|8)'

# import all bands, subset to region and reproject
i.landsat.import -r \
  input=$HOME/gisdata/landsat_data \
  extent=region

# list raster maps
g.list type=raster mapset=.

# check metadata of some imported bands
r.info map=LC08_L1TP_229082_20200114_20200127_01_T1_B4
r.info map=LC08_L1TP_229082_20200114_20200127_01_T1_B8


#
# DN to surface reflectance (Atmospheric correction through DOS)
#


# set the region to a 30m band
g.region -p raster=LC08_L1TP_229082_20200114_20200127_01_T1_B4

# convert from DN to surface reflectance and temperature - requires to uncompress data locally
i.landsat.toar \
  input=LC08_L1TP_229082_20200114_20200127_01_T1_B \
  output=LC08_229082_20200114_toar_B \
  sensor=oli8 \
  metfile=$HOME/gisdata/landsat_data/LC08_L1TP_229082_20200114_20200127_01_T1_MTL.txt \
  method=dos1

# list output maps
g.list type=raster mapset=. pattern="*toar*"

# check info before and after for one band
r.info map=LC08_L1TP_229082_20200114_20200127_01_T1_B3
r.info map=LC08_229082_20200114_toar_B3


#
# Color enhancements and RGB compositions
#


# enhance the colors
i.colors.enhance \
  red=LC08_229082_20200114_toar_B4 \
  green=LC08_229082_20200114_toar_B3 \
  blue=LC08_229082_20200114_toar_B2 \
  strength=95

# display RGB
d.mon wx0
d.rgb \
  red=LC08_229082_20200114_toar_B4 \
  green=LC08_229082_20200114_toar_B3 \
  blue=LC08_229082_20200114_toar_B2


#
# Cloud mask from the QA layer
#


# create a rule set
i.landsat.qa \
  collection=1 \
  cloud_shadow_confidence="Medium,High" \
  cloud_confidence="Medium,High" \
  output=Cloud_Mask_rules.txt

# reclass the BQA band based on the rule set created
r.reclass \
  input=LC08_L1TP_229082_20200114_20200127_01_T1_BQA \
  output=LC08_229082_20200114_Cloud_Mask \
  rules=Cloud_Mask_rules.txt

# report % of clouds and shadows
r.report -e map=LC08_229082_20200114_Cloud_Mask units=p

# display reclassified map over RGB
d.mon wx0
d.rgb \
  red=LC08_229082_20200114_toar_B4 \
  green=LC08_229082_20200114_toar_B3 \
  blue=LC08_229082_20200114_toar_B2
d.rast LC08_229082_20200114_Cloud_Mask


#
# Pansharpening
#


# Install the reqquired addon
g.extension extension=i.fusion.hpf

# Set the region to PAN band (15m)
g.region -p raster=LC08_229082_20200114_toar_B8

# Apply the fusion based on high pass filter
i.fusion.hpf -l -c pan=LC08_229082_20200114_toar_B8 \
  msx=`g.list type=raster mapset=. pattern=*_toar_B[1-7] separator=,` \
  suffix=_hpf \
  center=high \
  modulation=max \
  trim=0.0

# list the fused maps
g.list type=raster mapset=. pattern=*_hpf

# display original and fused maps
g.gui.mapswipe \
  first=LC08_229082_20200114_toar_B5 \
  second=LC08_229082_20200114_toar_B5_hpf


#
# Vegetation and Water Indices
#


# Set the cloud mask to avoid computing over clouds
r.mask raster=LC08_229082_20200114_Cloud_Mask

# Compute NDVI
r.mapcalc \
  expression="LC08_229082_20200114_NDVI = \
  (LC08_229082_20200114_toar_B5_hpf - LC08_229082_20200114_toar_B4_hpf) / \
  (LC08_229082_20200114_toar_B5_hpf + LC08_229082_20200114_toar_B4_hpf) * 1.0"
# Set the color palette
r.colors map=LC08_229082_20200114_NDVI color=ndvi

# Compute NDWI
r.mapcalc expression="LC08_229082_20200114_NDWI = \
  (LC08_229082_20200114_toar_B5_hpf - LC08_229082_20200114_toar_B6_hpf) / \
  (LC08_229082_20200114_toar_B5_hpf + LC08_229082_20200114_toar_B6_hpf) * 1.0"
# Set the color palette
r.colors map=LC08_229082_20200114_NDWI color=ndwi

# display maps in different monitors
d.mon wx0
d.rast map=LC08_229082_20200114_NDVI

d.mon wx1
d.rast map=LC08_229082_20200114_NDWI


#
# Unsupervised Classification
#


# list the bands needed for classification
g.list type=raster mapset=. pattern=*_toar*_hpf

# add maps to an imagery group for easier management
i.group group=l8 subgroup=l8 \
 input=`g.list type=raster mapset=. pattern=*_toar*_hpf sep=","`

# statistics for unsupervised classification
i.cluster group=l8 subgroup=l8 \
 sig=l8_hpf \
 classes=7 \
 separation=0.6

# Maximum Likelihood unsupervised classification
i.maxlik group=l8 subgroup=l8 \
 sig=l8_hpf \
 output=l8_hpf_class \
 rej=l8_hpf_rej

# display results
d.mon wx0
d.rast map=l8_hpf_class



