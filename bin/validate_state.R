#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
helper_dir <- dirname(normalizePath(script))
source(file.path(helper_dir, "pipeline.R"))
if (length(args) != 7L) fail("Usage: validate_state.R CONFIG INPUT LOCK BACKING OPTIONS_JSON PREVIOUS_SIGNATURE SOURCE_DIRECTORY")
config <- readRDS(args[1]); lock <- readRDS(args[3])
validate_config(config); validate_identity(lock)
read_bundle(args[2], config, lock, args[4]) |> invisible()
helpers <- sort(list.files(helper_dir, full.names = TRUE))
helpers <- helpers[!dir.exists(helpers)]
helper_hashes <- vapply(helpers, hash_file, character(1)); names(helper_hashes) <- basename(helpers)
options <- jsonlite::fromJSON(args[5])
if (identical(options$execution_mode, 'distributed') &&
    !all(c('prepare_execution','execute_work_unit','collect_execution') %in% getNamespaceExports('sceptre')))
    fail('Distributed mode requires the qualified package work-unit API; use --execution_mode reference for this package.')
sources <- sort(list.files(args[7], full.names = TRUE))
sources <- sources[!dir.exists(sources)]
if (!length(sources)) fail('Missing workflow/module/config implementation sources.')
source_hashes <- vapply(sources, hash_file, character(1)); names(source_hashes) <- basename(sources)
signature <- list(kind = 'sceptre-pipeline-run', schema = 1L,
    input_sha256 = hash_file(file.path(args[2], 'manifest.rds')),
    config_sha256 = hash_value(config), package = lock,
    options = options, helpers_sha256 = hash_value(helper_hashes),
    workflow_sha256 = hash_value(source_hashes))
previous <- readRDS(args[6])
if (!is.null(previous) && !identical(signature, previous))
    fail('Output directory belongs to a different run, input, settings or implementation. Use a fresh --outdir; only an identical -resume can reuse publication paths.')
saveRDS(signature, 'run_signature.rds')
