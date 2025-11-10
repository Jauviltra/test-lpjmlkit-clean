#!/usr/bin/env Rscript
# Simple fallback map: scatter of cell centers using ggplot2 only
if (!requireNamespace("readr", quietly = TRUE)) stop("Install 'readr'")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install 'ggplot2'")

df <- readr::read_csv('cells_coords.csv', show_col_types = FALSE)
names(df) <- tolower(names(df))
if (!('lon' %in% names(df) && 'lat' %in% names(df))) stop('cells_coords.csv must have lon and lat')

dir.create('figures', showWarnings = FALSE)
library(ggplot2)

p <- ggplot(df, aes(x = lon, y = lat)) +
  geom_point(size = 1.5, color = '#2b83ba') +
  theme_minimal() +
  labs(title = 'LPJmL selected cells (fallback scatter)') +
  coord_quickmap()

ggsave('figures/cells_map_spain_simple.png', p, width = 7, height = 6, dpi = 150)
message('Wrote figures/cells_map_spain_simple.png')
