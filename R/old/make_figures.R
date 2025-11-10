#' Make common LPJmL figures from globalflux CSV
#'
#' Reads LPJmL globalflux-style CSV output and makes a small set of time-series
#' and summary plots. Uses ggplot2 and readr if available.
#'
#' @param globalflux_csv Path to globalflux CSV file
#' @param out_dir Directory to write figures to (created if missing)
#' @param prefix Prefix for output filenames (default "fig")
#' @return A character vector with paths to created figure files
#' @export
make_figures <- function(globalflux_csv, out_dir = "./figures", prefix = "fig") {
  if (missing(globalflux_csv) || !file.exists(globalflux_csv)) stop("globalflux_csv must exist")
  if (!requireNamespace("readr", quietly = TRUE) || !requireNamespace("ggplot2", quietly = TRUE)) {
    stop("readr and ggplot2 are required for make_figures(). Please install them.")
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  df <- readr::read_csv(globalflux_csv, show_col_types = FALSE)

  # Try to infer time column
  time_col <- intersect(c("year", "time", "t"), tolower(names(df)))[1]
  if (is.null(time_col) || is.na(time_col)) {
    # fallback: first numeric column
    num_cols <- vapply(df, is.numeric, logical(1))
    time_col <- names(df)[which(num_cols)[1]]
  }

  fig_paths <- character()
  # Simple time series for first numeric column vs time
  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  numeric_cols <- setdiff(numeric_cols, time_col)
  if (length(numeric_cols) >= 1) {
    p <- ggplot2::ggplot(df, ggplot2::aes_string(x = time_col, y = numeric_cols[1])) +
      ggplot2::geom_line() +
      ggplot2::theme_minimal() +
      ggplot2::labs(x = time_col, y = numeric_cols[1], title = paste(numeric_cols[1], "over time"))
    f1 <- file.path(out_dir, paste0(prefix, "_", numeric_cols[1], ".png"))
    ggplot2::ggsave(f1, p)
    fig_paths <- c(fig_paths, f1)
  }

  # Distribution plot of first numeric variable
  if (length(numeric_cols) >= 1) {
    p2 <- ggplot2::ggplot(df, ggplot2::aes_string(x = numeric_cols[1])) +
      ggplot2::geom_histogram(bins = 30) +
      ggplot2::theme_minimal() +
      ggplot2::labs(x = numeric_cols[1], title = paste("Distribution of", numeric_cols[1]))
    f2 <- file.path(out_dir, paste0(prefix, "_", numeric_cols[1], "_hist.png"))
    ggplot2::ggsave(f2, p2)
    fig_paths <- c(fig_paths, f2)
  }

  fig_paths
}
