#!/usr/bin/env Rscript
# Invoke with OBJECT CONFIG OUTPUT LOCK [BACKING_DIRECTORY]; source pipeline.R for in-process helpers.
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
source(file.path(dirname(normalizePath(script)), "pipeline.R"))
source(file.path(dirname(normalizePath(script)), 'distributed.R'))
if (!length(args) %in% c(4L, 5L)) fail("Usage: prepare_input.R OBJECT CONFIG OUTPUT LOCK [BACKING_DIRECTORY]")
lock <- readRDS(args[4]); validate_identity(lock)
object <- readRDS(args[1])
object <- validate_object(object)
if (length(args) == 5L) {
    files <- pipeline_staged_backing_map(object, args[5])
    object <- pipeline_read_object(args[1], files, args[5])
}
create_input(object, args[3], readRDS(args[2]), lock)
