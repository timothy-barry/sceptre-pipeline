#!/usr/bin/env Rscript
# Inspect a completed real demo, inside the same pinned runtime.
args <- commandArgs(TRUE)
if (length(args) != 1L) stop('Usage: Rscript demo/check-output.R DEMO_RUN_DIRECTORY')
source('bin/pipeline.R')
source('bin/scientific_report.R')
source('report/check-reference.R')
root <- args[1]
config <- readRDS(file.path(root, 'fixture', 'config.rds'))
lock <- readRDS(file.path(root, 'fixture', 'lock.rds'))
validate_identity(lock)
state <- read_bundle(file.path(root, 'results', 'discovery', 'state'), config, lock)
report_dir <- file.path(root, 'results', 'exports', 'scientific-report')
stopifnot(jsonlite::fromJSON(file.path(report_dir, 'report-status.json'))$status == 'completed')
report <- readRDS(file.path(report_dir, 'report-data.rds'))
plain <- function(x) {
    if (is.data.frame(x)) return(list(names = names(x), columns = lapply(as.list(x), plain)))
    if (is.list(x)) return(lapply(x, plain))
    x
}
for (stage in c('calibration', 'power', 'discovery')) {
    name <- switch(stage, calibration = 'run_calibration_check', power = 'run_power_check', discovery = 'run_discovery_analysis')
    stopifnot(report$analyses[[stage]]$status == 'completed',
        check_report_reference(report_dir, stage, sceptre::get_result(state$object, name)),
        file.exists(file.path(report_dir, 'tables', paste0(stage, '.csv'))))
}
stopifnot(report$qc$imported_cells == 320L, report$qc$retained_cells == 315L,
    report$qc$excluded_cells == 5L, sum(!report$analyses$discovery$table$pass_qc) == 1L,
    report$provenance$manifest$seed == 271828L,
    identical(report$provenance$manifest$package, lock),
    file.exists(file.path(root, 'demo-receipt.json')),
    file.exists(file.path(report_dir, 'report.qmd')),
    file.exists(file.path(root, 'results', 'pipeline_info', 'report.html')))
cat('PASS demo: all three previews/full CSV/native columns equal public saved results; QC, runtime, seed, source bundle and execution report present\n')
