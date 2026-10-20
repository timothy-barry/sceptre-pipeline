#!/usr/bin/env Rscript
# Invoke with OBJECT CONFIG OUTPUT LOCK [BACKING_DIRECTORY]; source pipeline.R for in-process helpers.
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
source(file.path(dirname(normalizePath(script)), "pipeline.R"))
if (!length(args) %in% c(4L, 5L)) fail("Usage: prepare_input.R OBJECT CONFIG OUTPUT LOCK [BACKING_DIRECTORY]")
lock <- readRDS(args[4]); validate_identity(lock)
object <- readRDS(args[1])
validate_object(object)
for (store in list(object@data@response_matrix, object@data@grna_matrix)) {
    if (methods::is(store, "BackedCountStore") && !is.null(store@handle))
        fail("Raw serialization contains a backed process handle. Save the source object with write_ondisc_backed_sceptre_object() before preparing the bundle.")
}
if (length(args) == 5L) {
    if (!methods::is(object@data@response_matrix, "BackedCountStore"))
        fail("A backing directory is only valid for a backed source object.")
    object <- sceptre::read_ondisc_backed_sceptre_object(args[1],
        file.path(args[5], "response.odm"), file.path(args[5], "grna.odm"))
}
create_input(object, args[3], readRDS(args[2]), lock)
