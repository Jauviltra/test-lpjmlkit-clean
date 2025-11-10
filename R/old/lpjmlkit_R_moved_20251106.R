library(testthat)

# Change these paths for your computer
model_path <- "/home/jvt/LPJmL"
sim_path <- "/home/jvt/LPJmL/simulation"

# Running only for a subset of cells, change to NA to run all cells
# Actually NA means to use default values in `lpjml_config.cjson`
startgrid <- 27410
endgrid <- 27433

# Adapt to the number of CPU cores of your computer
# If you get an error message about cores when running, try to reduce them
use_cores <- 1

# Actual simulation year ranges (after the spinup)
simulation_start_year <- 1901
simulation_end_year <- 1902

# Only spinup phase, no simulation
# I wrote firstyear/lastyear for simulation_start_year because I didn't
# know how to choose no years at all
# Though I wrote everything in one script, spinup is meant to be run only once
spinup_params <- tibble::tibble(
  sim_name = "spinup",
  inpath = file.path(model_path, "inputs"),
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  nspinup = 2,
  firstyear = simulation_start_year,
  lastyear = simulation_start_year,
)

spinup_config_details <- lpjmlkit::write_config(
  x = spinup_params,
  model_path = model_path,
  sim_path = sim_path,
  debug = TRUE
)



# Actual simulation scenarios after spinup. Tibble can have multiple rows,
# one for each scenario to simulate. It uses the `-DFROM_RESTART` macro
# to indicate that we use the already run spinup
simulation_params <- tibble::tibble(
  sim_name = "scenario_1",
  inpath = file.path(model_path, "inputs"),
  `-DFROM_RESTART` = TRUE,
  restart_filename = "restart/spinup/restart.lpj",
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  nspinup = 0,
  firstyear = simulation_start_year,
  lastyear = simulation_end_year,
)

simulation_config_details <- lpjmlkit::write_config(
  x = simulation_params,
  model_path = model_path,
  sim_path = sim_path,
  debug = TRUE
)

# Previous was just setting up configuration, now actually running the model

# As mentioned before, this can be run only once
spinup_run_details <- lpjmlkit::run_lpjml(
  spinup_config_details,
  model_path,
  sim_path,
  run_cmd = stringr::str_glue("mpirun -np {use_cores} ")
)

# This runs the simulations starting after the spinup
simulation_run_details <- lpjmlkit::run_lpjml(
  simulation_config_details,
  model_path,
  sim_path,
  run_cmd = stringr::str_glue("mpirun -np {use_cores} ")
)
