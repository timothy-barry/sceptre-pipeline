process SCEPTRE_VALIDATE {
    tag "${meta.id}:validate"
    label 'process_single'
    publishDir "${params.outdir}", mode: 'copy', overwrite: false
    cache false // Check actual runtime even on -resume; scientific tasks remain cacheable.

    input:
    tuple val(meta), path(state, name: 'input_state')
    path config, name: 'analysis_config.rds'
    path lock, name: 'environment_lock.rds'
    path backing, name: 'backing'
    path tools_dir, name: 'pipeline_bin'
    path previous_signature, name: 'previous_signature.rds'
    val run_options
    path implementation_sources, name: 'pipeline_source/file????'

    output:
    val true, emit: ready
    path 'run_signature.rds', emit: signature

    script:
    """
    Rscript --vanilla pipeline_bin/validate_state.R analysis_config.rds input_state environment_lock.rds backing '${run_options}' previous_signature.rds pipeline_source
    """
}
