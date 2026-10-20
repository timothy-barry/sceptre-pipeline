# Bounded report consumer contract

Status: the pipeline consumer is implemented and small contract tests pass.
The package object/store adapter, actual disk-backed qualification and final
runtime acceptance remain pending. This document does not qualify a scale or a
scientific method.

`bin/report_bundle.R` consumes three independent operations. The source object
is never serialized or frozen in the report. W01 owns correction, result-store
readers and the streaming CSV exporter; W05 owns object/family handles, native
payload/provenance and portable save/reopen. The report owns presentation only.

- `describe(key)` returns completed/omitted/unavailable/failed and exact
  `summary$returned_rows`, `pass_qc_rows`, `significant_rows`, method and bounded
  provenance. Missing significance counts mean undefined, not zero. Counts
  describe the full saved family, including failed-QC rows when supplied.
- `read_preview(key, n)` returns exactly the first `n` canonical saved rows,
  with `n <= 100`. The consumer retains at most 32 scalar columns and 500 text
  characters per value, rebuilding columns to remove arbitrary result-record
  and global-provenance attributes. Excluded columns/counts are labelled.
- `export_csv(key, target)` writes all scalar rows by streaming and returns
  `complete = TRUE`, `rows`, `sha256`, optional `bytes`, column names and omitted
  columns. The consumer checks the receipt and file size without rereading the
  complete CSV. Qualification independently checks its row count/hash/values.
- `export_native(key, directory)` retains complete native values and exact
  analysis provenance, including list/matrix fields unavailable in CSV. It
  returns a relative `manifest` file, full `rows`, its `sha256`,
  `complete = TRUE` and `provenance_complete = TRUE`. The manifest and every
  payload it references must be portable inside the copied bundle. A scalar
  CSV plus bounded preview is not a complete native result. Missing/incomplete
  native exports fail reporting rather than silently losing fields.

The package API proposed by W01 is `result_store_summary()`,
`result_store_preview()`, `result_store_iterator()`, `export_result_store()` and
explicit-budget `materialize_result_store()`. The object-to-store getter and
portable native writer are being agreed with W05. The report source callbacks
will map these APIs; they do not implement storage or correction themselves.
The explicit disk backend may require checked Python/SQLite versions. Default
small in-memory package use does not acquire a mandatory Python dependency.

`capture_report_source()` performs only fixed-prefix capture and bounded
metadata traversal. `write_report_source()` separately invokes the complete
CSV/native exporters, copies original config/manifest files as raw byte streams,
and saves a small schema-2 `report-data.rds`. Export I/O grows with the complete
family; the report does not claim constant total export time or disk space.
The fixed report capture/render memory and time are measured separately from
complete export I/O. No report step runs correction or advances scientific RNG.

Plots show saved-row p-values from the deterministic prefix with explicit
preview/total/finite/omitted counts. They are not full-family QQ/calibration
plots. Full-family significance counts come from the certified summary, never
from counting only preview flags. Native/CSV/manifest links remain relative.

Retain the whole report directory with `native/`, `tables/`, `plots/`, original
provenance files, renderer and manifests. `Rscript --vanilla rerender.R` uses
only the small frozen view and base R. A renderer failure leaves complete
exports and the frozen view available; report status records failure separately.
The source scientist's artifact is never mutated to repair presentation.

Small executable contract tests: `Rscript --vanilla report/check-bundle.R`.
They verify exact total/preview distinctions, no attached global-family leakage,
unchanged RNG, partial receipt rejection, a list-column tail sentinel outside
the preview retained through native export/relocation, every generated relative
asset link, and induced-renderer recovery. Actual 10xH store/RSS/time/export
correction checks and final pipeline runtime tests have separate receipts.
