########################################################################
# Commands for the TGRASS lecture at GEOSTAT Summer School in Prague
# Author: Veronica Andreo
# Date: July - August, 2018 - Edited October, 2018
########################################################################

# Load rgrass and sf libraries
library(rgrass7)
library(sf)

# List available vectors
execGRASS("g.list", parameters = list(type="vector", mapset="."))

# Read in GRASS vector maps as sf
use_sf()
cba_summer_lst <- readVECT("cba_summer_lst")
cba_surr_summer_lst <- readVECT("cba_surr_summer_lst")

# Remove columns we don't need
cba_summer_lst <- cba_summer_lst[,-c(2:9)]
cba_surr_summer_lst <- cba_surr_summer_lst[,-c(2:3)]

# Paste the 2 vectors together
cba <- rbind(cba_summer_lst,cba_surr_summer_lst)

# Quick sf plot
plot(cba[c(2:6)], border = 'grey', axes = TRUE, key.pos = 4)


# Let's try with ggplot library
library(ggplot2)
library(dplyr)
library(tidyr)

# Arrange data from wide to long format
cba2 <-
  cba %>%
  select(LST_Day_mean_3month_2015_01_01_average,
         LST_Day_mean_3month_2016_01_01_average,
         LST_Day_mean_3month_2017_01_01_average,
         LST_Day_mean_3month_2018_01_01_average,
         LST_Day_mean_3month_2019_01_01_average,
         geom) %>%
  gather(YEAR, LST_summer, -geom)

# Replace values in YEAR column
cba2$YEAR <- rep(c(2015:2019),2)

# Plot
ggplot() +
  geom_sf(data = cba2, aes(fill = LST_summer)) +
  facet_wrap(~YEAR, ncol = 3) +
  scale_fill_distiller(palette = "YlOrRd",
                       direction = 1) +
  scale_y_continuous()


# Let's try also with tmap
library(tmap)

# Plot
tm_shape(cba2) +
  tm_polygons(col = "LST_summer", style = "cont") +
  tm_facets(by = "YEAR", nrow = 1, free.coords = FALSE)


# mapview for quick visualizations with basemaps is really cool!
library(mapview)
mapview(cba)
