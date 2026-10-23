#!/usr/bin/env Rscript
# Native schema-7 input admission must never normalize older object schemas.
source("bin/pipeline.R")
source("tests/fixture.R")
args <- commandArgs(TRUE)
root <- if (length(args)) tail(args, 1L) else tempfile("schema7-admission-")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
fixture <- pipeline_fixture()
stopifnot(identical(fixture$object@schema_version, 7L),
    methods::is(sceptre::get_screen_experiment(fixture$object), "SingleCellExperiment"))
identity <- package_identity()
input <- file.path(root, "native-input")
create_input(fixture$object, input, fixture$config, identity)
invisible(read_bundle(input, fixture$config, identity))
for (version in c(3L, 4L, 5L, 6L)) {
    old <- fixture$object
    old@schema_version <- version
    original <- serialize(old, NULL)
    output <- file.path(root, paste0("rejected-schema", version))
    error <- tryCatch(create_input(old, output, fixture$config, identity), error = function(e) e)
    stopifnot(inherits(error, "error"), grepl("schema-7", conditionMessage(error), fixed = TRUE),
        !file.exists(output), identical(original, serialize(old, NULL)))
}
# A correctly checksummed manifest must not hide a historical physical owner.
# This genuine old result-container shape is accepted by the package's public
# migration reader, but the pipeline must reject it before calling that reader.
historical_dir <- file.path(root, "mislabeled-historical-schema6")
dir.create(historical_dir)
stopifnot(all(file.copy(list.files(input, full.names = TRUE), historical_dir)))
historical <- fixture$object
attr(historical, "results") <- methods::new("ResultRecord")
attr(historical, "schema_version") <- 6L
historical_file <- file.path(historical_dir, "sceptre_object.rds")
saveRDS(historical, historical_file)
manifest <- readRDS(file.path(historical_dir, "manifest.rds"))
manifest$object_sha256 <- hash_file(historical_file)
stopifnot(identical(manifest$object_schema, 7L))
saveRDS(manifest, file.path(historical_dir, "manifest.rds"))
stopifnot(identical(sceptre::read_sceptre_object(historical_file)@schema_version, 7L))
original_hash <- hash_file(historical_file)
error <- tryCatch(read_bundle(historical_dir, fixture$config, identity), error = function(e) e)
stopifnot(inherits(error, "error"), grepl("schema-7", conditionMessage(error), fixed = TRUE),
    identical(hash_file(historical_file), original_hash),
    identical(readRDS(historical_file)@schema_version, 6L))
cat("PASS mislabeled historical schema-6 payload rejects before public migration
")
cat("PASS native schema-7 transport and older-schema rejection without input mutation\n")
