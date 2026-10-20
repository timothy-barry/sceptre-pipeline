include { SCEPTRE_EXPORT } from '../../../modules/local/sceptre_export/main'
include { SCEPTRE_VALIDATE } from '../../../modules/local/sceptre_validate/main'
include { SCEPTRE_STAGE as PARAMETERS } from '../../../modules/local/sceptre_stage/main'
include { SCEPTRE_STAGE as ASSIGNMENT } from '../../../modules/local/sceptre_stage/main'
include { SCEPTRE_STAGE as QC } from '../../../modules/local/sceptre_stage/main'
include { SCEPTRE_ANALYSIS as CALIBRATION } from '../sceptre_analysis/main'
include { SCEPTRE_ANALYSIS as POWER } from '../sceptre_analysis/main'
include { SCEPTRE_ANALYSIS as DISCOVERY } from '../sceptre_analysis/main'

workflow SCEPTRE {
    take:
    state
    config
    lock
    backing
    tools_dir
    previous_signature
    run_options
    implementation_sources
    analyses
    stop_after
    seed
    execution_mode
    n_units

    main:
    SCEPTRE_VALIDATE(state, config, lock, backing, tools_dir, previous_signature, run_options, implementation_sources)
    validated = state.combine(SCEPTRE_VALIDATE.out.ready).map { meta, bundle, ready -> tuple(meta, bundle) }
    PARAMETERS(validated, config, lock, backing, tools_dir, 'parameters', seed)
    current = PARAMETERS.out.state
    if (stop_after != 'parameters') {
        ASSIGNMENT(current, config, lock, backing, tools_dir, 'assignment', seed)
        current = ASSIGNMENT.out.state
        if (stop_after != 'assignment') {
            QC(current, config, lock, backing, tools_dir, 'qc', seed)
            current = QC.out.state
            if (stop_after == 'analysis') {
                if ('calibration' in analyses) {
                    CALIBRATION(current, config, lock, backing, tools_dir, 'calibration', seed, execution_mode, n_units)
                    current = CALIBRATION.out.state
                }
                if ('power' in analyses) {
                    POWER(current, config, lock, backing, tools_dir, 'power', seed, execution_mode, n_units)
                    current = POWER.out.state
                }
                if ('discovery' in analyses) {
                    DISCOVERY(current, config, lock, backing, tools_dir, 'discovery', seed, execution_mode, n_units)
                    current = DISCOVERY.out.state
                }
            }
        }
    }
    if (stop_after != 'parameters') {
        SCEPTRE_EXPORT(current, config, lock, backing, tools_dir)
    }
    emit:
    state = current
}
