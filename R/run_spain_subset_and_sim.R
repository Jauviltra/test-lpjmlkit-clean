#!/usr/bin/env Rscript
# Run full Spain subset and LPJmL simulation (spinup + scenario)
# - saves a config JSON under config/spain_subset_config.json
# - calls prepare_subset() with bbox and method='overlap'
# - writes LPJmL configs and runs LPJmL via lpjmlkit

if (!requireNamespace('jsonlite', quietly=TRUE)) stop('Install jsonlite')
if (!requireNamespace('readr', quietly=TRUE)) stop('Install readr')

# parameters (editable)
bbox <- '-9.5,36.0,3.5,44.5'
method <- 'overlap'
use_cores <- 4
first_year <- 1901
last_year <- 1910

model_path <- '/home/jvt/LPJmL'
sim_path <- file.path(model_path, 'simulation')

# gridbin path (adjust if your grid.bin is elsewhere)
# Prefer a repo-local `inputs/grid.bin` when present to make runs reproducible.
# Allow overriding `gridbin`/`grid_json` from the environment or caller by
# only assigning defaults when they don't already exist.
repo_grid <- file.path(getwd(), 'inputs', 'grid.bin')
repo_grid_json <- paste0(repo_grid, '.json')
if (!exists('gridbin')) {
  if (file.exists(repo_grid)) {
    gridbin <- repo_grid
  } else {
    # fallback to the legacy path used previously (update if you keep a different location)
    gridbin <- '/home/jvt/old_repos/test-lpjmlkit.bak_1761638288/lpjm_inputs_spain/grid.bin'
  }
}
if (!exists('grid_json')) {
  # Prefer explicit repo json if available, otherwise use gridbin.json when present
  if (file.exists(repo_grid_json)) {
    grid_json <- repo_grid_json
  } else if (file.exists(paste0(gridbin, '.json'))) {
    grid_json <- paste0(gridbin, '.json')
  } else {
    grid_json <- NULL
  }
}

# create config dir and save parameters
cfg_dir <- file.path(getwd(), 'config')
dir.create(cfg_dir, recursive = TRUE, showWarnings = FALSE)
cfg <- list(bbox = bbox, method = method, use_cores = use_cores, first_year = first_year, last_year = last_year, gridbin = gridbin, grid_json = grid_json, model_path = model_path, sim_path = sim_path)
jsonlite::write_json(cfg, file.path(cfg_dir, 'spain_subset_config.json'), auto_unbox = TRUE, pretty = TRUE)
cat('Wrote config to', file.path(cfg_dir, 'spain_subset_config.json'), '\n')

# source prepare_subset function
prep_path <- file.path(getwd(), 'R', 'prepare_subset.R')
if (!file.exists(prep_path)) stop('prepare_subset.R not found at ', prep_path)
source(prep_path)

out_dir <- '/tmp/test-lpjmlkit-smoke/outputs'
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
res <- prepare_subset(gridbin = gridbin, grid_json = grid_json, out_dir = out_dir, out_basename = 'spain_subset', indices = NULL, bbox = bbox, method = method)
cat('prepare_subset results:\n')
print(res)

# read produced csv and determine start/end indices
# `prepare_subset()` returns a list(list(csv=..., txt=..., header=...))
# but older code assumed it returned a single path. Handle both cases.
if (is.list(res) && !is.null(res$csv)) {
  csvf <- res$csv
} else if (is.character(res) && length(res) == 1) {
  csvf <- res
} else {
  stop('Unexpected return value from prepare_subset(): ', class(res))
}
if (!file.exists(csvf)) stop('Expected CSV not found: ', csvf)
df <- readr::read_csv(csvf, show_col_types = FALSE)
cn <- tolower(names(df))
if ('index' %in% cn) {
  idx_col <- df[[which(cn == 'index')]]
} else if ('id' %in% cn) {
  idx_col <- df[[which(cn == 'id')]]
} else if ('cell_id' %in% cn) {
  idx_col <- df[[which(cn == 'cell_id')]]
} else {
  # fallback: try first column
  idx_col <- df[[1]]
}
startgrid <- min(idx_col, na.rm = TRUE)
endgrid <- max(idx_col, na.rm = TRUE)
cat('Selected grid indices:', startgrid, 'to', endgrid, '\n')

# prepare LPJmL configs using lpjmlkit
if (!requireNamespace('lpjmlkit', quietly = TRUE)) stop('Install lpjmlkit')
if (!requireNamespace('tibble', quietly = TRUE)) stop('Install tibble')

# spinup params
spinup_params <- tibble::tibble(
  sim_name = 'spinup',
  inpath = file.path(model_path, 'inputs'),
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  nspinup = 2,
  firstyear = first_year,
  lastyear = first_year
)
spinup_cfg <- lpjmlkit::write_config(x = spinup_params, model_path = model_path, sim_path = sim_path, debug = TRUE)

# simulation params
simulation_params <- tibble::tibble(
  sim_name = 'scenario_1',
  inpath = file.path(model_path, 'inputs'),
  `-DFROM_RESTART` = TRUE,
  restart_filename = 'restart/spinup/restart.lpj',
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  nspinup = 0,
  firstyear = first_year,
  lastyear = last_year
)
sim_cfg <- lpjmlkit::write_config(x = simulation_params, model_path = model_path, sim_path = sim_path, debug = TRUE)

# run LPJmL: spinup then simulation
run_cmd <- sprintf('mpirun -np %d ', use_cores)
cat('Running spinup with command:', run_cmd, '\n')
spinup_run <- lpjmlkit::run_lpjml(spinup_cfg, model_path, sim_path, run_cmd = run_cmd)
cat('Spinup run output:\n')
print(spinup_run)

cat('Running simulation with command:', run_cmd, '\n')
sim_run <- lpjmlkit::run_lpjml(sim_cfg, model_path, sim_path, run_cmd = run_cmd)
cat('Simulation run output:\n')
print(sim_run)

cat('Done. Check outputs under', file.path(sim_path, 'output'), '\n')
