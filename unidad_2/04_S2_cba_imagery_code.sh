#!/bin/bash

########################################################################
# Worflow for Sentinel 2 data processing in GRASS GIS
# GRASS GIS online workshop
# Author: Veronica Andreo
# February, 2021
########################################################################


#
# Launch GRASS and settings
#


# start grass in Cordoba location
grass78 grassdata/posgar2007_4_cba/PERMANENT

# Create a new mapset
g.mapset -c mapset=sentinel2

# set the computational region to the extent of
# Cordoba urban area
g.region -p vector=radio_urbano_cba


#
# Search, download and import S2 data
#


# install i.sentinel extension
g.extension extension=i.sentinel

# explore list of scenes for a certain date range
i.sentinel.download -l \
  settings=$HOME/gisdata/SENTINEL_SETTING.txt \
  start="2020-03-01" \
  end="2020-04-30" \
  producttype=S2MSI2A \
  clouds=30

# filter list of scenes by area_relation=Contains
i.sentinel.download -l \
  settings=$HOME/gisdata/SENTINEL_SETTING.txt \
  start="2020-03-01" \
  end="2020-04-30" \
  producttype=S2MSI2A \
  clouds=30 \
  area_relation=Contains

# download the scene that fully contains our region
i.sentinel.download \
  settings=$HOME/gisdata/SENTINEL_SETTING.txt \
  uuid=9a1ea49c-0561-4aa5-ba7a-dc820dc1a316 \
  output=$HOME/gisdata/s2_data
# DO NOT RUN NOW! :)

# print bands info before importing
# (1 -proj match, 0 -no proj match)
i.sentinel.import -p input=$HOME/gisdata/s2_data

# import bands relevant for RGB, NDVI and NDWI
i.sentinel.import -rc \
  input=$HOME/gisdata/s2_data \
  pattern='B(02_1|03_1|04_1|08_1|8A_2|11_2|12_2)0m' \
  extent=region

# list raster maps
g.list type=raster mapset=.

# check metadata of some imported bands
r.info map=T20JLL_20200330T141049_B03_10m
r.info map=T20JLL_20200330T141049_B8A_20m


#
# Color balance and RGB composition
#


# apply grey color to RGB bands
r.colors map=T20JLL_20200330T141049_B04_10m,T20JLL_20200330T141049_B03_10m,T20JLL_20200330T141049_B02_10m \
  color=grey

# perform color auto-balancing for RGB bands
i.colors.enhance \
  red=T20JLL_20200330T141049_B04_10m \
  green=T20JLL_20200330T141049_B03_10m \
  blue=T20JLL_20200330T141049_B02_10m \
  strength=95

# display the enhanced RGB combination
d.mon wx0
d.rgb -n \
  red=T20JLL_20200330T141049_B04_10m \
  green=T20JLL_20200330T141049_B03_10m \
  blue=T20JLL_20200330T141049_B02_10m


#
# Identify and mask clouds and cloud shadows
#


# identify and mask clouds and clouds shadows: i.sentinel.mask
i.sentinel.mask -s --o \
  blue=T20JLL_20200330T141049_B02_10m \
  green=T20JLL_20200330T141049_B03_10m \
  red=T20JLL_20200330T141049_B04_10m \
  nir=T20JLL_20200330T141049_B08_10m \
  nir8a=T20JLL_20200330T141049_B8A_20m \
  swir11=T20JLL_20200330T141049_B11_20m \
  swir12=T20JLL_20200330T141049_B12_20m \
  cloud_mask=cloud \
  shadow_mask=shadow \
  scale_fac=10000 \
  mtd=$HOME/gisdata/s2_data/S2B_MSIL2A_20200330T141049_N0214_R110_T20JLL_20200330T182252.SAFE/GRANULE/L2A_T20JLL_A016009_20200330T141532/MTD_TL.xml

# display output
d.mon wx0
d.rgb \
  red=T20JLL_20200330T141049_B04_10m \
  green=T20JLL_20200330T141049_B03_10m \
  blue=T20JLL_20200330T141049_B02_10m
d.vect map=cloud fill_color=red
d.vect map=shadow fill_color=blue


#
# Estimate vegetation and water indices
#


# set region
g.region -p raster=T20JLL_20200330T141049_B08_10m

# set clouds mask
v.patch input=cloud,shadow \
 output=cloud_shadow_mask
r.mask -i vector=cloud_shadow_mask

# estimate vegetation indices
i.vi \
  red=T20JLL_20200330T141049_B04_10m \
  nir=T20JLL_20200330T141049_B08_10m \
  output=T20JLL_20200330T141049_NDVI_10m \
  viname=ndvi
 
# install extension
g.extension extension=i.wi

# estimate water indices and set color palette
i.wi \
  green=T20JLL_20200330T141049_B03_10m \
  nir=T20JLL_20200330T141049_B08_10m \
  output=T20JLL_20200330T141049_NDWI_10m \
  winame=ndwi_mf
r.colors map=T20JLL_20200330T141049_NDWI_10m \
  color=ndwi


#
# Image segmentation
#


# install extension
g.extension extension=i.superpixels.slic

# list maps
g.list type=raster pattern="*20200330T141049*" \
  mapset=. output=list.txt

# create groups and subgroups
i.group group=s2 subgroup=s2 file=list.txt

# run i.superpixels.slic
i.superpixels.slic input=s2 \
  output=superpixels \
  num_pixels=2000

# convert the resulting raster to vector
r.to.vect input=superpixels \
  output=superpixels type=area

# run i.segment
i.segment group=s2 output=segments \
  threshold=0.5 minsize=50 memory=500

# convert the resulting raster to vector
r.to.vect input=segments \
  output=segments type=area

# display NDVI along with the 2 segmentation outputs
d.mon wx0
d.rast map=T20JLL_20200330T141049_NDVI_10m
d.vect map=superpixels color=yellow fill_color=none
d.vect map=segments color=red fill_color=none


#
# Image classification: Maximum Likelihood
#


# convert to raster
v.to.rast input=training output=training \
  use=cat label_column=class

# obtain signature files
i.gensig trainingmap=training \
  group=s2 subgroup=s2 \
  signaturefile=sig_sentinel

# perform ML supervised classification
i.maxlik group=s2 subgroup=s2 \
  signaturefile=sig_sentinel \
  output=sentinel_maxlik

# label classes
r.category sentinel_maxlik separator=":" rules=- << EOF
1:vegetation
2:urban
3:bare soil
EOF


#
# Image classification: Machine Learning
#


# install extension
g.extension extension=r.learn.ml

# perform random forest classification
r.learn.ml trainingmap=training group=s2 \
  output=sentinel_rf n_estimators=300

# label classes
r.category sentinel_rf separator=":" rules=- << EOF
1:vegetation
2:urban
3:bare soil
EOF


