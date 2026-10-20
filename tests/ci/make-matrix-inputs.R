#!/usr/bin/env Rscript
# Every input and runtime lock is generated inside the same pinned test image.
source("bin/pipeline.R")
source("tests/fixture.R")
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L)
root <- args[1]
dir.create(root, recursive = TRUE, showWarnings = FALSE)
lock <- package_identity()
for (name in c("low_nt_permutation", "high_empirical_crt", "low_nt_permutation_backed", "low_nt_crt_backed")) {
    path <- file.path(root, name)
    dir.create(path)
    backed <- endsWith(name, "_backed")
    case <- sub("_backed$", "", name)
    opts <- pipeline_fixture_cases()[[case]]
    backing <- NULL
    if (backed) {
        backing <- file.path(path, "backing")
        dir.create(backing)
        opts <- c(opts, list(backed = TRUE, directory = backing))
    }
    fixture <- do.call(pipeline_fixture, opts)
    saveRDS(fixture$config, file.path(path, "config.rds"))
    saveRDS(lock, file.path(path, "lock.rds"))
    create_input(fixture$object, file.path(path, "input"), fixture$config,
        backing = backing, identity = lock)
    message("Created mandatory matrix fixture ", name)
}
# Adversarial inputs must reach real runtime validation, not schema-only failure.
copy_tree <- function(from, to) {
    dir.create(to)
    stopifnot(all(file.copy(list.files(from, full.names = TRUE, all.files = TRUE,
        no.. = TRUE), to, recursive = TRUE)))
}
source <- file.path(root, "low_nt_permutation")
for (name in c("wrong_runtime", "corrupt_input")) {
    target <- file.path(root, name)
    copy_tree(source, target)
    if (name == "wrong_runtime") {
        value <- readRDS(file.path(target, "lock.rds"))
        value$version <- "wrong-runtime-version"
        saveRDS(value, file.path(target, "lock.rds"))
    } else {
        file <- file.path(target, "input", "sceptre_object.rds")
        connection <- file(file, "ab")
        writeBin(charToRaw("intentional checksum corruption"), connection)
        close(connection)
    }
}
