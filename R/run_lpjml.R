#' Run LPJmL model wrapper
#'
#' This function prepares a command to run the LPJmL binary with the provided
#' configuration and optionally runs it. It does minimal validation and logs
#' output. The LPJmL binary must be available on the user's system and callable
#' as `mpirun` or directly as `lpjml` depending on installation.
#'
#' @param config_json Path to LPJmL JSON configuration file
#' @param lpjml_bin Path to LPJmL binary executable (optional)
#' @param nproc Number of processors to use with mpirun (default 1)
#' @param run Logical; if TRUE the command will be executed, otherwise it returns the command string
#' @param workdir Working directory to run LPJmL in (defaults to current dir)
#' @return If run=FALSE returns the assembled command (character); if run=TRUE returns a list with stdout, stderr and status
#' @export
run_lpjml <- function(config_json, lpjml_bin = NULL, nproc = 1L, run = TRUE, workdir = getwd()) {
  if (missing(config_json) || !file.exists(config_json)) stop("config_json must point to an existing file")
  if (is.null(lpjml_bin)) {
    # try to discover lpjml in PATH
    lpjml_bin <- Sys.which("lpjml")
    if (!nzchar(lpjml_bin)) {
      # fallback to mpirun + lpjml if mpirun is present
      mpirun <- Sys.which("mpirun")
      if (!nzchar(mpirun)) stop("Could not find lpjml or mpirun in PATH. Provide lpjml_bin explicitly")
      lpjml_cmd <- mpirun
      args <- c("-n", as.character(as.integer(nproc)), "lpjml", "-c", config_json)
    } else {
      lpjml_cmd <- lpjml_bin
      args <- c("-c", config_json)
    }
  } else {
    lpjml_cmd <- lpjml_bin
    args <- c("-c", config_json)
  }

  cmd <- paste(shQuote(lpjml_cmd), paste(shQuote(args), collapse = " "))

  if (!run) return(cmd)

  # Run in the requested working directory, capturing output
  owd <- getwd()
  on.exit(setwd(owd), add = TRUE)
  setwd(workdir)
  res_out <- tryCatch({
    out <- system2(lpjml_cmd, args = args, stdout = TRUE, stderr = TRUE)
    list(stdout = out, status = attr(out, "status") %||% 0L)
  }, error = function(e) {
    list(error = conditionMessage(e))
  })
  res_out
  }

  ## helpers are centralised in R/utils.R; ensure it's loaded when needed
  if (!exists("%||%")) {
    if (file.exists(file.path(getwd(), "R", "utils.R"))) {
      source(file.path(getwd(), "R", "utils.R"))
    } else if (file.exists("R/utils.R")) {
      source("R/utils.R")
    }
  }
