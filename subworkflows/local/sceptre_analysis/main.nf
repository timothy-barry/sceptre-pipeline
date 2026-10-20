include { SCEPTRE_STAGE } from '../../../modules/local/sceptre_stage/main'
include { SCEPTRE_PREPARE } from '../../../modules/local/sceptre_prepare/main'
include { SCEPTRE_WORKER } from '../../../modules/local/sceptre_worker/main'
include { SCEPTRE_COLLECT } from '../../../modules/local/sceptre_collect/main'

workflow SCEPTRE_ANALYSIS {
    take:
    state
    config
    lock
    backing
    tools_dir
    stage
    seed
    execution_mode
    n_units
    main:
    single_state = state.toList().map { states ->
        if (states.size() != 1) error 'An analysis invocation requires exactly one certified screen state.'
        states[0]
    }
    if (execution_mode == 'reference') {
        SCEPTRE_STAGE(single_state, config, lock, backing, tools_dir, stage, seed)
        completed = SCEPTRE_STAGE.out.state
    } else {
        SCEPTRE_PREPARE(single_state, config, lock, backing, tools_dir, stage, seed, n_units)
        unit_ids = SCEPTRE_PREPARE.out.units.splitText().map { line ->
            def id = line.trim()
            if (!(id ==~ /unit-[0-9]{6}/)) error "Invalid certified unit id: ${id}"
            id
        }
        SCEPTRE_WORKER(single_state, config, lock, backing, tools_dir,
            SCEPTRE_PREPARE.out.execution, stage, seed, unit_ids)
        SCEPTRE_COLLECT(single_state, config, lock, backing, tools_dir,
            SCEPTRE_PREPARE.out.execution, SCEPTRE_WORKER.out.proposal.toList(), stage, seed)
        completed = SCEPTRE_COLLECT.out.state
    }
    emit:
    state = completed
}
