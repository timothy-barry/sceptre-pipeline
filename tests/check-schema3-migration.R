#!/usr/bin/env Rscript
# Genuine historical physical schema-3 object, public normalization only.
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L, file.exists(args[1L]), !dir.exists(args[2L]))
library(sceptre)
source("bin/pipeline.R")
stopifnot(all(c("get_perturbation_fit_method", "set_perturbation_fit_method") %in%
    getNamespaceExports("sceptre")))
old <- readRDS(args[1L])
before <- serialize(old, NULL)
stopifnot(identical(old@schema_version, 3L),
    is.null(attr(old@spec, "perturbation_fit_method", exact = TRUE)))
expected <- sceptre::set_perturbation_fit_method(old,
    sceptre::get_perturbation_fit_method(old))
config <- list()
runtime <- package_identity()
dir.create(args[2L], recursive = TRUE)
input <- file.path(args[2L], "input")
create_input(old, input, config, runtime)
stopifnot(identical(serialize(old, NULL), before))
saved <- readRDS(file.path(input, "sceptre_object.rds"))
stopifnot(identical(saved, expected),
    identical(sceptre::get_result(saved, "run_discovery_analysis"),
        sceptre::get_result(expected, "run_discovery_analysis")))
# Reproduce an externally written old-layout bundle under the current runtime.
# Checksum validation must bind the stored old bytes before normalization.
saveRDS(old, file.path(input, "sceptre_object.rds"))
manifest <- readRDS(file.path(input, "manifest.rds"))
manifest$object_sha256 <- hash_file(file.path(input, "sceptre_object.rds"))
saveRDS(manifest, file.path(input, "manifest.rds"))
hashes <- c(hash_file(file.path(input, "manifest.rds")),
    hash_file(file.path(input, "sceptre_object.rds")))
loaded <- read_bundle(input, config, runtime)$object
stopifnot(identical(loaded, expected), identical(serialize(old, NULL), before),
    identical(hashes, c(hash_file(file.path(input, "manifest.rds")),
        hash_file(file.path(input, "sceptre_object.rds")))))
# A malformed current representation still fails admission; it is not repaired
# by the historical-layout normalization path.
bad <- expected
bad@spec@multiple_testing_alpha <- 2
error <- tryCatch(validate_object(bad), error = function(e) e)
stopifnot(inherits(error, "error"),
    grepl("multiple_testing_alpha", conditionMessage(error), fixed = TRUE))
wrong <- manifest
wrong$package$installed_sha256 <- "other-runtime"
saveRDS(wrong, file.path(input, "manifest.rds"))
error <- tryCatch(read_bundle(input, config, runtime), error = function(e) e)
stopifnot(inherits(error, "error"),
    grepl("Artifact package identity mismatch", conditionMessage(error), fixed = TRUE))
cat("PASS historical schema-3 normalization, current results, caller/input immutability, and runtime lock rejection\n")
