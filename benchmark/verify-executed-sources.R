#!/usr/bin/env Rscript
# Verify retained, original validation certificates against post-run source bytes.
args <- commandArgs(TRUE); stopifnot(length(args) == 1L)
run <- args[[1L]]; checks <- list()
for (directory in list.dirs(run,recursive=FALSE,full.names=TRUE)) {
    if (!grepl('/pipeline-units-[123]$',directory)) next
    signature <- readRDS(file.path(directory,'results','run_signature.rds'))
    external_config <- digest::digest(file=file.path(run,'bounded.config'),algo='sha256')
    stopifnot(external_config %in% signature$options$external_config_sha256)
    tasks <- list.files(file.path(directory,'work'),pattern='^\\.command\\.sh$',recursive=TRUE,full.names=TRUE,all.files=TRUE)
    validation <- Filter(function(path) any(grepl('validate_state.R',readLines(path,warn=FALSE),fixed=TRUE)),tasks)
    stopifnot(length(validation) == 1L)
    task <- dirname(validation[[1L]])
    files <- sort(list.files(file.path(task,'pipeline_source'),full.names=TRUE))
    hashes <- vapply(files,function(path) digest::digest(file=path,algo='sha256'),character(1))
    names(hashes) <- basename(files)
    helper_files <- sort(list.files(file.path(task,'pipeline_bin'),full.names=TRUE))
    helpers <- vapply(helper_files,function(path) digest::digest(file=path,algo='sha256'),character(1))
    names(helpers) <- basename(helper_files)
    stopifnot(identical(digest::digest(hashes,algo='sha256'),signature$workflow_sha256),
        identical(digest::digest(helpers,algo='sha256'),signature$helpers_sha256))
    checks[[basename(directory)]] <- list(status='exact_pass',
        original_workflow_certificate=signature$workflow_sha256,
        original_helpers_certificate=signature$helpers_sha256,
        external_config_sha256=external_config,
        current_staged_source_hashes=hashes,
        resolved_source_paths=stats::setNames(as.list(normalizePath(files)),basename(files)),
        current_helper_hashes=helpers)
}
stopifnot(length(checks) > 0L)
jsonlite::write_json(list(status='exact_pass',checkpoints='original per-run validation certificates versus bytes after completion',
    cases=checks),file.path(run,'executed-source-verification.json'),auto_unbox=TRUE,pretty=TRUE)
