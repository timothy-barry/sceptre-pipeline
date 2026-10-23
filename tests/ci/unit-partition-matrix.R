#!/usr/bin/env Rscript
# Supplement nf-test scheduling with exact numerical partition-boundary coverage.
source("bin/pipeline.R")
source("bin/distributed.R")
source("tests/fixture.R")
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L)
root <- args[1]
dir.create(root, recursive = TRUE, showWarnings = FALSE)
lock <- package_identity()
seed <- 271828L
plain <- function(x) {
    if (isS4(x)) return(list(class = class(x), slots = stats::setNames(
        lapply(methods::slotNames(x), function(n) plain(methods::slot(x, n))), methods::slotNames(x))))
    if (is.data.frame(x)) return(list(class = class(x), names = names(x),
        row_names = rownames(x), columns = lapply(x, plain)))
    if (is.list(x)) return(lapply(x, plain))
    x
}
same <- function(a, b, label) if (!identical(plain(a), plain(b))) stop(label, ": ",
    paste(all.equal(plain(a), plain(b)), collapse = "; "))
report <- list(runtime = lock, cases = list(), uneven_observed = FALSE)
for (name in c("low_nt_permutation", "high_empirical_crt")) {
    path <- file.path(root, name)
    dir.create(path)
    f <- do.call(pipeline_fixture, pipeline_fixture_cases()[[name]])
    input <- file.path(path, "input")
    create_input(f$object, input, f$config, identity = lock)
    for (stage in c("parameters", "assignment", "qc")) {
        output <- file.path(path, stage)
        run_stage(f$config, input, output, stage, seed, identity = lock)
        input <- output
    }
    initial <- read_bundle(input, f$config, lock)
    restore_execution_rng(initial$manifest, seed)
    direct <- sceptre::run_discovery_analysis(initial$object, print_progress = FALSE,
        parallel = FALSE, output_amount = f$config$execution$output_amount)
    expected_rng <- list(kind = RNGkind(), state = .Random.seed)
    family <- "run_discovery_analysis"
    assert_empirical_budget(direct@results[[sub("^run_", "", family)]]$provenance$plan, "discovery", f$config)
    rows <- list()
    for (n_units in c(1L, 2L, 3L, 99L)) {
        label <- paste0("units-", n_units)
        plan <- file.path(path, paste0(label, "-plan"))
        execution <- prepare_distributed(f$config, input, plan, "discovery", seed,
            n_units, backing = NULL, lock = lock)
        keys <- lapply(execution$units, function(unit) unit$keys)
        lengths <- lengths(keys)
        if (length(unique(lengths)) > 1L) report$uneven_observed <- TRUE
        stopifnot(length(keys) <= n_units, all(lengths > 0L), !anyDuplicated(unlist(keys)))
        if (n_units == 1L) stopifnot(length(keys) == 1L)
        if (n_units == 99L) stopifnot(all(lengths == 1L))
        proposals <- character()
        for (unit in rev(execution$units)) {
            proposal <- file.path(path, paste0(label, "-", unit$id, ".rds"))
            run_distributed_unit(f$config, input, plan, proposal, "discovery", seed,
                unit$id, backing = NULL, lock = lock)
            proposals <- c(proposals, proposal)
        }
        output <- file.path(path, label)
        collect_distributed(f$config, input, plan, proposals, output, "discovery", seed,
            backing = NULL, lock = lock)
        actual <- read_bundle(output, f$config, lock)
        same(sceptre::get_result(actual$object, paste0("run_", sub("^run_", "", family))), sceptre::get_result(direct, paste0("run_", sub("^run_", "", family))), paste(name, label, "table"))
        same(actual$object@results[[sub("^run_", "", family)]]$provenance$plan,
            direct@results[[sub("^run_", "", family)]]$provenance$plan, paste(name, label, "global plan"))
        same(actual$object@fits, direct@fits, paste(name, label, "fits"))
        same(actual$manifest$rng_kind, expected_rng$kind, paste(name, label, "RNG kind"))
        same(actual$manifest$rng_state, expected_rng$state, paste(name, label, "RNG state"))
        rows[[label]] <- list(passed = TRUE, requested_units = n_units,
            realized_units = length(keys), keys_per_unit = lengths)
        message("PASS partition ", name, " ", label)
    }
    report$cases[[name]] <- rows
}
stopifnot(report$uneven_observed)
saveRDS(report, file.path(root, "unit-partition-matrix.rds"))
message("PASS exact partition matrix: one, multiple, uneven and excess work units")
