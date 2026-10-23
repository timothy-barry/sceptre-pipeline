#!/usr/bin/env Rscript
# Compare actual native module artifacts to certified public results.
source('bin/pipeline.R')
source('bin/scientific_report.R')
source('report/check-reference.R')
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
mode <- args[1]; fixtures <- args[2]; output <- args[3]
config <- readRDS(file.path(fixtures, 'config.rds'))
lock <- readRDS(file.path(fixtures, 'lock.rds'))
state <- function(name) read_bundle(file.path(fixtures, name), config, lock)
plain_result <- function(x) {
    # data.table self-reference addresses are process-local, not scientific data.
    if (is.data.frame(x)) attr(x, '.internal.selfref') <- NULL
    x
}
same_result <- function(actual, expected) {
    stopifnot(identical(plain_result(actual), plain_result(expected)))
}
if (mode == 'collect') {
    actual <- read_bundle(output, config, lock)
    reference <- state('reference-discovery')
    before <- state('qc')
    stopifnot(identical(actual$manifest$completed, c(before$manifest$completed, 'discovery')),
        identical(names(Filter(Negate(is.null), actual$object@results)), 'discovery_analysis'),
        identical(actual$manifest$parent_sha256, hash_file(file.path(fixtures, 'qc', 'manifest.rds'))),
        identical(actual$manifest$execution$mode, 'distributed'),
        identical(actual$manifest$execution$units, readLines(file.path(fixtures, 'execution', 'unit_ids.txt'))))
    same_result(sceptre::get_result(actual$object, 'run_discovery_analysis'),
        sceptre::get_result(reference$object, 'run_discovery_analysis'))
    stopifnot(identical(actual$object@preparation@analysis_cells, before$object@preparation@analysis_cells))
} else {
    stopifnot(mode %in% c('export-discovery', 'export-qc'))
    selected <- if (mode == 'export-discovery') 'discovery' else 'qc'
    original <- state(selected)
    report_dir <- file.path(output, 'scientific-report')
    report <- readRDS(file.path(report_dir, 'report-data.rds'))
    receipt <- jsonlite::read_json(file.path(report_dir, 'report-status.json'))
    stopifnot(identical(receipt$status, 'completed'),
        file.info(file.path(report_dir, 'report.html'))$size > 0,
        identical(readRDS(file.path(report_dir, 'manifest.rds')), original$manifest),
        identical(readRDS(file.path(report_dir, 'requested-config.rds')), config),
        report$qc$retained_cells == length(original$object@preparation@analysis_cells))
    for (family in c('calibration', 'power', 'discovery')) {
        csv <- file.path(report_dir, 'tables', paste0(family, '.csv'))
        if (family == 'discovery' && selected == 'discovery') {
            expected <- sceptre::get_result(original$object, 'run_discovery_analysis')
            check_report_reference(report_dir, family, expected)
        } else {
            stopifnot(identical(report$analyses[[family]]$status, 'omitted'), !file.exists(csv),
                is.null(report$analyses[[family]]$table))
        }
    }
}
message('PASS native module semantic assertions: ', mode)
