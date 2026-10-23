# Exact public schema-7 result export oracle.
check_report_reference <- function(report_dir, key, expected) {
    report <- readRDS(file.path(report_dir, "report-data.rds"))
    actual <- report$analyses[[key]]
    stopifnot(actual$status == "completed", actual$total_rows == nrow(expected),
        identical(actual$table, utils::head(as.data.frame(expected), 100L)))
    saved <- readRDS(file.path(report_dir, "tables", paste0(key, ".rds")))
    stopifnot(identical(as.data.frame(saved), as.data.frame(expected)))
    temporary <- tempfile(fileext = ".csv")
    on.exit(unlink(temporary), add = TRUE)
    utils::write.csv(report_scalar_table(expected), temporary, row.names = FALSE)
    stopifnot(identical(digest::digest(file = temporary, algo = "sha256"),
        digest::digest(file = file.path(report_dir, "tables", paste0(key, ".csv")), algo = "sha256")))
    invisible(TRUE)
}
