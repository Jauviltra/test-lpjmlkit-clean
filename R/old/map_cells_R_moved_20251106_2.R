#!/usr/bin/env Rscript
# map_cells.R (archived copy)
# Plot selected grid cells (longitude/latitude) over Spain.

pkgs <- c('readr','sf','ggplot2','rnaturalearth','rnaturalearthdata')
missing <- pkgs[!(pkgs %in% rownames(installed.packages()))]
if(length(missing)){
  message('Installing missing packages: ', paste(missing, collapse=', '))
  install.packages(missing, repos='https://cloud.r-project.org')
}

library(readr)
library(sf)
library(ggplot2)
library(rnaturalearth)

infile <- 'cells_coords.csv'
if(!file.exists(infile)){
  stop('Coordinate file not found: ', infile, '\nPlease create a CSV named cells_coords.csv with columns: id, lon, lat')
}

df <- read_csv(infile, show_col_types = FALSE)
# normalize names
names(df) <- tolower(names(df))
if(!all(c('lon','lat') %in% names(df))){
  stop('CSV must contain lon and lat columns (case-insensitive)')
}

pts <- st_as_sf(df, coords = c('lon','lat'), crs = 4326, remove = FALSE)

spain <- ne_countries(country = 'spain', scale = 'medium', returnclass = 'sf')

dir.create('figures', showWarnings = FALSE)

p <- ggplot() +
  geom_sf(data = spain, fill = '#f0f0f0', color = '#444444') +
  geom_sf(data = pts, aes(color = as.factor(id)), size = 1.5, show.legend = FALSE) +
  coord_sf(xlim = st_bbox(spain)[c('xmin','xmax')], ylim = st_bbox(spain)[c('ymin','ymax')]) +
  theme_minimal() + labs(title = 'Selected LPJmL grid cells over Spain')

ggsave('figures/cells_map_spain.png', p, width = 7, height = 8, dpi = 150)
message('Wrote figures/cells_map_spain.png')
