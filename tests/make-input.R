#!/usr/bin/env Rscript
source('bin/pipeline.R')
source('tests/fixture.R')
args <- commandArgs(TRUE)
if (length(args) < 1L) stop('Usage: Rscript tests/make-input.R DIRECTORY [CASE]')
case <- if (length(args) > 1L) args[2] else 'high_crt'
if (!(case %in% names(pipeline_fixture_cases()))) stop('Unknown fixture case: ', case)
f <- do.call(pipeline_fixture, pipeline_fixture_cases()[[case]])
dir.create(args[1], recursive = TRUE, showWarnings = FALSE)
saveRDS(f$config, file.path(args[1], 'config.rds'))
saveRDS(package_identity(), file.path(args[1], 'lock.rds'))
create_input(f$object, file.path(args[1], 'input'), f$config)
