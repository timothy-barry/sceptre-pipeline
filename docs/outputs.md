# Outputs

Each completed stage is published under `OUTDIR/STAGE/`:

- `state/sceptre_object.rds`: usable schema-7 object; backed handles are closed.
- `state/manifest.rds`: versioned pipeline certificate and resolved run settings.
- `state/analysis_summary.txt`: package-rendered object summary.
- `state/versions.txt` and `versions.yml`: exact package implementation identity.
- `state/results_calibration.rds`, `results_power.rds`, or `results_discovery.rds`
  in the corresponding association stage: current full-family public result.

The final `exports/` directory preserves the package's standard plots, result
tables, analysis summary and `grna_assignment_matrix.rds`, through the public
exporter. Report failure does not rewrite the certified scientific artifact.

Earlier family tables remain in the final object's certified result records.
Use public `get_result()` for current/historical validity checks. Power's output
uses package-defined guide integration and is not relabeled as a discovery
significance family. Calibration and discovery perform their package-owned
full-family correction once.

`pipeline_info/` contains Nextflow trace, HTML report, timeline and DAG. On macOS
without a container, Nextflow does not report task runtime metrics; a successful
trace is not a memory benchmark. These artifacts describe actual executed tasks;
configuration alone does not establish hosted CI or scheduler qualification.
