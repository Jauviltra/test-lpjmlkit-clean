#' Prepare LPJmL subset of grid cells
#'
#' This convenience wrapper calls the robust extractor script to produce
#' CSV/TXT/GeoJSON files with selected cells and writes a manual header
#' suitable for LPJmL using `write_manual_header.R`.
#'
#' @param gridbin Path to `grid.bin` file
#' @param grid_json Path to `grid.bin.json` metadata (optional but recommended)
#' @param out_dir Directory where outputs will be written (created if missing)
#' @param out_basename Basename for outputs (default: "subset")
#' @param indices Optional integer vector of global indices to select (mutually exclusive with bbox)
#' @param bbox Optional bounding box string "lonmin,latmin,lonmax,latmax" to select cells by rectangle
#' @param method Selection method for bbox: "center" or "overlap" (passed to extractor)
#' @return A list with paths to created files: csv, txt, geojson, header
#' @export
prepare_subset <- function(gridbin, grid_json = NULL, out_dir = "./outputs", out_basename = "subset", indices = NULL, bbox = NULL, method = "center") {
  if (missing(gridbin) || !nzchar(gridbin) || !file.exists(gridbin)) stop("gridbin must be an existing path")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  outbase <- file.path(normalizePath(out_dir), out_basename)

  # Build command to call the robust extractor script. We use the cleaned R script
  # that is present in this repo: R/grid_cells_extract_safe.R (or dump_grid_coords_nosf_clean as fallback)
  extractor <- file.path(getwd(), "R", "grid_cells_extract_safe.R")
  if (!file.exists(extractor)) {
    # fallback to cleaned dump script
    extractor <- file.path(getwd(), "R", "dump_grid_coords_nosf_clean.R")
    if (!file.exists(extractor)) stop("No extractor script found in R/ directory")
  }

  args <- c(extractor, "--grid", gridbin, "--out", outbase)
  if (!is.null(grid_json) && nzchar(grid_json) && file.exists(grid_json)) {
    args <- c(args, "--grid-json", grid_json)
  }
  if (!is.null(bbox) && nzchar(bbox)) {
    args <- c(args, "--bbox", bbox)
  }
  if (!is.null(method) && nzchar(method)) args <- c(args, "--method", method)
  if (!is.null(indices)) {
    # write indices to a temp file and pass indices-file
    idxf <- tempfile(fileext = ".txt")
    writeLines(as.character(indices), idxf)
    args <- c(args, "--indices-file", idxf)
  }

  # Run extractor via Rscript so it executes in a clean R process
  res <- system2("Rscript", args = args, stdout = TRUE, stderr = TRUE)
  attr(res, "status") <- attr(res, "status")

  # expected outputs
  csvf <- paste0(outbase, "_cells.csv")
  txtf <- paste0(outbase, "_cells.txt")
  geojsonf <- paste0(outbase, "_cells.geojson")
  headerf <- paste0(outbase, "_header.bin")

  if (!file.exists(csvf)) stop("Extractor did not produce expected CSV: ", csvf)

  # Use the provided write_manual_header.R function (if present) to write a header
  hdr_script <- file.path(getwd(), "R", "write_manual_header.R")
  if (file.exists(hdr_script)) {
    # source the header writer and call it
    source(hdr_script)
    # the function write_manual_header should be available now
    if (!exists("write_manual_header")) stop("write_manual_header() not found after sourcing script")
    write_manual_header(txtf, grid_json %||% paste0(gridbin, ".json"), headerf)
  } else {
    warning("write_manual_header.R not found. Header not created")
    headerf <- NULL
  }

  list(csv = csvf, txt = txtf, geojson = if (file.exists(geojsonf)) geojsonf else NULL, header = headerf, extractor_stdout = res)
  }

  ## helpers are centralised in R/utils.R; ensure it's loaded when needed
  if (!exists("%||%")) {
    if (file.exists(file.path(getwd(), "R", "utils.R"))) {
      source(file.path(getwd(), "R", "utils.R"))
    } else if (file.exists("R/utils.R")) {
      source("R/utils.R")
    }
  }
