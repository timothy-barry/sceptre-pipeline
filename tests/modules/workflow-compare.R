#!/usr/bin/env Rscript
# Compare a directly invoked analysis subworkflow with an uninterrupted public-R family.
source("bin/pipeline.R")
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
fixture <- args[1]
config <- readRDS(file.path(fixture, "config.rds"))
lock <- readRDS(file.path(fixture, "lock.rds"))
actual <- read_bundle(args[2], config, lock)
expected <- read_bundle(file.path(fixture, "reference-discovery"), config, lock)
plain <- function(x) {
    if (isS4(x)) return(list(class = class(x), slots = stats::setNames(
        lapply(methods::slotNames(x), function(n) plain(methods::slot(x, n))), methods::slotNames(x))))
    if (is.data.frame(x)) return(list(class = class(x), names = names(x),
        row_names = rownames(x), columns = lapply(x, plain),
        attributes = lapply(attributes(x)[setdiff(names(attributes(x)),
            c("class", "names", "row.names", ".internal.selfref"))], plain)))
    if (is.list(x)) return(list(values = lapply(x, plain), attributes = lapply(attributes(x), plain)))
    x
}
same <- function(a, b, label) if (!identical(plain(a), plain(b))) stop(label, ": ",
    paste(all.equal(plain(a), plain(b)), collapse = "; "))
same(actual$object@spec, expected$object@spec, "spec")
same(actual$object@preparation, expected$object@preparation, "preparation including cells, design, QC and pairs")
same(actual$object@fits, expected$object@fits, "fits")
same(sceptre::get_grna_assignments(actual$object), sceptre::get_grna_assignments(expected$object), "assignments")
same(names(actual$object@results@records), "run_discovery_analysis", "exact discovery-only family")
for (family in names(expected$object@results@records)) {
    same(sceptre::get_result(actual$object, family), sceptre::get_result(expected$object, family), "complete family table")
    same(actual$object@results@records[[family]]$provenance$plan,
        expected$object@results@records[[family]]$provenance$plan, "global family plan")
}
for (field in c("rng_kind", "rng_state", "stage", "completed"))
    same(actual$manifest[[field]], expected$manifest[[field]], paste("manifest", field))
message("PASS direct analysis subworkflow: discovery-only family, complete numerical table, plan, fits, QC, assignments and RNG")
