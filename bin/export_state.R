#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
source(file.path(dirname(normalizePath(script)), "pipeline.R"))
if (length(args) != 4L) fail("Usage: export_state.R CONFIG INPUT LOCK BACKING")
config <- readRDS(args[1]); lock <- readRDS(args[3])
validate_config(config); validate_identity(lock)
state <- read_bundle(args[2], config, lock, args[4])
# Keep report generation separate from the certified scientific result commit.
sceptre::write_outputs_to_directory(state$object, 'exports')

# Presentation is a separate, recoverable boundary from the saved science.
helper <- file.path(dirname(normalizePath(script)), 'scientific_report.R')
source(helper)
write_scientific_report_safely(state$object, state$manifest, config,
    file.path('exports', 'scientific-report'), helper)
