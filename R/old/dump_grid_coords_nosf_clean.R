#!/usr/bin/env Rscript
# dump_grid_coords_nosf_clean.R -- no top-level library() calls; uses jsonlite:: and optparse::

## central helpers
if (!exists("%||%")) {
  if (file.exists(file.path(getwd(), "R", "utils.R"))) {
    source(file.path(getwd(), "R", "utils.R"))
  } else if (file.exists("R/utils.R")) {
    source("R/utils.R")
  }
}

## logging helper: prefer cli if available
log_info <- function(...) {
  txt <- paste(..., collapse = " ")
  if (requireNamespace("cli", quietly = TRUE)) cli::cli_alert_info(txt) else message(txt)
}

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install package 'jsonlite'")
if (!requireNamespace("optparse", quietly = TRUE)) stop("Install package 'optparse'")

option_list <- list(
  optparse::make_option(c("--grid"), type="character"),
  optparse::make_option(c("--grid-json"), type="character", default=NA),
  optparse::make_option(c("--out"), type="character", default="grid_all_cells.csv"),
  optparse::make_option(c("--bbox"), type="character", default=NA,
              help="lonmin,latmin,lonmax,latmax used for plausibility scoring"),
  optparse::make_option(c("--indices-file"), type="character", default=NA,
              help="optional file with one global_index per line; if provided, script writes only those rows to out (but still creates full CSV)"),
  optparse::make_option(c("--verbose"), action="store_true", default=FALSE)
)
opt <- optparse::parse_args(optparse::OptionParser(option_list=option_list))

v <- function(...) {
  if (isTRUE(opt$verbose)) {
    log_info(...)
  }
}

if (is.null(opt$grid) || !nzchar(opt$grid) || !file.exists(opt$grid)) stop("Provide existing --grid path")

meta <- list()
if (!is.na(opt$`grid-json`) && nzchar(opt$`grid-json`) && file.exists(opt$`grid-json`)) {
  meta <- jsonlite::fromJSON(opt$`grid-json`)
  v("Read JSON:", paste(names(meta), collapse=", "))
} else {
  v("No JSON provided or not found; will assume defaults (scalar=0.01)")
}

filesize <- file.info(opt$grid)$size
if (is.na(filesize)) stop("grid file not found")
nshorts <- as.integer(filesize / 2)
ncell_est <- as.integer(nshorts / 2)
firstcell <- as.integer(meta$firstcell %||% 0)
ncell_meta <- if (!is.null(meta$ncell)) as.integer(meta$ncell) else NA
ncell <- if (!is.na(ncell_meta)) ncell_meta else ncell_est
scalar_guess <- if (!is.null(meta$scalar)) as.numeric(meta$scalar) else if (!is.null(meta$scale)) as.numeric(meta$scale) else 0.01
  v(sprintf("filesize=%d nshorts=%d ncell=%d firstcell=%s scalar=%s", filesize, nshorts, ncell, firstcell, scalar_guess))

# helper to compute score: fraction of points within bbox
score_coords <- function(lon, lat, bbox = c(-180,-90,180,90)) {
  ok <- is.finite(lon) & is.finite(lat)
  if (!any(ok)) return(0)
  lon <- lon[ok]; lat <- lat[ok]
  inside <- (lon >= bbox[1] & lon <= bbox[3] & lat >= bbox[2] & lat <= bbox[4])
  mean(inside)
}

read_shorts <- function(path, nshorts, endian) {
  con <- file(path, "rb"); on.exit(close(con))
  readBin(con, integer(), n = nshorts, size = 2, signed = TRUE, endian = endian)
}

candidates <- list()
if (!is.na(opt$bbox) && nzchar(opt$bbox)) {
  parts <- as.numeric(strsplit(opt$bbox, ",")[[1]])
  if (length(parts) != 4) stop("--bbox must be lonmin,latmin,lonmax,latmax")
  bbox <- parts
} else {
  bbox <- c(-20, 28, 6, 46)
}

v("Using scoring bbox:", paste(bbox, collapse=","))

vals_le <- tryCatch(read_shorts(opt$grid, nshorts, "little"), error = function(e) NULL)
vals_be <- NULL
if (is.null(vals_le)) stop("Failed to read grid.bin as little-endian")

lon1 <- vals_le[seq(1, length(vals_le), by=2)] * scalar_guess
lat1 <- vals_le[seq(2, length(vals_le), by=2)] * scalar_guess
candidates[[length(candidates)+1]] <- list(endian="little", order="pair", lon=lon1, lat=lat1,
                                            score=score_coords(lon1, lat1, bbox))

candidates[[length(candidates)+1]] <- list(endian="little", order="swap", lon=lat1, lat=lon1,
                                            score=score_coords(lat1, lon1, bbox))

vals_be <- tryCatch(read_shorts(opt$grid, nshorts, "big"), error = function(e) NULL)
if (!is.null(vals_be)) {
  lon3 <- vals_be[seq(1, length(vals_be), by=2)] * scalar_guess
  lat3 <- vals_be[seq(2, length(vals_be), by=2)] * scalar_guess
  candidates[[length(candidates)+1]] <- list(endian="big", order="pair", lon=lon3, lat=lat3,
                                              score=score_coords(lon3, lat3, bbox))
  candidates[[length(candidates)+1]] <- list(endian="big", order="swap", lon=lat3, lat=lon3,
                                              score=score_coords(lat3, lon3, bbox))
}

if (length(vals_le) >= 2*ncell) {
  lon_block2 <- vals_le[1:ncell] * scalar_guess
  lat_block2 <- vals_le[(ncell+1):(2*ncell)] * scalar_guess
  candidates[[length(candidates)+1]] <- list(endian="little", order="block", lon=lon_block2, lat=lat_block2,
                                              score=score_coords(lon_block2, lat_block2, bbox))
  candidates[[length(candidates)+1]] <- list(endian="little", order="block_swap", lon=lat_block2, lat=lon_block2,
                                              score=score_coords(lat_block2, lon_block2, bbox))
  if (!is.null(vals_be) && length(vals_be) >= 2*ncell) {
    lon_block2b <- vals_be[1:ncell] * scalar_guess
    lat_block2b <- vals_be[(ncell+1):(2*ncell)] * scalar_guess
    candidates[[length(candidates)+1]] <- list(endian="big", order="block", lon=lon_block2b, lat=lat_block2b,
                                                score=score_coords(lon_block2b, lat_block2b, bbox))
    candidates[[length(candidates)+1]] <- list(endian="big", order="block_swap", lon=lat_block2b, lat=lon_block2b,
                                                score=score_coords(lat_block2b, lon_block2b, bbox))
  }
}

scores <- sapply(candidates, function(x) x$score)
best_i <- which.max(scores)
best <- candidates[[best_i]]
  v(sprintf("Best candidate: endian=%s order=%s score=%.4f", best$endian, best$order, best$score))

nrows <- length(best$lon)
nrows_use <- min(nrows, ncell)
global_index <- as.integer(firstcell + seq_len(nrows_use) - 1)
df <- data.frame(global_index = global_index, lon = best$lon[1:nrows_use], lat = best$lat[1:nrows_use], stringsAsFactors=FALSE)

write.csv(df, opt$out, row.names = FALSE)
v("Wrote CSV:", opt$out)

if (!is.na(opt$`indices-file`) && nzchar(opt$`indices-file`) && file.exists(opt$`indices-file`)) {
  inds <- scan(opt$`indices-file`, what=integer(), quiet=TRUE)
  sel <- df$global_index %in% inds
  filtered <- df[sel, , drop=FALSE]
  outf <- sub("(\\.csv)?$", "_filtered.csv", opt$out)
  write.csv(filtered, outf, row.names = FALSE)
  v("Wrote filtered CSV:", outf, " (selected rows:", nrow(filtered), ")")
}

v("Done")
