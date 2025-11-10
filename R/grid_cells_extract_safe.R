#!/usr/bin/env Rscript
# Safe wrapper for grid_cells_extract.R
# Usage: same args as grid_cells_extract.R; it will try to run the original script
# and if it errors (e.g. due to NA coordinates -> st_as_sf failure) it will fall back
# to a robust extraction that removes invalid coords and writes CSV/GeoJSON/TXT outputs.

args <- commandArgs(trailingOnly = TRUE)
# central helpers
if (!exists("%||%")) {
  if (file.exists(file.path(getwd(), "R", "utils.R"))) {
    source(file.path(getwd(), "R", "utils.R"))
  } else if (file.exists("R/utils.R")) {
    source("R/utils.R")
  }
}

# Try to locate the original extractor; when run under different R frontends the
# computed path may not always be correct, so fall back to the known repo path.
orig <- tryCatch(file.path(dirname(dirname(sys.frame(1)$ofile %||% ".")), "gridbin_to_clm", "scripts", "grid_cells_extract.R"), error = function(e) NA)
orig <- if (is.na(orig) || !nzchar(orig)) "/home/jvt/test-lpjmlkit/gridbin_to_clm/scripts/grid_cells_extract.R" else orig

run_original <- function() {
  cmd <- c(orig, args)
  message("Running original extractor: ", paste(cmd, collapse = " "))
  res <- system2("Rscript", cmd, stdout = "", stderr = "")
  return(invisible(res == 0))
}

fallback_extract <- function(opts) {
  # opts should contain grid, grid-json, rect (lonmin,latmin,lonmax,latmax), method, out
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Please install jsonlite in this R")
  if (!requireNamespace("sf", quietly = TRUE)) stop("Please install sf in this R")
  # use package prefixes instead of library()

  gridbin <- opts$grid
  gridjson <- opts$grid_json
  outbase <- opts$out
  method <- opts$method %||% "center"
  rect <- opts$rect

  if (!file.exists(gridbin) || !file.exists(gridjson)) stop("grid binary or json not found")
  g <- jsonlite::fromJSON(gridjson)
  ncell <- as.integer(g$ncell)
  scalar <- as.numeric(g$scalar)
  firstcell <- as.integer(g$firstcell %||% 0)

  vals <- readBin(gridbin, integer(), n = ncell*2, size = 2, signed = TRUE, endian = "little")
  lon <- vals[seq(1, length(vals), by = 2)] * scalar
  lat <- vals[seq(2, length(vals), by = 2)] * scalar
  idx <- seq(from = firstcell, length.out = ncell, by = 1)
  df <- data.frame(index = idx, lon = lon, lat = lat)

  # defensive diagnostics: report counts of problematic coordinates and drop them
  total_rows <- nrow(df)
  na_lon <- is.na(df$lon) | !is.finite(df$lon)
  na_lat <- is.na(df$lat) | !is.finite(df$lat)
  na_any <- na_lon | na_lat
  n_bad <- sum(na_any)
  message("Read ", total_rows, " rows from grid. Invalid lon: ", sum(na_lon), ", invalid lat: ", sum(na_lat), ", any invalid: ", n_bad)
  if (n_bad > 0) {
    warning(n_bad, " rows had invalid coordinates and will be dropped")
    if (n_bad > 0) {
      message("Sample bad rows (first 5):")
      print(head(df[na_any, , drop = FALSE], 5))
    }
    df <- df[!na_any, , drop = FALSE]
  }

  # apply selection
  if (!is.null(rect) && nzchar(rect)) {
    parts <- as.numeric(strsplit(rect, ",")[[1]])
    if (length(parts) != 4) stop("--rect must be lonmin,latmin,lonmax,latmax")
    lonmin <- parts[1]; latmin <- parts[2]; lonmax <- parts[3]; latmax <- parts[4]
    if (method == "center") {
      sel <- df$lon >= lonmin & df$lon <= lonmax & df$lat >= latmin & df$lat <= latmax
      df <- df[sel, , drop = FALSE]
    } else {
      cellsize_lon <- as.numeric(g$cellsize_lon %||% g$cellsize %||% 0.5)
      cellsize_lat <- as.numeric(g$cellsize_lat %||% g$cellsize %||% 0.5)
      halfx <- cellsize_lon/2; halfy <- cellsize_lat/2
      sel <- (df$lon + halfx) >= lonmin & (df$lon - halfx) <= lonmax & (df$lat + halfy) >= latmin & (df$lat - halfy) <= latmax
      df <- df[sel, , drop = FALSE]
    }
  }

  dir.create(dirname(outbase), showWarnings = FALSE, recursive = TRUE)
  csvf <- paste0(outbase, "_cells.csv")
  geojsonf <- paste0(outbase, "_cells.geojson")
  txtf <- paste0(outbase, "_cells.txt")

  write.csv(df, csvf, row.names = FALSE)
  write.table(df$index, txtf, row.names = FALSE, col.names = FALSE)
  # write geojson as points, but be defensive: sf::st_as_sf can error on strange inputs
  if (nrow(df) == 0) {
    message("No valid rows to write as GeoJSON; wrote CSV/TXT only")
    message("Wrote: ", csvf, ", ", txtf)
    invisible(TRUE)
  } else {
    pts <- tryCatch(
      sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326),
      error = function(e) {
        message("sf::st_as_sf failed: ", e$message)
        NULL
      }
    )
    if (is.null(pts)) {
      message("Could not convert to sf points. GeoJSON will not be written. CSV/TXT are available for inspection: ", csvf)
      invisible(TRUE)
    } else {
      tryCatch({ sf::st_write(pts, geojsonf, delete_dsn = TRUE, quiet = TRUE); message("Wrote: ", csvf, ", ", txtf, ", ", geojsonf) },
               error = function(e) { message("sf::st_write failed: ", e$message); message("Wrote CSV/TXT only: ", csvf, ", ", txtf) })
      invisible(TRUE)
    }
  }
}

parse_args <- function(argv) {
  opts <- list()
  i <- 1
  while (i <= length(argv)) {
    a <- argv[i]
    if (a == "--grid") { opts$grid <- argv[i+1]; i <- i+2 }
    else if (a == "--grid-json") { opts$grid_json <- argv[i+1]; i <- i+2 }
    else if (a == "--rect") { opts$rect <- argv[i+1]; i <- i+2 }
    else if (a == "--method") { opts$method <- argv[i+1]; i <- i+2 }
    else if (a == "--out") { opts$out <- argv[i+1]; i <- i+2 }
    else i <- i+1
  }
  opts
}

opts <- parse_args(args)
ok <- FALSE
try({ ok <- run_original() }, silent = TRUE)
if (!isTRUE(ok)) {
  message("Original extractor failed or returned non-zero. Falling back to safe extractor...")
  tryCatch({ fallback_extract(opts) }, error = function(e) { message("Fallback extractor failed: ", e$message); quit(status = 2) })
}
