# Scientific report source and checks

The production implementation is `bin/scientific_report.R`, sourced by
`bin/export_state.R` after public scientific exports succeed. Its default Quarto
entry point is an R literal so the existing staged, identity-bound `bin/*.R`
bundle contains every rendering dependency. No extra Nextflow mount, template
lookup, network assets or Quarto runtime is needed for default HTML generation.
Each output bundle contains its own editable `render.R` and `report.qmd`.

Run the saved-state checks inside the same qualified image used for science:

```bash
Rscript report/check.R NEW_TEST_DIRECTORY
```

The checks execute real public discovery without calibration, compare public
scientific values and frozen seed/budgets, verify omitted/unavailable/empty
presentation, inject renderer failures before and after scientific completion,
check input/object hashes, and rerender frozen data in a fresh base-R process
without loading SCEPTRE. The injected empty/unavailable views are presentation
fixtures, never completed scientific artifacts.

`demo/check-output.R DEMO_RUN_DIRECTORY` checks all three real scientific tables
against saved public getters, QC retention and failed requests, runtime/seed,
source bundle and Nextflow execution-report presence after an actual demo run.
CI invokes these checks with the qualified container; presentation checks do not
replace direct/pipeline scientific-equivalence tests.

User guidance: [scientific report](../docs/report.md) and
[one-command demo](../docs/demo.md). Neither report generation nor rerendering
publishes anything.


HTML tables show at most the first 100 saved rows. Settings and provenance use
bounded previews (up to 64 short scalar settings and 12 other entries/rows per
field, 5 nesting levels, 512 visited entries, 500 characters per value, 20,000 displayed characters per section).
The page explicitly identifies these limits and links to complete frozen inputs;
complete scalar-column CSV downloads and `report-data.rds` are preserved.
Production reporting uses read-only getters and snapshots. Full scientific-object
nonmutation checks remain in `report/check.R` on small real states, avoiding two
whole-object serialization buffers during ordinary export.

The independent base-R memory regression creates growing synthetic result and
provenance tables, verifies a fixed HTML preview and allocation cap, and checks
that all CSV rows and saved input hashes survive unchanged:

```bash
Rscript report/check-memory.R NEW_DIRECTORY 100000 render
Rscript report/check-memory.R ANOTHER_DIRECTORY 1000000 render
```

For process RSS comparisons, run matching `baseline` cases under an external
process timer. Complete frozen inputs still occupy memory proportional to their
size; the bounded guarantee covers HTML construction, not loading the full report
bundle or constructing scientific results.
