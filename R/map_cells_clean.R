#!/usr/bin/env Rscript
# map_cells_clean.R -- uses pkg::function instead of library()

if (!requireNamespace("readr", quietly = TRUE)) stop("Install package 'readr'")
if (!requireNamespace("sf", quietly = TRUE)) stop("Install package 'sf'")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install package 'ggplot2'")
if (!requireNamespace("rnaturalearth", quietly = TRUE)) stop("Install package 'rnaturalearth'")
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install package 'jsonlite'")

infile <- 'cells_coords.csv'
if (!file.exists(infile)){
  stop('Coordinate file not found: ', infile, '\nPlease create a CSV named cells_coords.csv with columns: id, lon, lat')
}

df <- readr::read_csv(infile, show_col_types = FALSE)
names(df) <- tolower(names(df))
if (!all(c('lon','lat') %in% names(df))) stop('CSV must contain lon and lat columns (case-insensitive)')

# Ensure there is an `id` column for plotting; accept `index` as alternative
if (!('id' %in% names(df))) {
  if ('index' %in% names(df)) {
    df$id <- df$index
  } else {
    df$id <- seq_len(nrow(df))
  }
}

pts <- sf::st_as_sf(df, coords = c('lon','lat'), crs = 4326, remove = FALSE)

spain <- rnaturalearth::ne_countries(country = 'spain', scale = 'medium', returnclass = 'sf')

## Determine cell size: prefer local grid.bin.json if present, otherwise default to 0.5 deg
cellsize_lon <- 0.5
cellsize_lat <- 0.5
if (file.exists('grid.bin.json')){
  js <- jsonlite::fromJSON('grid.bin.json')
  if (!is.null(js$cellsize_lon)) cellsize_lon <- as.numeric(js$cellsize_lon)
  if (!is.null(js$cellsize_lat)) cellsize_lat <- as.numeric(js$cellsize_lat)
}

dir.create('figures', showWarnings = FALSE)

# Build polygon (square) for each cell using lon/lat center and cell sizes
half_w <- cellsize_lon / 2
half_h <- cellsize_lat / 2
polys <- lapply(seq_len(nrow(df)), function(i){
  x <- df$lon[i]; y <- df$lat[i]
  mat <- matrix(c(
    x - half_w, y - half_h,
    x + half_w, y - half_h,
    x + half_w, y + half_h,
    x - half_w, y + half_h,
    x - half_w, y - half_h
  ), ncol = 2, byrow = TRUE)
  list(mat)
})

# Each polygon must be a list of linear rings (matrix), so wrap matrices in a list
sfc <- sf::st_sfc(lapply(polys, function(rings) sf::st_polygon(rings)), crs = 4326)
cells_sf <- sf::st_sf(df, geometry = sfc)

p <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = spain, fill = '#f0f0f0', color = '#444444') +
  ggplot2::geom_sf(data = cells_sf, mapping = ggplot2::aes(fill = as.factor(id)), color = NA, show.legend = FALSE) +
  ggplot2::coord_sf(xlim = sf::st_bbox(spain)[c('xmin','xmax')], ylim = sf::st_bbox(spain)[c('ymin','ymax')]) +
  ggplot2::theme_minimal() + ggplot2::labs(title = 'Selected LPJmL grid cells over Spain')

ggplot2::ggsave('figures/cells_map_spain.png', p, width = 7, height = 8, dpi = 150)
message('Wrote figures/cells_map_spain.png (cells as polygons)')
