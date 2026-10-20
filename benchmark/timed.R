#!/usr/bin/env Rscript
# Kernel high-water marks, not sampled R allocation totals.
args <- commandArgs(TRUE); stopifnot(length(args) >= 2L)
script <- args[[1L]]; metrics <- args[[2L]]; trailing <- args[-c(1L,2L)]
read_kernel <- function(path) if (file.exists(path)) readLines(path, warn = FALSE) else NA_character_
start <- Sys.time(); cpu <- proc.time(); error <- NULL
# Source scripts see exactly their own CLI arguments, without changing production.
script_env <- new.env(parent = globalenv())
script_env$commandArgs <- function(trailingOnly = FALSE) if (trailingOnly) trailing else c('Rscript', script, trailing)
tryCatch(sys.source(script, envir = script_env), error = function(e) { error <<- conditionMessage(e) })
status <- read_kernel('/proc/self/status')
peak <- grep('^VmHWM:', status, value = TRUE)
jsonlite::write_json(list(status = if (is.null(error)) 'completed' else 'failed', error = error,
    elapsed_seconds = as.numeric(difftime(Sys.time(), start, units = 'secs')),
    user_seconds = unname((proc.time() - cpu)[['user.self']]), system_seconds = unname((proc.time() - cpu)[['sys.self']]),
    process_peak_rss_kib = if (length(peak)) as.numeric(gsub('[^0-9]', '', peak)) else NA_real_,
    cgroup_memory_peak_bytes = read_kernel('/sys/fs/cgroup/memory.peak'),
    cgroup_cpu_stat = read_kernel('/sys/fs/cgroup/cpu.stat'), R = R.version.string,
    source_receipt = jsonlite::fromJSON('/opt/sceptre/source.json')),
    metrics, auto_unbox = TRUE, pretty = TRUE)
if (!is.null(error)) stop(error)
