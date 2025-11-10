#!/usr/bin/env Rscript
# analysis_plots.R (improved)
# Read LPJmL globalflux CSV and produce time-series PNGs for
# Carbon (NEP, NBP), Water (transp, evap) and Nitrogen (nuptake, nlosses, ninflux).

pkgs <- c('readr','dplyr','tidyr','ggplot2')
missing <- pkgs[!(pkgs %in% rownames(installed.packages()))]
if(length(missing)){
  message('Installing missing packages: ', paste(missing, collapse=', '))
  install.packages(missing, repos='https://cloud.r-project.org')
}

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

infile <- 'spain_sim/output/spain_test/globalflux_spinup.csv'
if(!file.exists(infile)) stop('Input CSV not found: ', infile)

df <- read_csv(infile, comment = '#', show_col_types = FALSE)
message('Read ', nrow(df), ' rows and ', ncol(df), ' columns from ', infile)

# Normalize column names to simple lower-case names for selection
names(df) <- make.names(names(df), unique = TRUE)
names(df) <- tolower(names(df))

if(!('year' %in% names(df))) stop('No Year column found (expected "Year") in ', infile)

# Remove any rows where year is NA or non-numeric (sometimes units row present)
df <- df %>% mutate(year = suppressWarnings(as.integer(as.numeric(year)))) %>% filter(!is.na(year))

# Quick sanity print
message('Years in data: ', paste(range(df$year), collapse = ' - '))
message('Columns available: ', paste(names(df), collapse = ', '))

dir.create('figures', showWarnings = FALSE)

save_plot <- function(p, filename){
  ggsave(filename, p, width = 8, height = 4.5, dpi = 150)
  message('Wrote ', filename)
}

# Utility: pivot selected columns and plot
plot_vars <- function(df, vars, ylab, outname){
  vars <- intersect(vars, names(df))
  if(length(vars) == 0){
    message('No variables found for ', outname)
    return(invisible(NULL))
  }
  long <- df %>% select(year, all_of(vars)) %>% pivot_longer(cols = -year, names_to = 'variable', values_to = 'value')
  # ensure numeric
  long <- long %>% mutate(value = as.numeric(value))
  p <- ggplot(long, aes(x = year, y = value, color = variable)) +
    geom_line(aes(group = variable)) +
    geom_point(size = 1) +
    theme_minimal() +
    labs(x = 'Year', y = ylab, title = outname)
  save_plot(p, file.path('figures', outname))
}

# Carbon
plot_vars(df, c('nep','nbp'), 'Flux (model units)', 'globalflux_carbon_nep_nbp.png')

# Water
plot_vars(df, c('transp','evap'), 'Water (model units)', 'globalflux_water_transp_evap.png')

# Nitrogen
plot_vars(df, c('nuptake','nlosses','ninflux'), 'N (model units)', 'globalflux_nitrogen.png')

message('Analysis complete. Figures are in ./figures/')
