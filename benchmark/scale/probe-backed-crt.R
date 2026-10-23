#!/usr/bin/env Rscript
# Native schema-7 CRT comparison through public package execution only.
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L, !file.exists(args[1L]))
out <- args[1L]
dir.create(out, recursive = TRUE)
source("tests/fixture.R")
observations <- list()
for (backed in c(FALSE, TRUE)) {
    name <- if (backed) "native_hdf5" else "memory"
    directory <- if (backed) file.path(out, "backing") else NULL
    if (backed) dir.create(directory)
    fixture <- pipeline_fixture(moi = "high", control = "complement", mechanism = "crt",
        approximation = "no_approximation", backed = backed, directory = directory)
    object <- fixture$object
    stopifnot(identical(object@schema_version, 7L))
    set.seed(271828L)
    start <- proc.time()
    for (stage in c("analysis", "assignment", "qc", "discovery")) {
        fun <- switch(stage, analysis = sceptre::set_analysis_parameters,
            assignment = sceptre::assign_grnas, qc = sceptre::run_qc,
            discovery = sceptre::run_discovery_analysis)
        options <- fixture$config[[stage]]
        if (is.null(options)) options <- list()
        if (stage %in% c("assignment", "discovery")) {
            options$parallel <- FALSE
            options$print_progress <- FALSE
        }
        if (stage == "discovery") options$output_amount <- fixture$config$execution$output_amount
        object <- do.call(fun, c(list(sceptre_object = object), options))
    }
    observations[[name]] <- list(table = as.data.frame(sceptre::get_result(object, "run_discovery_analysis")),
        rng_kind = RNGkind(), rng_state = .Random.seed,
        timing = proc.time() - start)
}
stopifnot(identical(observations$memory$table, observations$native_hdf5$table),
    identical(observations$memory$rng_kind, observations$native_hdf5$rng_kind),
    identical(observations$memory$rng_state, observations$native_hdf5$rng_state))
saveRDS(observations, file.path(out, "native-crt.rds"))
cat("PASS public native CRT: memory/HDF5 complete results and continuous RNG match exactly\n")
