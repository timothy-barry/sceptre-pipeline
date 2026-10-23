#!/usr/bin/env Rscript
# Fail closed for method names outside this package's native execution contract.
source("bin/pipeline.R")
source("tests/fixture.R")
args <- commandArgs(TRUE)
root <- if (length(args)) args[1L] else tempfile("native-method-admission-")
dir.create(root, recursive = TRUE)
fixture <- pipeline_fixture()
before <- serialize(fixture$object, NULL)
identity <- package_identity()
for (field in c("resampling_mechanism", "resampling_approximation")) {
    config <- fixture$config
    config$analysis[[field]] <- "unsupported"
    output <- file.path(root, field)
    error <- tryCatch({
        create_input(fixture$object, output, config, identity)
        run_stage(config, output, paste0(output, "-parameters"), "parameters", 271828L, identity = identity)
        NULL
    }, error = function(e) e)
    stopifnot(inherits(error, "error"), !dir.exists(paste0(output, "-parameters")),
        identical(before, serialize(fixture$object, NULL)))
}
cat("PASS unsupported scientific configuration fails before execution without input mutation\n")
