#!/usr/bin/env Rscript
source("bin/diagnostics.R")
cases <- c(
    "Two or more non-targeting gRNAs must be present to run the calibration check",
    "`calibration_group_size` exceeds the active non-targeting gRNA count after QC (1).",
    "Zero pairs pass pairwise QC. Cannot run analysis.",
    "Discovery pairs have not been supplied.",
    "Modalities must have aligned cells",
    "Backed artifact requires an explicitly staged backing directory.",
    "Artifact configuration mismatch; start from a new input bundle.")
for (text in cases) {
    output <- capture.output(report_pipeline_failure(simpleError(text)), type = "message")
    stopifnot(any(grepl(text, output, fixed = TRUE)),
        any(grepl("Recovery checks (no settings changed)", output, fixed = TRUE)))
}
stopifnot(identical(pipeline_recovery_hint("unrelated numerical failure"), ""))
source("bin/scientific_report.R")
x <- list(title = "edge case", qc = list(), analyses = list(
    discovery = list(status = "completed", table = data.frame(p_value = seq_len(101L)), provenance = list())),
    plots = character())
x$analyses$discovery$table$draws <- I(lapply(seq_len(101L), identity))
html <- scientific_report_html(x, NULL)
stopifnot(grepl("Non-scalar columns omitted from this HTML table and CSV: draws", html, fixed = TRUE),
    grepl("Showing the first 100 of 101 rows", html, fixed = TRUE),
    nrow(x$analyses$discovery$table) == 101L, length(x$analyses$discovery$table$draws) == 101L)
x$analyses$discovery$table <- data.frame(p_value = numeric())
stopifnot(grepl("Completed with no returned rows; this is not evidence of no effects.", scientific_report_html(x, NULL), fixed = TRUE))
cat("PASS original errors retained; known recovery hints; unknown errors unchanged; nested-column and row truncation disclosure; completed empty result label\n")
