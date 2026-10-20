#!/usr/bin/env Rscript
# Run from repo root with an isolated qualified package in R_LIBS.
# REQUIRE_ONDISC=true also requires the optional supported backed qualification.
source("tests/fixture.R")
source("bin/pipeline.R")
source("bin/distributed.R")

plain <- function(x) {
    if (isS4(x)) return(list(class = class(x), slots = stats::setNames(
        lapply(methods::slotNames(x), function(n) plain(methods::slot(x, n))), methods::slotNames(x))))
    if (is.data.frame(x)) return(list(class = class(x), names = names(x),
        row_names = rownames(x), columns = lapply(x, plain)))
    if (is.list(x)) return(lapply(x, plain))
    x
}
same <- function(actual, expected, label) {
    if (!identical(plain(actual), plain(expected))) stop(label, ": ",
        paste(all.equal(plain(actual), plain(expected)), collapse = "; "))
}
owned <- function(x) unserialize(serialize(x, NULL))
rng <- function() list(kind = RNGkind(), state = .Random.seed)
expect_rejected <- function(code, output, pattern = NULL) {
    error <- tryCatch({force(code); NULL}, error = identity)
    if (!inherits(error, "error")) stop("Expected failure: ", output)
    if (!is.null(pattern) && !grepl(pattern, conditionMessage(error), ignore.case = TRUE)) stop(error)
    stopifnot(!file.exists(output))
    invisible(conditionMessage(error))
}
no_execution_resources <- function(x) {
    # Inspect scientific payloads. data.table's internal bookkeeping attributes
    # are deliberately excluded, as in the value comparisons above.
    stopifnot(!typeof(x) %in% c("externalptr", "environment", "closure"),
        !methods::is(x, "ResultRecord"), !methods::is(x, "sceptre_object"),
        !methods::is(x, "BackedCountStore"))
    if (isS4(x)) for (name in methods::slotNames(x)) no_execution_resources(methods::slot(x, name))
    else if (is.list(x)) for (value in x) no_execution_resources(value)
    invisible(TRUE)
}
reference_stage <- function(object, config, stage) {
    args <- switch(stage, parameters = config$analysis,
        assignment = c(config$assignment, list(print_progress = FALSE, parallel = FALSE)),
        qc = config$qc,
        calibration = c(config$calibration, list(print_progress = FALSE, parallel = FALSE,
            output_amount = config$execution$output_amount)),
        power = list(print_progress = FALSE, parallel = FALSE, output_amount = config$execution$output_amount),
        discovery = list(print_progress = FALSE, parallel = FALSE, output_amount = config$execution$output_amount))
    fun <- switch(stage, parameters = sceptre::set_analysis_parameters,
        assignment = sceptre::assign_grnas, qc = sceptre::run_qc,
        calibration = sceptre::run_calibration_check, power = sceptre::run_power_check,
        discovery = sceptre::run_discovery_analysis)
    do.call(fun, c(list(sceptre_object = object), args))
}

args <- commandArgs(trailingOnly = TRUE)
output_root <- if (length(args)) args[[1L]] else tempfile("pipeline-distributed-")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
required <- c("prepare_execution", "execute_work_unit", "collect_execution")
stopifnot(all(required %in% getNamespaceExports("sceptre")))
output_root <- normalizePath(output_root)
collector_script <- normalizePath("bin/distributed_stage.R")
empty_backing <- normalizePath("resources/empty_backing")
lock <- package_identity()
seed <- 271828L
report <- list(runtime = lock, cases = list(), optional_backend = NULL)

run_case <- function(name, fixture, backing = NULL) {
    config <- fixture$config
    root <- file.path(output_root, name)
    dir.create(root)
    input <- file.path(root, "input")
    create_input(fixture$object, input, config, identity = lock, backing = backing)
    # The reference is an ordinary uninterrupted public workflow: one seed at
    # analysis start; neither partition scheduling nor saved artifacts intervene.
    direct <- fixture$object
    reference <- list()
    set.seed(seed)
    for (stage in c("parameters", "assignment", "qc", "calibration", "power", "discovery")) {
        direct <- reference_stage(direct, config, stage)
        reference[[stage]] <- owned(list(rng = rng(), fits = direct@fits,
            assignments = if (stage != "parameters") sceptre::get_grna_assignments(direct) else NULL,
            cells = direct@preparation@analysis_cells,
            tables = lapply(names(direct@results@records), function(analysis) sceptre::get_result(direct, analysis)),
            records = direct@results@records))
        names(reference[[stage]]$tables) <- names(direct@results@records)
    }
    for (stage in c("parameters", "assignment", "qc")) {
        target <- file.path(root, stage)
        run_stage(config, input, target, stage, seed, backing = backing, identity = lock)
        input <- target
    }
    family_report <- list()
    for (stage in c("calibration", "power", "discovery")) {
        plan_dir <- file.path(root, paste0(stage, "-plan"))
        input_hash <- hash_file(file.path(input, "sceptre_object.rds"))
        prepare_distributed(config, input, plan_dir, stage, seed, 3L, backing, lock)
        execution <- readRDS(file.path(plan_dir, "execution.rds"))
        no_execution_resources(execution)
        stopifnot(identical(execution$protocol, 1L), length(execution$units) >= 1L,
            length(execution$units) <= 3L, is.character(execution$identity),
            nzchar(execution$identity), is.list(execution$runtime), is.list(execution$methods))
        analysis <- analysis_name(stage)
        assert_empirical_budget(execution$plan, stage, config)
        same(execution$plan, reference[[stage]]$records[[analysis]]$provenance$plan,
            paste(name, stage, "full global plan and realized budget"))
        unit_ids <- vapply(execution$units, function(unit) unit$id, character(1))
        row_ids <- unlist(lapply(execution$units, function(unit) unit$row_ids), use.names = FALSE)
        stopifnot(!anyDuplicated(unit_ids), !anyDuplicated(row_ids),
            identical(sort(row_ids), which(execution$plan@pairs$pass_qc)))
        # Reverse execution and arrival order, and serialize every plan/proposal.
        proposals <- character(length(unit_ids))
        names(proposals) <- unit_ids
        for (id in rev(unit_ids)) {
            path <- file.path(root, paste0(stage, "-", id, ".rds"))
            run_distributed_unit(config, input, plan_dir, path, stage, seed, id, backing, lock)
            proposal <- readRDS(path)
            unit <- execution$units[[match(id, unit_ids)]]
            no_execution_resources(proposal)
            stopifnot(is.null(proposal$records), is.null(proposal$results),
                !"significant" %in% names(proposal$result), "grna_group" %in% names(proposal$result),
                identical(proposal$execution, execution$identity), identical(proposal$unit_id, id),
                identical(proposal$protocol, execution$protocol),
                is.character(proposal$identity), nzchar(proposal$identity))
            same(proposal$result$.sceptre_global_pair_row, unit$row_ids,
                paste(name, stage, id, "global row identities"))
            proposals[[id]] <- path
        }
        same(hash_file(file.path(input, "sceptre_object.rds")), input_hash,
            paste(name, stage, "workers leave input state unchanged"))
        # Check rejection of partial, duplicate, wrong/corrupt and mismatched work.
        if (name == "low_nt_permutation" && stage == "discovery") {
            for (kind in c("missing", "duplicate", "wrong", "corrupt", "rows")) {
                files <- unname(proposals)
                if (kind == "missing") files <- files[-length(files)]
                if (kind == "duplicate") files <- c(files, files[[1L]])
                if (kind %in% c("wrong", "corrupt", "rows")) {
                    value <- readRDS(files[[1L]])
                    if (kind == "wrong") value$execution <- "wrong-execution"
                    if (kind == "corrupt") value$result$p_value[[1L]] <- -1
                    if (kind == "rows") {
                        value$result$.sceptre_global_pair_row[[1L]] <- 999999L
                        # An internally signed invalid row still fails coverage.
                        value$identity <- digest::digest(value[setdiff(names(value), "identity")], algo = "sha256")
                    }
                    files[[1L]] <- file.path(root, paste0("invalid-", kind, ".rds"))
                    saveRDS(value, files[[1L]])
                }
                target <- file.path(root, paste0("rejected-", kind))
                expect_rejected(collect_distributed(config, input, plan_dir, files,
                    target, stage, seed, backing, lock), target)
            }
            target <- file.path(root, "rejected-worker.rds")
            expect_rejected(run_distributed_unit(config, input, plan_dir, target, stage,
                seed, "unit-999999", backing, lock), target, "Unknown.*unit")
            same(hash_file(file.path(input, "sceptre_object.rds")), input_hash,
                "failed collection leaves input state unchanged")
        }
        target <- file.path(root, stage)
        collect_distributed(config, input, plan_dir, rev(unname(proposals)), target,
            stage, seed, backing, lock)
        if (name == "low_nt_permutation" && stage == "discovery") {
            # Exercise the real CLI discovery of staged proposal_unit*.rds files.
            # Its collector reads proposals/ in the current task directory.
            run_cli_collector <- function(directory, include_proposals) {
                dir.create(directory)
                staged <- file.path(directory, "proposals")
                dir.create(staged)
                if (include_proposals) {
                    destinations <- file.path(staged, paste0("proposal_", names(proposals), ".rds"))
                    stopifnot(all(file.copy(unname(proposals), destinations)))
                    writeLines("not an RDS proposal", file.path(staged, "ignore.txt"))
                }
                saveRDS(config, file.path(directory, "config.rds"))
                saveRDS(lock, file.path(directory, "lock.rds"))
                input_absolute <- normalizePath(input)
                plan_absolute <- normalizePath(plan_dir)
                backing_absolute <- if (is.null(backing)) empty_backing else normalizePath(backing)
                previous <- setwd(directory)
                on.exit(setwd(previous), add = TRUE)
                arguments <- c(collector_script, "collect", "config.rds", input_absolute,
                    plan_absolute, "collected", stage, as.character(seed), "3", "unused", "lock.rds",
                    backing_absolute)
                status <- system2(file.path(R.home("bin"), "Rscript"),
                    args = vapply(arguments, shQuote, character(1)),
                    stdout = "collector.stdout.log", stderr = "collector.stderr.log")
                if (include_proposals) {
                    if (!identical(status, 0L)) stop("CLI collector failed; inspect ", directory)
                } else {
                    stopifnot(status != 0L, !file.exists("collected"))
                }
                invisible(status)
            }
            cli <- file.path(root, "discovery-cli")
            run_cli_collector(cli, TRUE)
            cli_state <- read_bundle(file.path(cli, "collected"), config, lock, backing)
            function_state <- read_bundle(target, config, lock, backing)
            same(sceptre::get_result(cli_state$object, analysis),
                sceptre::get_result(function_state$object, analysis), "actual collector CLI final result")
            same(cli_state$object@fits, function_state$object@fits, "actual collector CLI fits")
            same(cli_state$manifest$rng_state, function_state$manifest$rng_state,
                "actual collector CLI RNG state")
            run_cli_collector(file.path(root, "discovery-cli-no-proposals"), FALSE)
        }
        completed <- read_bundle(target, config, lock, backing)
        actual <- completed$object
        stopifnot(identical(actual@results@records[[analysis]]$scope, "complete_family"))
        same(sceptre::get_grna_assignments(actual), reference[[stage]]$assignments,
            paste(name, stage, "assignments"))
        same(actual@preparation@analysis_cells, reference[[stage]]$cells,
            paste(name, stage, "ordered cells"))
        same(actual@fits, reference[[stage]]$fits, paste(name, stage, "compact compatible fits"))
        for (family in names(reference[[stage]]$tables)) {
            same(sceptre::get_result(actual, family), reference[[stage]]$tables[[family]],
                paste(name, stage, family, "complete corrected table"))
        }
        same(completed$manifest$rng_kind, reference[[stage]]$rng$kind,
            paste(name, stage, "RNG kind"))
        same(completed$manifest$rng_state, reference[[stage]]$rng$state,
            paste(name, stage, "single-session RNG state"))
        family_report[[stage]] <- list(units = length(unit_ids), eligible_rows = length(row_ids),
            final_rows = nrow(sceptre::get_result(actual, analysis)), passed = TRUE)
        input <- target
    }
    message("PASS distributed ", name)
    family_report
}

for (name in names(pipeline_fixture_cases())) {
    fixture <- do.call(pipeline_fixture, pipeline_fixture_cases()[[name]])
    report$cases[[name]] <- run_case(name, fixture)
    saveRDS(report, file.path(output_root, "distributed-comparison.rds"))
}

# The optional backed path must use permutations; native CRT ondisc is unsupported.
capability <- tryCatch({
    probe <- get0("require_ondisc_capabilities", envir = asNamespace("sceptre"), inherits = FALSE)
    if (is.function(probe)) probe() else {
        if (!requireNamespace("ondisc", quietly = TRUE)) stop("ondisc unavailable")
        if (!exists("create_odm_from_r_matrix_internal", envir = asNamespace("ondisc"), inherits = FALSE))
            stop("ondisc matrix-import API unavailable")
    }
    NULL
}, error = identity)
if (inherits(capability, "error")) {
    report$optional_backend <- list(skipped = TRUE, reason = conditionMessage(capability))
    if (Sys.getenv("REQUIRE_ONDISC") == "true") stop(capability)
    message("SKIP optional distributed backed qualification: ", conditionMessage(capability))
} else {
    for (case in c("low_nt_permutation", "high_permutation")) {
        backing <- file.path(output_root, paste0(case, "-backing"))
        dir.create(backing)
        fixture <- do.call(pipeline_fixture, c(pipeline_fixture_cases()[[case]],
            list(backed = TRUE, directory = backing)))
        before <- vapply(file.path(backing, c("response.odm", "grna.odm")), hash_file, character(1))
        name <- paste0(case, "_backed")
        report$cases[[name]] <- run_case(name, fixture, backing)
        same(vapply(names(before), hash_file, character(1)), before, paste(name, "immutable backing"))
    }
    report$optional_backend <- list(skipped = FALSE, passed = TRUE,
        version = as.character(utils::packageVersion("ondisc")))
}
saveRDS(report, file.path(output_root, "distributed-comparison.rds"))
message("All distributed comparisons passed: ", normalizePath(output_root))
