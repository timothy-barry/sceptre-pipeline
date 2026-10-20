# Fresh candidate package on R_LIBS; no source-slot mutation in normal use.
# Usage: Rscript tests/external-assignments.R NEW_OUTPUT_DIRECTORY
args <- commandArgs(TRUE)
stopifnot(length(args) == 1L, !dir.exists(args[1L]))
root <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])))
source(file.path(root, "..", "bin", "pipeline.R"))
source(file.path(root, "fixture.R"))
out <- args[1L]
dir.create(out, recursive = TRUE)
fixture <- pipeline_fixture()
object <- do.call(sceptre::set_analysis_parameters, c(list(fixture$object), fixture$config$analysis))
calls <- as.matrix(sceptre::get_grna_matrix(object)) >= 40
calls[1, 2] <- TRUE
object <- sceptre::set_grna_assignments(object, calls, "pipeline external test caller v1")
config <- fixture$config
config$analysis <- config$assignment <- NULL
identity <- package_identity()
run_case <- function(object, cfg, label) {
    start <- file.path(out, paste0(label, "-input"))
    configured <- file.path(out, paste0(label, "-parameters"))
    assigned <- file.path(out, paste0(label, "-assignment"))
    create_input(object, start, cfg, identity)
    run_stage(cfg, start, configured, "parameters", 19L, identity = identity)
    run_stage(cfg, configured, assigned, "assignment", 19L, identity = identity)
    read_bundle(assigned, cfg, identity)$object
}
preserved <- run_case(object, config, "preserve")
stopifnot(identical(sceptre::get_grna_assignments(preserved), sceptre::get_grna_assignments(object)),
          identical(preserved@spec@grna_assignment_hyperparameters, object@spec@grna_assignment_hyperparameters))
override <- config
override$assignment <- list(method = "thresholding", threshold = 40)
reassigned <- run_case(object, override, "override")
stopifnot(identical(reassigned@spec@grna_assignment_method, "thresholding"),
          !identical(sceptre::get_grna_assignments(reassigned), sceptre::get_grna_assignments(object)))
expect_failure <- function(expr, pattern) {
    error <- tryCatch({force(expr); NULL}, error = function(e) e)
    stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}
stale <- object
stale@preparation@guide_assignments[[1L]] <- integer()
expect_failure(run_case(stale, config, "stale"), "not yet been called")
changed_design <- config
changed_design$analysis <- fixture$config$analysis
expect_failure(run_case(object, changed_design, "design-reset"), "not yet been called")
cat("PASS: preserve validated external calls; explicit reassignment; reject stale assignment and invalidated design\n")
