model_path <- "/home/usuario/LPJmL"

cells <- "inputs/spain_cells.csv" |>
  readLines() |>
  as.integer()

soil <- model_path |>
  file.path("inputs/soil/soil_30arcmin_13_types.nc") |>
  terra::rast()

soil[-cells] <- NA

terra::writeCDF(
  soil,
  filename = file.path(model_path, "inputs/soil/soil_types_subset.nc"),
  varname = "soil_type",
  overwrite = TRUE
)
