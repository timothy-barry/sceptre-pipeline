#!/usr/bin/env Rscript
# Semantic assertions for actual nf-test workflow outputs, under the same image.
source("bin/pipeline.R")
source("tests/fixture.R")
compare_saved_workflow <- function(fixture, results, seed, stop_after, analyses, backing = "none") {
args <- c(fixture, results, as.character(seed), stop_after, analyses, backing)
config <- readRDS(file.path(args[1], "config.rds"))
lock <- readRDS(file.path(args[1], "lock.rds"))
backing <- if (args[6] == "none") NULL else args[6]
state <- read_bundle(file.path(args[1], "input"), config, lock, backing)
object <- state$object
plain <- function(x) {
    if (isS4(x)) return(list(class = class(x), slots = stats::setNames(
        lapply(methods::slotNames(x), function(n) plain(methods::slot(x, n))), methods::slotNames(x))))
    if (is.data.frame(x)) return(list(class = class(x), names = names(x),
        row_names = rownames(x), columns = lapply(x, plain),
        attributes = lapply(attributes(x)[setdiff(names(attributes(x)),
            c("class", "names", "row.names", ".internal.selfref"))], plain)))
    if (is.list(x)) return(list(values = lapply(x, plain), attributes = lapply(attributes(x), plain)))
    x
}
same <- function(a, b, label) if (!identical(plain(a), plain(b))) stop(label, ": ",
    paste(all.equal(plain(a), plain(b)), collapse = "; "))
selected <- if (args[5] == "none") character() else strsplit(args[5], ",", fixed = TRUE)[[1]]
stages <- switch(args[4], parameters = "parameters", assignment = c("parameters", "assignment"),
    qc = c("parameters", "assignment", "qc"), analysis = c("parameters", "assignment", "qc", selected))
stopifnot(length(stages) > 0L)
set.seed(as.integer(args[3]))
for (stage in stages) {
    fun <- switch(stage, parameters = sceptre::set_analysis_parameters,
        assignment = sceptre::assign_grnas, qc = sceptre::run_qc,
        calibration = sceptre::run_calibration_check, power = sceptre::run_power_check,
        discovery = sceptre::run_discovery_analysis)
    options <- switch(stage, parameters = config$analysis, assignment = config$assignment,
        qc = config$qc, calibration = config$calibration, list())
    if (stage %in% c("assignment", "calibration", "power", "discovery")) {
        options$parallel <- FALSE
        options$print_progress <- FALSE
    }
    if (stage %in% c("calibration", "power", "discovery"))
        options$output_amount <- config$execution$output_amount
    object <- do.call(fun, c(list(sceptre_object = object), options))
    expected_rng <- list(kind = RNGkind(), state = .Random.seed)
    actual <- read_bundle(file.path(args[2], stage, "state"), config, lock, backing)
    same(actual$object@spec, object@spec, paste(stage, "spec"))
    same(actual$object@preparation@analysis_cells, object@preparation@analysis_cells, paste(stage, "cells"))
    same(actual$object@fits, object@fits, paste(stage, "fits"))
    for (field in c("design_matrix", "discovery_pairs_with_info", "positive_control_pairs_with_info", "cell_removal_metrics"))
        same(methods::slot(actual$object@preparation, field), methods::slot(object@preparation, field),
            paste(stage, field))
    same(names(actual$object@results@records), names(object@results@records), paste(stage, "exact result family names"))
    same(actual$manifest$rng_kind, expected_rng$kind, paste(stage, "RNG kind"))
    same(actual$manifest$rng_state, expected_rng$state, paste(stage, "RNG state"))
    if (stage != "parameters") same(sceptre::get_grna_assignments(actual$object),
        sceptre::get_grna_assignments(object), paste(stage, "assignments"))
    for (family in names(object@results@records)) {
        same(sceptre::get_result(actual$object, family), sceptre::get_result(object, family),
            paste(stage, family, "complete table"))
        same(actual$object@results@records[[family]]$provenance$plan,
            object@results@records[[family]]$provenance$plan, paste(stage, family, "global plan"))
    }
}
for (stage in setdiff(c("parameters", "assignment", "qc", "calibration", "power", "discovery"), stages))
    stopifnot(!dir.exists(file.path(args[2], stage)))
message("PASS real nf-test workflow semantics: ", paste(stages, collapse = ", "),
    "; exact families/tables/plans/fits/design/pairQC/metrics/assignments/RNG and absent excluded stages")
invisible(TRUE)
}
if (sys.nframe() == 0L) {
    args <- commandArgs(TRUE)
    if (length(args) != 6L) stop("Usage: compare-workflow.R FIXTURE RESULTS SEED STOP_AFTER ANALYSES BACKING")
    do.call(compare_saved_workflow, as.list(args))
}
