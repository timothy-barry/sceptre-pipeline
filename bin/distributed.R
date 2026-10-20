# Scheduling adapter around the package-owned certified protocol-1 executor.
# Nothing here selects scientific subfamilies or finalizes worker rows.
analysis_name <- function(stage) switch(stage, calibration = 'run_calibration_check',
    power = 'run_power_check', discovery = 'run_discovery_analysis', fail('Unknown analysis stage: ', stage))
restore_execution_rng <- function(m, seed) {
    if (!identical(m$seed, as.integer(seed)) || is.null(m$rng_kind) || is.null(m$rng_state))
        fail('Missing or incompatible RNG state for distributed execution.')
    do.call(RNGkind, as.list(m$rng_kind))
    assign('.Random.seed', m$rng_state, envir = .GlobalEnv)
}
load_execution_input <- function(config, input, lock, backing, stage, seed) {
    validate_config(config); validate_identity(lock)
    if (!all(c('prepare_execution', 'execute_work_unit', 'collect_execution') %in% getNamespaceExports('sceptre')))
        fail('This package does not export certified distributed execution. Use --execution_mode reference or install the qualified candidate.')
    state <- read_bundle(input, config, lock, backing)
    if (!('qc' %in% state$manifest$completed) || stage %in% state$manifest$completed)
        fail('Distributed preparation requires current completed QC and an uncompleted analysis family.')
    analysis_name(stage)
    restore_execution_rng(state$manifest, seed)
    state
}
prepare_distributed <- function(config, input, output, stage, seed, n_units, backing, lock) {
    state <- load_execution_input(config, input, lock, backing, stage, seed)
    args <- list(sceptre_object = state$object, analysis = analysis_name(stage),
        n_work_units = n_units, output_amount = if (is.null(config$execution$output_amount)) 1L else config$execution$output_amount)
    if (stage == 'calibration') args <- c(args, config$calibration)
    execution <- do.call(sceptre::prepare_execution, args)
    ids <- vapply(execution$units, function(unit) unit$id, character(1))
    if (!length(ids) || anyDuplicated(ids) || any(!grepl('^unit-[0-9]{6}$', ids))) fail('Unsupported or duplicate package work-unit IDs.')
    if (dir.exists(output)) fail('Execution output already exists.')
    tmp <- tempfile('.prepare-', tmpdir = dirname(output)); dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    saveRDS(execution, file.path(tmp, 'execution.rds'))
    wrapper <- list(kind = 'sceptre-pipeline-execution', schema = 1L, stage = stage,
        package = lock, config_sha256 = hash_value(config),
        parent_sha256 = hash_file(file.path(input, 'manifest.rds')),
        execution_sha256 = hash_file(file.path(tmp, 'execution.rds')),
        rng_kind = RNGkind(), rng_state = get('.Random.seed', envir = .GlobalEnv),
        seed = as.integer(seed), unit_ids = ids)
    saveRDS(wrapper, file.path(tmp, 'manifest.rds'))
    writeLines(ids, file.path(tmp, 'unit_ids.txt'))
    if (!file.rename(tmp, output)) fail('Could not publish certified execution plan.')
    invisible(execution)
}
read_execution <- function(plan_dir, input, config, stage, seed, lock) {
    m <- readRDS(file.path(plan_dir, 'manifest.rds'))
    if (!identical(m$kind, 'sceptre-pipeline-execution') || !identical(m$schema, 1L) ||
        !identical(m$stage, stage) || !identical(m$package, lock) ||
        !identical(m$config_sha256, hash_value(config)) ||
        !identical(m$parent_sha256, hash_file(file.path(input, 'manifest.rds'))) ||
        !identical(m$execution_sha256, hash_file(file.path(plan_dir, 'execution.rds'))))
        fail('Distributed execution artifact kind/schema/context/runtime mismatch.')
    restore_execution_rng(m, seed)
    execution <- readRDS(file.path(plan_dir, 'execution.rds'))
    ids <- vapply(execution$units, function(unit) unit$id, character(1))
    if (!identical(ids, m$unit_ids)) fail('Execution unit list mismatch.')
    list(execution = execution, manifest = m)
}
run_distributed_unit <- function(config, input, plan_dir, output, stage, seed, unit_id, backing, lock) {
    state <- load_execution_input(config, input, lock, backing, stage, seed)
    prepared <- read_execution(plan_dir, input, config, stage, seed, lock)
    if (!unit_id %in% prepared$manifest$unit_ids) fail('Unknown certified work-unit ID.')
    proposal <- sceptre::execute_work_unit(state$object, prepared$execution, unit_id)
    if (file.exists(output)) fail('Proposal output already exists.')
    tmp <- tempfile('.proposal-', tmpdir = dirname(output))
    on.exit(unlink(tmp), add = TRUE)
    saveRDS(proposal, tmp)
    if (!file.rename(tmp, output)) fail('Could not publish completed work proposal.')
    invisible(proposal)
}
collect_distributed <- function(config, input, plan_dir, proposal_files, output, stage, seed, backing, lock) {
    state <- load_execution_input(config, input, lock, backing, stage, seed)
    prepared <- read_execution(plan_dir, input, config, stage, seed, lock)
    # Package collector validates identities, exact row/unit coverage, raw metadata,
    # compact fit compatibility and canonical integration/correction/commit.
    object <- sceptre::collect_execution(state$object, prepared$execution, lapply(proposal_files, readRDS))
    m <- state$manifest
    m$execution <- list(mode = 'distributed', protocol = prepared$execution$protocol,
        identity = prepared$execution$identity, units = prepared$manifest$unit_ids,
        plan_sha256 = prepared$manifest$execution_sha256)
    write_completed_bundle(object, m, input, output, stage, seed, lock)
}
