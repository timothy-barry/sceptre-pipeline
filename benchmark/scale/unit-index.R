#!/usr/bin/env Rscript
# Isolate the real scheduling kernel. Not a scientific full-family analysis.
args <- commandArgs(TRUE)
stopifnot(length(args) == 4L)
source_path <- normalizePath(args[1])
H <- as.integer(args[2]); U <- as.integer(args[3]); out <- args[4]
env <- new.env(parent = globalenv())
sys.source(source_path, envir = env)
methods::setClass("ScaleIndexPlan", slots = c(pairs = "data.frame"))
# Nonmonotone original keys, interleaved excluded rows, original global row IDs.
pass <- rep(c(TRUE, TRUE, FALSE, TRUE), length.out = H)
plan <- methods::new("ScaleIndexPlan", pairs = data.frame(pass_qc = pass))
keys <- rep(rev(seq_len(U)) * 3L, length.out = sum(pass))
context <- list(index = list(pair_rows = data.frame(response_idx = keys, group_idx = rev(keys))))
gc()
started <- proc.time()
x <- env$execution_units(context, plan, 4L, TRUE)
timing <- proc.time() - started
ids <- unlist(lapply(x, `[[`, "row_ids"), use.names = FALSE)
stopifnot(identical(sort(ids), which(pass)), !anyDuplicated(ids))
jsonlite::write_json(list(H = H, U = U, eligible = sum(pass),
    kernel_seconds = unname(timing[3]), cpu_seconds = unname(sum(timing[1:2])),
    output_bytes = as.numeric(object.size(x)), units_sha256 = digest::digest(x, algo = "sha256"),
    source_sha256 = digest::digest(file = source_path, algo = "sha256"),
    R = R.version.string), out, auto_unbox = TRUE, pretty = TRUE)
