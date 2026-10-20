#!/usr/bin/env Rscript
# Exercise the real CLI: cache directories are not implementation files, while
# edits to real helpers and workflow sources must still reject resume.
library(sceptre)
source("bin/pipeline.R")
source("tests/fixture.R")
a <- commandArgs(TRUE)
stopifnot(length(a) == 1L, !file.exists(a[1L]))
dir.create(a[1L], recursive = TRUE)
root <- normalizePath(a[1L])
helpers <- file.path(root, "bin"); dir.create(helpers)
files <- list.files("bin", full.names = TRUE)
stopifnot(all(file.copy(files[!dir.exists(files)], helpers)))
sources <- file.path(root, "sources"); dir.create(sources)
workflow <- file.path(sources, "main.nf")
writeLines("workflow {}", workflow)
for (directory in c(helpers, sources)) {
    cache <- file.path(directory, "__pycache__"); dir.create(cache)
    writeBin(as.raw(0:255), file.path(cache, "cached.pyc"))
}
f <- pipeline_fixture("high", "complement", "crt")
lock <- package_identity()
create_input(f$object, file.path(root, "input"), f$config, lock)
saveRDS(f$config, file.path(root, "config.rds"))
saveRDS(lock, file.path(root, "lock.rds"))
saveRDS(NULL, file.path(root, "previous.rds"))
task <- file.path(root, "task"); dir.create(task)
old <- setwd(task); on.exit(setwd(old), add = TRUE)
arguments <- c("--vanilla", file.path(helpers, "validate_state.R"),
    file.path(root, "config.rds"), file.path(root, "input"),
    file.path(root, "lock.rds"), "none", '{"execution_mode":"reference"}',
    file.path(root, "previous.rds"), sources)
run <- function(name) {
    log <- file.path(root, paste0(name, ".log"))
    list(status = system2(file.path(R.home("bin"), "Rscript"), shQuote(arguments),
        stdout = log, stderr = log), log = log)
}
first <- run("with-cache-directories")
stopifnot(first$status == 0L)
signature <- readRDS("run_signature.rds")
saveRDS(signature, file.path(root, "previous.rds"))
writeBin(as.raw(255:0), file.path(helpers, "__pycache__", "cached.pyc"))
second <- run("cache-only-change")
stopifnot(second$status == 0L, identical(readRDS("run_signature.rds"), signature))
helper <- file.path(helpers, "stage.R")
bytes <- readBin(helper, "raw", n = file.info(helper)$size)
cat("\n# changed implementation\n", file = helper, append = TRUE)
third <- run("real-helper-change")
stopifnot(third$status != 0L,
    any(grepl("different run, input, settings or implementation", readLines(third$log), fixed = TRUE)),
    identical(readRDS("run_signature.rds"), signature))
writeBin(bytes, helper)
cat("\n// changed workflow implementation\n", file = workflow, append = TRUE)
fourth <- run("real-workflow-change")
stopifnot(fourth$status != 0L,
    any(grepl("different run, input, settings or implementation", readLines(fourth$log), fixed = TRUE)),
    identical(readRDS("run_signature.rds"), signature))
jsonlite::write_json(list(status = "passed", cache_directories_admitted = TRUE,
    cache_only_change_admitted = TRUE, helper_change_rejected = TRUE,
    workflow_change_rejected = TRUE, previous_signature_unchanged_after_failures = TRUE,
    package = lock), file.path(root, "receipt.json"), pretty = TRUE, auto_unbox = TRUE)
cat("PASS actual validate_state CLI with cache directories; real helper/workflow edits still reject resume\n")
