#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
script <- sub('^--file=', '', grep('^--file=', commandArgs(), value = TRUE)[1L])
root <- dirname(normalizePath(script))
source(file.path(root, 'pipeline.R')); source(file.path(root, 'distributed.R'))
tryCatch({
    if (length(args) != 11L) fail('Usage: distributed_stage.R MODE CONFIG INPUT PLAN OUTPUT STAGE SEED N_UNITS UNIT LOCK BACKING')
    mode <- args[1]; config <- readRDS(args[2]); lock <- readRDS(args[10])
    if (mode == 'prepare') prepare_distributed(config, args[3], args[5], args[6], as.integer(args[7]), as.integer(args[8]), args[11], lock)
    else if (mode == 'worker') run_distributed_unit(config, args[3], args[4], args[5], args[6], as.integer(args[7]), args[9], args[11], lock)
    else if (mode == 'collect') collect_distributed(config, args[3], args[4],
        sort(Filter(function(path) endsWith(path, '.rds'), list.files('proposals', full.names = TRUE))), args[5], args[6], as.integer(args[7]), args[11], lock)
    else fail('Unknown distributed mode.')
}, error = function(e) {
    message('SCEPTRE distributed stage failed: ', conditionMessage(e)); quit(status = 1L)
})
