#!/usr/bin/env Rscript
# Copy native backing files once into a content-addressed transport directory.
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
source(file.path(dirname(normalizePath(script)), "pipeline.R"))
if (length(args) != 2L) fail("Usage: stage_backing.R OBJECT OUTPUT_DIRECTORY")
object <- validate_object(readRDS(args[1]))
if (file.exists(args[2])) fail("Output directory already exists.")
files <- unlist(pipeline_backing_map(object), use.names = TRUE)
# unlist prefixes modality names; derive destination directly from content.
dir.create(args[2], recursive = TRUE)
for (path in unique(unname(files))) {
    dest <- file.path(args[2], paste0(hash_file(path), ".h5"))
    if (!file.exists(dest) && !file.copy(path, dest)) fail("Could not stage native backing file: ", path)
    if (!identical(hash_file(dest), hash_file(path))) fail("Staged native backing checksum mismatch.")
}
saveRDS(list(kind = "sceptre-pipeline-native-backing", schema = 1L,
    object_schema = 7L, import_identity = pipeline_import_identity(object),
    files = pipeline_backing_map(object)), file.path(args[2], "backing_manifest.rds"))
