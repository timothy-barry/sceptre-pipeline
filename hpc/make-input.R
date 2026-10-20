#!/usr/bin/env Rscript
# Run inside the same SIF that executes the pipeline and direct comparison.
source("bin/pipeline.R")
source("tests/fixture.R")
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
case <- args[2]
backed <- identical(case, "low_nt_permutation_backed")
base <- if (backed) "low_nt_permutation" else case
stopifnot(base %in% c("low_nt_permutation", "high_empirical_crt"))
dir.create(args[1], recursive = TRUE)
options <- pipeline_fixture_cases()[[base]]
backing <- NULL
if (backed) {
    backing <- file.path(args[1], "backing")
    dir.create(backing)
    options <- c(options, list(backed = TRUE, directory = backing))
}
fixture <- do.call(pipeline_fixture, options)
lock <- package_identity()
saveRDS(fixture$config, file.path(args[1], "config.rds"))
saveRDS(lock, file.path(args[1], "lock.rds"))
create_input(fixture$object, file.path(args[1], "input"), fixture$config,
    backing = backing, identity = lock)
message("Created same-SIF immutable input and runtime lock: ", case)
