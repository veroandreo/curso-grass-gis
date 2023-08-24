#!/bin/bash

########################################################################
# Commands for the OBIA exercise within IG MSc Course Image Processing
# Author: Veronica Andreo based on Grippa et al 2017.
# Date: July, 2020
########################################################################


#
# Create mapset and import data
#


# create mapset
g.mapset -c mapset=obia_spot

# import pansharpened SPOT data
r.import input=$HOME/gisdata/SPOT_20180621_PANSHARP_p.tif \
  output=SPOT_20180621_PANSHARP \
  resolution=value \
  resolution_value=1.5

# import SPOT PAN band
r.import input=$HOME/gisdata/SPOT_20180621_PAN.tif \
  output=SPOT_20180621_PAN \
  resolution=value \
  resolution_value=1.5

# align region to one of the raster bands
g.region -p raster=SPOT_20180621_PANSHARP.1 \
  save=obia_full


#
# Display RGB with enhanced contrast
#


# set grey color table to RGB bands
r.colors \
  map=SPOT_20180621_PANSHARP.1,SPOT_20180621_PANSHARP.2,SPOT_20180621_PANSHARP.3 \
  color=grey

# display RGB
d.mon wx0
d.rgb red=SPOT_20180621_PANSHARP.3 \
  green=SPOT_20180621_PANSHARP.2 \
  blue=SPOT_20180621_PANSHARP.1

# enhance contrast
i.colors.enhance red=SPOT_20180621_PANSHARP.3 \
  green=SPOT_20180621_PANSHARP.2 \
  blue=SPOT_20180621_PANSHARP.1 \
  strength=95


#
# Are there NULL values?
#


# one band
r.univar map=SPOT_20180621_PANSHARP.2

# joint stats for all the bands
r.univar \
  map=SPOT_20180621_PANSHARP.1,SPOT_20180621_PANSHARP.2,SPOT_20180621_PANSHARP.3,SPOT_20180621_PANSHARP.4


#
# Generate variables from raw data
#


# estimate vegetation index
i.vi \
  output=SPOT_20180621_NDVI \
  viname=ndvi \
  red=SPOT_20180621_PANSHARP.3 \
  nir=SPOT_20180621_PANSHARP.4

# install i.wi
g.extension i.wi

# estimate water index
i.wi \
  output=SPOT_20180621_NDWI \
  winame=ndwi_mf \
  green=SPOT_20180621_PANSHARP.2 \
  nir=SPOT_20180621_PANSHARP.4

# set ndwi color palette
r.colors map=SPOT_20180621_NDWI color=ndwi

# estimate textures measures
r.texture \
  input=SPOT_20180621_PAN \
  output=SPOT_20180621 \
  size=7 \
  distance=3 \
  method=idm,asm

# set color table to grey for texture bands
r.colors -e map=SPOT_20180621_IDM color=grey
r.colors -e map=SPOT_20180621_ASM color=grey

# frame plot with all 4 bands
d.mon cairo out=obia_frames.png width=400 height=300 resolution=4

d.frame -c frame=first at=0,50,0,50
d.rast map=SPOT_20180621_NDVI
d.text text='NDVI' color=black font=sans size=10

d.frame -c frame=second at=0,50,50,100
d.rast map=SPOT_20180621_NDWI
d.text text='NDWI' color=black font=sans size=10

d.frame -c frame=third at=50,100,0,50
d.rast map=SPOT_20180621_IDM
d.text text='IDM' color=white font=sans size=10

d.frame -c frame=fourth at=50,100,50,100
d.rast map=SPOT_20180621_ASM
d.text text='ASM' color=white font=sans size=10

d.mon -r


#
# Segmentation: manual trial and error for threshold values determination
#


# create imagery group (only bands)
i.group group=spot_bands \
  input=SPOT_20180621_PANSHARP.1,SPOT_20180621_PANSHARP.2,SPOT_20180621_PANSHARP.3,SPOT_20180621_PANSHARP.4

# set smaller region
g.region -p \
  n=6525171 s=6523179 \
  w=4390557 e=4393257 \
  save=obia_subset

# run segmentation - small threshold
i.segment \
  group=spot_bands \
  output=segment_001\
  threshold=0.01 \
  memory=2000
# convert output to vector
r.to.vect -tv input=segment_001 \
  output=segment_001 \
  type=area

# run segmentation - larger threshold
i.segment \
  group=spot_bands \
  output=segment_005 \
  threshold=0.05 \
  memory=2000
# convert output to vector
r.to.vect -tv \
  input=segment_005 \
  output=segment_005 \
  type=area


#
# Superpixels
#


# install i.superpixels.slic
g.extension i.superpixels.slic

# run superpixel segm to use as seeds
i.superpixels.slic \
  input=spot_bands \
  output=superpixels \
  step=2 \
  compactness=0.7 \
  memory=2000


#
# Segmentation with USPO
#


# install extensions
g.extension r.neighborhoodmatrix
g.extension i.segment.uspo

# run segmentation with uspo
i.segment.uspo group=spot_bands \
  output=uspo_parameters.csv \
  region=obia_subset \
  seeds=superpixels \
  segment_map=segs \
  threshold_start=0.005 \
  threshold_stop=0.05 \
  threshold_step=0.005 \
  minsizes=3 number_best=5 \
  memory=2000 processes=4

# convert to vector the rank1
r.to.vect -tv \
  input=segs_obia_subset_rank1 \
  output=segs \
  type=area


#
# Extraer estadisticas de los segmentos
#


# install extensions
g.extension i.segment.stats
g.extension r.object.geometry

# extract stats for segments
i.segment.stats \
  map=segs_obia_subset_rank1 \
  rasters=SPOT_20180621_ASM,SPOT_20180621_IDM,SPOT_20180621_NDVI,SPOT_20180621_NDWI,SPOT_20180621_PAN \
  raster_statistics=mean,stddev \
  area_measures=area,perimeter,compact_circle,compact_square \
  vectormap=segs_stats \
  processes=4


#
# Generate ground truth points and label them
#


# get info of labeled points
v.info labeled_points

# copy vector to current mapset (access to tables from different mapsets is not allowed)
g.copy vector=labeled_points@PERMANENT,labeled_points

# get number of points per class
db.select \
  sql="SELECT train_class,COUNT(cat) as count_class
       FROM labeled_points
       GROUP BY train_class"

# select segments that are below labeled points
v.select \
  ainput=segs_stats \
  binput=labeled_points \
  output=train_segments \
  operator=overlap

# get info of segments
v.info train_segments

# add column to train segments
v.db.addcolumn train_segments \
  column="class int"

# assign label from points to segments
v.distance from=train_segments \
  to=labeled_points \
  upload=to_attr \
  column=class \
  to_column=train_class

# group training segments per class
db.select \
  sql="SELECT class,COUNT(cat) as count_class
       FROM train_segments
       GROUP BY class"


#
# Classification with Machine Learning
#


# install extension
g.extension v.class.mlR

# run classification
v.class.mlR -nf \
  segments_map=segs_stats \
  training_map=train_segments \
  train_class_column=class \
  output_class_column=class_rf \
  classified_map=classification \
  raster_segments_map=segs_obia_subset_rank1 \
  classifier=rf \
  folds=5 partitions=10 tunelength=10 \
  weighting_modes=smv \
  weighting_metric=accuracy \
  output_model_file=model \
  variable_importance_file=var_imp.txt \
  accuracy_file=accuracy.csv \
  classification_results=all_results.csv \
  model_details=classifier_runs.txt \
  r_script_file=Rscript_mlR.R \
  processes=4

# set color table that we created interactively
r.colors \
  map=classification_rf \
  rules=obia_urban


#
# Validation using a new set of data
#


# convert labeled test segments to raster
v.to.rast map=testing \
  use=attr \
  attribute_column=class \
  output=testing

# create confusion matrix and estimate precision measures
r.kappa \
  classification=classification_rf \
  reference=testing


#
# Alternatively...
#


## Open RStudio from within GRASS terminal ##

# load libraries
library(rgrass7)
library(dplyr)

# load vector from GRASS
use_sf()
v <- readVECT("labeled_points")

# test dataset
test <- v %>%
        group_by(train_class) %>%
        sample_frac(.3)

table(test$train_class)

# training dataset
train <- v[!v$cat %in% test$cat,]

# write back into GRASS
writeVECT(test, "test")
writeVECT(train, "train")


#
# Run classification with the train subset
#


# repeat steps described above within GRASS


#
# Validation
#


# add column to test point map
v.db.addcolumn map=test \
  column="pred_class integer"

# query the classified map
v.what.rast map=test \
  column=pred_class \
  raster=classification_rf


#
# Confusion matrix and evaluation metrics in R
#


# read the test vector
test_complete <- readVECT("test")

# confusion matrix and evaluation stats
library(caret)
rf_CM <- confusionMatrix(as.factor(test_complete$pred_class),
                         as.factor(test_complete$train_class))
print(rf_CM)

