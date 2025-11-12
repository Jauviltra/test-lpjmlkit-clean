test-lpjmlkit-clean

Quick start
- See PICKUP_LPJML_v3.md for full 'Try it (WSL)' instructions.
- Run a quick smoke test (prepare subset & dry-run):
  Rscript R/prepare_subset.R --grid inputs/grid.bin --outdir /tmp/spain_subset_outputs
  # Then run the canonical runner (spinup+1901-1910 example)
  Rscript R/run_spain_subset_and_sim.R --cores 4 --start-year 1901 --end-year 1910 --workdir /home/jvt/test-lpjmlkit-clean/output/spain_sim --lpj-inputs /home/jvt/LPJmL/inputs --lpj-bin /home/jvt/LPJmL/bin/lpjml

See PICKUP_LPJML_v3.md for details and paths.
