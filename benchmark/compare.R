#!/usr/bin/env Rscript
args <- commandArgs(TRUE); stopifnot(length(args) == 3L)
direct <- args[[1L]]; pipeline <- args[[2L]]; output <- args[[3L]]
# Preserve all scientific values/attributes, excluding only process-local DT
# self-reference and source formula environment addresses (baseenv here).
canonical <- function(x) {
    if (isS4(x)) return(list(class = class(x), slots = stats::setNames(lapply(methods::slotNames(x), function(n) canonical(methods::slot(x,n))), methods::slotNames(x))))
    if (is.environment(x)) return(list(environment = environmentName(x)))
    attrs <- attributes(x); attrs$.internal.selfref <- NULL
    if (is.data.frame(x)) attrs$row.names <- .row_names_info(x, 0L)
    if (is.list(x)) return(list(values = lapply(x, canonical), attributes = lapply(attrs, canonical)))
    if (length(attrs)) { attributes(x) <- NULL; return(list(value = x, attributes = lapply(attrs, canonical))) }
    x
}
check <- function(a,b,label) {
    if (!identical(canonical(a), canonical(b))) stop(label, ': ', paste(all.equal(canonical(a),canonical(b),tolerance=0),collapse='; '))
    digest::digest(canonical(a),algo='sha256')
}
records <- list()
for (stage in c('parameters','assignment','qc','discovery')) {
    reference <- readRDS(file.path(direct,paste0(stage,'.rds')))
    actual <- readRDS(file.path(pipeline,stage,'state','sceptre_object.rds'))
    m <- readRDS(file.path(pipeline,stage,'state','manifest.rds'))
    hashes <- list(spec = check(actual@spec, reference$object@spec, paste(stage,'spec')),
        data_identity = check(S4Vectors::metadata(sceptre::get_screen_experiment(actual))$sceptre$identity,S4Vectors::metadata(sceptre::get_screen_experiment(reference$object))$sceptre$identity,paste(stage,'data identity')),
        preparation = check(actual@preparation,reference$object@preparation,paste(stage,'preparation')),
        fits = check(actual@fits, reference$object@fits,paste(stage,'complete FitCache')),
        RNGkind = check(m$rng_kind,reference$rng_kind,paste(stage,'RNG kind')),
        RNGstate = check(m$rng_state,reference$rng_state,paste(stage,'continuous RNG state')))
    if (stage == 'discovery') {
        hashes$table <- check(sceptre::get_result(actual,'run_discovery_analysis'),sceptre::get_result(reference$object,'run_discovery_analysis'),'full discovery table')
        hashes$record <- check(actual@results, reference$object@results,'all complete result records, frozen plans and identities')
    }
    records[[stage]] <- hashes
}
jsonlite::write_json(list(status='exact_pass', tolerance=0, compared=records),output,auto_unbox=TRUE,pretty=TRUE)
message('PASS: exact full tables, plans, identities, preparation, fits and stage RNG states')
