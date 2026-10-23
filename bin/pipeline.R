# Native schema-7 pipeline transport and stage contracts.
fail <- function(...) stop(..., call. = FALSE)
# Initialize the declared package namespace before native matrix operations.
# This avoids the verified nested first-import load warning in the R 4.5 image.
if (!requireNamespace("sceptre", quietly = TRUE)) fail("Install the selected sceptre package before running the pipeline.")
hash_file <- function(path) digest::digest(file = path, algo = "sha256")
hash_value <- function(x) digest::digest(x, algo = "sha256")
scientific_scope <- function(object) {
    describe <- function(pairs) list(n_requested = nrow(pairs), sha256 = hash_value(pairs))
    list(discovery = describe(object@preparation@discovery_pairs),
         power = describe(object@preparation@positive_control_pairs))
}
pipeline_screen <- function(object) sceptre::get_screen_experiment(object)
pipeline_meta <- function(object) S4Vectors::metadata(pipeline_screen(object))$sceptre
pipeline_low_moi <- function(object) pipeline_meta(object)$low_moi
pipeline_import_identity <- function(object) pipeline_meta(object)$identity
pipeline_count_matrices <- function(object) {
    sce <- pipeline_screen(object)
    list(response = SummarizedExperiment::assay(sce, "counts", withDimnames = FALSE),
         grna = SummarizedExperiment::assay(SingleCellExperiment::altExp(sce, "gRNA", withDimnames = FALSE), "counts", withDimnames = FALSE))
}
pipeline_count_paths <- function(object) lapply(pipeline_count_matrices(object), function(matrix) {
    paths <- unique(unlist(DelayedArray::seedApply(matrix, function(seed) {
        if (isS4(seed) && "filepath" %in% methods::slotNames(seed)) as.character(methods::slot(seed, "filepath")) else character()
    }), use.names = FALSE))
    if (length(paths)) paths else character()
})
pipeline_backing_map <- function(object) lapply(pipeline_count_paths(object), function(paths) {
    if (!length(paths)) return(character())
    stats::setNames(paths, vapply(paths, function(path) paste0(hash_file(path), ".h5"), character(1)))
})
pipeline_staged_backing_map <- function(object, backing) {
    path <- file.path(backing, "backing_manifest.rds")
    if (!file.exists(path)) fail("Native backing transport requires backing_manifest.rds; create it with stage_backing.R before relocating the source files.")
    manifest <- readRDS(path)
    if (!is.list(manifest) || !identical(manifest$kind, "sceptre-pipeline-native-backing") ||
        !identical(manifest$schema, 1L) || !identical(manifest$object_schema, 7L) ||
        !identical(manifest$import_identity, pipeline_import_identity(object)) ||
        !is.list(manifest$files) || !identical(names(manifest$files), c("response", "grna")) ||
        !identical(lapply(manifest$files, unname), pipeline_count_paths(object)))
        fail("Native backing transport manifest does not match the saved schema-7 object.")
    if (!any(lengths(manifest$files))) fail("A backing directory requires native HDF5 counts.")
    manifest$files
}
pipeline_is_backed <- function(object) any(lengths(pipeline_backing_map(object)) > 0L)
pipeline_save_object <- function(object, file) sceptre::write_sceptre_object(object, file)
pipeline_read_object <- function(file, files, backing = NULL) {
    saved <- readRDS(file)
    pipeline_assert_native_schema(saved)
    if (is.null(backing)) return(sceptre::read_sceptre_object(file))
    matrices <- pipeline_count_matrices(saved)
    # Preserve saved delayed views and seed traversal order. Staged transport
    # names bind each distinct source path, including same-basename files, by immutable content.
    for (modality in names(matrices)) {
        paths <- files[[modality]]
        if (!length(paths)) next
        if (!is.character(paths) || is.null(names(paths)) ||
            anyNA(paths) || anyNA(names(paths)) || any(!grepl("^[a-f0-9]{64}[.]h5$", names(paths))))
            fail("Malformed native HDF5 transport mapping.")
        replacements <- file.path(backing, names(paths))
        if (!all(file.exists(replacements))) fail("Missing staged native HDF5 backing files for ", modality, ".")
        matrices[[modality]] <- DelayedArray::modify_seeds(matrices[[modality]], function(seed) {
            if (isS4(seed) && "filepath" %in% methods::slotNames(seed)) {
                if (!(methods::is(seed, "H5SparseMatrixSeed") || methods::is(seed, "HDF5ArraySeed"))) fail("Unsupported HDF5 seed for relocation.")
                index <- match(as.character(methods::slot(seed, "filepath")), paths)
                if (is.na(index)) fail("HDF5 seed is absent from the transport mapping.")
                methods::slot(seed, "filepath") <- normalizePath(replacements[[index]], mustWork = TRUE)
            }
            seed
        })
    }
    sceptre::read_sceptre_object(file, matrices$response, matrices$grna)
}
# Pristine imported screens have no inference choices yet. This state grants
# transport permission only; every execution mode still needs positive admission.
pipeline_parameters_pending <- function(object) {
    !length(object@preparation@stages) && !any(vapply(object@results, Negate(is.null), logical(1))) &&
        !length(object@spec@run_permutations) &&
        !length(object@spec@resampling_approximation) &&
        !length(object@spec@grna_integration_strategy) &&
        !length(object@spec@formula_object)
}
validate_requested_pipeline_method <- function(object, config, mode) {
    candidate <- object
    if (!is.null(config$analysis)) {
        candidate <- do.call(sceptre::set_analysis_parameters,
            c(list(sceptre_object = object), config$analysis))
    } else if (pipeline_parameters_pending(object)) {
        fail("Supply config$analysis for an unconfigured input object.")
    }
    validate_pipeline_method(candidate, mode)
    invisible(NULL)
}
pipeline_inference_scope <- function(object) {
    if (pipeline_parameters_pending(object)) return(list(configured = FALSE))
    # The selected package owns numerical-method admission and distributed
    # certificates. Bind configured choices without inventing a second policy.
    list(protocol = "sceptre-pipeline-schema7-inference/v1", configured = TRUE,
        permutations = object@spec@run_permutations,
        approximation = object@spec@resampling_approximation,
        integration = object@spec@grna_integration_strategy)
}
installed_runtime_files <- function(root) {
    files <- sort(list.files(root, recursive = TRUE, full.names = TRUE))
    files <- files[!dir.exists(files)]
    relative <- substring(files, nchar(root) + 2L)
    files[!grepl("(^|/)__pycache__(/|$)|[.]py[co]$", relative)]
}
package_identity <- function() {
    root <- system.file(package = "sceptre")
    if (!nzchar(root)) fail("Install the pinned sceptre package first.")
    files <- installed_runtime_files(root)
    hashes <- vapply(files, hash_file, character(1))
    names(hashes) <- substring(files, nchar(root) + 2L)
    deps <- tools::package_dependencies("sceptre", db = utils::installed.packages(), recursive = TRUE)[[1L]]
    versions <- vapply(sort(unique(c("sceptre", "jsonlite", deps))), function(p) {
        if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "unavailable"
    }, character(1))
    identity <- list(package = "sceptre", object_schema = 7L,
         version = as.character(utils::packageVersion("sceptre")),
         installed_sha256 = hash_value(hashes), dependencies = versions,
         R = paste(R.version$major, R.version$minor, R.version$platform))
    identity
}
validate_identity <- function(expected) {
    if (!identical(expected, package_identity()))
        fail("Runtime/package identity mismatch. Rebuild the environment lock and start a new run; do not resume across package changes.")
}
validate_pipeline_method <- function(object, mode = NULL) {
    if (!is.null(mode) && !mode %in% c("direct", "distributed")) fail("Unsupported execution mode.")
    if (identical(mode, "distributed") && !all(c("prepare_execution", "execute_work_unit", "collect_execution") %in% getNamespaceExports("sceptre")))
        fail("The selected package does not export distributed execution.")
    invisible(object)
}
pipeline_assert_native_schema <- function(object) {
    if (!methods::is(object, "sceptre_object") || !identical(object@schema_version, 7L) ||
        !methods::is(object@data, "SingleCellExperiment"))
        fail("Expected a native schema-7 SingleCellExperiment sceptre_object. Reimport older input with the selected package before starting a new run.")
    invisible(object)
}
validate_object <- function(object, mode = NULL) {
    pipeline_assert_native_schema(object)
    methods::validObject(object)
    if (pipeline_parameters_pending(object) && !is.null(mode)) fail("Configure analysis parameters before execution.")
    validate_pipeline_method(object, mode)
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
    object <- validate_object(object); validate_config(config); validate_identity(identity)
    if (dir.exists(dir)) fail("Output directory already exists: ", dir)
    dir.create(dir, recursive = TRUE)
    backed <- pipeline_is_backed(object)
    pipeline_save_object(object, file.path(dir, "sceptre_object.rds"))
    manifest <- list(kind = "sceptre-pipeline-state", schema = 1L, object_schema = object@schema_version,
        stage = "input", completed = character(), package = identity,
        config_sha256 = hash_value(config), object_sha256 = hash_file(file.path(dir, "sceptre_object.rds")),
        backend = if (backed) "native-hdf5" else "memory",
        backing_files = pipeline_backing_map(object), parent_sha256 = NULL,
        scientific_scope = scientific_scope(object),
        inference_scope = pipeline_inference_scope(object),
        import_identity = pipeline_import_identity(object))
    saveRDS(manifest, file.path(dir, "manifest.rds"))
    invisible(manifest)
}
read_bundle <- function(dir, config, identity, backing = NULL) {
    m <- readRDS(file.path(dir, "manifest.rds"))
    if (!is.list(m) || !identical(m$kind, "sceptre-pipeline-state") || !identical(m$schema, 1L) ||
        !identical(m$object_schema, 7L)) fail("Unsupported artifact kind/schema; legacy pipeline work directories cannot be resumed.")
    if (!identical(m$package, identity)) fail("Artifact package identity mismatch.")
    if (!identical(m$config_sha256, hash_value(config))) fail("Artifact configuration mismatch; start from a new input bundle.")
    if (!identical(m$object_sha256, hash_file(file.path(dir, "sceptre_object.rds")))) fail("Artifact object checksum mismatch.")
    if (!m$backend %in% c("native-hdf5", "memory")) fail("Unknown native count backend.")
    object <- pipeline_read_object(file.path(dir, "sceptre_object.rds"), m$backing_files,
        if (identical(m$backend, "native-hdf5")) backing else NULL)
    object <- validate_object(object)
    if (!identical(m$object_schema, object@schema_version)) fail("Artifact object schema mismatch.")
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
    if (!identical(m$inference_scope, pipeline_inference_scope(object)))
        fail("Artifact numerical method/runtime scope mismatch; start a new run.")
    if (!identical(m$import_identity, pipeline_import_identity(object))) fail("Artifact import identity mismatch.")
    list(object = object, manifest = m)
}
run_stage <- function(config, input, output, stage, seed, backing = NULL, identity = package_identity()) {
    validate_config(config); validate_identity(identity)
    if (length(seed) != 1L || is.na(seed) || seed < 0 || seed > .Machine$integer.max || seed != as.integer(seed)) fail("seed must be an integer between 0 and 2147483647.")
    state <- read_bundle(input, config, identity, backing)
    m <- state$manifest; object <- state$object
    if (stage %in% c("calibration", "power", "discovery"))
        validate_pipeline_method(object, "direct")
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
    } else if (identical(stage, "assignment") && is.null(config$assignment) &&
               identical(object@spec@grna_assignment_method, "external")) {
        # The getter verifies the live preparation identity, including design,
        # data, assignments and provenance. A saved completion flag alone is
        # insufficient. Explicit config$assignment always requests reassignment.
        sceptre::get_grna_assignments(object) |> invisible()
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
    object <- validate_object(object)
    # Build in a temporary sibling; failed functions never publish a completed bundle.
    if (dir.exists(output)) fail("Output directory already exists: ", output)
    tmp <- tempfile(".stage-", tmpdir = dirname(output))
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    pipeline_save_object(object, file.path(tmp, "sceptre_object.rds"))
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
    m$backing_files <- pipeline_backing_map(object)
    m$scientific_scope <- scientific_scope(object)
    m$inference_scope <- pipeline_inference_scope(object)
    m$resolved <- list(low_moi = pipeline_low_moi(object), permutations = object@spec@run_permutations,
                       complement = object@spec@control_group_complement,
                       integration = object@spec@grna_integration_strategy)
    saveRDS(m, file.path(tmp, "manifest.rds"))
    capture.output(print(object), file = file.path(tmp, "analysis_summary.txt"))
    writeLines(c(paste("R:", R.version.string), paste("sceptre:", identity$version),
                 paste("installed_sha256:", identity$installed_sha256)), file.path(tmp, "versions.txt"))
    if (!file.rename(tmp, output)) fail("Could not publish completed artifact: ", output)
    invisible(object)
}
