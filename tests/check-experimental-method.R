#!/usr/bin/env Rscript
# Actual adapter rejection, including preconfigured objects and saved bundles.
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L, !dir.exists(args[1L]))
root <- normalizePath(args[1L], mustWork = FALSE)
dir.create(root, recursive = TRUE)
library(sceptre)
source("bin/pipeline.R")
source("tests/fixture.R")
api <- getNamespaceExports("sceptre")
runtime <- package_identity()
expect_rejected <- function(expr, pattern, output = NULL) {
    value <- tryCatch(force(expr), error = function(e) e)
    stopifnot(inherits(value, "error"),
        grepl(pattern, conditionMessage(value), fixed = TRUE))
    if (!is.null(output)) stopifnot(!file.exists(output), !dir.exists(output))
}
check_boundary <- function(selected, reference, config, label, pattern) {
    base <- file.path(root, paste0(label, "-reference"))
    create_input(reference, base, config, runtime)
    stopifnot(methods::is(read_bundle(base, config, runtime)$object, "sceptre_object"))
    output <- file.path(root, paste0(label, "-rejected-input"))
    expect_rejected(create_input(selected, output, config, runtime), pattern, output)
    # Externally written, checksummed bundles must still satisfy method admission.
    saveRDS(selected, file.path(base, "sceptre_object.rds"))
    manifest <- readRDS(file.path(base, "manifest.rds"))
    manifest$object_sha256 <- hash_file(file.path(base, "sceptre_object.rds"))
    saveRDS(manifest, file.path(base, "manifest.rds"))
    expect_rejected(read_bundle(base, config, runtime), pattern)
    output <- file.path(root, paste0(label, "-rejected-stage"))
    expect_rejected(run_stage(config, base, output, "parameters", 271828L,
        identity = runtime), pattern, output)
    cat("PASS", label, "input publication, saved bundle and reference-stage guards\n")
}
fixture <- pipeline_fixture("high", "complement", "crt")
if ("set_perturbation_fit_method" %in% api) {
    selected <- sceptre::set_perturbation_fit_method(fixture$object, "fast_logistic")
    check_boundary(selected, fixture$object, fixture$config, "fitter",
        "supported only by direct R execution")
} else if (identical(Sys.getenv("SCEPTRE_REQUIRE_EXPERIMENTAL_GUARD"), "true")) {
    stop("Required experimental fitter API unavailable in this runtime")
} else cat("UNQUALIFIED fitter guard: API absent in this runtime\n")
if (all(c("get_result_methods", "run_wilcoxon") %in% api)) {
    fixture <- pipeline_fixture()
    object <- do.call(sceptre::set_analysis_parameters,
        c(list(sceptre_object = fixture$object), fixture$config$analysis))
    object <- do.call(sceptre::assign_grnas,
        c(list(sceptre_object = object, print_progress = FALSE), fixture$config$assignment))
    object <- do.call(sceptre::run_qc,
        c(list(sceptre_object = object), fixture$config$qc))
    selected <- sceptre::run_wilcoxon(object)
    stopifnot(any(sceptre::get_result_methods(selected) == "wilcoxon_unadjusted"))
    check_boundary(selected, object, fixture$config, "wilcoxon",
        "Experimental Wilcoxon is unsupported in pipeline bundles")
} else if (identical(Sys.getenv("SCEPTRE_REQUIRE_WILCOXON_GUARD"), "true")) {
    stop("Required Wilcoxon method API unavailable in this runtime")
} else cat("UNQUALIFIED Wilcoxon guard: API absent in this runtime\n")
