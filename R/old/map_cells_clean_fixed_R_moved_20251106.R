#!/usr/bin/env Rscript
# map_cells_clean.R -- uses pkg::function instead of library()

if (!requireNamespace("readr", quietly = TRUE)) stop("Install package 'readr'")
if (!requireNamespace("sf", quietly = TRUE)) stop("Install package 'sf'")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install package 'ggplot2'")
if (!requireNamespace("rnaturalearth", quietly = TRUE)) stop("Install package 'rnaturalearth'")

## logging helper: prefer cli if available
log_info <- function(...) {
  txt <- paste(..., collapse = " ")
  if (requireNamespace("cli", quietly = TRUE)) cli::cli_alert_info(txt) else message(txt)
}

infile <- 'cells_coords.csv'
if (!file.exists(infile)){
  stop('Coordinate file not found: ', infile, '\nPlease create a CSV named cells_coords.csv with columns: id, lon, lat')
}

df <- readr::read_csv(infile, show_col_types = FALSE)
names(df) <- tolower(names(df))
if (!all(c('lon','lat') %in% names(df))) stop('CSV must contain lon and lat columns (case-insensitive)')

pts <- sf::st_as_sf(df, coords = c('lon','lat'), crs = 4326, remove = FALSE)

spain <- rnaturalearth::ne_countries(country = 'spain', scale = 'medium', returnclass = 'sf')

dir.create('figures', showWarnings = FALSE)

p <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = spain, fill = '#f0f0f0', color = '#444444') +
  ggplot2::geom_sf(data = pts, ggplot2::aes(color = as.factor(id)), size = 1.5, show.legend = FALSE) +
  ggplot2::coord_sf(xlim = sf::st_bbox(spain)[c('xmin','xmax')], ylim = sf::st_bbox(spain)[c('ymin','ymax')]) +
  ggplot2::theme_minimal() + ggplot2::labs(title = 'Selected LPJmL grid cells over Spain')

ggplot2::ggsave('figures/cells_map_spain.png', p, width = 7, height = 8, dpi = 150)
log_info('Wrote figures/cells_map_spain.png')
