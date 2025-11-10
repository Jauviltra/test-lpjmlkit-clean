#!/usr/bin/env bash
# watch_and_plot_on_finish.sh
# Wait for lpjml/mpirun to finish, then run the requested R plotting scripts

set -euo pipefail

REPO_DIR="/home/jvt/test-lpjmlkit-clean"
LOGDIR="/tmp"
PLOTLOG="$LOGDIR/plotting_$(date +%Y%m%dT%H%M%S).log"

echo "Watcher started at $(date). Will poll for mpirun/lpjml processes..." | tee -a "$PLOTLOG"
cd "$REPO_DIR"

while pgrep -f "mpirun|lpjml" >/dev/null 2>&1; do
  sleep 10
done

echo "LPJmL run finished at $(date) — launching R plotting scripts" | tee -a "$PLOTLOG"

echo "Running map_cells_clean.R" | tee -a "$PLOTLOG"
if command -v Rscript >/dev/null 2>&1; then
  Rscript R/map_cells_clean.R >> "$PLOTLOG" 2>&1 || echo "map script failed, see $PLOTLOG" | tee -a "$PLOTLOG"
else
  echo "Rscript not found in PATH; skipping map generation" | tee -a "$PLOTLOG"
fi

echo "Running analysis_plots_clean.R" | tee -a "$PLOTLOG"
if command -v Rscript >/dev/null 2>&1; then
  Rscript R/analysis_plots_clean.R >> "$PLOTLOG" 2>&1 || echo "analysis script failed, see $PLOTLOG" | tee -a "$PLOTLOG"
else
  echo "Rscript not found in PATH; skipping analysis plots" | tee -a "$PLOTLOG"
fi

echo "Plotting finished at $(date). Log: $PLOTLOG" | tee -a "$PLOTLOG"

echo "List figures/ and output directory:" | tee -a "$PLOTLOG"
ls -l figures 2>&1 | tee -a "$PLOTLOG" || true
ls -l output/spain_sim/output/spain_test 2>&1 | tee -a "$PLOTLOG" || true

echo "WATCHER_DONE" | tee -a "$PLOTLOG"

exit 0
