PICKUP_LPJML_v3

Resumen y pasos rápidos para reproducir el subset de España y lanzar LPJmL

Este documento contiene instrucciones condensadas (WSL) para preparar el subset de España,
generar la configuración y ejecutar LPJmL (spinup + 1901–1910). Incluye rutas clave y comprobaciones.

Rutas importantes (asumidas en este repo limpio)
- Repo limpio: /home/jvt/test-lpjmlkit-clean
- Grid bin reproducible (en el repo): /home/jvt/test-lpjmlkit-clean/inputs/grid.bin
- Metadatos grid (json): /home/jvt/test-lpjmlkit-clean/inputs/grid.bin.json
- Inputs grandes de LPJ (no incluidos en el repo): /home/jvt/LPJmL/inputs
- Binario LPJmL: /home/jvt/LPJmL/bin/lpjml
- Runner principal: R/run_spain_subset_and_sim.R
- Helpers: R/prepare_subset.R, R/run_lpjml.R, R/write_manual_header.R
- Salida sugerida (no trackeada): /home/jvt/test-lpjmlkit-clean/output/spain_sim

Try it (WSL) — uso RECOMENDADO: runner único (spinup + 1901–1910, 4 cores)

Abra WSL y ejecute:

```bash
# desde WSL — en /home/jvt
cd /home/jvt/test-lpjmlkit-clean

# Ejecutar el runner canónico: prepara subset, escribe config y lanza LPJmL
# Parámetros: --cores, --start-year, --end-year, --workdir, --lpj-inputs, --lpj-bin
Rscript R/run_spain_subset_and_sim.R --cores 4 \
  --start-year 1901 --end-year 1910 \
  --workdir /home/jvt/test-lpjmlkit-clean/output/spain_sim \
  --lpj-inputs /home/jvt/LPJmL/inputs \
  --lpj-bin /home/jvt/LPJmL/bin/lpjml
