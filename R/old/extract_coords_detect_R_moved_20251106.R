#!/usr/bin/env Rscript
# extract_coords_detect.R (archived copy)

args <- commandArgs(trailingOnly = TRUE)
if(length(args) < 3) {
  cat('Usage: Rscript extract_coords_detect.R grid.bin first_global_index ncell [out=cells_coords.csv] [--swap]\n')
  quit(status = 1)
}
gridbin <- args[1]
first_index <- as.integer(args[2])
ncell_req <- as.integer(args[3])
out <- 'cells_coords.csv'
swap_endian <- FALSE
if(length(args) >= 4) for(a in args[4:length(args)]){
  if(grepl('^out=', a)) out <- sub('^out=', '', a)
  if(a == '--swap') swap_endian <- TRUE
}

if(!file.exists(gridbin)) stop('grid.bin not found: ', gridbin)
gridjson <- paste0(gridbin, '.json')
meta <- list()
if(file.exists(gridjson)) {
  if(!requireNamespace('jsonlite', quietly = TRUE)) stop('Please install jsonlite')
  meta <- jsonlite::fromJSON(gridjson)
}

scalar_candidates <- unique(na.omit(c(as.numeric(meta$scalar), as.numeric(meta$scale), 0.01, 0.001, 1)))
firstcell_meta <- if(!is.null(meta$firstcell)) as.integer(meta$firstcell) else 0L

con <- file(gridbin, 'rb')
endian <- ifelse(swap_endian, ifelse(.Platform$endian == 'little', 'big','little'), .Platform$endian)
vals <- readBin(con, integer(), size = 2, signed = TRUE, endian = endian, n = file.info(gridbin)$size / 2)
close(con)
if(length(vals) < 2) stop('No numeric data read from grid.bin')

total_cells <- floor(length(vals)/2)
global_indices <- as.integer(firstcell_meta + seq_len(total_cells) - 1)
wanted <- seq(from = first_index, length.out = ncell_req)
pos <- match(wanted, global_indices)
if(all(is.na(pos))) stop('No requested global indices present in the file (check first_index)')
pos <- pos[!is.na(pos)]

results <- list()
for(s in scalar_candidates){
  lon1 <- vals[seq(1, length(vals), by = 2)] * s
  lat1 <- vals[seq(2, length(vals), by = 2)] * s
  lon2 <- vals[seq(2, length(vals), by = 2)] * s
  lat2 <- vals[seq(1, length(vals), by = 2)] * s

  cand <- list(
    list(name='lon,lat', lon=lon1, lat=lat1, scalar=s),
    list(name='lat,lon', lon=lon2, lat=lat2, scalar=s)
  )
  for(c in cand){
    sel_lon <- c$lon[pos]
    sel_lat <- c$lat[pos]
    in_spain_bbox <- (sel_lon >= -20 & sel_lon <= 10 & sel_lat >= 30 & sel_lat <= 46)
    score <- sum(in_spain_bbox, na.rm = TRUE) / length(sel_lon)
    results[[length(results)+1]] <- list(name=c$name, scalar=c$scalar, score=score, lon=sel_lon, lat=sel_lat)
  }
}

scores <- sapply(results, function(x) x$score)
best <- which.max(scores)
cat('Tried', length(results), 'candidates. Best score =', scores[best], '\n')
if(scores[best] < 0.25){
  cat('Warning: best candidate has low plausibility for Spain (score < 0.25).\n')
  cat('Showing top 5 candidates:\n')
  ord <- order(scores, decreasing = TRUE)
  for(i in head(ord, 5)){
    cat(sprintf('  candidate %d: name=%s scalar=%g score=%.3f\n', i, results[[i]]$name, results[[i]]$scalar, results[[i]]$score))
  }
  cat('You can inspect other scalar values or run with --swap endian flag if needed.\n')
}

best_c <- results[[best]]
df <- data.frame(id = seq_len(length(best_c$lon)), lon = best_c$lon, lat = best_c$lat, global_index = wanted[1:length(best_c$lon)], stringsAsFactors = FALSE)
df_out <- df[seq_len(length(best_c$lon)), , drop = FALSE]
write.csv(df_out[, c('id','lon','lat')], out, row.names = FALSE)
cat('Wrote', out, 'with', nrow(df_out), 'rows (using scalar=', best_c$scalar, ' order=', best_c$name, ')\n')
