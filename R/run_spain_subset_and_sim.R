# Change these paths for your computer
model_path <- "/home/usuario/LPJmL"
sim_path <- "/home/usuario/LPJmL/simulation"

# Use to run only subset of cells
# Works because cells with null soil type value are skipped
# (https://github.com/PIK-LPJmL/LPJmL/issues/71)
# Check to generate this in `R/prepare_subset.R`
# Otherwise set to `NA` to use default
input_soil_path <- file.path("soil/soil_types_subset.nc")

# Running only for a subset of cells, set to NA to run all
# cells with a non-null soil type value.
# Actually NA means to use default values in `lpjml_config.cjson`
startgrid <- NA
endgrid <- NA

# Adapt to the number of CPU cores of your computer
# If you get an error message about cores when running, try to reduce them
use_cores <- 1

# Actual simulation year ranges (after the spinup)
simulation_start_year <- 1901
simulation_end_year <- 1902
nspinup <- 2

# Actual simulation scenarios after spinup. Tibble can have multiple rows,
# one for each scenario to simulate. It uses the `-DFROM_RESTART` macro
# to indicate that we use the already run spinup
simulation_params <- tibble::tibble(
  sim_name = "scenario_1",
  inpath = file.path(model_path, "inputs"),
  startgrid = startgrid,
  endgrid = endgrid,
  river_routing = FALSE,
  firstyear = simulation_start_year,
  lastyear = simulation_end_year,
  nspinup = nspinup,
  `input.soil.name` = input_soil_path,
  landuse = "yes"
)

simulation_config_details <- lpjmlkit::write_config(
  x = simulation_params,
  model_path = model_path,
  sim_path = sim_path,
  debug = TRUE
)

# Previous was just setting up configuration, now actually running the model

simulation_run_details <- lpjmlkit::run_lpjml(
  simulation_config_details,
  model_path,
  sim_path,
  run_cmd = stringr::str_glue("mpirun -np {use_cores} ")
)
