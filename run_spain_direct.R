#!/usr/bin/env Rscript
# Minimal direct runner: prepare subset from repo inputs/grid.bin and run LPJ (spinup + scenario)

# abort early on error
options(error = function() { quit(status = 1) })

# load helper
prep_path <- file.path(getwd(), "R", "prepare_subset.R")
if (!file.exists(prep_path)) stop("prepare_subset.R not found at ", prep_path)
source(prep_path)

# inputs / paths
gridbin <- file.path(getwd(), "inputs", "grid.bin")
grid_json <- if (file.exists(paste0(gridbin, ".json"))) paste0(gridbin, ".json") else NULL
out_dir <- "/tmp/test-lpjmlkit-smoke/outputs"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# prepare subset (bbox/method as in repo)
res <- prepare_subset(gridbin = gridbin, grid_json = grid_json, out_dir = out_dir, out_basename = "spain_subset", indices = NULL, bbox = "-9.5,36.0,3.5,44.5", method = "overlap")
cat("prepare_subset returned:\n"); print(res)

# get CSV path (prepare_subset may return character or list)
csvf <- if (is.character(res)) res else (if (!is.null(res$csv)) res$csv else stop("CSV path not found in prepare_subset result"))
if (!file.exists(csvf)) stop("CSV not produced: ", csvf)

df <- read.csv(csvf, stringsAsFactors = FALSE)
idx <- df[[1]]
startgrid <- min(idx, na.rm = TRUE)
endgrid <- max(idx, na.rm = TRUE)
cat("Selected indices:", startgrid, "to", endgrid, " (n=", length(unique(idx)), ")\n")

# require lpjmlkit and tibble
if (!requireNamespace("lpjmlkit", quietly = TRUE)) stop("Install lpjmlkit in R: install.packages('lpjmlkit') or use renv")
if (!requireNamespace("tibble", quietly = TRUE)) install.packages("tibble")

# model path and sim path
model_path <- "/home/jvt/LPJmL"
sim_path <- file.path(getwd(), "output", "spain_sim")
dir.create(sim_path, recursive = TRUE, showWarnings = FALSE)

# spinup config
spinup_params <- tibble::tibble(
  sim_name = "spinup",
  inpath = file.path(model_path, "inputs"),
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  nspinup = 2,
  firstyear = 1901,
  lastyear = 1901
)
spin_cfg <- lpjmlkit::write_config(x = spinup_params, model_path = model_path, sim_path = sim_path, debug = TRUE)

# run spinup (mpirun -np 4)
run_cmd <- sprintf("mpirun -np %d ", 4)
cat("Running spinup with:", run_cmd, "\n")
spin_res <- lpjmlkit::run_lpjml(spin_cfg, model_path, sim_path, run_cmd = run_cmd)
cat("Spinup finished, result object:\n"); print(spin_res)

# scenario: from restart written by spinup
sim_params <- tibble::tibble(
  sim_name = "scenario_1",
  inpath = file.path(model_path, "inputs"),
  `-DFROM_RESTART` = TRUE,
  restart_filename = file.path("restart", "spinup", "restart.lpj"),
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  nspinup = 0,
  firstyear = 1901,
  lastyear = 1910
)
sim_cfg <- lpjmlkit::write_config(x = sim_params, model_path = model_path, sim_path = sim_path, debug = TRUE)
cat("Running scenario with:", run_cmd, "\n")
sim_res <- lpjmlkit::run_lpjml(sim_cfg, model_path, sim_path, run_cmd = run_cmd)
cat("Scenario finished, result object:\n"); print(sim_res)

cat("Done. Outputs under:", file.path(sim_path, "output"), "\n")
