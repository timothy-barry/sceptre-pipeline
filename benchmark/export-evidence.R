#!/usr/bin/env Rscript
args <- commandArgs(TRUE); stopifnot(length(args) == 1L)
run <- args[[1L]]; out <- file.path(run, 'scientific-evidence')
dir.create(out, showWarnings = FALSE)
reference <- readRDS(file.path(run,'direct','discovery.rds'))
object <- reference$object
# No count matrices: retain original scientific certificates and compact caches.
saveRDS(list(spec=object@spec, fits=object@fits, results=object@results,
    import_identity=object@data@identity, ordered_cells=object@preparation@analysis_cells,
    design_sha256=digest::digest(object@preparation@design_matrix,algo='sha256'),
    rng_kind=reference$rng_kind,rng_state=reference$rng_state),file.path(out,'direct-scientific-payload.rds'))
lock <- readRDS(file.path(run,'fixture','lock.rds'))
jsonlite::write_json(lock,file.path(out,'runtime-lock.json'),auto_unbox=TRUE,pretty=TRUE)
for (directory in list.dirs(run,recursive=FALSE,full.names=TRUE)) {
    if (!grepl('/pipeline-units-[123]$',directory)) next
    source <- file.path(directory,'results','run_signature.rds')
    if (file.exists(source)) file.copy(source,file.path(out,paste0(basename(directory),'-run-signature.rds')),overwrite=TRUE)
}
