#!/usr/bin/env Rscript
# Relocation must work with original native HDF5 paths physically absent.
source("tests/fixture.R")
source("bin/pipeline.R")
args <- commandArgs(TRUE)
root <- if (length(args)) args[1L] else tempfile("native-relocation-")
dir.create(root, recursive = TRUE)
source_dir <- file.path(root, "original")
dir.create(source_dir)
fixture <- pipeline_fixture(backed = TRUE, directory = source_dir)
object <- fixture$object
expected <- lapply(list(sceptre::get_response_matrix(object), sceptre::get_grna_matrix(object)), as.matrix)
files <- pipeline_backing_map(object)
identity <- package_identity()
input <- file.path(root, "input")
create_input(object, input, fixture$config, identity)
staged <- file.path(root, "staged")
script <- normalizePath("bin/stage_backing.R")
status <- system2(file.path(R.home("bin"), "Rscript"), vapply(c(script,
    file.path(input, "sceptre_object.rds"), staged), shQuote, character(1)))
stopifnot(status == 0L)
originals <- unique(unlist(files, use.names = FALSE))
for (file in originals) stopifnot(file.rename(file, paste0(file, ".preserved")))
stopifnot(!any(file.exists(originals)))
relocated <- read_bundle(input, fixture$config, identity, staged)$object
actual <- lapply(list(sceptre::get_response_matrix(relocated), sceptre::get_grna_matrix(relocated)), as.matrix)
stopifnot(identical(actual, expected))
# Raw input CLI must relocate from the stage_backing sidecar without trying
# to hash the original paths that have just been physically removed.
sidecar_file <- file.path(staged, "backing_manifest.rds")
sidecar <- readRDS(sidecar_file)
stopifnot(identical(sidecar$kind, "sceptre-pipeline-native-backing"),
    identical(sidecar$schema, 1L), identical(sidecar$object_schema, 7L),
    identical(sidecar$files, files))
config_file <- file.path(root, "config.rds")
lock_file <- file.path(root, "lock.rds")
saveRDS(fixture$config, config_file)
saveRDS(identity, lock_file)
prepare_script <- normalizePath("bin/prepare_input.R")
invoke_prepare <- function(name) {
    output <- file.path(root, name)
    status <- system2(file.path(R.home("bin"), "Rscript"),
        vapply(c(prepare_script, file.path(input, "sceptre_object.rds"),
            config_file, output, lock_file, staged), shQuote, character(1)),
        stdout = file.path(root, paste0(name, ".stdout.log")),
        stderr = file.path(root, paste0(name, ".stderr.log")))
    list(status = status, output = output)
}
prepared <- invoke_prepare("prepared-from-relocated-raw")
stopifnot(prepared$status == 0L)
prepared_object <- read_bundle(prepared$output, fixture$config, identity, staged)$object
prepared_counts <- lapply(list(sceptre::get_response_matrix(prepared_object),
    sceptre::get_grna_matrix(prepared_object)), as.matrix)
stopifnot(identical(prepared_counts, expected), !any(file.exists(originals)))
# The CLI must fail closed when the saved mapping is missing or belongs to
# another screen; neither failure may publish a successful input artifact.
stopifnot(file.rename(sidecar_file, paste0(sidecar_file, ".preserved")))
missing <- invoke_prepare("rejected-missing-sidecar")
stopifnot(missing$status != 0L, !file.exists(missing$output),
    file.rename(paste0(sidecar_file, ".preserved"), sidecar_file))
wrong <- sidecar
wrong$import_identity <- "another-screen"
saveRDS(wrong, sidecar_file)
mismatch <- invoke_prepare("rejected-wrong-sidecar")
stopifnot(mismatch$status != 0L, !file.exists(mismatch$output))
saveRDS(sidecar, sidecar_file)
cat("PASS raw input CLI relocation with originals absent; missing/mismatched sidecars reject
")
# Corrupt one staged file; transport/package validation must reject it.
target <- file.path(staged, names(files$response)[1L])
backup <- paste0(target, ".preserved")
stopifnot(file.copy(target, backup))
writeBin(charToRaw("invalid native HDF5"), target)
error <- tryCatch(read_bundle(input, fixture$config, identity, staged), error = function(e) e)
stopifnot(inherits(error, "error"), file.copy(backup, target, overwrite = TRUE))
invisible(read_bundle(input, fixture$config, identity, staged))
cat("PASS native HDF5 relocation with original paths absent; exact counts and corrupted backing rejection\n")
