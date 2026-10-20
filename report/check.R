#!/usr/bin/env Rscript
# Real saved-state tests, run in the qualified image from the repository root.
args <- commandArgs(TRUE)
if (length(args) != 1L) stop('Usage: Rscript report/check.R NEW_DIRECTORY')
source('demo/make-input.R')
source('bin/scientific_report.R')
helper <- normalizePath('bin/scientific_report.R')
config <- readRDS(file.path(args[1], 'config.rds'))
identity <- readRDS(file.path(args[1], 'lock.rds'))
state <- read_bundle(file.path(args[1], 'input'), config, identity)
before <- serialize(state$object, NULL)
input_hash <- hash_file(file.path(args[1], 'input', 'sceptre_object.rds'))
omitted <- file.path(args[1], 'omitted-report')
stopifnot(write_scientific_report_safely(state$object, state$manifest, config, omitted, helper))
x <- readRDS(file.path(omitted, 'report-data.rds'))
stopifnot(all(vapply(x$analyses, function(a) identical(a$status, 'omitted'), logical(1))),
    is.na(x$qc$retained_cells), identical(serialize(state$object, NULL), before))
failed <- file.path(args[1], 'failed-report')
stopifnot(!write_scientific_report_safely(state$object, state$manifest, config, failed, helper,
    renderer = function(...) stop('deliberate renderer failure')),
    jsonlite::fromJSON(file.path(failed, 'report-status.json'))$status == 'failed',
    identical(hash_file(file.path(args[1], 'input', 'sceptre_object.rds')), input_hash),
    identical(serialize(state$object, NULL), before))
# Presentation edge cases use synthetic copies of the frozen report input;
# they are not committed scientific results.
unavailable_manifest <- state$manifest
unavailable_manifest$completed <- 'discovery'
unavailable <- file.path(args[1], 'unavailable-report')
stopifnot(write_scientific_report_safely(state$object, unavailable_manifest, config, unavailable, helper),
    readRDS(file.path(unavailable, 'report-data.rds'))$analyses$discovery$status == 'unavailable')
empty_view <- x
empty_view$analyses$discovery <- list(status = 'completed', table = data.frame(p_value = numeric()), provenance = list())
empty_html <- scientific_report_html(empty_view, NULL)
stopifnot(grepl('Structured aggregation of distributed worker warnings is unavailable', empty_html, fixed = TRUE),
    grepl('0 returned rows', empty_html, fixed = TRUE), grepl('No rows available.', empty_html, fixed = TRUE))
input <- file.path(args[1], 'input')
for (stage in c('parameters', 'assignment', 'qc', 'discovery')) {
    output <- file.path(args[1], stage)
    run_stage(config, input, output, stage, 271828, identity = identity)
    input <- output
}
state <- read_bundle(input, config, identity)
before <- serialize(state$object, NULL)
completed <- file.path(args[1], 'discovery-report')
stopifnot(write_scientific_report_safely(state$object, state$manifest, config, completed, helper))
x <- readRDS(file.path(completed, 'report-data.rds'))
public <- sceptre::get_result(state$object, 'run_discovery_analysis')
stopifnot(x$analyses$calibration$status == 'omitted', x$analyses$power$status == 'omitted',
    x$analyses$discovery$status == 'completed', x$qc$retained_cells == 315L,
    identical(x$analyses$discovery$table$p_value, public$p_value),
    identical(x$analyses$discovery$table$significant, public$significant),
    identical(serialize(state$object, NULL), before),
    identical(x$provenance$manifest$seed, 271828L),
    identical(x$analyses$discovery$provenance$plan$B1, 499L))
# A failed renderer cannot invalidate an already completed scientific artifact.
science_hash <- hash_file(file.path(input, 'sceptre_object.rds'))
stopifnot(!write_scientific_report_safely(state$object, state$manifest, config,
    file.path(args[1], 'failed-after-science'), helper, renderer = function(...) stop('render failed after science')),
    identical(hash_file(file.path(input, 'sceptre_object.rds')), science_hash))
frozen_hash <- hash_file(file.path(completed, 'report-data.rds'))
# Fresh base-R presentation process: no package analysis namespace is loaded.
rerender <- file.path(completed, 'rerender-check.R')
writeLines(c('source("render.R")', 'stopifnot(!"sceptre" %in% loadedNamespaces())',
    'scientific_report_html(readRDS("report-data.rds"), "rerender.html")',
    'stopifnot(!"sceptre" %in% loadedNamespaces())'), rerender)
old <- setwd(completed)
status <- system2(file.path(R.home('bin'), 'Rscript'), c('--vanilla', 'rerender-check.R'))
setwd(old)
stopifnot(status == 0L, file.exists(file.path(completed, 'rerender.html')),
    identical(hash_file(file.path(completed, 'report-data.rds')), frozen_hash))
cat('PASS report: real discovery without calibration; omitted-stage labels; public values/seed/budgets; failure isolation; immutable base-R rerender\n')
