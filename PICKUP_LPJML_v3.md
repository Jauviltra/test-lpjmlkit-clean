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

Working WSL example (background, logs)

```bash
# From the repo root in WSL
cd /home/jvt/test-lpjmlkit-clean
mkdir -p output/spain_sim

# Run in background, redirect output to a log file and follow it
Rscript R/run_spain_subset_and_sim.R \
  --cores 4 \
  --start-year 1901 --end-year 1910 \
  --workdir /home/jvt/test-lpjmlkit-clean/output/spain_sim \
  --lpj-inputs /home/jvt/LPJmL/inputs \
  --lpj-bin /home/jvt/LPJmL/bin/lpjml \
  > /tmp/run_spain_full_350.log 2>&1 &

tail -n 200 -f /tmp/run_spain_full_350.log
```

Notas rápidas sobre por qué funcionó aquí

- El runner ahora detecta y prefiere `inputs/grid.bin` y `inputs/grid.bin.json` del repo cuando existen. Evita rutas antiguas absolutas.
- `prepare_subset()` devuelve una lista con elementos `csv`, `txt`, `geojson`, `header`; el runner ha sido adaptado para usar `res$csv` correctamente.
- Para la corrida posterior (scenario), el script ahora usa la clave especial ``-DFROM_RESTART`` en la tabla de parámetros para que `lpjmlkit::write_config()` genere la macro adecuada en la configuración de LPJmL.

Cambios realizados (resumen para commit/PR)

- Preferencia por `inputs/grid.bin(.json)` cuando existe en repo (evita dependencias de rutas absolutas externas).
- Manejo correcto del valor devuelto por `prepare_subset()` (usar `res$csv`).
- Usar ``-DFROM_RESTART`` en `simulation_params` para escribir la macro de restart correctamente.
- Pequeña nota en este documento con el comando WSL que fue probado exitosamente (arranca en background y escribe log en `/tmp/run_spain_full_350.log`).

Archivos temporales o wrappers

- `R/run_spain_with_repo_grid.R` existe como wrapper que simplemente define `gridbin`/`grid_json` y sourcea el runner. No fue necesario para la ejecución final; puedes borrarlo si quieres mantener el repositorio más limpio, pero es inofensivo y puede servir como ejemplo.
- No he encontrado `tmp_run_spain_now.R` en el repo.
