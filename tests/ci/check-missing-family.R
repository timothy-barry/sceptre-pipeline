#!/usr/bin/env Rscript
# A self-consistent saved artifact with a missing family must fail semantic parity.
source("tests/ci/compare-workflow.R")
args <- commandArgs(TRUE)
if (length(args) != 3L) stop("Usage: check-missing-family.R FIXTURE RESULTS NEW_NEGATIVE_DIRECTORY")
stopifnot(!file.exists(args[3]))
dir.create(args[3], recursive = TRUE)
for (stage in c("parameters", "assignment", "qc", "calibration", "power", "discovery")) {
    destination <- file.path(args[3], stage)
    dir.create(destination)
    stopifnot(file.copy(file.path(args[2], stage, "state"), destination, recursive = TRUE))
}
path <- file.path(args[3], "discovery", "state")
object <- readRDS(file.path(path, "sceptre_object.rds"))
stopifnot("discovery_analysis" %in% names(Filter(Negate(is.null), object@results)))
object@results["discovery_analysis"] <- list(NULL)
saveRDS(object, file.path(path, "sceptre_object.rds"))
manifest <- readRDS(file.path(path, "manifest.rds"))
manifest$object_sha256 <- hash_file(file.path(path, "sceptre_object.rds"))
# Keep the deliberately incomplete artifact internally consistent: it claims only
# completed power, so the semantic expected-family gate must catch the omission.
manifest$completed <- setdiff(manifest$completed, "discovery")
manifest$stage <- tail(manifest$completed, 1L)
saveRDS(manifest, file.path(path, "manifest.rds"))
error <- tryCatch({compare_saved_workflow(args[1], args[3], 271828L, "analysis",
    "calibration,power,discovery", "none"); NULL}, error = function(condition) condition)
stopifnot(inherits(error, "error"), grepl("exact result family names", conditionMessage(error), fixed = TRUE))
cat("PASS missing expected discovery family rejected despite matching object checksum; actual input/output artifacts unchanged\n")
