#!/usr/bin/env Rscript
# analysis_plots_clean.R -- uses pkg::function instead of library()

if (!requireNamespace("readr", quietly = TRUE)) stop("Install package 'readr'")
if (!requireNamespace("tidyr", quietly = TRUE)) stop("Install package 'tidyr'")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install package 'ggplot2'")

## logging helper: prefer cli if available
log_info <- function(...) {
  txt <- paste(..., collapse = " ")
  if (requireNamespace("cli", quietly = TRUE)) cli::cli_alert_info(txt) else message(txt)
}

infile <- 'spain_sim/output/spain_test/globalflux_spinup.csv'
if (!file.exists(infile)) stop('Input CSV not found: ', infile)

# read data
df <- readr::read_csv(infile, comment = '#', show_col_types = FALSE)
log_info('Read', nrow(df), 'rows and', ncol(df), 'columns from', infile)

# Normalize column names to simple lower-case names for selection
names(df) <- make.names(names(df), unique = TRUE)
names(df) <- tolower(names(df))

if (!('year' %in% names(df))) stop('No Year column found (expected "Year") in ', infile)

# Remove any rows where year is NA or non-numeric
df$year <- suppressWarnings(as.integer(as.numeric(df$year)))
df <- df[!is.na(df$year), , drop = FALSE]

log_info('Years in data:', paste(range(df$year), collapse = ' - '))
log_info('Columns available:', paste(names(df), collapse = ', '))

dir.create('figures', showWarnings = FALSE)

save_plot <- function(p, filename){
  ggplot2::ggsave(filename, p, width = 8, height = 4.5, dpi = 150)
  log_info('Wrote', filename)
}

plot_vars <- function(df, vars, ylab, outname){
  vars <- intersect(vars, names(df))
  if (length(vars) == 0){
    log_info('No variables found for', outname)
    return(invisible(NULL))
  }
  wide_cols <- c('year', vars)
  long <- tidyr::pivot_longer(df[, wide_cols, drop = FALSE], cols = -year,
                              names_to = 'variable', values_to = 'value')
  long$value <- as.numeric(long$value)
  p <- ggplot2::ggplot(long, ggplot2::aes(x = year, y = value, color = variable)) +
    ggplot2::geom_line(ggplot2::aes(group = variable)) +
    ggplot2::geom_point(size = 1) +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = 'Year', y = ylab, title = outname)
  save_plot(p, file.path('figures', outname))
}

# Carbon
plot_vars(df, c('nep','nbp'), 'Flux (model units)', 'globalflux_carbon_nep_nbp.png')
# Water
plot_vars(df, c('transp','evap'), 'Water (model units)', 'globalflux_water_transp_evap.png')
# Nitrogen
plot_vars(df, c('nuptake','nlosses','ninflux'), 'N (model units)', 'globalflux_nitrogen.png')

log_info('Analysis complete. Figures are in ./figures/')
