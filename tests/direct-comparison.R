#!/usr/bin/env Rscript
# Usage: R_LIBS=/isolated/library Rscript tests/direct-comparison.R [output-directory]
# Run from the repository root. All statistical work uses the public package API.
source("tests/fixture.R")
source("bin/pipeline.R")

# Compare payloads without data.table's process-local self-reference pointer.
plain_value <- function(x) {
    if (isS4(x)) return(list(class = class(x), slots = stats::setNames(
        lapply(methods::slotNames(x), function(n) plain_value(methods::slot(x, n))),
        methods::slotNames(x))))
    if (is.data.frame(x)) return(list(class = class(x), names = names(x),
        row_names = rownames(x), columns = lapply(x, plain_value)))
    if (is.list(x)) return(lapply(x, plain_value))
    x
}
assert_same <- function(actual, expected, label) {
    if (!identical(plain_value(actual), plain_value(expected))) {
        stop(label, ": ", paste(all.equal(plain_value(actual), plain_value(expected)), collapse = "; "))
    }
}

direct_stage <- function(object, config, stage, seed) {
    args <- switch(stage,
        parameters = config$analysis,
        assignment = c(config$assignment, list(parallel = FALSE, print_progress = FALSE)),
        qc = config$qc,
        calibration = c(config$calibration, list(parallel = FALSE,
            print_progress = FALSE, output_amount = config$execution$output_amount)),
        power = list(parallel = FALSE, print_progress = FALSE,
            output_amount = config$execution$output_amount),
        discovery = list(parallel = FALSE, print_progress = FALSE,
            output_amount = config$execution$output_amount))
    fun <- switch(stage, parameters = sceptre::set_analysis_parameters,
        assignment = sceptre::assign_grnas, qc = sceptre::run_qc,
        calibration = sceptre::run_calibration_check, power = sceptre::run_power_check,
        discovery = sceptre::run_discovery_analysis)
    do.call(fun, c(list(sceptre_object = object), args))
}

# Keep an independent direct stream when driver and reference share this R process.
rng_snapshot <- function() list(kind = RNGkind(), state = .Random.seed)
rng_restore <- function(rng) {
    do.call(RNGkind, as.list(rng$kind))
    assign(".Random.seed", rng$state, envir = .GlobalEnv)
}
assert_manifest_rng <- function(dir, expected, label) {
    manifest <- readRDS(file.path(dir, "manifest.rds"))
    assert_same(manifest$rng_kind, expected$kind, paste(label, "RNG kind"))
    assert_same(manifest$rng_state, expected$state, paste(label, "continuous RNG state"))
}
assert_final_reference <- function(actual, reference, label) {
    assert_same(sceptre::get_grna_assignments(actual), sceptre::get_grna_assignments(reference),
        paste(label, "single-session assignments"))
    for (analysis in names(actual@results@records)) {
        assert_same(sceptre::get_result(actual, analysis), sceptre::get_result(reference, analysis),
            paste(label, "single-session", analysis))
        assert_same(actual@results@records[[analysis]]$provenance$plan,
            reference@results@records[[analysis]]$provenance$plan,
            paste(label, "single-session plan", analysis))
    }
}

# Actual input CLI must reopen a safely saved source after its descriptor paths
# disappear. The intentionally invalid raw-active RDS is only a negative fixture.
assert_prepare_input_cli <- function(source, config, relocated, expected_identity,
                                     expected_rows, invalid_active, directory) {
    dir.create(directory)
    saveRDS(config, file.path(directory, "config.rds"))
    saveRDS(package_identity(), file.path(directory, "lock.rds"))
    script <- normalizePath("bin/prepare_input.R")
    invoke <- function(object_path, output, label) {
        arguments <- c(script, normalizePath(object_path),
            normalizePath(file.path(directory, "config.rds")), output,
            normalizePath(file.path(directory, "lock.rds")), normalizePath(relocated))
        system2(file.path(R.home("bin"), "Rscript"),
            args = vapply(arguments, shQuote, character(1)),
            stdout = file.path(directory, paste0(label, ".stdout.log")),
            stderr = file.path(directory, paste0(label, ".stderr.log")))
    }
    output <- file.path(directory, "prepared")
    status <- invoke(source, output, "reopen")
    if (status != 0L) stop("prepare_input CLI reopen failed; inspect ", directory)
    stored <- readRDS(file.path(output, "sceptre_object.rds"))
    stopifnot(is.null(stored@data@response_matrix@handle),
        is.null(stored@data@grna_matrix@handle))
    actual <- sceptre::read_ondisc_backed_sceptre_object(file.path(output, "sceptre_object.rds"),
        file.path(relocated, "response.odm"), file.path(relocated, "grna.odm"))
    assert_same(actual@data@identity, expected_identity, "input CLI relocated import identity")
    store <- sceptre::get_response_matrix(actual)
    assert_same(lapply(seq_len(nrow(store)), function(i) as.numeric(store[i, ])),
        expected_rows, "input CLI relocated counts")
    invalid_output <- file.path(directory, "rejected-raw-active")
    status <- invoke(invalid_active, invalid_output, "raw-active")
    stopifnot(status != 0L, !file.exists(invalid_output))
    diagnostic <- paste(readLines(file.path(directory, "raw-active.stderr.log")), collapse = "\n")
    stopifnot(grepl("process handle", diagnostic, fixed = TRUE))
    invisible(TRUE)
}

args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[[1L]] else tempfile("pipeline-direct-")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
seed <- 271828L
report <- list(package_version = as.character(utils::packageVersion("sceptre")),
    package_path = find.package("sceptre"), R = R.version.string,
    runtime = package_identity(), cases = list())
for (name in names(pipeline_fixture_cases())) {
    fixture <- do.call(pipeline_fixture, pipeline_fixture_cases()[[name]])
    config <- fixture$config
    case_dir <- file.path(out, name)
    dir.create(case_dir, recursive = TRUE)
    saveRDS(config, file.path(case_dir, "config.rds"))
    input <- file.path(case_dir, "import")
    create_input(fixture$object, input, config)
    direct <- fixture$object
    set.seed(seed)
    direct_rng <- rng_snapshot()
    for (stage in c("parameters", "assignment", "qc", "calibration", "power", "discovery")) {
        target <- file.path(case_dir, stage)
        run_stage(config, input, target, stage, seed)
        rng_restore(direct_rng)
        direct <- direct_stage(direct, config, stage, seed)
        direct_rng <- rng_snapshot()
        if (stage == "qc") qc_rng <- direct_rng
        assert_manifest_rng(target, direct_rng, paste(name, stage))
        actual <- readRDS(file.path(target, "sceptre_object.rds"))
        stopifnot(identical(actual@schema_version, 3L))
        assert_same(actual@spec@run_permutations,
            fixture$mechanism == "permutations", paste(name, stage, "mechanism"))
        assert_same(actual@spec@control_group_complement,
            fixture$control == "complement", paste(name, stage, "controls"))
        assert_same(actual@data@low_moi, fixture$moi == "low", paste(name, stage, "MOI"))
        assert_same(actual@spec, direct@spec, paste(name, stage, "settings"))
        if (stage %in% c("assignment", "qc", "calibration", "power", "discovery")) {
            assert_same(actual@spec@grna_assignment_method, fixture$config$assignment$method,
                paste(name, stage, "assignment method"))
            assert_same(sceptre::get_grna_assignments(actual),
                sceptre::get_grna_assignments(direct), paste(name, stage, "assignments"))
        }
        if (stage %in% c("qc", "calibration", "power", "discovery")) {
            assert_same(actual@preparation@analysis_cells, direct@preparation@analysis_cells,
                paste(name, stage, "ordered cells"))
            assert_same(actual@preparation@design_matrix, direct@preparation@design_matrix,
                paste(name, stage, "aligned design"))
            stopifnot(any(!actual@preparation@discovery_pairs_with_info$pass_qc))
        }
        for (analysis in names(actual@results@records)) {
            record <- actual@results@records[[analysis]]
            if (is.null(record)) next
            stopifnot(identical(record$scope, "complete_family"))
            assert_same(sceptre::get_result(actual, analysis),
                sceptre::get_result(direct, analysis), paste(name, stage, analysis, "full table"))
            assert_empirical_budget(record$provenance$plan,
                if (analysis == "run_calibration_check") "calibration" else "analysis", config)
            assert_same(record$provenance$plan, direct@results@records[[analysis]]$provenance$plan,
                paste(name, stage, analysis, "realized budget and scope"))
        }
        input <- target
    }
    # An ordinary uninterrupted R workflow has exactly one initial seed.
    driver_final <- actual
    single_session <- fixture$object
    set.seed(seed)
    for (stage in c("parameters", "assignment", "qc", "calibration", "power", "discovery")) {
        single_session <- direct_stage(single_session, config, stage, seed)
    }
    assert_final_reference(driver_final, single_session, name)
    assert_same(rng_snapshot(), direct_rng, paste(name, "single-session final RNG"))
    # Public power/discovery are independently valid immediately after QC.
    for (stage in c("power", "discovery")) {
        target <- file.path(case_dir, paste0(stage, "_without_calibration"))
        run_stage(config, file.path(case_dir, "qc"), target, stage, seed)
        rng_restore(qc_rng)
        standalone <- direct_stage(readRDS(file.path(case_dir, "qc", "sceptre_object.rds")),
            config, stage, seed)
        standalone_rng <- rng_snapshot()
        assert_manifest_rng(target, standalone_rng, paste(name, stage, "standalone"))
        actual <- readRDS(file.path(target, "sceptre_object.rds"))
        analysis <- paste0("run_", if (stage == "power") "power_check" else "discovery_analysis")
        assert_empirical_budget(actual@results@records[[analysis]]$provenance$plan, stage, config)
        assert_same(actual@results@records[[analysis]]$provenance$plan,
            driver_final@results@records[[analysis]]$provenance$plan,
            paste(name, stage, "standalone complete budget plan"))
        assert_same(sceptre::get_result(actual, analysis), sceptre::get_result(standalone, analysis),
            paste(name, stage, "without calibration"))
    }
    final_table <- sceptre::get_result(actual, "run_discovery_analysis")
    stopifnot(nrow(final_table) == if (fixture$integration == "singleton") 10L else 5L,
        any(!final_table$pass_qc), any(is.finite(final_table$p_value)))
    report$cases[[name]] <- list(passed = TRUE,
        discovery_rows = nrow(final_table),
        failed_qc_rows = sum(!final_table$pass_qc),
        mechanism = fixture$mechanism, control = fixture$control,
        integration = fixture$integration,
        discovery_plan = actual@results@records$run_discovery_analysis$provenance$plan)
    saveRDS(report, file.path(out, "direct-comparison.rds"))
    message("PASS ", name)
}
message("All nine in-memory complete-family comparisons passed: ", normalizePath(out))

# Rejected operations must leave no successful artifact behind.
expect_failure <- function(code, pattern, output) {
    error <- tryCatch({ force(code); NULL }, error = identity)
    stopifnot(inherits(error, "error"),
        grepl(pattern, conditionMessage(error), ignore.case = TRUE), !dir.exists(output))
    invisible(conditionMessage(error))
}
failure_dir <- file.path(out, "failures")
dir.create(failure_dir)
f <- pipeline_fixture()
create_input(f$object, file.path(failure_dir, "input"), f$config)
failed_output <- file.path(failure_dir, "incomplete-output")
expect_failure(run_stage(f$config, file.path(failure_dir, "input"), failed_output,
    "power", seed), "requires", failed_output)
invalid_config <- f$config
invalid_config$unknown <- list()
failed_output <- file.path(failure_dir, "invalid-config-output")
expect_failure(run_stage(invalid_config, file.path(failure_dir, "input"), failed_output,
    "parameters", seed), "Unknown configuration", failed_output)
changed_config <- f$config
changed_config$analysis$multiple_testing_alpha <- 0.05
failed_output <- file.path(failure_dir, "changed-config-output")
expect_failure(run_stage(changed_config, file.path(failure_dir, "input"), failed_output,
    "parameters", seed), "configuration mismatch", failed_output)
changed_identity <- package_identity()
changed_identity$installed_sha256 <- "incorrect-runtime"
failed_output <- file.path(failure_dir, "changed-runtime-output")
expect_failure(run_stage(f$config, file.path(failure_dir, "input"), failed_output,
    "parameters", seed, identity = changed_identity), "identity mismatch", failed_output)
copy_bundle <- function(source, target) {
    dir.create(target)
    stopifnot(all(file.copy(list.files(source, full.names = TRUE), target)))
}
# Deliberately advance a saved stream without changing scientific state. This
# boundary test distinguishes restoration from resetting the same initial seed,
# even when a package branch preserves its caller's R RNG state internally.
rng_config <- readRDS(file.path(out, "low_nt_permutation", "config.rds"))
rng_input <- file.path(out, "low_nt_permutation", "parameters")
failed_output <- file.path(failure_dir, "changed-seed-output")
expect_failure(run_stage(rng_config, rng_input, failed_output, "assignment", seed + 1L),
    "RNG handoff mismatch", failed_output)
shifted <- file.path(failure_dir, "advanced-stream-input")
copy_bundle(rng_input, shifted)
m <- readRDS(file.path(shifted, "manifest.rds"))
rng_restore(list(kind = m$rng_kind, state = m$rng_state))
invisible(stats::runif(13L))
shifted_rng <- rng_snapshot()
m$rng_state <- shifted_rng$state
saveRDS(m, file.path(shifted, "manifest.rds"))
shifted_output <- file.path(failure_dir, "advanced-stream-assignment")
run_stage(rng_config, shifted, shifted_output, "assignment", seed)
rng_restore(shifted_rng)
shifted_direct <- direct_stage(readRDS(file.path(shifted, "sceptre_object.rds")),
    rng_config, "assignment", seed)
assert_manifest_rng(shifted_output, rng_snapshot(), "advanced saved stream")
assert_same(sceptre::get_grna_assignments(readRDS(file.path(shifted_output, "sceptre_object.rds"))),
    sceptre::get_grna_assignments(shifted_direct), "advanced saved stream assignments")
corrupt <- file.path(failure_dir, "corrupt")
copy_bundle(file.path(failure_dir, "input"), corrupt)
saveRDS(NULL, file.path(corrupt, "sceptre_object.rds"))
failed_output <- file.path(failure_dir, "corrupt-output")
expect_failure(run_stage(f$config, corrupt, failed_output,
    "parameters", seed), "checksum mismatch", failed_output)
wrong_schema <- file.path(failure_dir, "wrong-schema")
copy_bundle(file.path(failure_dir, "input"), wrong_schema)
m <- readRDS(file.path(wrong_schema, "manifest.rds"))
m$schema <- 999L
saveRDS(m, file.path(wrong_schema, "manifest.rds"))
failed_output <- file.path(failure_dir, "wrong-schema-output")
expect_failure(run_stage(f$config, wrong_schema, failed_output,
    "parameters", seed), "kind/schema", failed_output)
# Exercise a real package failure after valid assignment and QC, rather than a stub.
bad <- f$config
bad$calibration$calibration_group_size <- 10000L
previous <- file.path(failure_dir, "bad-calibration-input")
create_input(f$object, previous, bad)
for (stage in c("parameters", "assignment", "qc")) {
    next_dir <- file.path(failure_dir, paste0("bad-", stage))
    run_stage(bad, previous, next_dir, stage, seed)
    previous <- next_dir
}
failed_output <- file.path(failure_dir, "failed-family-output")
expect_failure(run_stage(bad, previous, failed_output, "calibration", seed),
    "calibration_group_size|non-targeting", failed_output)
stopifnot(is.null(readRDS(file.path(previous, "sceptre_object.rds"))@results@records$run_calibration_check))
report$failure_checks <- "incomplete, unknown config, changed config/runtime, checksum/schema corruption, real family failure without publication"
saveRDS(report, file.path(out, "direct-comparison.rds"))
message("PASS artifact failure checks")

# Optional backend qualification is explicit. Set REQUIRE_ONDISC=true in the
# supported-backend job so a missing/incompatible ondisc install fails that job.
capability <- tryCatch({
    probe <- get0("require_ondisc_capabilities", envir = asNamespace("sceptre"), inherits = FALSE)
    if (is.function(probe)) probe() else {
        if (!requireNamespace("ondisc", quietly = TRUE)) stop("ondisc is not installed")
        if (!exists("create_odm_from_r_matrix_internal", envir = asNamespace("ondisc"), inherits = FALSE))
            stop("ondisc lacks the supported matrix-import API")
    }
    NULL
}, error = identity)
if (inherits(capability, "error")) {
    report$ondisc <- list(passed = FALSE, skipped = TRUE,
        reason = conditionMessage(capability))
    if (identical(Sys.getenv("REQUIRE_ONDISC"), "true")) stop(capability)
    message("SKIP optional ondisc: ", conditionMessage(capability))
} else {
    for (case in c("low_nt_permutation", "high_permutation")) {
        backed_dir <- file.path(out, paste0(case, "_ondisc"))
        dir.create(backed_dir)
        backing <- file.path(backed_dir, "original")
        dir.create(backing)
        f <- do.call(pipeline_fixture, c(pipeline_fixture_cases()[[case]],
            list(backed = TRUE, directory = backing)))
        # Backed CRT is explicitly unsupported by the package.
        unsupported <- f$config
        unsupported$analysis$resampling_mechanism <- "crt"
        unsupported_input <- file.path(backed_dir, "unsupported-crt-import")
        create_input(f$object, unsupported_input, unsupported)
        unsupported_output <- file.path(backed_dir, "unsupported-crt-output")
        expect_failure(run_stage(unsupported, unsupported_input, unsupported_output,
            "parameters", seed, backing = backing), "resampling_mechanism.*permutations", unsupported_output)
        input <- file.path(backed_dir, "import")
        create_input(f$object, input, f$config)
        stored <- readRDS(file.path(input, "sceptre_object.rds"))
        stopifnot(is.null(stored@data@response_matrix@handle),
            is.null(stored@data@grna_matrix@handle))
        relocated <- file.path(backed_dir, "relocated")
        dir.create(relocated)
        stopifnot(all(file.copy(file.path(backing, c("response.odm", "grna.odm")), relocated)))
        original_hash <- vapply(file.path(relocated, c("response.odm", "grna.odm")), hash_file, character(1))
        direct <- sceptre::read_ondisc_backed_sceptre_object(
            file.path(input, "sceptre_object.rds"),
            file.path(relocated, "response.odm"), file.path(relocated, "grna.odm"))
        read_rows <- function(object) {
            store <- sceptre::get_response_matrix(object)
            lapply(seq_len(nrow(store)), function(i) as.numeric(store[i, ]))
        }
        assert_same(read_rows(direct), read_rows(f$object), paste(case, "relocated counts"))
        direct_input <- direct
        set.seed(seed)
        direct_rng <- rng_snapshot()
        for (stage in c("parameters", "assignment", "qc", "calibration", "power", "discovery")) {
            target <- file.path(backed_dir, stage)
            run_stage(f$config, input, target, stage, seed, backing = relocated)
            rng_restore(direct_rng)
            direct <- direct_stage(direct, f$config, stage, seed)
            direct_rng <- rng_snapshot()
            assert_manifest_rng(target, direct_rng, paste(case, stage, "backed"))
            stored <- readRDS(file.path(target, "sceptre_object.rds"))
            stopifnot(is.null(stored@data@response_matrix@handle),
                is.null(stored@data@grna_matrix@handle))
            actual <- sceptre::read_ondisc_backed_sceptre_object(
                file.path(target, "sceptre_object.rds"),
                file.path(relocated, "response.odm"), file.path(relocated, "grna.odm"))
            assert_same(actual@preparation@analysis_cells, direct@preparation@analysis_cells,
                paste(case, stage, "backed alignment"))
            for (analysis in names(actual@results@records)) {
                assert_same(sceptre::get_result(actual, analysis), sceptre::get_result(direct, analysis),
                    paste(case, stage, "backed", analysis))
            }
            input <- target
        }
        single_session <- direct_input
        set.seed(seed)
        for (stage in c("parameters", "assignment", "qc", "calibration", "power", "discovery")) {
            single_session <- direct_stage(single_session, f$config, stage, seed)
        }
        assert_final_reference(actual, single_session, paste(case, "backed"))
        assert_same(rng_snapshot(), direct_rng, paste(case, "backed final RNG"))
        assert_same(vapply(names(original_hash), hash_file, character(1)), original_hash,
            paste(case, "backing files unchanged"))
        # Retain immutable expected values, then release the sole references to
        # the original fixture handles before making their descriptor paths stale.
        expected_identity <- f$object@data@identity
        expected_rows <- read_rows(f$object)
        invalid_active <- file.path(backed_dir, "intentionally-invalid-raw-active.rds")
        saveRDS(f$object, invalid_active)
        f$object <- NULL
        invisible(gc())
        stopifnot(file.rename(backing, paste0(backing, "-preserved")), !dir.exists(backing))
        assert_prepare_input_cli(file.path(backed_dir, "import", "sceptre_object.rds"),
            f$config, relocated, expected_identity, expected_rows, invalid_active,
            file.path(backed_dir, "prepare-input-cli"))
        assert_same(vapply(names(original_hash), hash_file, character(1)), original_hash,
            paste(case, "input CLI backing files unchanged"))
        message("PASS ", case, " input CLI stale-path reopen and raw-active rejection")
        message("PASS ", case, " save/reopen/relocation")
    }
    report$ondisc <- list(passed = TRUE, skipped = FALSE,
        version = as.character(utils::packageVersion("ondisc")),
        cases = c("low_nt_permutation", "high_permutation"))
}
saveRDS(report, file.path(out, "direct-comparison.rds"))
