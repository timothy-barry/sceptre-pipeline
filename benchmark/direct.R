#!/usr/bin/env Rscript
# Independent statistical reference. Deliberately does not source pipeline.R or
# call any driver/distributed helpers. One seed, then continuous public-R stages.
args <- commandArgs(TRUE); stopifnot(length(args) == 3L)
input <- args[[1L]]; output <- args[[2L]]; seed <- as.integer(args[[3L]])
dir.create(output, recursive = TRUE, showWarnings = FALSE)
config <- readRDS(file.path(input, 'config.rds'))
object <- readRDS(file.path(input, 'input', 'sceptre_object.rds'))
set.seed(seed)
timings <- list()
for (stage in c('parameters','assignment','qc','discovery')) {
    options <- switch(stage, parameters = config$analysis, assignment = config$assignment,
        qc = config$qc, discovery = list(output_amount = config$execution$output_amount))
    fun <- switch(stage, parameters = sceptre::set_analysis_parameters,
        assignment = sceptre::assign_grnas, qc = sceptre::run_qc,
        discovery = sceptre::run_discovery_analysis)
    if (stage %in% c('assignment','discovery')) {
        options$parallel <- FALSE; options$print_progress <- FALSE
    }
    before <- proc.time(); start <- Sys.time()
    object <- do.call(fun, c(list(sceptre_object = object), options))
    timings[[stage]] <- list(stage = stage, elapsed_seconds = as.numeric(difftime(Sys.time(), start, units = 'secs')),
        user_seconds = unname((proc.time() - before)[['user.self']]), system_seconds = unname((proc.time() - before)[['sys.self']]))
    saveRDS(list(object = object, rng_kind = RNGkind(), rng_state = .Random.seed),
        file.path(output, paste0(stage, '.rds')))
}
saveRDS(timings, file.path(output, 'timings.rds'))
jsonlite::write_json(timings, file.path(output, 'timings.json'), auto_unbox = TRUE, pretty = TRUE)
write.csv(as.data.frame(sceptre::get_result(object, 'run_discovery_analysis')),
    file.path(output, 'result.csv'), row.names = FALSE)
plan <- object@results@records$run_discovery_analysis$provenance$plan
jsonlite::write_json(list(B1 = plan@B1, B2 = plan@B2, B3 = plan@B3,
    total_resamples = as.double(plan@B1) + plan@B2 + plan@B3,
    requested = nrow(plan@pairs), eligible = sum(plan@pairs$pass_qc),
    analyzed_cells = length(object@preparation@analysis_cells),
    design_columns = colnames(object@preparation@design_matrix),
    response_fits = length(object@fits@response_fits), perturbation_fits = length(object@fits@perturbation_fits),
    identity = plan@identity), file.path(output, 'realized-plan.json'), auto_unbox = TRUE, pretty = TRUE)
