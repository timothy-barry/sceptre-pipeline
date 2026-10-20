#!/usr/bin/env Rscript
# Real certified artifacts for direct module and subworkflow contract tests.
source('bin/pipeline.R')
source('bin/distributed.R')
source('tests/fixture.R')
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L, !dir.exists(args[1]))
dir.create(args[1], recursive = TRUE)
root <- normalizePath(args[1])
f <- do.call(pipeline_fixture, pipeline_fixture_cases()[['high_crt']])
config <- f$config
lock <- package_identity()
seed <- 271828L
backing <- normalizePath('resources/empty_backing')
saveRDS(config, file.path(root, 'config.rds'))
saveRDS(lock, file.path(root, 'lock.rds'))
create_input(f$object, file.path(root, 'input'), config, identity = lock)
previous <- 'input'
for (stage in c('parameters', 'assignment', 'qc')) {
    run_stage(config, file.path(root, previous), file.path(root, stage), stage,
        seed, backing, lock)
    previous <- stage
}
qc <- file.path(root, 'qc')
execution <- file.path(root, 'execution')
prepare_distributed(config, qc, execution, 'discovery', seed, 3L, backing, lock)
ids <- readLines(file.path(execution, 'unit_ids.txt'))
stopifnot(identical(ids, c("unit-000001", "unit-000002")))
dir.create(file.path(root, 'proposals'))
proposals <- file.path(root, 'proposals', paste0('proposal_', ids, '.rds'))
for (i in seq_along(ids)) {
    run_distributed_unit(config, qc, execution, proposals[i], 'discovery', seed,
        ids[i], backing, lock)
}
collect_distributed(config, qc, execution, proposals, file.path(root, 'discovery'),
    'discovery', seed, backing, lock)
run_stage(config, qc, file.path(root, 'reference-discovery'), 'discovery', seed,
    backing, lock)
message('Prepared certified module fixtures: ', root)
