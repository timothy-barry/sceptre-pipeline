# Scientific results report

A successful export attempts to create
`exports/scientific-report/report.html` from the validated native package state.
This is separate from Nextflow's execution reports. The producer obtains saved
results through public `get_result()`; reporting does not fit, sample, integrate
or adjust results.

The report includes saved family results, available QC/assignment information,
requested/resolved settings and source/runtime provenance. Omitted, unavailable
and empty results are distinguished. Full scalar CSV and native RDS tables are
retained in `tables/`; HTML previews are truncated and labelled. Full result
materialization and export can consume memory proportional to the result family.
No fixed-memory producer or full-screen scale qualification is claimed.

The frozen `report-data.rds`, `manifest.rds`, `requested-config.rds` and editable
renderer preserve rerendering without counts or Nextflow work directories. Copy
the whole report directory and run:

```bash
Rscript rerender.R
```

Optional `report.qmd` requires Quarto and knitr. Keep table/plot files together
when relocating the report. Preserve original report inputs when using them as
evidence; customize the renderer or narrative separately.

`report-status.json` records completion or failure. A renderer failure does not
rewrite scientific results. `Rscript report/check.R NEW_DIRECTORY` exercises
real saved-state reporting, values, omitted-stage handling, nonmutation and
failure isolation in the current runtime. Historical bounded producer, compact
view and memory receipts do not qualify this native report implementation.
