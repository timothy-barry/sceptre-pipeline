#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
source(file.path(dirname(normalizePath(script)), "pipeline.R"))
if (length(args) != 1L) fail("Usage: lock_environment.R OUTPUT_LOCK")
saveRDS(package_identity(), args[1])
