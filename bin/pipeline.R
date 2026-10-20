# Pipeline-owned contracts. Read schema-3 components; never mutate package slots.
fail <- function(...) stop(..., call. = FALSE)
hash_file <- function(path) digest::digest(file = path, algo = "sha256")
hash_value <- function(x) digest::digest(x, algo = "sha256")
scientific_scope <- function(object) {
    describe <- function(pairs) list(n_requested = nrow(pairs), sha256 = hash_value(pairs))
    list(discovery = describe(object@spec@discovery_pairs),
         power = describe(object@spec@positive_control_pairs))
}
package_identity <- function() {
    root <- system.file(package = "sceptre")
    if (!nzchar(root)) fail("Install the qualified schema-3 sceptre package first.")
    files <- sort(list.files(root, recursive = TRUE, full.names = TRUE))
    files <- files[!dir.exists(files)]
    hashes <- vapply(files, hash_file, character(1))
    names(hashes) <- substring(files, nchar(root) + 2L)
    deps <- tools::package_dependencies("sceptre", db = utils::installed.packages(), recursive = TRUE)[[1L]]
    versions <- vapply(sort(unique(c("sceptre", "jsonlite", deps))), function(p) {
        if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "unavailable"
    }, character(1))
    backend_root <- find.package("ondisc", quiet = TRUE)
    backend <- if (!length(backend_root)) NULL else {
        backend_files <- sort(list.files(backend_root, recursive = TRUE, full.names = TRUE))
        backend_files <- backend_files[!dir.exists(backend_files)]
        backend_hashes <- vapply(backend_files, hash_file, character(1))
        names(backend_hashes) <- substring(backend_files, nchar(backend_root) + 2L)
        list(version = as.character(utils::packageVersion("ondisc")),
             installed_sha256 = hash_value(backend_hashes))
    }
    list(package = "sceptre", optional_backend = backend, version = as.character(utils::packageVersion("sceptre")),
         installed_sha256 = hash_value(hashes), dependencies = versions,
         R = paste(R.version$major, R.version$minor, R.version$platform))
}
validate_identity <- function(expected) {
    if (!identical(expected, package_identity()))
        fail("Runtime/package identity mismatch. Rebuild the environment lock and start a new run; do not resume across package changes.")
}
# Experimental direct-R fitters need separate pipeline runtime qualification.
# Older qualified packages expose no selector and retain the reference method.
validate_pipeline_method <- function(object) {
    api <- getNamespaceExports("sceptre")
    if ("get_perturbation_fit_method" %in% api &&
        !identical(sceptre::get_perturbation_fit_method(object), "glm.fit"))
        fail("Experimental fast_logistic is supported only by direct R execution; switch to glm.fit before creating or reading pipeline input.")
    if ("get_result_methods" %in% api &&
        any(sceptre::get_result_methods(object) == "wilcoxon_unadjusted"))
        fail("Experimental Wilcoxon is unsupported in pipeline bundles; use run_wilcoxon() directly with a separate prepared object.")
    invisible(object)
}
validate_object <- function(object) {
    if (!methods::is(object, "sceptre_object") ||
        !identical(object@schema_version, 3L))
        fail("Expected a current schema-3 sceptre_object; migrate/reimport with the qualified package before running.")
    methods::validObject(object)
    validate_pipeline_method(object)
    invisible(object)
}
validate_config <- function(config) {
    if (!is.list(config) || (length(config) && is.null(names(config))) || anyDuplicated(names(config))) fail("Configuration must be a named list.")
    unknown <- setdiff(names(config), c("analysis", "assignment", "qc", "calibration", "execution"))
    if (length(unknown)) fail("Unknown configuration section: ", paste(unknown, collapse = ", "))
    funcs <- list(analysis = sceptre::set_analysis_parameters, qc = sceptre::run_qc,
                  calibration = sceptre::run_calibration_check)
    allowed <- lapply(funcs, function(f) setdiff(names(formals(f)),
        c("sceptre_object", "parallel", "n_processors", "print_progress", "log_dir", "output_amount")))
    allowed$assignment <- c("method", "threshold", "umi_fraction_threshold", "min_grna_n_umis_threshold",
                            "n_em_rep", "pi_guess_range", "g_pert_guess_range", "n_nonzero_cells_cutoff", "backup_threshold", "probability_threshold", "formula_object")
    allowed$execution <- "output_amount"
    for (section in names(config)) {
        x <- config[[section]]
        if (!is.list(x) || (length(x) && (is.null(names(x)) || anyDuplicated(names(x)) || any(!nzchar(names(x))))))
            fail("Configuration section must be a named argument list: ", section)
        bad <- setdiff(names(x), allowed[[section]])
        if (length(bad)) fail("Unsupported ", section, " argument: ", paste(bad, collapse = ", "))
    }
    if (length(config$execution$output_amount) &&
        !(length(config$execution$output_amount) == 1L && config$execution$output_amount %in% 1:3))
        fail("execution$output_amount must be 1, 2, or 3.")
    invisible(config)
}
# Explicit scientific scope is retained in the package spec; this manifest merely
# certifies the serialized boundary and records pipeline stage completion.
create_input <- function(object, dir, config, identity = package_identity(), backing = NULL) {
    validate_object(object); validate_config(config); validate_identity(identity)
    if (dir.exists(dir)) fail("Output directory already exists: ", dir)
    dir.create(dir, recursive = TRUE)
    backed <- methods::is(object@data@response_matrix, "BackedCountStore")
    if (backed) sceptre::write_ondisc_backed_sceptre_object(object, dir) else saveRDS(object, file.path(dir, "sceptre_object.rds"))
    manifest <- list(kind = "sceptre-pipeline-state", schema = 1L, object_schema = 3L,
        stage = "input", completed = character(), package = identity,
        config_sha256 = hash_value(config), object_sha256 = hash_file(file.path(dir, "sceptre_object.rds")),
        backend = if (backed) "ondisc" else "memory", parent_sha256 = NULL,
        scientific_scope = scientific_scope(object),
        import_identity = object@data@identity)
    saveRDS(manifest, file.path(dir, "manifest.rds"))
    invisible(manifest)
}
read_bundle <- function(dir, config, identity, backing = NULL) {
    m <- readRDS(file.path(dir, "manifest.rds"))
    if (!is.list(m) || !identical(m$kind, "sceptre-pipeline-state") || !identical(m$schema, 1L) ||
        !identical(m$object_schema, 3L)) fail("Unsupported artifact kind/schema; legacy pipeline work directories cannot be resumed.")
    if (!identical(m$package, identity)) fail("Artifact package identity mismatch.")
    if (!identical(m$config_sha256, hash_value(config))) fail("Artifact configuration mismatch; start from a new input bundle.")
    if (!identical(m$object_sha256, hash_file(file.path(dir, "sceptre_object.rds")))) fail("Artifact object checksum mismatch.")
    if (identical(m$backend, "ondisc")) {
        if (is.null(backing)) fail("Backed artifact requires an explicitly staged backing directory.")
        object <- sceptre::read_ondisc_backed_sceptre_object(file.path(dir, "sceptre_object.rds"),
            file.path(backing, "response.odm"), file.path(backing, "grna.odm"))
    } else if (identical(m$backend, "memory")) object <- readRDS(file.path(dir, "sceptre_object.rds")) else fail("Unknown count backend.")
    validate_object(object)
    allowed <- c("parameters", "assignment", "qc", "calibration", "power", "discovery")
    if (!is.character(m$completed) || anyDuplicated(m$completed) || any(!m$completed %in% allowed) ||
        !identical(m$stage, if (length(m$completed)) tail(m$completed, 1L) else "input"))
        fail("Malformed artifact stage/completion record.")
    for (stage in m$completed) {
        prerequisite <- switch(stage, parameters = NULL, assignment = "parameters", qc = "assignment", "qc")
        if (length(prerequisite) && !(prerequisite %in% head(m$completed, match(stage, m$completed) - 1L)))
            fail("Artifact completion record has missing prerequisites.")
        fields <- switch(stage, parameters = "design", assignment = "assignment", qc = c("cell_qc", "pair_qc"), character())
        if (!all(fields %in% names(object@preparation@stages)))
            fail("Artifact claims a preparation stage that the saved object has not completed.")
        if (stage %in% c("calibration", "power", "discovery")) {
            family <- switch(stage, calibration = "run_calibration_check", power = "run_power_check", discovery = "run_discovery_analysis")
            sceptre::get_result(object, family) |> invisible()
        }
    }
    if (!identical(m$scientific_scope, scientific_scope(object))) fail("Artifact scientific scope mismatch.")
    if (!identical(m$import_identity, object@data@identity)) fail("Artifact import identity mismatch.")
    list(object = object, manifest = m)
}
run_stage <- function(config, input, output, stage, seed, backing = NULL, identity = package_identity()) {
    validate_config(config); validate_identity(identity)
    if (length(seed) != 1L || is.na(seed) || seed < 0 || seed > .Machine$integer.max || seed != as.integer(seed)) fail("seed must be an integer between 0 and 2147483647.")
    state <- read_bundle(input, config, identity, backing)
    m <- state$manifest; object <- state$object
    if (!length(m$completed)) {
        set.seed(as.integer(seed))
    } else {
        if (!identical(m$seed, as.integer(seed)) || is.null(m$rng_state) || is.null(m$rng_kind))
            fail("RNG handoff mismatch or missing state; rebuild the input bundle and start a new run.")
        do.call(RNGkind, as.list(m$rng_kind))
        assign(".Random.seed", m$rng_state, envir = .GlobalEnv)
    }
    prerequisite <- switch(stage, parameters = "input", assignment = "parameters", qc = "assignment",
                           calibration = "qc", power = "qc", discovery = "qc", fail("Unknown pipeline stage: ", stage))
    if (!(prerequisite %in% c("input", m$completed))) fail("Incomplete artifact: stage ", stage, " requires ", prerequisite, ".")
    if (stage %in% m$completed) fail("Stage already complete: ", stage)
    args <- switch(stage, parameters = config$analysis, assignment = config$assignment,
                   qc = config$qc, calibration = config$calibration, list())
    if (is.null(args)) args <- list()
    if (identical(stage, "parameters") && is.null(config$analysis)) {
        # Preserve a previously configured current object without reconstructing spec.
        if (is.null(object@preparation@stages$design)) fail("Supply config$analysis for an unconfigured input object.")
    } else {
        fun <- switch(stage, parameters = sceptre::set_analysis_parameters, assignment = sceptre::assign_grnas,
                      qc = sceptre::run_qc, calibration = sceptre::run_calibration_check,
                      power = sceptre::run_power_check, discovery = sceptre::run_discovery_analysis)
        if (stage %in% c("assignment", "calibration", "power", "discovery")) {
            args$parallel <- FALSE; args$print_progress <- FALSE
        }
        if (stage %in% c("calibration", "power", "discovery")) args$output_amount <- if (is.null(config$execution$output_amount)) 1L else config$execution$output_amount
        object <- withCallingHandlers(do.call(fun, c(list(sceptre_object = object), args)),
            warning = function(condition) {
                m$warnings[[length(m$warnings) + 1L]] <<- list(stage = stage,
                    message = conditionMessage(condition), class = class(condition))
            })
    }
    write_completed_bundle(object, m, input, output, stage, seed, identity)
}
write_completed_bundle <- function(object, m, input, output, stage, seed, identity) {
    validate_object(object)
    # Build in a temporary sibling; failed functions never publish a completed bundle.
    if (dir.exists(output)) fail("Output directory already exists: ", output)
    tmp <- tempfile(".stage-", tmpdir = dirname(output))
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    if (m$backend == "ondisc") sceptre::write_ondisc_backed_sceptre_object(object, tmp) else saveRDS(object, file.path(tmp, "sceptre_object.rds"))
    if (stage %in% c("calibration", "power", "discovery")) {
        family <- switch(stage, calibration = "run_calibration_check", power = "run_power_check", discovery = "run_discovery_analysis")
        saveRDS(sceptre::get_result(object, family), file.path(tmp, paste0("results_", stage, ".rds")))
    }
    m$parent_sha256 <- hash_file(file.path(input, "manifest.rds"))
    m$stage <- stage; m$completed <- c(m$completed, stage); m$seed <- as.integer(seed)
    m$rng_contract <- "single initial analysis seed; serialized R state across stages; native sampler seeds owned by package"
    m$rng_kind <- RNGkind()
    m$rng_state <- get(".Random.seed", envir = .GlobalEnv)
    m$object_sha256 <- hash_file(file.path(tmp, "sceptre_object.rds"))
    m$scientific_scope <- scientific_scope(object)
    m$resolved <- list(low_moi = object@data@low_moi, permutations = object@spec@run_permutations,
                       complement = object@spec@control_group_complement,
                       integration = object@spec@grna_integration_strategy)
    saveRDS(m, file.path(tmp, "manifest.rds"))
    capture.output(print(object), file = file.path(tmp, "analysis_summary.txt"))
    writeLines(c(paste("R:", R.version.string), paste("sceptre:", identity$version),
                 paste("installed_sha256:", identity$installed_sha256)), file.path(tmp, "versions.txt"))
    if (!file.rename(tmp, output)) fail("Could not publish completed artifact: ", output)
    invisible(object)
}
