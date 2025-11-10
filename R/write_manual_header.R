# write_manual_header.R -- create a .hdr-like manual header from selected cells
# This variant avoids library() in top-level code and uses jsonlite::fromJSON

write_manual_header <- function(cells_txt, grid_json, out_header) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Please install jsonlite")
  # cells_txt: file with indices, one per line
  # grid_json: grid.bin.json with metadata
  # out_header: path to write binary header

  if (!file.exists(cells_txt)) stop("cells_txt not found: ", cells_txt)
  if (!file.exists(grid_json)) stop("grid_json not found: ", grid_json)

  cells <- as.integer(readLines(cells_txt))
  g <- jsonlite::fromJSON(grid_json)

  # fields expected (some names may vary; use sensible defaults)
  version <- as.integer(g$version %||% 1)
  order <- as.integer(g$order %||% 1)
  firstyear <- as.integer(g$firstyear %||% 1901)
  nyear <- as.integer(g$nyear %||% 1)
  firstcell <- as.integer(min(cells))
  ncell <- as.integer(length(cells))
  nbands <- as.integer(g$nbands %||% 1)
  cellsize_lon <- as.numeric(g$cellsize_lon %||% g$cellsize %||% 0.5)
  scalar <- as.numeric(g$scalar %||% 1)
  cellsize_lat <- as.numeric(g$cellsize_lat %||% g$cellsize %||% 0.5)
  datatype <- as.integer(g$datatype %||% 1)
  nstep <- as.integer(g$nstep %||% 1)
  timestep <- as.integer(g$timestep %||% 1)

  con <- file(out_header, "wb")
  on.exit(close(con), add = TRUE)
  writeBin(as.integer(version), con, size = 4, endian = "little")
  writeBin(as.integer(order), con, size = 4, endian = "little")
  writeBin(as.integer(firstyear), con, size = 4, endian = "little")
  writeBin(as.integer(nyear), con, size = 4, endian = "little")
  writeBin(as.integer(firstcell), con, size = 4, endian = "little")
  writeBin(as.integer(ncell), con, size = 4, endian = "little")
  writeBin(as.integer(nbands), con, size = 4, endian = "little")
  writeBin(as.numeric(cellsize_lon), con, size = 8, endian = "little")
  writeBin(as.numeric(scalar), con, size = 8, endian = "little")
  writeBin(as.numeric(cellsize_lat), con, size = 8, endian = "little")
  writeBin(as.integer(datatype), con, size = 4, endian = "little")
  writeBin(as.integer(nstep), con, size = 4, endian = "little")
  writeBin(as.integer(timestep), con, size = 4, endian = "little")

  invisible(TRUE)
  }

  ## central helpers
  if (!exists("%||%")) {
    if (file.exists(file.path(getwd(), "R", "utils.R"))) {
      source(file.path(getwd(), "R", "utils.R"))
    } else if (file.exists("R/utils.R")) {
      source("R/utils.R")
    }
  }
