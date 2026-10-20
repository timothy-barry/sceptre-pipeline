> Publication scope: historical validation below refers to the explicitly named original source/runtime. Detailed local evidence and raster previews are not distributed in this review branch. This publication commit has its own pending qualification; see the publication scope document.

# Scientific results report

Each successful pipeline export attempts to create
`exports/scientific-report/report.html` from the saved SCEPTRE state. This is a
scientific report, distinct from Nextflow's execution/timeline reports and this
documentation website. It requires no network assets or Quarto installation.

The report includes assignment membership counts; imported/retained/excluded
cells and saved QC metrics; requested, compiled and passing hypothesis counts;
calibration and positive-control results when run; discovery tables and saved
significance flags; exported figures; captured pipeline warnings; requested
versus resolved settings; realized per-analysis budgets/families; and exact
pipeline/package/source provenance with seed/RNG handoff and checksums.

The renderer reads completed results through the public getter. It does not fit,
sample, integrate guides, adjust p-values or change results. Calibration is
optional. Omitted stages, completed empty tables and unavailable outputs are
identified honestly. Positive-control results describe the supplied pairs, not
universal power. Statistical associations do not establish biological mechanisms.
Scalar table columns are inspectable in the HTML and downloadable as CSV; the
RDS retains the full public results, including nested columns and provenance.

## Bounded HTML previews

Each HTML table shows at most the first 100 rows in saved order, with explicit
row counts and truncation labels. Settings/provenance previews also have fixed
entry, nesting and text limits. Important plan budgets, scientific settings,
seed and source identity appear before large canonical arrays. The complete
public results, requested/resolved settings and provenance remain in the frozen
RDS; CSV downloads retain every row and complete scalar values. No hypothesis is
removed from scientific correction because its HTML row is outside the preview.

The production exporter no longer serializes the entire count/result object
twice just to assert nonmutation. Real-state regression checks retain the
nonmutation guarantee, including identical full CSV bytes and frozen inputs
apart from the generation timestamp.

The saved memory study (historical evidence retained locally)
compares the same 100,000-row input before/after this rendering change: whole-
process peak RSS was approximately 491 MB versus 98 MB, and HTML was 26.7 MB
versus 19 KB. In a separate 100,000-to-1,000,000-row sweep, HTML stayed near 19 KB
and tracked renderer allocations near 6 MB. These are local presentation checks,
not scientific execution or atlas-scale benchmarks. Complete input memory and
CSV/RDS size still grow with the result family; allocation totals are not peak
RSS. `report/check-memory.R` preserves the bounded-view/full-data regression.

## Rerender without rerunning science

Copy the whole `scientific-report` directory, then run inside it:

```bash
Rscript -e 'source("render.R"); scientific_report_html(readRDS("report-data.rds"), "report.html")'
```

The default renderer needs base R only for presentation. It reads the frozen
bundle, not the original counts, live count handles, Nextflow work directory or
an analysis runtime. Do not edit `report-data.rds` if it is being used as evidence;
keep an immutable original and customize `render.R`, CSS or narrative instead.
An optional editable Quarto entry point is provided:

```bash
quarto render report.qmd
```

That path additionally needs Quarto and knitr. Its code emits the same report
fragment from frozen data. Plot files and CSVs use relative paths, so retain the
`plots/` and `tables/` directories when moving a bundle. No publishing is done.

## Failure and provenance boundary

`report-status.json` records `completed` or `failed` with a reason. A rendering
failure is isolated from the completed scientific result: the pipeline retains
its scientific artifacts and reports the presentation failure separately.
Rerender after correcting the renderer/environment; rerunning science is not
required. Warnings during analysis are captured without suppressing them and
remain attached to the pipeline manifest with their stage. Distributed worker warning aggregation is unavailable in this report; those
warnings remain in execution logs. An empty captured list does not mean no
distributed warnings occurred. Earlier imports may also have warnings outside
that capture scope; absence of recorded warnings is not a
universal warning-free guarantee.

`manifest.rds`, `requested-config.rds` and the frozen result provenance are
retained for review. Frozen RunPlans expose realized B1/B2/B3 and calibration
choices; canonical requested pairs remain distinct from expanded/QC guide rows.
The complete-family correction policy belongs to SCEPTRE; the report copies its
significance flags rather than substituting a local correction. The source
receipt is taken from the container when available, with installed runtime
identity retained in all cases. Timestamp/session differences are presentation
and execution metadata, not altered scientific settings.

## Local presentation evidence

The saved qualification receipt (historical evidence retained locally),
report check log (historical evidence retained locally) and
desktop review image (historical evidence retained locally) retain
the local presentation checks. The default-build synthetic demo has a separate
receipt (historical evidence retained locally) and
execution log (historical evidence retained locally).
These are bounded local checkpoints; automatic scientific comparisons and their
exact source hashes are recorded in the [CI evidence](ci.md).
