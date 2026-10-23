#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
helper_dir <- dirname(normalizePath(script))
source(file.path(helper_dir, "pipeline.R"))
source(file.path(helper_dir, "distributed.R"))
if (length(args) != 4L) fail("Usage: export_state.R CONFIG INPUT LOCK BACKING")
config <- readRDS(args[1]); lock <- readRDS(args[3])
validate_config(config); validate_identity(lock)
state <- read_bundle(args[2], config, lock, args[4])
helper <- file.path(helper_dir, "scientific_report.R")
source(helper)
if (!write_scientific_report_safely(state$object, state$manifest, config,
    file.path("exports", "scientific-report"), helper)) quit(status = 1L)
