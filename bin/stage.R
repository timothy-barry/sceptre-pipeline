#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
source(file.path(dirname(normalizePath(script)), "pipeline.R"))
source(file.path(dirname(normalizePath(script)), 'distributed.R'))
source(file.path(dirname(normalizePath(script)), "diagnostics.R"))
tryCatch({
    if (length(args) != 7L) fail("Usage: stage.R CONFIG INPUT OUTPUT STAGE SEED LOCK BACKING")
    run_stage(readRDS(args[1]), args[2], args[3], args[4], as.numeric(args[5]), args[7], readRDS(args[6]))
}, error = function(e) {
    report_pipeline_failure(e, if (length(args) >= 4L) args[4] else NULL)
    quit(status = 1L)
})
