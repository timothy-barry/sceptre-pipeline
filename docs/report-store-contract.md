# Bounded report consumer contract

Status: the pipeline consumer is implemented and small contract tests pass.
The exact W05 public view/context binding and export-stage forwarding are now
source-integrated. Actual installed disk-backed qualification and final runtime
acceptance remain pending. This document does not qualify a scale or a
scientific method.

`bin/report_bundle.R` consumes four independent operations. The source object
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

The public object route binds W05 result-view APIs at 2e9779be and
`get_report_context(object, analyses, assignment_rows=100L, max_bytes=256*1024)`
at d4bed1c7. Only manifest-selected discovery/power names request exact legacy
QC scans; calibration metadata comes from its saved result view. Summaries and
prefixes have explicit row/column/byte bounds. Complete CSV/native exports are
separate and all borrowed views close on success or failure. The producer never
calls the eager `write_outputs_to_directory()` or full `get_result()`.
`export_state.R` forwards original config/manifest file paths for byte copying
after the certified native schema-7 state loader.
W06/W10 loader, capability and runtime integration remain separate owners/gates.
The direct store route binds W01 `result_store_summary`, `result_store_preview`,
`export_result_store` and `export_result_store_bundle` without another correction
engine. Explicit disk use may require checked Python/SQLite versions; default
small in-memory use does not acquire a mandatory Python dependency.

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

The initial W01 disk prototype rejected list/matrix/custom-S3 result columns.
Final scalable acceptance must cover the actual W12 schema, including scalar
`p_value_source` and nested/list `spa_diagnostics`, Bonferroni per-guide IDs,
QC/p-values/source/original diagnostic lists, and actual output-3 null fields.
The complete native route must preserve those fields and their types, nested
attributes and order, with bounded storage/reads and portable provenance. A
scalar SQL projection can perform correction while the native route retains
the original payload. Unknown unadvertised classes may fail explicitly before
publication; silently dropping supported scientific fields is not permitted.
See W12's `tools/accelerations/result-schema.md` (8d0daf1e) and
`test-saddlepoint-integration.R` for the source/test schema contract. This is
not yet actual package/store integration qualification.

The adapter projects at most 32 named scalar columns before reading rows.
Without an explicit `scalar_columns` declaration it reads only known scalar
fields, never an early native/list diagnostic merely because it appears in
the schema. Complete CSVs retain every scalar field/row by default, with native
omissions disclosed. W01's planned portable operation is
`export_result_store_bundle()` with `open_result_store()` relocation.

## Actual-store qualification commands (not yet executed)

Use an exact candidate library and already produced W01 stores with at least a
10-fold H difference; do not generate another correction engine or prototype
sweep. Run each store in a fresh R process through the shared lease wrapper,
using platform `time` tooling for whole-process RSS:

```bash
R_LIBS=/exact/candidate/library Rscript --vanilla report/measure-store.R STORE_ROOT NEW_OUTPUT
R_LIBS=/exact/candidate/library Rscript --vanilla report/check-store-reference.R STORE_ROOT REFERENCE_RDS MAX_ADMITTED_BYTES RECEIPT_JSON
```

The first records capture/render allocations/time and small frozen-view size
separately from complete CSV/native export I/O, independently streams CSV bytes
once for a count and SHA256, compares every native source/copied iterator
chunk, checks RNG and base-R rerender. Allocation totals are not peak RSS;
external process RSS includes store opening, export and verification. The
second deliberately loads an explicitly admitted full R-native reference in a
separate process and compares every column value/type/attribute/order, including
full corrected p-values and native payload. Such reference loading is a
qualification cost, never part of report production or its bounded-memory claim.
Actual package API/storage/schema integration and receipts are still required.

The full native reference comparison uses strict numeric/NA/attribute identity
(`num.eq = FALSE`, `single.NA = FALSE`, `attrib.as.set = FALSE`), including signed
zero and native nested fields. CSV is a scalar textual projection with native
omissions disclosed; exact native types/attributes are checked in the complete
native bundle, not inferred from CSV row counts or its byte hash.
