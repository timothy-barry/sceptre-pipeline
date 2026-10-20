#!/usr/bin/env Rscript
# Actual adapter rejection, including a preconfigured object and a saved bundle.
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L, !dir.exists(args[1L]))
root <- normalizePath(args[1L], mustWork = FALSE)
dir.create(root, recursive = TRUE)
library(sceptre)
source("bin/pipeline.R")
source("tests/fixture.R")
fixture <- pipeline_fixture("high", "complement", "crt")
identity <- package_identity()
config <- fixture$config
base <- file.path(root, "reference-input")
create_input(fixture$object, base, config, identity)
stopifnot(methods::is(read_bundle(base, config, identity)$object, "sceptre_object"))
if (!"set_perturbation_fit_method" %in% getNamespaceExports("sceptre")) {
    if (identical(Sys.getenv("SCEPTRE_REQUIRE_EXPERIMENTAL_GUARD"), "true"))
        stop("Required experimental fitter API is unavailable in this runtime")
    cat("PASS reference adapter; experimental fitter API unavailable in this runtime\n")
    quit(status = 0L)
}
selected <- sceptre::set_perturbation_fit_method(fixture$object, "fast_logistic")
expect_rejected <- function(expr, output = NULL) {
    value <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(value, "error"),
        grepl("supported only by direct R execution", conditionMessage(value), fixed = TRUE))
    if (!is.null(output)) stopifnot(!file.exists(output), !dir.exists(output))
}
output <- file.path(root, "rejected-input")
expect_rejected(create_input(selected, output, config, identity), output)
# Model an externally written bundle that passes byte/identity checks. Reading
# still applies the method boundary; no reference task may bypass it.
saveRDS(selected, file.path(base, "sceptre_object.rds"))
manifest <- readRDS(file.path(base, "manifest.rds"))
manifest$object_sha256 <- hash_file(file.path(base, "sceptre_object.rds"))
saveRDS(manifest, file.path(base, "manifest.rds"))
expect_rejected(read_bundle(base, config, identity))
output <- file.path(root, "rejected-reference-stage")
expect_rejected(run_stage(config, base, output, "parameters", 271828L,
    identity = identity), output)
cat("PASS selected fitter rejected before input publication, saved bundle reading, and reference-stage execution\n")
